`timescale 1ns / 1ps

module mem_wb_reg #(
    parameter int XLEN = 32
) (
    input  logic             clk,
    input  logic             rst,        // active-high synchronous reset

    input  logic             flush_i,    // optional (set 0 if unused)
    input  logic             stall_i,    // optional (set 0 if unused)

    // Inputs from EX/MEM (control + rd + calc/alu result)
    input  logic             ex_mem_valid_i,
    input  logic [31:0]      ex_mem_instr_i,
    input  logic [4:0]       ex_mem_rd_i,
    input  logic             ex_mem_regwrite_i,
    input  logic             ex_mem_write_data_i, // 1=mem->wb, 0=alu->wb
    input  logic [XLEN-1:0]  ex_mem_alu_out_i,

    // Inputs from mem_unit (formatted load result)
    input  logic             mem_load_valid_i,
    input  logic [XLEN-1:0]  mem_load_data_i,

    // Outputs to WB stage
    output logic             mem_wb_valid_o,
    output logic [31:0]      mem_wb_instr_o,
    output logic [4:0]       mem_wb_rd_o,
    output logic             mem_wb_regwrite_o,
    output logic             mem_wb_write_data_o,
    output logic [XLEN-1:0]  mem_wb_alu_out_o,
    output logic             mem_wb_load_valid_o,
    output logic [XLEN-1:0]  mem_wb_load_data_o
);
    // Shadow Registers (1-Cycle Delayed) necessary for the holding EX/MEM data from request cycle
    // Necessary for ensuring accuracy for Load operations
    logic            ex_mem_valid_q;
    logic [31:0]     ex_mem_instr_q;
    logic [4:0]      ex_mem_rd_q;
    logic            ex_mem_regwrite_q;
    logic            ex_mem_write_data_q;
    logic [XLEN-1:0] ex_mem_alu_out_q;
    
    always_ff @(posedge clk) begin
        if (rst || flush_i) begin
            // Flush/reset kills side effects (NOP bubble)
            mem_wb_valid_o        <= 1'b0;
            mem_wb_instr_o        <= 32'h00000013; // NOP
            mem_wb_rd_o           <= 5'd0;
            mem_wb_regwrite_o     <= 1'b0;
            mem_wb_write_data_o   <= 1'b0;
            mem_wb_alu_out_o      <= 32'b0;
            mem_wb_load_valid_o   <= 1'b0;
            mem_wb_load_data_o    <= 32'b0;
            
            // Clear Shadow Registers
            ex_mem_valid_q        <= 1'b0;
            ex_mem_instr_q        <= 32'h00000013;
            ex_mem_rd_q           <= 5'd0;
            ex_mem_regwrite_q     <= 1'b0;
            ex_mem_write_data_q   <= 1'b0;
            ex_mem_alu_out_q      <= 32'b0;
        end
        else if (!stall_i) begin
            // Always update shadow with the current EX/MEM metadata
            ex_mem_valid_q        <= ex_mem_valid_i;
            ex_mem_instr_q        <= ex_mem_instr_i;
            ex_mem_rd_q           <= ex_mem_rd_i;
            ex_mem_regwrite_q     <= ex_mem_regwrite_i;
            ex_mem_write_data_q   <= ex_mem_write_data_i;
            ex_mem_alu_out_q      <= ex_mem_alu_out_i;
            
            // If a load response arrives this cycle, use shadow metadata (request-cycle)
            if (mem_load_valid_i) begin
                mem_wb_valid_o      <= ex_mem_valid_q;
                mem_wb_instr_o      <= ex_mem_instr_q;
                mem_wb_rd_o         <= ex_mem_rd_q;
                mem_wb_regwrite_o   <= ex_mem_regwrite_q;
                mem_wb_write_data_o <= ex_mem_write_data_q; // should be 1 for loads
                mem_wb_alu_out_o    <= ex_mem_alu_out_q;

                mem_wb_load_valid_o <= 1'b1;
                mem_wb_load_data_o  <= mem_load_data_i;     // response-cycle data
            end
            else begin
                // Non-load (ALU, store, etc.) passes through normally
                mem_wb_valid_o      <= ex_mem_valid_i;
                mem_wb_instr_o      <= ex_mem_instr_i;
                mem_wb_rd_o         <= ex_mem_rd_i;
                mem_wb_regwrite_o   <= ex_mem_regwrite_i;
                mem_wb_write_data_o <= ex_mem_write_data_i;
                mem_wb_alu_out_o    <= ex_mem_alu_out_i;

                mem_wb_load_valid_o <= 1'b0;
                mem_wb_load_data_o  <= '0;
            end
        // else: stall -> hold state (do nothing)
        end
    end

endmodule

