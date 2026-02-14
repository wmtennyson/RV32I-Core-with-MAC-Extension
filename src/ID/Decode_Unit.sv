`include "Def.vh"
`timescale 1ns/1ps

module Decode_Unit (
    input  logic        clk,
    input  logic        rst,

    // From Fetch (IF/ID)
    input  logic        instr_valid_i,
    input  logic [31:0] instr_i,
    input  logic [31:0] pc_i,
    input  logic [31:0] pc4_i,

    // From Writeback (WB -> Regfile)
    input  logic        wb_we_i,
    input  logic [4:0]  wb_rd_i,
    input  logic [31:0] wb_wdata_i,

    // From pipeline (for forwarding/hazard)
    // Instruction currently in EX stage (ID/EX regs)
    input  logic [4:0]  id_ex_rd_i,
    input  logic [4:0]  id_ex_rs1_i,
    input  logic [4:0]  id_ex_rs2_i,
    input  logic        id_ex_regwrite_i,
    input  logic        id_ex_mem_read_i,
    input  logic [31:0] ex_alu_out_i,        

    // Instruction currently in MEM stage (EX/MEM regs)
    input  logic [4:0]  ex_mem_rd_i,
    input  logic        ex_mem_regwrite_i,
    input  logic        ex_mem_mem_read_i,
    input  logic [31:0] ex_mem_alu_out_i,   

    // WB stage (MEM/WB regs)
    input  logic [4:0]  mem_wb_rd_i,
    input  logic        mem_wb_regwrite_i,
    input  logic [31:0] mem_wb_value_i,     

    // To Fetch (hazard / redirect)
    output logic        stall_o,            
    output logic        flush_o,             
    output logic [31:0] branch_target_o,    

    // ID/EX pipeline register outputs (to Execute stage and beyond)
    output logic        id_ex_valid_o,

    output logic [31:0] id_ex_pc_o,
    output logic [31:0] id_ex_pc4_o,
    output logic [31:0] id_ex_rs1_val_o,
    output logic [31:0] id_ex_rs2_val_o,
    output logic [31:0] id_ex_imm_o,

    output logic [4:0]  id_ex_rs1_o,
    output logic [4:0]  id_ex_rs2_o,
    output logic [4:0]  id_ex_rd_o,
    output logic [2:0]  id_ex_funct3_o,
    output logic [6:0]  id_ex_funct7_o,

    // Control to later stages
    output logic        id_ex_regwrite_o,
    output logic        id_ex_mem_read_o,
    output logic        id_ex_mem_write_o,
    output logic        id_ex_branch_o,
    output logic        id_ex_jump_o,
    output logic        id_ex_write_data_o,  
    output logic        id_ex_lui_o,
    output logic        id_ex_is_jalr_o,
    output logic [2:0]  id_ex_alu_op_o,

    // Execute operand selects / forwarding selects
    output logic [1:0]  id_ex_opA_sel_o,    
    output logic        id_ex_opB_sel_o,     
    output logic [1:0]  id_ex_rs1_sel_o,   
    output logic [1:0]  id_ex_rs2_sel_o     
);
    localparam logic [31:0] NOP_INSTR = 32'h0000_0013;

    // Field decode
    logic [6:0] opcode;
    logic [4:0] rd, rs1, rs2;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr_i[6:0];
    assign rd     = instr_i[11:7];
    assign funct3 = instr_i[14:12];
    assign rs1    = instr_i[19:15];
    assign rs2    = instr_i[24:20];
    assign funct7 = instr_i[31:25];

    // Regfile read
    logic [31:0] rs1_rf, rs2_rf;

    regfile RF (
        .clk      (clk),
        .rst      (rst),
        .we_i     (wb_we_i),
        .waddr_i  (wb_rd_i),
        .wdata_i  (wb_wdata_i),
        .raddr1_i (rs1),
        .raddr2_i (rs2),
        .rdata1_o (rs1_rf),
        .rdata2_o (rs2_rf)
    );

    // Immediate generator
    logic [31:0] imm_d;

    ImmGen IG (
        .instr_i (instr_i),
        .imm_o   (imm_d)
    );

    // Control decode
    logic        regwrite_d,
                 mem_read_d,
                 mem_write_d,
                 branch_d,
                 jump_d,
                 write_data_d,
                 opA_sel_bit_d,
                 opB_sel_d,
                 lui_d,
                 is_jalr_d;
    logic [2:0]  alu_op_d;

    Control_Unit CU (
        .opcode     (opcode),
        .regwrite   (regwrite_d),
        .mem_read   (mem_read_d),
        .mem_write  (mem_write_d),
        .branch     (branch_d),
        .jump       (jump_d),
        .write_data (write_data_d),
        .OpA_sel    (opA_sel_bit_d),
        .OpB_sel    (opB_sel_d),
        .lui        (lui_d),
        .is_jalr    (is_jalr_d),
        .alu_op     (alu_op_d)
    );

    // Gate control with instr_valid (so bubbles don't redirect / write)
    logic        regwrite_g,
                 mem_read_g,
                 mem_write_g,
                 branch_g,
                 jump_g,
                 write_data_g,
                 lui_g,
                 is_jalr_g;
    logic [2:0]  alu_op_g;

    always_comb begin
        if (!instr_valid_i) begin
            regwrite_g   = 1'b0;
            mem_read_g   = 1'b0;
            mem_write_g  = 1'b0;
            branch_g     = 1'b0;
            jump_g       = 1'b0;
            write_data_g = 1'b0;
            lui_g        = 1'b0;
            is_jalr_g    = 1'b0;
            alu_op_g     = `NOP;
        end else begin
            regwrite_g   = regwrite_d;
            mem_read_g   = mem_read_d;
            mem_write_g  = mem_write_d;
            branch_g     = branch_d;
            jump_g       = jump_d;
            write_data_g = write_data_d;
            lui_g        = lui_d;
            is_jalr_g    = is_jalr_d;
            alu_op_g     = alu_op_d;
        end
    end

    // Forwarding for branch compare (ID-stage)
    logic [1:0] BrFwd_A, BrFwd_B;
    logic [1:0] RS1_Sel_d, RS2_Sel_d;

    Forwarding_Unit FU (
        .IF_ID_rs1        (rs1),
        .IF_ID_rs2        (rs2),
        .ID_EX_rd         (id_ex_rd_i),
        .ID_EX_rs1        (id_ex_rs1_i),
        .ID_EX_rs2        (id_ex_rs2_i),
        .EX_MEM_rd        (ex_mem_rd_i),
        .MEM_WB_rd        (mem_wb_rd_i),

        .EX_MEM_RegWrite  (ex_mem_regwrite_i),
        .MEM_WB_RegWrite  (mem_wb_regwrite_i),
        .ID_EX_RegWrite   (id_ex_regwrite_i),
        .ID_EX_mem_read   (id_ex_mem_read_i),
        .EX_MEM_mem_read  (ex_mem_mem_read_i),

        .BrFwd_A          (BrFwd_A),
        .BrFwd_B          (BrFwd_B),
        .RS1_Sel          (RS1_Sel_d),
        .RS2_Sel          (RS2_Sel_d)
    );

    // Build forwarded operands for Branch_Unit
    logic [31:0] br_rs1_val, br_rs2_val;

    always_comb begin
        // defaults = regfile
        br_rs1_val = rs1_rf;
        br_rs2_val = rs2_rf;

        unique case (BrFwd_A)
            2'b00: br_rs1_val = rs1_rf;
            2'b01: br_rs1_val = mem_wb_value_i;
            2'b10: br_rs1_val = ex_mem_alu_out_i;
            2'b11: br_rs1_val = ex_alu_out_i;
            default: br_rs1_val = rs1_rf;
        endcase

        unique case (BrFwd_B)
            2'b00: br_rs2_val = rs2_rf;
            2'b01: br_rs2_val = mem_wb_value_i;
            2'b10: br_rs2_val = ex_mem_alu_out_i;
            2'b11: br_rs2_val = ex_alu_out_i;
            default: br_rs2_val = rs2_rf;
        endcase
    end

    // Branch / Jump decision in ID
    logic        redirect_d;
    logic [31:0] target_pc_d;
    logic [31:0] link_pc_d;

    Branch_Unit BU (
        .pc            (pc_i),
        .pc4           (pc4_i),
        .rs1           (br_rs1_val),
        .rs2           (br_rs2_val),
        .imm           (imm_d),
        .branch        (branch_g),
        .jump          (jump_g),
        .pcsrc         (is_jalr_g),
        .funct3        (funct3),
        .redirect      (redirect_d),
        .target_pc     (target_pc_d),
        .link_register (link_pc_d)
    );

    assign flush_o         = redirect_d;   
    assign branch_target_o = target_pc_d;

    // Hazard detection -> stall
    logic uses_rs1, uses_rs2;

    always_comb begin
        uses_rs1 = 1'b0;
        uses_rs2 = 1'b0;

        if (instr_valid_i) begin
            unique case (opcode)
                7'b0110111: begin uses_rs1 = 1'b0; uses_rs2 = 1'b0; end // LUI
                7'b0010111: begin uses_rs1 = 1'b0; uses_rs2 = 1'b0; end // AUIPC
                7'b1101111: begin uses_rs1 = 1'b0; uses_rs2 = 1'b0; end // JAL
                7'b1100111: begin uses_rs1 = 1'b1; uses_rs2 = 1'b0; end // JALR
                7'b1100011: begin uses_rs1 = 1'b1; uses_rs2 = 1'b1; end // BRANCH
                7'b0100011: begin uses_rs1 = 1'b1; uses_rs2 = 1'b1; end // STORE
                7'b0000011: begin uses_rs1 = 1'b1; uses_rs2 = 1'b0; end // LOAD
                7'b0010011: begin uses_rs1 = 1'b1; uses_rs2 = 1'b0; end // I-type ALU
                7'b0110011: begin uses_rs1 = 1'b1; uses_rs2 = 1'b1; end // R-type ALU
                default:    begin uses_rs1 = 1'b0; uses_rs2 = 1'b0; end
            endcase
        end
    end

    logic hazard_ex_load, hazard_mem_load;

    always_comb begin
        hazard_ex_load  = 1'b0;
        hazard_mem_load = 1'b0;

        // If instruction in EX is a load and we need its rd now -> stall
        if (id_ex_mem_read_i && (id_ex_rd_i != 5'd0) && instr_valid_i) begin
            if ((uses_rs1 && (id_ex_rd_i == rs1)) ||
                (uses_rs2 && (id_ex_rd_i == rs2))) begin
                hazard_ex_load = 1'b1;
            end
        end

        // If instruction in EX/MEM is a load and we need its rd now -> stall
        // (Needed if you can only forward load results at MEM/WB due to sync BRAM timing)
        if (ex_mem_mem_read_i && (ex_mem_rd_i != 5'd0) && instr_valid_i) begin
            if ((uses_rs1 && (ex_mem_rd_i == rs1)) ||
                (uses_rs2 && (ex_mem_rd_i == rs2))) begin
                hazard_mem_load = 1'b1;
            end
        end
    end

    // Flush has priority over stall (if you redirect, don't also "stall")
    always_comb begin
        if (flush_o) stall_o = 1'b0;
        else         stall_o = hazard_ex_load | hazard_mem_load;
    end

    logic [1:0] opA_sel_d;

    always_comb begin
        opA_sel_d = 2'b10;

        // If CU requests PC-based A operand (AUIPC), use PC
        if (opA_sel_bit_d) opA_sel_d = 2'b00;
    end

    // ID/EX pipeline register (bubble on stall/invalid, bubble on flush)
    task automatic set_idex_nop();
        begin
            id_ex_valid_o       <= 1'b0;

            id_ex_pc_o          <= 32'd0;
            id_ex_pc4_o         <= 32'd0;
            id_ex_rs1_val_o     <= 32'd0;
            id_ex_rs2_val_o     <= 32'd0;
            id_ex_imm_o         <= 32'd0;

            id_ex_rs1_o         <= 5'd0;
            id_ex_rs2_o         <= 5'd0;
            id_ex_rd_o          <= 5'd0;
            id_ex_funct3_o      <= 3'd0;
            id_ex_funct7_o      <= 7'd0;

            id_ex_regwrite_o    <= 1'b0;
            id_ex_mem_read_o    <= 1'b0;
            id_ex_mem_write_o   <= 1'b0;
            id_ex_branch_o      <= 1'b0;
            id_ex_jump_o        <= 1'b0;
            id_ex_write_data_o  <= 1'b0;
            id_ex_lui_o         <= 1'b0;
            id_ex_is_jalr_o     <= 1'b0;
            id_ex_alu_op_o      <= `NOP;

            id_ex_opA_sel_o     <= 2'b10; 
            id_ex_opB_sel_o     <= 1'b0;

            id_ex_rs1_sel_o     <= 2'b00;
            id_ex_rs2_sel_o     <= 2'b00;
        end
    endtask

    always_ff @(posedge clk) begin
        if (rst) begin
            set_idex_nop();
        end else if (flush_o) begin
            set_idex_nop();
        end else if (stall_o) begin
            set_idex_nop();
        end else if (!instr_valid_i) begin
            set_idex_nop();
        end else begin
            id_ex_valid_o       <= 1'b1;

            id_ex_pc_o          <= pc_i;
            id_ex_pc4_o         <= pc4_i;
            id_ex_rs1_val_o     <= rs1_rf;
            id_ex_rs2_val_o     <= rs2_rf;
            id_ex_imm_o         <= imm_d;

            id_ex_rs1_o         <= rs1;
            id_ex_rs2_o         <= rs2;
            id_ex_rd_o          <= rd;
            id_ex_funct3_o      <= funct3;
            id_ex_funct7_o      <= funct7;

            id_ex_regwrite_o    <= regwrite_g;
            id_ex_mem_read_o    <= mem_read_g;
            id_ex_mem_write_o   <= mem_write_g;
            id_ex_branch_o      <= branch_g;
            id_ex_jump_o        <= jump_g;
            id_ex_write_data_o  <= write_data_g;
            id_ex_lui_o         <= lui_g;
            id_ex_is_jalr_o     <= is_jalr_g;
            id_ex_alu_op_o      <= alu_op_g;

            id_ex_opA_sel_o     <= opA_sel_d;
            id_ex_opB_sel_o     <= opB_sel_d;

            // forwarding selects computed in ID, used in EX
            id_ex_rs1_sel_o     <= RS1_Sel_d;
            id_ex_rs2_sel_o     <= RS2_Sel_d;
        end
    end

endmodule
