`timescale 1ns/1ps
`include "Def.vh"

// ------------------------------------------------------------
// ID/EX Pipeline Register + OpA Select Builder
// - Computes opA_sel from opA_sel_bit (your decode control)
// - Registers all ID-stage outputs into ID/EX outputs
// - Inserts bubble (NOP) on reset/flush/stall/invalid
// ------------------------------------------------------------
module id_ex_pipe_reg (
    input  logic        clk,
    input  logic        rst,

    input  logic        flush_i,
    input  logic        stall_i,
    input  logic        instr_valid_i,

    // ID-stage data inputs
    input  logic [31:0] pc_i,
    input  logic [31:0] pc4_i,
    input  logic [31:0] rs1_val_i,
    input  logic [31:0] rs2_val_i,
    input  logic [31:0] imm_i,

    input  logic [4:0]  rs1_i,
    input  logic [4:0]  rs2_i,
    input  logic [4:0]  rd_i,
    input  logic [2:0]  funct3_i,
    input  logic [6:0]  funct7_i,

    // ID-stage control inputs (already gated in decode if you did that)
    input  logic        regwrite_i,
    input  logic        mem_read_i,
    input  logic        mem_write_i,
    input  logic        branch_i,
    input  logic        jump_i,
    input  logic        write_data_i,
    input  logic        lui_i,
    input  logic        is_jalr_i,
    input  logic [2:0]  alu_op_i,

    // Execute select inputs
    input  logic        opA_sel_bit_i,     
    input  logic        opB_sel_i,         
    input  logic [1:0]  rs1_sel_i,         
    input  logic [1:0]  rs2_sel_i,

    // ID/EX registered outputs
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

    output logic        id_ex_regwrite_o,
    output logic        id_ex_mem_read_o,
    output logic        id_ex_mem_write_o,
    output logic        id_ex_branch_o,
    output logic        id_ex_jump_o,
    output logic        id_ex_write_data_o,
    output logic        id_ex_lui_o,
    output logic        id_ex_is_jalr_o,
    output logic [2:0]  id_ex_alu_op_o,

    output logic [1:0]  id_ex_opA_sel_o,  
    output logic        id_ex_opB_sel_o,
    output logic [1:0]  id_ex_rs1_sel_o,
    output logic [1:0]  id_ex_rs2_sel_o
);


    logic [1:0] opA_sel_d;

    always_comb begin
        opA_sel_d = 2'b10;            
        if (opA_sel_bit_i) opA_sel_d = 2'b00; 

    end

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

    // -------------------------
    // ID/EX pipeline register
    // -------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            set_idex_nop();
        end else if (flush_i) begin
            set_idex_nop();
        end else if (stall_i) begin
            set_idex_nop();
        end else if (!instr_valid_i) begin
            set_idex_nop();
        end else begin
            id_ex_valid_o       <= 1'b1;

            id_ex_pc_o          <= pc_i;
            id_ex_pc4_o         <= pc4_i;
            id_ex_rs1_val_o     <= rs1_val_i;
            id_ex_rs2_val_o     <= rs2_val_i;
            id_ex_imm_o         <= imm_i;

            id_ex_rs1_o         <= rs1_i;
            id_ex_rs2_o         <= rs2_i;
            id_ex_rd_o          <= rd_i;
            id_ex_funct3_o      <= funct3_i;
            id_ex_funct7_o      <= funct7_i;

            id_ex_regwrite_o    <= regwrite_i;
            id_ex_mem_read_o    <= mem_read_i;
            id_ex_mem_write_o   <= mem_write_i;
            id_ex_branch_o      <= branch_i;
            id_ex_jump_o        <= jump_i;
            id_ex_write_data_o  <= write_data_i;
            id_ex_lui_o         <= lui_i;
            id_ex_is_jalr_o     <= is_jalr_i;
            id_ex_alu_op_o      <= alu_op_i;

            id_ex_opA_sel_o     <= opA_sel_d;
            id_ex_opB_sel_o     <= opB_sel_i;

            id_ex_rs1_sel_o     <= rs1_sel_i;
            id_ex_rs2_sel_o     <= rs2_sel_i;
        end
    end

endmodule
