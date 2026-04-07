`timescale 1ns / 1ps

module mem_wb_reg (
    input  logic        clk,
    input  logic        rst,
    input  logic        flush_i,
    input  logic        stall_i,

    // From EX/MEM register
    input  logic        valid_i,
    input  logic [31:0] instr_i,
    input  logic [4:0]  rd_i,
    input  logic        regwrite_i,
    input  logic        wb_sel_i,       // 0=ALU, 1=MEM
    input  logic        wb_pc4_sel_i,   // 1=PC+4
    input  logic [31:0] alu_out_i,
    input  logic [31:0] pc4_i,

    // From mem_unit (arrives 1 cycle after read request)
    input  logic        load_valid_i,
    input  logic [31:0] load_data_i,
    input  logic [2:0]  MAC_op_i,           
    input  logic [63:0] MAC_delta_i,        

    // Registered outputs to WB
    output logic        valid_o,
    output logic [31:0] instr_o,
    output logic [4:0]  rd_o,
    output logic        regwrite_o,
    output logic        wb_sel_o,
    output logic        wb_pc4_sel_o,
    output logic [31:0] alu_out_o,
    output logic [31:0] pc4_o,
    output logic        load_valid_o,
    output logic [31:0] load_data_o,
    output logic [2:0]  MAC_op_o,           
    output logic [63:0] MAC_delta_o         
);

    always_ff @(posedge clk) begin
        if (rst || flush_i) begin
            valid_o      <= 1'b0;   
            instr_o      <= 32'h0000_0013;
            rd_o         <= 5'd0;   
            regwrite_o   <= 1'b0;
            wb_sel_o     <= 1'b0;   
            wb_pc4_sel_o <= 1'b0;
            alu_out_o    <= 32'd0;  
            pc4_o        <= 32'd0;
            load_valid_o <= 1'b0;   
            load_data_o  <= 32'd0;
            MAC_op_o     <= `MAC_OP_NOP;
            MAC_delta_o  <= 64'd0;
        end
        else if (!stall_i) begin
            valid_o      <= valid_i;
            instr_o      <= instr_i;
            rd_o         <= rd_i;
            regwrite_o   <= regwrite_i;
            wb_sel_o     <= wb_sel_i;
            wb_pc4_sel_o <= wb_pc4_sel_i;
            alu_out_o    <= alu_out_i;
            pc4_o        <= pc4_i;
            load_valid_o <= load_valid_i;
            load_data_o  <= load_data_i;
            MAC_op_o     <= MAC_op_i;
            MAC_delta_o  <= MAC_delta_i;
        end
    end

endmodule
