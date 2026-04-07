`timescale 1ns / 1ps

module ex_mem_reg (
    input  logic        clk,
    input  logic        rst,
    input  logic        flush_i,
    input  logic        stall_i,

    // From EX stage
    input  logic        valid_i,
    input  logic [31:0] instr_i,
    input  logic [31:0] alu_out_i,
    input  logic [31:0] store_data_i,
    input  logic [31:0] pc4_i,
    input  logic [4:0]  rd_i,
    input  logic [2:0]  funct3_i,
    input  logic        regwrite_i,
    input  logic        mem_read_i,
    input  logic        mem_write_i,
    input  logic        wb_sel_i,
    input  logic        wb_pc4_sel_i,
    input  logic [2:0]  MAC_op_i,           
    input  logic [63:0] MAC_delta_i,        

    // Registered outputs
    output logic        valid_o,
    output logic [31:0] instr_o,
    output logic [31:0] alu_out_o,
    output logic [31:0] store_data_o,
    output logic [31:0] pc4_o,
    output logic [4:0]  rd_o,
    output logic [2:0]  funct3_o,
    output logic        regwrite_o,
    output logic        mem_read_o,
    output logic        mem_write_o,
    output logic        wb_sel_o,
    output logic        wb_pc4_sel_o,
    output logic [2:0]  MAC_op_o,           
    output logic [63:0] MAC_delta_o         

);

    always_ff @(posedge clk) begin
        if (rst || flush_i) begin
            valid_o      <= 1'b0;   instr_o      <= 32'h0000_0013;
            alu_out_o    <= 32'd0;  store_data_o <= 32'd0;
            pc4_o        <= 32'd0;  rd_o         <= 5'd0;
            funct3_o     <= 3'd0;
            regwrite_o   <= 1'b0;   mem_read_o   <= 1'b0;
            mem_write_o  <= 1'b0;   wb_sel_o     <= 1'b0;
            wb_pc4_sel_o <= 1'b0;
            MAC_op_o     <= `MAC_OP_NOP;
            MAC_delta_o  <= 64'd0;
        end
        else if (!stall_i) begin
            valid_o      <= valid_i;
            instr_o      <= instr_i;
            alu_out_o    <= alu_out_i;
            store_data_o <= store_data_i;
            pc4_o        <= pc4_i;
            rd_o         <= rd_i;
            funct3_o     <= valid_i ? funct3_i : 3'd0;
            regwrite_o   <= regwrite_i  & valid_i;
            mem_read_o   <= mem_read_i  & valid_i;
            mem_write_o  <= mem_write_i & valid_i;
            wb_sel_o     <= wb_sel_i    & valid_i;
            wb_pc4_sel_o <= wb_pc4_sel_i & valid_i;
            MAC_op_o     <= MAC_op_i;
            MAC_delta_o  <= MAC_delta_i;
        end
    end

endmodule

