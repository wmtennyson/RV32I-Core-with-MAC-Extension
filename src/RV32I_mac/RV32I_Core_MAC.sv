`timescale 1ns / 1ps

module RV32I_Core (
    input  logic        clk,
    input  logic        rst,

    // Instruction memory (read-only, synchronous 1-cycle latency)
    output logic [31:0] imem_addr,
    output logic        imem_en,
    input  logic [31:0] imem_rdata,

    // Data memory
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    output logic [3:0]  dmem_wstrb,
    output logic        dmem_we,
    output logic        dmem_re,
    input  logic [31:0] dmem_rdata,

    // Debug / done
    output logic        done_o,
    output logic        trap_o
);

    // ============================ Global pipeline control ============================
    logic           stall,                     // Total stall: decode hazard or MEM load wait
                    stall_hz,                  // Decode-stage hazard stall
                    mem_stall,                 // MEM-stage synchronous-load stall
                    flush, 
                    flush_dec,          // Redirect after MEM stall clears
                    kill,  
                    kill_dec;           // Taken-branch kill after MEM stall clears
    logic [31:0]    branch_target, 
                    branch_target_dec;

    logic           halt;             // Latched done/trap — stops side-effects
    assign halt = done_o | trap_o;

    // ============================ FETCH STAGE ============================ 
    logic [31:0] if_pc, if_pc4;

    fetch_unit FeU (
        .clk                (clk), 
        .rst                (rst),
        
        .stall_i            (stall), 
        .flush_i            (flush), 
        .branch_target_i    (branch_target),
        .bram_addr_o        (imem_addr), 
        .bram_en_o          (imem_en),
        .if_pc_o            (if_pc), 
        .if_pc_plus4_o      (if_pc4)
    );

    // ============================  IF/ID REGISTER ============================ 
    logic           id_valid;
    logic [31:0]    id_instr, 
                    id_pc, 
                    id_pc4;

    if_id_reg IF_ID_REG (
        .clk                (clk), 
        .rst                (rst),
        
        .stall_i            (stall), 
        .flush_i            (flush),
        .if_pc              (if_pc), 
        .if_pc4             (if_pc4), 
        .bram_rdata_i       (imem_rdata),
        .id_instr_valid     (id_valid), 
        .id_instr           (id_instr),
        .id_pc              (id_pc), 
        .id_pc4             (id_pc4)
    );

    // ============================ DECODE STAGE ============================ 

    // Writeback → Decode (register file write)
    logic        wb_rf_we;
    logic [4:0]  wb_rf_waddr;
    logic [31:0] wb_rf_wdata;

    // Pipeline stage outputs (declared here, driven by registers below)
    // -- ID/EX register outputs
    logic           ex_valid, 
                    ex_regwrite, 
                    ex_mem_read, 
                    ex_mem_write,
                    ex_wb_pc4_sel, 
                    ex_lui,
                    ex_opA_sel, 
                    ex_opB_sel, 
                    ex_wb_sel;
    logic [4:0]     ex_rs1, 
                    ex_rs2, 
                    ex_rd;
    logic [31:0]    ex_pc, 
                    ex_pc4, 
                    ex_rs1_val, 
                    ex_rs2_val, 
                    ex_imm;
    logic [31:0]    ex_instr;
    logic [2:0]     ex_funct3;
    logic [6:0]     ex_funct7;
    logic [2:0]     ex_alu_op,
                    ex_MAC_op;
    logic           ex_branch, 
                    ex_jump, 
                    ex_is_jalr;

    // -- EX/MEM register outputs
    logic           mem_valid, 
                    mem_regwrite, 
                    mem_mem_read, 
                    mem_mem_write,
                    mem_wb_sel, 
                    mem_wb_pc4_sel;
    logic [4:0]     mem_rd;
    logic [31:0]    mem_alu_out, 
                    mem_store_data, 
                    mem_pc4, 
                    mem_instr;
    logic [2:0]     mem_funct3;

    // -- WB outputs (from WriteBack_Unit, after gating)
    logic           wb_regwrite;
    logic [4:0]     wb_rd;
    logic [31:0]    wb_value;

    // Forwarding Unit
    logic [1:0]     ex_fwd_a, 
                    ex_fwd_b,
                    br_fwd_a, 
                    br_fwd_b;
    logic           br_fwd_a_use_pc4, 
                    br_fwd_b_use_pc4;

    Forwarding_Unit FwU (
    
        // ID-stage source regs (for branch forwarding)
        .if_id_rs1          (id_instr[19:15]),
        .if_id_rs2          (id_instr[24:20]),
        
        // EX-stage source regs (for ALU forwarding)
        .id_ex_rs1          (ex_rs1),
        .id_ex_rs2          (ex_rs2),
        
        // Producer info: EX (ID/EX regs)
        .id_ex_rd           (ex_rd),
        .id_ex_regwrite     (ex_regwrite),
        .id_ex_mem_read     (ex_mem_read),
        .id_ex_wb_pc4_sel   (ex_wb_pc4_sel),
        
        // Producer info: MEM (EX/MEM regs)
        .ex_mem_rd          (mem_rd),
        .ex_mem_regwrite    (mem_regwrite),
        .ex_mem_mem_read    (mem_mem_read),
        .ex_mem_wb_pc4_sel  (mem_wb_pc4_sel),
        
        // Producer info: WB
        .mem_wb_rd          (wb_rd),
        .mem_wb_regwrite    (wb_regwrite),
        
        // EX-stage ALU forwarding
        .ex_fwd_a           (ex_fwd_a),
        .ex_fwd_b           (ex_fwd_b),
        
        // ID-stage branch forwarding
        .br_fwd_a           (br_fwd_a),
        .br_fwd_b           (br_fwd_b),
        .br_fwd_a_use_pc4   (br_fwd_a_use_pc4),
        .br_fwd_b_use_pc4   (br_fwd_b_use_pc4)
    );

    // EX-stage ALU result (combinational, used for branch forwarding from EX)
    logic [31:0] ex_alu_out;

    // Decode Unit outputs → ID/EX register
    logic           id_valid_out;
    logic [31:0]    id_rs1_val, 
                    id_rs2_val, 
                    id_imm;
    logic [4:0]     id_rs1, 
                    id_rs2, 
                    id_rd;
    logic [2:0]     id_funct3;
    logic [6:0]     id_funct7;
    logic           id_regwrite, 
                    id_mem_read, 
                    id_mem_write,
                    id_branch, 
                    id_jump, 
                    id_is_jalr, 
                    id_lui,
                    id_opA_sel, 
                    id_opB_sel, 
                    id_wb_sel, 
                    id_wb_pc4_sel;
    logic [2:0]     id_alu_op,
                    id_MAC_op;

    Decode_Unit DeU (
        .clk                    (clk), 
        .rst                    (rst),
        
        .instr_valid_i          (id_valid), 
        .instr_i                (id_instr),
        .pc_i                   (id_pc), 
        .pc4_i                  (id_pc4),
    
        .wb_we_i                (wb_rf_we), 
        .wb_rd_i                (wb_rf_waddr), 
        .wb_wdata_i             (wb_rf_wdata),
    
        .id_ex_mem_read_i       (ex_mem_read), 
        .id_ex_regwrite_i       (ex_regwrite),
        .id_ex_wb_pc4_sel_i     (ex_wb_pc4_sel), 
        .id_ex_rd_i             (ex_rd),
        .id_ex_MAC_op_i         (ex_MAC_op),
        .ex_mem_mem_read_i      (mem_mem_read), 
        .ex_mem_rd_i            (mem_rd),
        .ex_mem_MAC_op_i        (mem_MAC_op),
        
    
        .br_fwd_a_i             (br_fwd_a), 
        .br_fwd_b_i             (br_fwd_b),
        .br_fwd_a_use_pc4_i     (br_fwd_a_use_pc4), 
        .br_fwd_b_use_pc4_i     (br_fwd_b_use_pc4),
        .ex_alu_out_i           (ex_alu_out),
        .ex_mem_alu_out_i       (mem_alu_out), 
        .ex_mem_pc4_i           (mem_pc4),
        .wb_value_i             (wb_value),
    
        .stall_o                (stall_hz),
        .flush_o                (flush_dec),
        .kill_o                 (kill_dec),
        .branch_target_o        (branch_target_dec),
    
        .rs1_val_o              (id_rs1_val), 
        .rs2_val_o              (id_rs2_val), 
        .imm_o                  (id_imm),
        .rs1_o                  (id_rs1), 
        .rs2_o                  (id_rs2), 
        .rd_o                   (id_rd),
        .funct3_o               (id_funct3), 
        .funct7_o               (id_funct7),
        .regwrite_o             (id_regwrite), 
        .mem_read_o             (id_mem_read), 
        .mem_write_o            (id_mem_write),
        .branch_o               (id_branch), 
        .jump_o                 (id_jump), 
        .is_jalr_o              (id_is_jalr), 
        .lui_o                  (id_lui),
        .opA_sel_o              (id_opA_sel), 
        .opB_sel_o              (id_opB_sel),
        .wb_sel_o               (id_wb_sel), 
        .wb_pc4_sel_o           (id_wb_pc4_sel),
        .alu_op_o               (id_alu_op), 
        .valid_o                (id_valid_out),
        .MAC_op_o               (id_MAC_op)
    );

    // ============================  ID/EX REGISTER ============================ 
    id_ex_reg ID_EX_REG (
        .clk                (clk), 
        .rst                (rst),
        
        .flush_i            (kill),
        .stall_i            (mem_stall),
        .valid_i            (id_valid_out && !stall_hz),
        .instr_i            (id_instr), 
        .pc_i               (id_pc), 
        .pc4_i              (id_pc4),
        .rs1_val_i          (id_rs1_val), 
        .rs2_val_i          (id_rs2_val), 
        .imm_i              (id_imm),
        .rs1_i              (id_rs1), 
        .rs2_i              (id_rs2), 
        .rd_i               (id_rd),
        .funct3_i           (id_funct3), 
        .funct7_i           (id_funct7),
        .regwrite_i         (id_regwrite), 
        .mem_read_i         (id_mem_read), 
        .mem_write_i        (id_mem_write),
        .branch_i           (id_branch), 
        .jump_i             (id_jump), 
        .is_jalr_i          (id_is_jalr), 
        .lui_i              (id_lui),
        .opA_sel_i          (id_opA_sel), 
        .opB_sel_i          (id_opB_sel),
        .wb_sel_i           (id_wb_sel), 
        .wb_pc4_sel_i       (id_wb_pc4_sel), 
        .alu_op_i           (id_alu_op),
        .MAC_op_i           (id_MAC_op),
    
        .valid_o            (ex_valid), 
        .instr_o            (ex_instr),
        .pc_o               (ex_pc), 
        .pc4_o              (ex_pc4),
        .rs1_val_o          (ex_rs1_val), 
        .rs2_val_o          (ex_rs2_val), 
        .imm_o              (ex_imm),
        .rs1_o              (ex_rs1), 
        .rs2_o              (ex_rs2), 
        .rd_o               (ex_rd),
        .funct3_o           (ex_funct3), 
        .funct7_o           (ex_funct7),
        .regwrite_o         (ex_regwrite), 
        .mem_read_o         (ex_mem_read), 
        .mem_write_o        (ex_mem_write),
        .branch_o           (ex_branch), 
        .jump_o             (ex_jump), 
        .is_jalr_o          (ex_is_jalr), 
        .lui_o              (ex_lui),
        .opA_sel_o          (ex_opA_sel), 
        .opB_sel_o          (ex_opB_sel),
        .wb_sel_o           (ex_wb_sel), 
        .wb_pc4_sel_o       (ex_wb_pc4_sel), 
        .alu_op_o           (ex_alu_op),
        .MAC_op_o           (ex_MAC_op)
        
    );

    // ============================  EXECUTE STAGE ============================ 
    logic [31:0] ex_store_data;

    // Forwarded value from MEM: pick PC+4 for JAL/JALR links, else ALU result
    logic [31:0] mem_fwd_value;
    
    // Expose the rs1_fwd and rs2_fwd signals
    logic [31:0] rs1_fwd,
                 rs2_fwd;
    
    assign mem_fwd_value = mem_wb_pc4_sel ? mem_pc4 : mem_alu_out;

    Execute_Unit ExU (
        .pc_i           (ex_pc),
        .rs1_val_i      (ex_rs1_val), 
        .rs2_val_i      (ex_rs2_val), 
        .imm_i          (ex_imm),
        .funct3_i       (ex_funct3), 
        .funct7_i       (ex_funct7), 
        .alu_op_i       (ex_alu_op),
        .opA_sel_i      (ex_opA_sel), 
        .opB_sel_i      (ex_opB_sel), 
        .lui_i          (ex_lui),
        .fwd_a_i        (ex_fwd_a), 
        .fwd_b_i        (ex_fwd_b),
        .mem_fwd_i      (mem_fwd_value), 
        .wb_fwd_i       (wb_value),
        .alu_out_o      (ex_alu_out), 
        .store_data_o   (ex_store_data),
        .rs1_fwd_o      (rs1_fwd),
        .rs2_fwd_o      (rs2_fwd)
    );

    // ============================  EX/MEM REGISTER ============================ 
    logic [2:0]  mem_MAC_op;
    logic [63:0] mem_MAC_delta;


    ex_mem_reg EX_MEM_REG (
        .clk            (clk), 
        .rst            (rst), 
        
        .flush_i        (1'b0), 
        .stall_i        (mem_stall),
        .valid_i        (ex_valid), 
        .instr_i        (ex_instr),
        .alu_out_i      (ex_alu_out), 
        .store_data_i   (ex_store_data),
        .pc4_i          (ex_pc4), 
        .rd_i           (ex_rd), 
        .funct3_i       (ex_funct3),
        .regwrite_i     (ex_regwrite), 
        .mem_read_i     (ex_mem_read), 
        .mem_write_i    (ex_mem_write),
        .wb_sel_i       (ex_wb_sel), 
        .wb_pc4_sel_i   (ex_wb_pc4_sel),
        .MAC_op_i       (ex_MAC_op),
        .MAC_delta_i    (ex_MAC_delta),
    
        .valid_o        (mem_valid), 
        .instr_o        (mem_instr),
        .alu_out_o      (mem_alu_out), 
        .store_data_o   (mem_store_data),
        .pc4_o          (mem_pc4), 
        .rd_o           (mem_rd), 
        .funct3_o       (mem_funct3),
        .regwrite_o     (mem_regwrite), 
        .mem_read_o     (mem_mem_read), 
        .mem_write_o    (mem_mem_write),
        .wb_sel_o       (mem_wb_sel), 
        .wb_pc4_sel_o   (mem_wb_pc4_sel),
        .MAC_op_o       (mem_MAC_op),
        .MAC_delta_o    (mem_MAC_delta)
    );
    
    // ============================ MEMORY STAGE ============================ 
    logic           memwb_valid_in;
    logic           dmem_en_int;
    logic [3:0]     dmem_we_int;
    logic           mem_load_valid;
    logic [31:0]    mem_load_data;

    mem_unit MeU (
        .clk            (clk), 
        .rst            (rst),
        
        .valid_i        (mem_valid), 
        .addr_i         (mem_alu_out),
        .store_data_i   (mem_store_data), 
        .funct3_i       (mem_funct3),
        .mem_read_i     (mem_mem_read), 
        .mem_write_i    (mem_mem_write),
        .dmem_addr_o    (dmem_addr), 
        .dmem_en_o      (dmem_en_int),
        .dmem_we_o      (dmem_we_int), 
        .dmem_wdata_o   (dmem_wdata),
        .dmem_rdata_i   (dmem_rdata),
        .mem_stall_o    (mem_stall),
        .load_valid_o   (mem_load_valid), 
        .load_data_o    (mem_load_data)
    );

    assign stall         = stall_hz || mem_stall;
    assign flush         = flush_dec && !mem_stall;
    assign kill          = kill_dec  && !mem_stall;
    assign branch_target = branch_target_dec;

    assign dmem_wstrb    = dmem_we_int;
    assign dmem_we       = dmem_en_int && (|dmem_we_int) && !halt;
    assign dmem_re       = dmem_en_int && (dmem_we_int == 4'b0) && !halt;
    
    // Loads must enter MEM/WB only on the response cycle.
    // Non-loads can pass through immediately.
    assign memwb_valid_in = mem_load_valid ? mem_valid
                                           : (mem_valid && !mem_mem_read);
    
    
    // ============================  MEM/WB REGISTER ============================ 
    logic           wb_valid;
    logic [31:0]    wb_instr;
    logic [4:0]     wb_rd_raw;
    logic           wb_regwrite_raw;
    logic           wb_wb_sel, 
                    wb_wb_pc4_sel;
    logic [31:0]    wb_alu_out, wb_pc4;
    logic           wb_load_valid;
    logic [31:0]    wb_load_data;
    logic [2:0]     wb_MAC_op;
    logic [63:0]    wb_MAC_delta;

    mem_wb_reg MEM_WB_REG (
        .clk            (clk), 
        .rst            (rst), 
        
        .flush_i        (1'b0), 
        .stall_i        (1'b0),
        .valid_i        (memwb_valid_in), 
        .instr_i        (mem_instr),
        .rd_i           (mem_rd), 
        .regwrite_i     (mem_regwrite),
        .wb_sel_i       (mem_wb_sel), 
        .wb_pc4_sel_i   (mem_wb_pc4_sel),
        .alu_out_i      (mem_alu_out), 
        .pc4_i          (mem_pc4),
        .load_valid_i   (mem_load_valid), 
        .load_data_i    (mem_load_data),
        .MAC_op_i       (mem_MAC_op),
        .MAC_delta_i    (mem_MAC_delta),
    
        .valid_o        (wb_valid), 
        .instr_o        (wb_instr),
        .rd_o           (wb_rd_raw), 
        .regwrite_o     (wb_regwrite_raw),
        .wb_sel_o       (wb_wb_sel), 
        .wb_pc4_sel_o   (wb_wb_pc4_sel),
        .alu_out_o      (wb_alu_out), 
        .pc4_o          (wb_pc4),
        .load_valid_o   (wb_load_valid), 
        .load_data_o    (wb_load_data),
        .MAC_op_o       (wb_MAC_op),
        .MAC_delta_o    (wb_MAC_delta)
    );
    
    // ============================  MAC Unit ============================ 
    logic [63:0] ex_MAC_delta;
    logic [31:0] MAC_acc_lo_o,      
                 MAC_acc_hi_o;
                 
   MAC_Unit MAC_U(
        .clk                (clk),
        .rst                (rst),
    
        // EX-stage inputs (combinational multiply)
        .ex_rs1_val_i       (rs1_fwd),
        .ex_rs2_val_i       (rs2_fwd),
        .ex_mac_op_i        (ex_MAC_op),
        .ex_mac_delta_o     (ex_MAC_delta),
    
        // WB-stage inputs (accumulator commit)
        .wb_valid_i         (wb_valid),
        .wb_mac_op_i        (wb_MAC_op),
        .wb_mac_delta_i     (wb_MAC_delta),
    
        // Accumulator read ports
        .acc_lo_o           (MAC_acc_lo_o),
        .acc_hi_o           (MAC_acc_hi_o)
    );
    

    // ============================ WRITEBACK STAGE ============================ 
    logic           rf_we;
    logic [4:0]     rf_waddr;
    logic [31:0]    rf_wdata;

    WriteBack_Unit WbU (
        .valid_i        (wb_valid), 
        .rd_i           (wb_rd_raw), 
        .regwrite_i     (wb_regwrite_raw),
        .wb_sel_i       (wb_wb_sel), 
        .wb_pc4_sel_i   (wb_wb_pc4_sel),
        .alu_out_i      (wb_alu_out), 
        .load_valid_i   (wb_load_valid),
        .load_data_i    (wb_load_data), 
        .pc4_i          (wb_pc4),
        
        // Register file write
        .rf_we_o        (rf_we), 
        .rf_waddr_o     (rf_waddr), 
        .rf_wdata_o     (rf_wdata),
        
        // Forwarding outputs
        .wb_valid_o     (), 
        .wb_regwrite_o  (wb_regwrite),
        .wb_rd_o        (wb_rd), 
        .wb_value_o     (wb_value),
        
        // MAC Variables
        .MAC_op_i       (wb_MAC_op),          
        .MAC_acc_lo_i   (MAC_acc_lo_o),      
        .MAC_acc_hi_i   (MAC_acc_hi_o)     
    );

    // WB → Decode register-file write (gated by halt)
    assign wb_rf_we    = rf_we && !halt;
    assign wb_rf_waddr = rf_waddr;
    assign wb_rf_wdata = rf_wdata;

    // ============================  DONE / TRAP DETECTION ============================ 
    localparam logic [31:0] EBREAK = 32'h00100073;
    localparam logic [31:0] ECALL  = 32'h00000073;

    logic wb_is_ebreak, wb_is_ecall;
    
    assign wb_is_ebreak = wb_valid && (wb_instr == EBREAK);
    assign wb_is_ecall  = wb_valid && (wb_instr == ECALL);

    always_ff @(posedge clk) begin
        if (rst) begin
            done_o <= 1'b0;
            trap_o <= 1'b0;
        end
        else if (!halt) begin
            if (wb_is_ebreak)      done_o <= 1'b1;
            else if (wb_is_ecall)  trap_o <= 1'b1;
        end
    end

endmodule
