`timescale 1ns / 1ps
//`default_nettype none       // Disable Any Implicit Declarations (Debugging)

module RV32I_Core(
  input  logic        clk,
  input  logic        rst,

  // instruction memory (read-only)
  output logic [31:0] imem_addr,
  output logic        imem_en,
  input  logic [31:0] imem_rdata,

  // data memory / MMIO
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  output logic [3:0]  dmem_wstrb,   // byte enables
  output logic        dmem_we,
  output logic        dmem_re,
  input  logic [31:0] dmem_rdata,

  // demo/debug
  output logic        done_o,
  output logic        trap_o
);
    
    // Temp assignments
    assign done_o = 1'b0;           // TestBench Purposes
    assign trap_o = 1'b0;
    
    
    // ---------------------- Instruction Fetch Stage ----------------------
    // ID -> IF Stage (Control)
    logic            id_stall,
                     id_flush;
    logic [31:0]     id_branch_target;

    // IF -> ID Stage
    logic [31:0]     if_pc,
                     if_pc4;
                    
    fetch_unit FeU (
        // Top Level Input
        .clk             (clk),
        .rst             (rst),
        
        // Control (from hazard/branch logic later)
        .stall_i         (id_stall),
        .flush_i         (id_flush),
        .branch_target_i (id_branch_target),
        
        // BRAM / Instruction memory interface
        .bram_addr_o     (imem_addr),
        .bram_en_o       (imem_en),
        
        
        // Fetch outputs (to IF/ID next)
        .if_pc_o            (if_pc),
        .if_pc_plus4_o      (if_pc4)
    );
    
    // ---------------------- IF/ID Interstage Register ----------------------
    // IF -> ID
    logic           id_instr_valid;
    logic [31:0]    id_instr,
                    id_pc,
                    id_pc4;
                    
    if_id_reg IF_ID_REG (
        .clk            (clk),
        .rst            (rst),
    
        // Inputs - Hazard and pipeline control
        .stall          (id_stall),   // from Decode (Hazard Unit)
        .flush          (id_flush),   // from Decode (Branch taken)
    
        // Inputs - Data coming from Fetch Stage
        .if_pc          (if_pc),
        .if_pc4         (if_pc4),
    
        // Inputs - Data coming from Instruction Memory (BRAM 1-cycle latency output)
        .bram_rdata_i   (imem_rdata),
    
        // Outputs - Data going to Decode Stage
        .id_instr_valid (id_instr_valid),
        .id_instr       (id_instr),
        .id_pc          (id_pc),
        .id_pc4         (id_pc4)
    
    );
         
    // ---------------------- Instruction Decode Stage ----------------------
    // WB -> ID Stage
    logic           id_we;
    logic [4:0]     id_rd;
    logic [31:0]    id_wdata;
    
    // ID/EX -> ID
    logic [4:0]     id_ex_rd_i,
                    id_ex_rs1_i,
                    id_ex_rs2_i;
    logic           id_ex_regwrite_i,
                    id_ex_mem_read_i;
    logic [31:0]    ex_alu_out_i;   
    
    // EX/MEM -> ID Stage
    logic [4:0]     ex_mem_rd_i;
    logic           ex_mem_regwrite_i,
                    ex_mem_mem_read_i;
    logic [31:0]    ex_mem_alu_out_i;   
    
    // MEM/WB -> ID Stage
    logic [4:0]     mem_wb_rd_i;
    logic           mem_wb_regwrite_i;
    logic [31:0]    mem_wb_value_i;  
    
    // ID -> ID/EX Stage
    logic [31:0]    id_ex_rs1_val_o,
                    id_ex_rs2_val_o,
                    id_ex_imm_o;

    logic [4:0]     id_ex_rs1_o,
                    id_ex_rs2_o,
                    id_ex_rd_o;
                    
    logic [2:0]     id_ex_funct3_o;
    logic [6:0]     id_ex_funct7_o;

    // ID -> EX, MEM, WB Stages (Control)
    logic           id_ex_regwrite_o,
                    id_ex_mem_read_o,
                    id_ex_mem_write_o,
                    id_ex_branch_o,
                    id_ex_jump_o,
                    id_ex_write_data_o,     // 1 = mem result, 0 = alu result
                    id_ex_lui_o,
                    id_ex_is_jalr_o;
    logic [2:0]     id_ex_alu_op_o;

    // Mux Selects
    logic           id_ex_opA_sel_o,    
                    id_ex_opB_sel_o;     
    logic [1:0]     id_ex_rs1_sel_o,   
                    id_ex_rs2_sel_o; 
    
    Decode_Unit DeU (
        .clk                (clk),
        .rst                (rst),
        
        //Inputs 
        // From Fetch (IF/ID)
        .instr_valid_i      (id_instr_valid),
        .instr_i            (id_instr),
        .pc_i               (id_pc),
        .pc4_i              (id_pc4),
        
        // From Writeback (WB -> Regfile)
        .wb_we_i            (id_we),
        .wb_rd_i            (id_rd),
        .wb_wdata_i         (id_wdata),
        
        // From pipeline (for forwarding/hazard)
        // Instruction currently in EX stage (ID/EX regs)
        .id_ex_rd_i         (id_ex_rd_i),
        .id_ex_rs1_i        (id_ex_rs1_i),
        .id_ex_rs2_i        (id_ex_rs2_i),
        .id_ex_regwrite_i   (id_ex_regwrite_i),
        .id_ex_mem_read_i   (id_ex_mem_read_i),
        .ex_alu_out_i       (ex_alu_out_i),
        
        // Instruction currently in MEM stage (EX/MEM regs)     // TAKE FROM EX/MEM
        .ex_mem_rd_i        (ex_mem_rd_i),                  // THIS DOES NOT EXIST 
        .ex_mem_regwrite_i  (ex_mem_regwrite_i),
        .ex_mem_mem_read_i  (ex_mem_mem_read_i),
        .ex_mem_alu_out_i   (ex_mem_alu_out_i),             // THIS DOES NOT EXIST
        
        // WB stage (MEM/WB regs)
        .mem_wb_rd_i        (mem_wb_rd_i),
        .mem_wb_regwrite_i  (mem_wb_regwrite_i),
        .mem_wb_value_i     (mem_wb_value_i),
        
        // To Fetch (hazard / redirect)
        .stall_o            (id_stall),            
        .flush_o            (id_flush),             
        .branch_target_o    (id_branch_target),  
        
        // Outputs
        // ID -> ID/EX pipeline(to Execute stage and beyond)
        .rs1_val_o    (id_ex_rs1_val_o),
        .rs2_val_o    (id_ex_rs2_val_o),
        .imm_o        (id_ex_imm_o),
    
        .rs1_o        (id_ex_rs1_o),
        .rs2_o        (id_ex_rs2_o),
        .rd_o         (id_ex_rd_o),
        .funct3_o     (id_ex_funct3_o),
        .funct7_o     (id_ex_funct7_o),
    
        // Control to later stages
        .regwrite_o   (id_ex_regwrite_o),
        .mem_read_o   (id_ex_mem_read_o),
        .mem_write_o  (id_ex_mem_write_o),
        .branch_o     (id_ex_branch_o),
        .jump_o       (id_ex_jump_o),
        .write_data_o (id_ex_write_data_o),  
        .lui_o        (id_ex_lui_o),
        .is_jalr_o    (id_ex_is_jalr_o),
        .alu_op_o     (id_ex_alu_op_o),
    
        // Execute operand selects / forwarding selects
        .opA_sel_o    (id_ex_opA_sel_o),    
        .opB_sel_o    (id_ex_opB_sel_o),     
        .rs1_sel_o    (id_ex_rs1_sel_o),   
        .rs2_sel_o    (id_ex_rs2_sel_o)    
    );
    
    
    // ---------------------- ID/EX Interstage Register ----------------------
    // Bubble insertion on ID stall: prevent re-issuing the same ID instruction into EX
    logic        idex_issue_en;
    assign  idex_issue_en = ~id_stall;
    
    // ID/EX registered outputs
    logic        ex_valid_i;

    logic [31:0] ex_pc_i,
                 ex_pc4_i,
                 ex_rs1_val_i,
                 ex_rs2_val_i,
                 ex_imm_i;

    logic [4:0]  ex_rs1_i,
                 ex_rs2_i,
                 ex_rd_i;
    logic [2:0]  ex_funct3_i;
    logic [6:0]  ex_funct7_i;

    logic        ex_regwrite_i,
                 ex_mem_read_i,
                 ex_mem_write_i,
                 ex_branch_i,
                 ex_jump_i,
                 ex_write_data_i,
                 ex_lui_i,
                 ex_is_jalr_i;
    logic [2:0]  ex_alu_op_i;

    logic        ex_opA_sel_i,  
                 ex_opB_sel_i;
    logic [1:0]  ex_rs1_sel_i,
                 ex_rs2_sel_i;
    
    id_ex_reg ID_EX_REG (
        .clk                (clk),
        .rst                (rst),

        // Inputs
        .flush_i            (id_stall),             // Bubble on stall
        .stall_i            (1'b0),                 // optional (set 0 if unused)
        .instr_valid_i      (id_instr_valid && idex_issue_en),

        // data
        .pc_i               (id_pc),
        .pc4_i              (id_pc4),
        .rs1_val_i          (id_ex_rs1_val_o),
        .rs2_val_i          (id_ex_rs2_val_o),
        .imm_i              (id_ex_imm_o),

        .rs1_i              (id_ex_rs1_o),
        .rs2_i              (id_ex_rs2_o),
        .rd_i               (id_ex_rd_o),
        .funct3_i           (id_ex_funct3_o),
        .funct7_i           (id_ex_funct7_o),

        // control (gate to NOP on stall)
        .regwrite_i         (id_ex_regwrite_o   & idex_issue_en),
        .mem_read_i         (id_ex_mem_read_o   & idex_issue_en),
        .mem_write_i        (id_ex_mem_write_o  & idex_issue_en),
        .branch_i           (id_ex_branch_o     & idex_issue_en),
        .jump_i             (id_ex_jump_o       & idex_issue_en),
        .write_data_i       (id_ex_write_data_o & idex_issue_en),
        .lui_i              (id_ex_lui_o        & idex_issue_en),
        .is_jalr_i          (id_ex_is_jalr_o    & idex_issue_en),
        .alu_op_i           (id_ex_alu_op_o),

        // execute selects
        .opA_sel_i          (id_ex_opA_sel_o),
        .opB_sel_i          (id_ex_opB_sel_o),
        .rs1_sel_i          (id_ex_rs1_sel_o),
        .rs2_sel_i          (id_ex_rs2_sel_o),

        // Outputs (these are decode_unit outputs)
        .id_ex_valid_o      (ex_valid_i),

        .id_ex_pc_o         (ex_pc_i),
        .id_ex_pc4_o        (ex_pc4_i),
        .id_ex_rs1_val_o    (ex_rs1_val_i),
        .id_ex_rs2_val_o    (ex_rs2_val_i),
        .id_ex_imm_o        (ex_imm_i),

        .id_ex_rs1_o        (ex_rs1_i),
        .id_ex_rs2_o        (ex_rs2_i),
        .id_ex_rd_o         (ex_rd_i),
        .id_ex_funct3_o     (ex_funct3_i),
        .id_ex_funct7_o     (ex_funct7_i),

        .id_ex_regwrite_o   (ex_regwrite_i),
        .id_ex_mem_read_o   (ex_mem_read_i),
        .id_ex_mem_write_o  (ex_mem_write_i),
        .id_ex_branch_o     (ex_branch_i),
        .id_ex_jump_o       (ex_jump_i),
        .id_ex_write_data_o (ex_write_data_i),
        .id_ex_lui_o        (ex_lui_i),
        .id_ex_is_jalr_o    (ex_is_jalr_i),
        .id_ex_alu_op_o     (ex_alu_op_i),

        .id_ex_opA_sel_o    (ex_opA_sel_i),
        .id_ex_opB_sel_o    (ex_opB_sel_i),
        .id_ex_rs1_sel_o    (ex_rs1_sel_i),
        .id_ex_rs2_sel_o    (ex_rs2_sel_i)
    );
        
        
    // ---------------------- Execute Stage ----------------------
    // Execute Unit Outputs
    logic [31:0] ex_alu_out_o,
                 ex_store_data_o;
    
    // Forwarding Variables
    logic [31:0] mem_alu_out_i, 
                 wb_value;

    
    Execute_Unit EU (
        // Inputs
        // Inputs for Operand A
        .PC             (ex_pc_i),
        .RS1_IDEXE      (ex_rs1_val_i),
        .RS1_EXEMEM     (mem_alu_out_i),       // RS1_EXE/MEM is ex_mem_alu_out
        .RS1_MEMWB      (wb_value),          // RS1_MEM/WB is wb_value
        
        // Inputs for Operand B
        .RS2_IDEXE      (ex_rs2_val_i),
        .RS2_EXEMEM     (mem_alu_out_i),      // RS2_EXE/MEM is ex_mem_alu_out
        .RS2_MEMWB      (wb_value),         // RS2_MEM/WB is wb_value
        .imm            (ex_imm_i),
        
        // Inputs for ALU Control Unit
        .func3          (ex_funct3_i),
        .func7          (ex_funct7_i),
        .alu_op         (ex_alu_op_i),
        
        // Control Signals for Muxltiplexers
        .RS1_sel        (ex_rs1_sel_i),
        .RS2_sel        (ex_rs2_sel_i),
        .OpA_sel        (ex_opA_sel_i),
        .OpB_sel        (ex_opB_sel_i),   
        
        //Outputs
        // Execute Unit Output
        .alu_out        (ex_alu_out_o),
        .store_data     (ex_store_data_o)
    );
    
    // ---------------------- EX/MEM Interstage Register ----------------------
    // EX/MEM Pipeline Register - Inputs (from EX stage)
    logic        mem_valid_i;
    
    // Data into MEM stage
    logic [31:0] mem_store_data_i,     
                 mem_pc4_i;           
    logic [4:0]  mem_rd_i;
    
    // MEM control
    logic        mem_mem_read_i,
                 mem_mem_write_i;
    logic [2:0]  mem_funct3_i;     
    
    // WB control
    logic       mem_regwrite_i,
                mem_write_data_i;       
    
    ex_mem_reg EX_MEM_REG (
        .clk                (clk),
        .rst                (rst),
        
        // Inputs
        // EX/MEM Pipeline Register - Inputs (from EX stage)
        .flush              (1'b0),     // optional (set 0 if unused)
        .stall              (1'b0),     // optional (set 0 if unused)
        
        .ex_valid           (ex_valid_i),
        
        // Data into MEM stage
        .ex_alu_out         (ex_alu_out_o),        // ALU result / load-store address
        .ex_store_data      (ex_store_data_o),     // store write data (after forwarding) 
        .ex_pc4             (ex_pc4_i),            // for JAL/JALR link writeback (optional)
        .ex_rd              (ex_rd_i),
        
        // MEM control
        .ex_mem_read        (ex_mem_read_i),
        .ex_mem_write       (ex_mem_write_i),
        .ex_funct3          (ex_funct3_i),     // size/sign for loads; size for stores
        
        // WB control
        .ex_regwrite        (ex_regwrite_i),
        .ex_write_data      (ex_write_data_i),         // 1- Memory Result, 0 = alu result
        
        // Outputs
        // EX/MEM Pipeline Register - Inputs (from EX stage)
        .ex_mem_valid       (mem_valid_i),
        
        // Data into MEM stage
        .ex_mem_alu_out     (mem_alu_out_i),
        .ex_mem_store_data  (mem_store_data_i),
        .ex_mem_pc4         (mem_pc4_i),           
        .ex_mem_rd          (mem_rd_i),
        
        // MEM control
        .ex_mem_mem_read    (mem_mem_read_i),
        .ex_mem_mem_write   (mem_mem_write_i),
        .ex_mem_funct3      (mem_funct3_i),     
        
        // WB control
        .ex_mem_regwrite    (mem_regwrite_i),
        .ex_mem_write_data  (mem_write_data_i)
    );
    
    // ---------------------- Memory Stage ----------------------
    //Output Variables
    logic        dmem_req;
    logic [3:0]  dmem_wstrb_int;     // NOTE: assumes mem_unit outputs byte strobes here
    logic        mem_load_valid;
    logic [31:0] mem_load_data;
    
    mem_unit MU (
        .clk                (clk),
        .rst                (rst),
    
        // Inputs
        // From EX/MEM pipeline regs
        .ex_mem_valid_i         (mem_valid_i),
        .ex_mem_addr_i          (mem_alu_out_i),  // Calulated Effective Address for lw/sw ops     
        .ex_mem_store_data_i    (mem_store_data_i),
        .ex_mem_funct3_i        (mem_funct3_i),
        .ex_mem_mem_read_i      (mem_mem_read_i),
        .ex_mem_mem_write_i     (mem_mem_write_i),
    
        //Outputs
        // Data memory BRAM interface (sync read, byte-write enables)
        .dmem_addr_o            (dmem_addr),
        .dmem_en_o              (dmem_req),
        .dmem_we_o              (dmem_wstrb_int),
        .dmem_wdata_o           (dmem_wdata),
        .dmem_rdata_i           (dmem_rdata),
    
        // To MEM/WB stage
        .load_valid_o           (mem_load_valid),    
        .load_data_o            (mem_load_data) 
    );
    
   // Drive wrapper outputs
    assign dmem_wstrb = dmem_wstrb_int;
    assign dmem_we    = dmem_req && (|dmem_wstrb_int);         // write when enabled and any byte strobe set
    assign dmem_re    = dmem_req && (dmem_wstrb_int == 4'b0);  // read when enabled and no write strobes

    
    // ---------------------- MEM/WB Interstage Register ----------------------
    // Outputs to WB stage
    logic             wb_valid_i;
    logic [4:0]       wb_rd_i;
    logic             wb_regwrite_i,
                      wb_write_data_i;
    logic [31:0]      wb_alu_out_i;
    logic             wb_load_valid_i;
    logic [31:0]      wb_load_data_i;
    
    mem_wb_reg MEM_WB_REG(
        .clk                   (clk),
        .rst                   (rst),
        
        // Inputs
        .flush_i               (1'b0),    // optional (set 0 if unused)
        .stall_i               (1'b0),    // optional (set 0 if unused)
    
        // Inputs from EX/MEM (control + rd + calc/alu result)
        .ex_mem_valid_i         (mem_valid_i),
        .ex_mem_rd_i            (mem_rd_i),   
        .ex_mem_regwrite_i      (mem_regwrite_i),
        .ex_mem_write_data_i    (mem_write_data_i), // 1=mem->wb, 0=alu->wb
        .ex_mem_alu_out_i       (mem_alu_out_i),
    
        // Inputs from mem_unit (formatted load result)
        .mem_load_valid_i       (mem_load_valid),
        .mem_load_data_i        (mem_load_data),
    
        // Outputs to WB stage
        .mem_wb_valid_o         (wb_valid_i),
        .mem_wb_rd_o            (wb_rd_i),
        .mem_wb_regwrite_o      (wb_regwrite_i), 
        .mem_wb_write_data_o    (wb_write_data_i),
        .mem_wb_alu_out_o       (wb_alu_out_i),
        .mem_wb_load_valid_o    (wb_load_valid_i),
        .mem_wb_load_data_o     (wb_load_data_i)
    );
    
    
    
    // ---------------------- Writeback Stage ----------------------
    // register file write port
    logic        rf_we;
    logic [4:0]  rf_waddr;
    logic [31:0] rf_wdata;

    // writeback stage outputs (forwarding / debug visibility)
    logic        wb_valid,
                 wb_regwrite_eff;     // regwrite after gating
    logic [4:0]  wb_rd;
    
    writeback_unit WbU (
        //Inputs
        // from mem/wb pipeline register
        .mem_wb_valid       (wb_valid_i),
        .mem_wb_rd          (wb_rd_i),
        .mem_wb_regwrite    (wb_regwrite_i),
        .mem_wb_write_data  (wb_write_data_i),   // 1 = memory result, 0 = alu result
        .mem_wb_alu_out     (wb_alu_out_i),
        .mem_wb_load_valid  (wb_load_valid_i),
        .mem_wb_load_data   (wb_load_data_i),
    
        // register file write port
        .rf_we              (rf_we),
        .rf_waddr           (rf_waddr),
        .rf_wdata           (rf_wdata),
        
        // Outputs
        // writeback stage outputs (forwarding / debug visibility)
        .wb_valid           (wb_valid),
        .wb_regwrite_eff    (wb_regwrite_eff),     // regwrite after gating
        .wb_rd              (wb_rd),
        .wb_value           (wb_value)
    );

    // ----------------------- Final Assignments to Tie up Loose Ends---------------
    // WB -> ID (Decode expects these names)
    assign id_we    = rf_we;
    assign id_rd    = rf_waddr;
    assign id_wdata = rf_wdata;

    // EX stage taps (from ID/EX reg outputs)
    assign id_ex_rd_i        = ex_rd_i;
    assign id_ex_rs1_i       = ex_rs1_i;
    assign id_ex_rs2_i       = ex_rs2_i;
    assign id_ex_regwrite_i  = ex_regwrite_i;
    assign id_ex_mem_read_i  = ex_mem_read_i;

    // EX ALU result tap (combinational)
    assign ex_alu_out_i      = ex_alu_out_o;

    // MEM stage taps (from EX/MEM reg outputs)
    assign ex_mem_rd_i       = mem_rd_i;
    assign ex_mem_regwrite_i = mem_regwrite_i;
    assign ex_mem_mem_read_i = mem_mem_read_i;
    assign ex_mem_alu_out_i  = mem_alu_out_i;

    // WB stage taps (use gated WB outputs)
    assign mem_wb_rd_i        = wb_rd;
    assign mem_wb_regwrite_i  = wb_regwrite_eff;
    assign mem_wb_value_i     = wb_value;


endmodule



