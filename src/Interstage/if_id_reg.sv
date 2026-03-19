`timescale 1ns / 1ps

module if_id_reg #(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
)(
    input  logic        clk,
    input  logic        rst,

    input  logic        stall_i,
    input  logic        flush_i,

    // From fetch unit (PC that matches the BRAM request 1 cycle ago)
    input  logic [31:0] if_pc,
    input  logic [31:0] if_pc4,

    // From instruction BRAM (synchronous 1-cycle read)
    input  logic [31:0] bram_rdata_i,

    // To Decode stage
    output logic        id_instr_valid,
    output logic [31:0] id_instr,
    output logic [31:0] id_pc,
    output logic [31:0] id_pc4
);

    localparam logic [31:0] NOP = 32'h0000_0013;

    // After reset or flush, absorb 1 cycle of BRAM read latency
    logic drop_q;

    always_ff @(posedge clk) begin
        if (rst) begin
            id_instr_valid <= 1'b0;
            id_instr       <= NOP;
            id_pc          <= RESET_VECTOR;
            id_pc4         <= RESET_VECTOR + 32'd4;
            drop_q         <= 1'b1;
        end
        else if (flush_i) begin
            // Kill current instruction, drop 1 cycle for BRAM redirect
            id_instr_valid <= 1'b0;
            id_instr       <= NOP;
            drop_q         <= 1'b1;
        end
        else if (drop_q) begin
            // Absorb BRAM latency, output stays invalid
            id_instr_valid <= 1'b0;
            drop_q         <= 1'b0;
        end
        else if (stall_i) begin
            // Hold all outputs, BRAM retains its last output on the data bus,
            // so when stall releases, the correct data is still available.
        end
        else begin
            // Normal capture
            id_instr_valid <= 1'b1;
            id_instr       <= bram_rdata_i;
            id_pc          <= if_pc;
            id_pc4         <= if_pc4;
        end
    end

endmodule
