`timescale 1ns / 1ps
module if_id_reg #(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        stall,
    input  logic        flush,
    input  logic [31:0] if_pc,
    input  logic [31:0] if_pc4,
    input  logic [31:0] bram_rdata_i,
    output logic        id_instr_valid,
    output logic [31:0] id_instr,
    output logic [31:0] id_pc,
    output logic [31:0] id_pc4
);
    localparam logic [31:0] NOP_INSTR = 32'h0000_0013;

    logic        valid_q;
    logic [31:0] instr_q, pc_q, pc4_q;
    logic [1:0]  drop_count_q;

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_q      <= 1'b0;
            instr_q      <= NOP_INSTR;
            pc_q         <= RESET_VECTOR;
            pc4_q        <= RESET_VECTOR + 32'd4;
            drop_count_q <= 2'd1;   // absorb 1-cycle IMEM latency on boot
        end else if (flush) begin
            valid_q      <= 1'b0;
            instr_q      <= NOP_INSTR;
            pc_q         <= RESET_VECTOR;
            pc4_q        <= RESET_VECTOR + 32'd4;
            drop_count_q <= 2'd1;   // one stale response to discard post-redirect
        end else if (drop_count_q != 2'd0) begin
            valid_q      <= 1'b0;
            drop_count_q <= drop_count_q - 2'd1;
        end else if (stall) begin
            // Hold everything - fetch_unit is re-fetching req_pc_q so
            // bram_rdata_i will be correct on the cycle stall releases.
        end else begin
            valid_q <= 1'b1;
            instr_q <= bram_rdata_i;
            pc_q    <= if_pc;
            pc4_q   <= if_pc4;
        end
    end

    assign id_instr_valid = valid_q;
    assign id_instr       = valid_q ? instr_q : NOP_INSTR;
    assign id_pc          = pc_q;
    assign id_pc4         = pc4_q;

endmodule
