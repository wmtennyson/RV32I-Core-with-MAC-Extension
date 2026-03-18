`timescale 1ns / 1ps
module fetch_unit#(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        stall_i,
    input  logic        flush_i,
    input  logic [31:0] branch_target_i,
    output logic [31:0] bram_addr_o,
    output logic        bram_en_o,
    output logic [31:0] if_pc_o,
    output logic [31:0] if_pc_plus4_o
);
    logic [31:0] pc_f;
    logic [31:0] req_pc_q;
    logic        post_rst_q;

    always_ff @(posedge clk) begin
        if (rst) begin
            pc_f        <= RESET_VECTOR;
            req_pc_q    <= RESET_VECTOR;
            post_rst_q  <= 1'b1;
        end else begin
            post_rst_q <= 1'b0;

            // Track the address actually being sent to IMEM this cycle.
            // Stall: re-sending req_pc_q, so don't update it.
            // Flush: redirect immediately to branch target.
            if (!stall_i || flush_i)
                req_pc_q <= flush_i ? branch_target_i : pc_f;

            if (flush_i)
                pc_f <= branch_target_i;
            else if (!stall_i && !post_rst_q)
                pc_f <= pc_f + 32'd4;
        end
    end

    // During stall: re-present req_pc_q so the IMEM keeps returning the
    // in-flight instruction. When stall releases, bram_rdata_i will have
    // the correct next instruction and if_id_reg can capture it normally.
    assign bram_addr_o   = flush_i ? branch_target_i :
                           stall_i  ? req_pc_q :
                                      pc_f;
    assign bram_en_o     = 1'b1;   // always enabled - no dead cycles

    assign if_pc_o       = req_pc_q;
    assign if_pc_plus4_o = req_pc_q + 32'd4;

endmodule
