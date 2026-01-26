`include "Def.vh"
`timescale 1ns / 1ps

module Decode_Unit(
    input  logic        clk,
    input  logic        rst,

    // From fetch
    input  logic        instr_valid_i,
    input  logic [31:0] instr_i,
    input  logic [31:0] pc_i,
    input  logic [31:0] pc_plus4_i,

    // Pipeline control
    input  logic        stall_i,   // hold IF/ID, insert bubble to ID/EX (typical load-use behavior)
    input  logic        flush_i,   // kill instruction in decode / bubble

    // Writeback into regfile
    input  logic        wb_we_i,
    input  logic [4:0]  wb_rd_i,
    input  logic [31:0] wb_wdata_i,

    // To execute (ID/EX registered outputs)
    output logic        idexe_valid_o,
    output logic [31:0] pc_o,
    output logic [31:0] pc4_o,
    output logic [31:0] rs1_val_o,
    output logic [31:0] rs2_val_o,
    output logic [31:0] imm_o,
    output logic [4:0]  rd_o,
    output logic [4:0]  rs1_o,
    output logic [4:0]  rs2_o,
    output logic [2:0]  func3_o,
    output logic [31:25] func7_o,

    // Control signals to execute/mem/wb
    output logic        regwrite_o,
    output logic        mem_read_o,
    output logic        mem_write_o,
    output logic        branch_o,
    output logic        jump_o,
    output logic        write_data_o,
    output logic        lui_o,
    output logic        pcsrc_o,
    output logic [2:0]  alu_op_o,
    output logic [1:0]  OpA_sel_o,
    output logic        OpB_sel_o
);

    // --------- Field extraction ----------
    logic [6:0] opcode;
    logic [4:0] rd, rs1, rs2;
    logic [2:0] func3;
    logic [31:25] func7;

    assign opcode = instr_i[6:0];
    assign rd     = instr_i[11:7];
    assign func3  = instr_i[14:12];
    assign rs1    = instr_i[19:15];
    assign rs2    = instr_i[24:20];
    assign func7  = instr_i[31:25];

    // --------- Regfile read ----------
    logic [31:0] rs1_val, rs2_val;

    regfile rf (
        .clk     (clk),
        .rst     (rst),
        .we_i    (wb_we_i),
        .waddr_i (wb_rd_i),
        .wdata_i (wb_wdata_i),
        .raddr1_i(rs1),
        .raddr2_i(rs2),
        .rdata1_o(rs1_val),
        .rdata2_o(rs2_val)
    );

    // --------- Immediate ----------
    logic [31:0] imm_d;
    ImmGen ig (
        .instr_i(instr_i),
        .imm_o  (imm_d)
    );

    // --------- Control Unit ----------
    logic regwrite_d, mem_read_d, mem_write_d, branch_d, jump_d;
    logic write_data_d, OpA_sel_1b_d, OpB_sel_d, lui_d, pcsrc_d;
    logic [2:0] alu_op_d;

    Control_Unit cu (
        .opcode     (opcode),
        .regwrite   (regwrite_d),
        .mem_read   (mem_read_d),
        .mem_write  (mem_write_d),
        .branch     (branch_d),
        .jump       (jump_d),
        .write_data (write_data_d),
        .OpA_sel    (OpA_sel_1b_d), // NOTE: 1-bit in your current CU
        .OpB_sel    (OpB_sel_d),
        .lui        (lui_d),
        .pcsrc      (pcsrc_d),
        .alu_op     (alu_op_d)
    );

    // Expand OpA_sel to 2 bits for Execute_Unit
    // Default: RS1
    logic [1:0] OpA_sel_d2;
    always_comb begin
        OpA_sel_d2 = 2'b10; // RS1

        // AUIPC wants PC + imm
        if (opcode == 7'b0010111) OpA_sel_d2 = 2'b00; // PC

        // JAL/JALR typically need PC for pc+4 writeback path
        if (opcode == 7'b1101111 || opcode == 7'b1100111) OpA_sel_d2 = 2'b00; // PC

        // If your team later wants PC4 for something, use 2'b01
    end

    // --------- Bubble / valid gating ----------
    logic kill_d;
    assign kill_d = flush_i || !instr_valid_i;

    // Typical behavior:
    // - flush_i kills the instruction (turn into bubble)
    // - stall_i inserts a bubble into ID/EX (while IF/ID is held by fetch+skid)
    // If your hazard unit uses stall differently, adjust this block.
    always_ff @(posedge clk) begin
        if (rst) begin
            idexe_valid_o <= 1'b0;

            pc_o <= 32'd0; pc4_o <= 32'd0;
            rs1_val_o <= 32'd0; rs2_val_o <= 32'd0; imm_o <= 32'd0;
            rd_o <= 5'd0; rs1_o <= 5'd0; rs2_o <= 5'd0;
            func3_o <= 3'd0; func7_o <= '0;

            regwrite_o <= 1'b0; mem_read_o <= 1'b0; mem_write_o <= 1'b0;
            branch_o <= 1'b0; jump_o <= 1'b0; write_data_o <= 1'b0;
            lui_o <= 1'b0; pcsrc_o <= 1'b0;
            alu_op_o <= `NOP;
            OpA_sel_o <= 2'b10;
            OpB_sel_o <= 1'b0;
        end else if (stall_i) begin
            // insert bubble into execute stage
            idexe_valid_o <= 1'b0;
            regwrite_o <= 1'b0; mem_read_o <= 1'b0; mem_write_o <= 1'b0;
            branch_o <= 1'b0; jump_o <= 1'b0; write_data_o <= 1'b0;
            lui_o <= 1'b0; pcsrc_o <= 1'b0;
            alu_op_o <= `NOP;
            OpA_sel_o <= 2'b10;
            OpB_sel_o <= 1'b0;
        end else begin
            idexe_valid_o <= !kill_d;

            // datapath fields
            pc_o      <= pc_i;
            pc4_o     <= pc_plus4_i;
            rs1_val_o <= rs1_val;
            rs2_val_o <= rs2_val;
            imm_o     <= imm_d;

            rd_o   <= rd;
            rs1_o  <= rs1;
            rs2_o  <= rs2;
            func3_o <= func3;
            func7_o <= func7;

            // controls (killed -> forced to 0)
            regwrite_o   <= kill_d ? 1'b0 : regwrite_d;
            mem_read_o   <= kill_d ? 1'b0 : mem_read_d;
            mem_write_o  <= kill_d ? 1'b0 : mem_write_d;
            branch_o     <= kill_d ? 1'b0 : branch_d;
            jump_o       <= kill_d ? 1'b0 : jump_d;
            write_data_o <= kill_d ? 1'b0 : write_data_d;
            lui_o        <= kill_d ? 1'b0 : lui_d;
            pcsrc_o      <= kill_d ? 1'b0 : pcsrc_d;
            alu_op_o     <= kill_d ? `NOP : alu_op_d;

            OpA_sel_o    <= kill_d ? 2'b10 : OpA_sel_d2;
            OpB_sel_o    <= kill_d ? 1'b0  : OpB_sel_d;
        end
    end

endmodule
