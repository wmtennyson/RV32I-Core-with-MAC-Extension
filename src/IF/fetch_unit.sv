`timescale 1ns / 1ps

module fetch_unit #(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
)(
    input  logic        clk,
    input  logic        rst,

    // Pipeline control (from Decode stage)
    input  logic        stall_i,
    input  logic        flush_i,
    input  logic [31:0] branch_target_i,

    // Instruction BRAM interface
    output logic [31:0] bram_addr_o,
    output logic        bram_en_o,

    // To IF/ID register (1-cycle delayed to match BRAM latency)
    output logic [31:0] if_pc_o,
    output logic [31:0] if_pc_plus4_o
);

    logic [31:0] pc_q;       // current fetch address sent to BRAM
    logic [31:0] req_pc_q;   // tracks which address was actually requested

    always_ff @(posedge clk) begin
        if (rst) begin
            pc_q     <= RESET_VECTOR;
            req_pc_q <= RESET_VECTOR;
        end
        else begin
            // Track the address we sent to BRAM this cycle
            if (!stall_i || flush_i)
                req_pc_q <= pc_q;

            // Advance or redirect the fetch PC
            if (flush_i)
                pc_q <= branch_target_i;
            else if (!stall_i)
                pc_q <= pc_q + 32'd4;
            // else: stall — hold pc_q
        end
    end

    assign bram_addr_o   = pc_q;
    assign bram_en_o     = !stall_i || flush_i;

    // req_pc_q lags pc_q by 1 cycle, matching the BRAM output latency
    assign if_pc_o       = req_pc_q;
    assign if_pc_plus4_o = req_pc_q + 32'd4;

endmodule
