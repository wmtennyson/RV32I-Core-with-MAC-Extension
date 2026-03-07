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
    input  logic [31:0] ex_mem_alu_out_i,    // for branch fwd = 10

    // WB stage (MEM/WB regs)
    input  logic [4:0]  mem_wb_rd_i,
    input  logic        mem_wb_regwrite_i,
    input  logic [31:0] mem_wb_value_i,      // the value that will be written back (for fwd = 01)

    // To Fetch (hazard / redirect)
    output logic        stall_o,             // freeze PC + IF/ID (connect to fetch_unit.stall_i)
    output logic        flush_o,             // branch/jump taken (connect to fetch_unit.flush_i)
    output logic [31:0] branch_target_o,     // connect to fetch_unit.branch_target_i

    // To ID/EX Reg
    output logic [31:0] rs1_val_o,
    output logic [31:0] rs2_val_o,
    output logic [31:0] imm_o,

    output logic [4:0]  rs1_o,
    output logic [4:0]  rs2_o,
    output logic [4:0]  rd_o,
    output logic [2:0]  funct3_o,
    output logic [6:0]  funct7_o,

    output logic        regwrite_o,
    output logic        mem_read_o,
    output logic        mem_write_o,
    output logic        branch_o,
    output logic        jump_o,
    output logic        write_data_o,
    output logic        lui_o,
    output logic        is_jalr_o,
    output logic [2:0]  alu_op_o,

    output logic        opA_sel_o,
    output logic        opB_sel_o,
    output logic [1:0]  rs1_sel_o,
    output logic [1:0]  rs2_sel_o
);

    // RISC-V NOP: addi x0, x0, 0 (currently unused)
    localparam logic [31:0] NOP_INSTR = 32'h0000_0013;

    // -------------------------
    // Field decode
    // -------------------------
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

    // -------------------------
    // Regfile read
    // -------------------------
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

    // Implement a WB-> ID Bypass in order to provide fresh operands
    // Give to Branch Operand Mux, ID/EX Reg
    logic [31:0] id_rs1_data, id_rs2_data;          

    always_comb begin
      id_rs1_data = rs1_rf;
      id_rs2_data = rs2_rf;
    
      if (wb_we_i && (wb_rd_i != 5'd0) && (wb_rd_i == rs1))
        id_rs1_data = wb_wdata_i;
    
      if (wb_we_i && (wb_rd_i != 5'd0) && (wb_rd_i == rs2))
        id_rs2_data = wb_wdata_i;
    end


    // -------------------------
    // Immediate generator
    // -------------------------
    logic [31:0] imm_d;

    ImmGen IG (
        .instr_i (instr_i),
        .imm_o   (imm_d)
    );

    // -------------------------
    // Control decode
    // -------------------------
    logic        regwrite_d,
                 mem_read_d,
                 mem_write_d,
                 branch_d,
                 jump_d,
                 write_data_d,
                 opA_sel_d,
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
        .OpA_sel    (opA_sel_d),
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
                 opA_sel_g,
                 opB_sel_g,
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
            opA_sel_g    = 1'b0;
            opB_sel_g    = 1'b0;
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
            opA_sel_g    = opA_sel_d;
            opB_sel_g    = opB_sel_d;
            lui_g        = lui_d;
            is_jalr_g    = is_jalr_d;
            alu_op_g     = alu_op_d;
        end
    end

    // -------------------------
    // Hazard detection -> stall 
    // -------------------------
    logic stall_hazard;

    Hazard_Unit HU (
        .instr_valid_i    (instr_valid_i),
        .opcode_i         (opcode),
        .rs1_i            (rs1),
        .rs2_i            (rs2),
        .id_ex_mem_read_i (id_ex_mem_read_i),
        .id_ex_rd_i       (id_ex_rd_i),
        .ex_mem_mem_read_i(ex_mem_mem_read_i),
        .ex_mem_rd_i      (ex_mem_rd_i),
        .stall_o          (stall_hazard)
    );

    assign stall_o = stall_hazard;

    // -------------------------
    // Forwarding for branch compare (ID-stage)
    // -------------------------
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
        br_rs1_val = id_rs1_data;
        br_rs2_val = id_rs2_data;

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

    // -------------------------
    // Branch / Jump decision in ID
    // -------------------------
    logic        redirect_d;
    logic [31:0] target_pc_d;
    logic [31:0] link_pc_d; // currently unused in this module

    // Do not allow redirect decisions while stalled
    logic branch_eff, jump_eff, jalr_eff;
    assign branch_eff = branch_g   & ~stall_o;
    assign jump_eff   = jump_g     & ~stall_o;
    assign jalr_eff   = is_jalr_g  & ~stall_o;

    Branch_Unit BU (
        .pc            (pc_i),
        .pc4           (pc4_i),
        .rs1           (br_rs1_val),
        .rs2           (br_rs2_val),
        .imm           (imm_d),
        .branch        (branch_eff),
        .jump          (jump_eff),
        .pcsrc         (jalr_eff),
        .funct3        (funct3),
        .redirect      (redirect_d),
        .target_pc     (target_pc_d)
    );

    // FIX: suppress flush while stalled
    assign flush_o         = redirect_d & ~stall_o;
    assign branch_target_o = target_pc_d;

    // -------------------------
    // Drive outputs to downstream stage
    // Bubble on invalid / redirect / stall / reset
    // -------------------------
    logic bubble;
    
    assign bubble = rst | !instr_valid_i | flush_o;

    always_comb begin
        // defaults = bubble
        rs1_val_o    = 32'd0;
        rs2_val_o    = 32'd0;
        imm_o        = 32'd0;

        rs1_o        = 5'd0;
        rs2_o        = 5'd0;
        rd_o         = 5'd0;
        funct3_o     = 3'd0;
        funct7_o     = 7'd0;

        regwrite_o   = 1'b0;
        mem_read_o   = 1'b0;
        mem_write_o  = 1'b0;
        branch_o     = 1'b0;
        jump_o       = 1'b0;
        write_data_o = 1'b0;
        lui_o        = 1'b0;
        is_jalr_o    = 1'b0;
        alu_op_o     = `NOP;

        opA_sel_o    = 1'b0;
        opB_sel_o    = 1'b0;
        rs1_sel_o    = 2'b00;
        rs2_sel_o    = 2'b00;

        if (!bubble) begin
            rs1_val_o    = id_rs1_data;
            rs2_val_o    = id_rs2_data;
            imm_o        = imm_d;

            rs1_o        = rs1;
            rs2_o        = rs2;
            rd_o         = rd;
            funct3_o     = funct3;
            funct7_o     = funct7;

            // Safer to use gated controls
            regwrite_o   = regwrite_g;
            mem_read_o   = mem_read_g;
            mem_write_o  = mem_write_g;
            branch_o     = branch_g;
            jump_o       = jump_g;
            write_data_o = write_data_g;
            lui_o        = lui_g;
            is_jalr_o    = is_jalr_g;
            alu_op_o     = alu_op_g;

            opA_sel_o    = opA_sel_g;
            opB_sel_o    = opB_sel_g;
            rs1_sel_o    = RS1_Sel_d;
            rs2_sel_o    = RS2_Sel_d;
        end
    end

endmodule
