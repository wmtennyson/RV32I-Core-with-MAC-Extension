`timescale 1ns / 1ps

module mem_wb_reg (
    input  logic        clk,
    input  logic        rst,

    input  logic        flush_i,      // optional (set 0 if unused)
    input  logic        stall_i,      // optional (set 0 if unused)

    // Inputs from EX/MEM (control + rd + alu result)
    input  logic        ex_mem_valid_i,
    input  logic [4:0]  ex_mem_rd_i,
    input  logic        ex_mem_regwrite_i,
    input  logic        ex_mem_write_data_i, // 1=mem->wb, 0=alu->wb
    input  logic [31:0] ex_mem_alu_out_i,

    // Inputs from mem_unit (formatted load result)
    input  logic        mem_load_valid_i,
    input  logic [31:0] mem_load_data_i,

    // Outputs to WB stage
    output logic        mem_wb_valid_o,
    output logic [4:0]  mem_wb_rd_o,
    output logic        mem_wb_regwrite_o,
    output logic        mem_wb_write_data_o,
    output logic [31:0] mem_wb_alu_out_o,
    output logic        mem_wb_load_valid_o,
    output logic [31:0] mem_wb_load_data_o
);

    always_ff @(posedge clk) begin
        if (rst || flush_i) begin
            mem_wb_valid_o        <= 1'b0;
            mem_wb_rd_o           <= 5'd0;
            mem_wb_regwrite_o     <= 1'b0;
            mem_wb_write_data_o   <= 1'b0;
            mem_wb_alu_out_o      <= 32'd0;
            mem_wb_load_valid_o   <= 1'b0;
            mem_wb_load_data_o    <= 32'd0;
        end else if (!stall_i) begin
            mem_wb_valid_o        <= ex_mem_valid_i;
            mem_wb_rd_o           <= ex_mem_rd_i;
            mem_wb_regwrite_o     <= ex_mem_regwrite_i;
            mem_wb_write_data_o   <= ex_mem_write_data_i;
            mem_wb_alu_out_o      <= ex_mem_alu_out_i;

            mem_wb_load_valid_o   <= mem_load_valid_i;
            mem_wb_load_data_o    <= mem_load_data_i;
        end
    end

endmodule
