`timescale 1ns / 1ps

module Forwarding_Unit (
    // Source registers of instruction in ID stage (for branch forwarding)
    input  logic [4:0]  if_id_rs1,
    input  logic [4:0]  if_id_rs2,

    // Source registers of instruction in EX stage (for ALU forwarding)
    input  logic [4:0]  id_ex_rs1,
    input  logic [4:0]  id_ex_rs2,

    // ID/EX stage (EX), producer info
    input  logic [4:0]  id_ex_rd,
    input  logic        id_ex_regwrite,
    input  logic        id_ex_mem_read,
    input  logic        id_ex_wb_pc4_sel,

    // EX/MEM stage (MEM), producer info
    input  logic [4:0]  ex_mem_rd,
    input  logic        ex_mem_regwrite,
    input  logic        ex_mem_mem_read,
    input  logic        ex_mem_wb_pc4_sel,

    // MEM/WB stage (WB), producer info
    input  logic [4:0]  mem_wb_rd,
    input  logic        mem_wb_regwrite,

    // EX-stage ALU operand forwarding (for Execute_Unit)
    //   00 = use ID/EX register value (no forward)
    //   01 = forward from MEM stage (EX/MEM ALU result)
    //   10 = forward from WB stage  (MEM/WB writeback value)
    output logic [1:0]  ex_fwd_a,
    output logic [1:0]  ex_fwd_b,

    // ID-stage branch compare forwarding (for Decode/Branch_Unit)
    //   00 = use register file value
    //   01 = forward from WB  (MEM/WB value)
    //   10 = forward from MEM (EX/MEM ALU out -or- PC+4)
    //   11 = forward from EX  (ID/EX ALU out, combinational)
    output logic [1:0]  br_fwd_a,
    output logic [1:0]  br_fwd_b,

    // When br_fwd selects MEM (10), use PC+4 instead of ALU out?
    output logic        br_fwd_a_use_pc4,
    output logic        br_fwd_b_use_pc4
);

    always_comb begin
        //  EX-stage forwarding (MEM > WB priority)
        ex_fwd_a = 2'b00;
        ex_fwd_b = 2'b00;

        // RS1
        if (ex_mem_regwrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs1) && !ex_mem_mem_read)
            ex_fwd_a = 2'b01;   // from MEM (ALU result)
        else if (mem_wb_regwrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs1))
            ex_fwd_a = 2'b10;   // from WB

        // RS2
        if (ex_mem_regwrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs2) && !ex_mem_mem_read)
            ex_fwd_b = 2'b01;
        else if (mem_wb_regwrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs2))
            ex_fwd_b = 2'b10;

        //  ID-stage branch forwarding (EX > MEM > WB priority)
        br_fwd_a         = 2'b00;
        br_fwd_b         = 2'b00;
        br_fwd_a_use_pc4 = 1'b0;
        br_fwd_b_use_pc4 = 1'b0;

        // RS1 for branch 
        if      (id_ex_regwrite  && (id_ex_rd  != 5'd0) && (id_ex_rd  == if_id_rs1) && !id_ex_mem_read && !id_ex_wb_pc4_sel)
            br_fwd_a = 2'b11;   // from EX ALU out
        else if (ex_mem_regwrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == if_id_rs1) && !ex_mem_mem_read) begin
            br_fwd_a         = 2'b10;   // from MEM
            br_fwd_a_use_pc4 = ex_mem_wb_pc4_sel;
        end
        else if (mem_wb_regwrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == if_id_rs1))
            br_fwd_a = 2'b01;   // from WB

        //  RS2 for branch
        if      (id_ex_regwrite  && (id_ex_rd  != 5'd0) && (id_ex_rd  == if_id_rs2) && !id_ex_mem_read && !id_ex_wb_pc4_sel)
            br_fwd_b = 2'b11;
        else if (ex_mem_regwrite && (ex_mem_rd != 5'd0) && (ex_mem_rd == if_id_rs2) && !ex_mem_mem_read) begin
            br_fwd_b         = 2'b10;
            br_fwd_b_use_pc4 = ex_mem_wb_pc4_sel;
        end
        else if (mem_wb_regwrite && (mem_wb_rd != 5'd0) && (mem_wb_rd == if_id_rs2))
            br_fwd_b = 2'b01;
    end

endmodule
