`include "Def.vh"
`timescale 1ns / 1ps

module MAC_Unit #(
    parameter int FRAC_BITS = `MAC_FRAC_BITS
)(
    input  logic        clk,
    input  logic        rst,

    // EX-stage inputs (combinational multiply)
    input  logic [31:0] ex_rs1_val_i,
    input  logic [31:0] ex_rs2_val_i,
    input  logic [2:0]  ex_mac_op_i,
    output logic [63:0] ex_mac_delta_o,

    // WB-stage inputs (accumulator commit)
    input  logic        wb_valid_i,
    input  logic [2:0]  wb_mac_op_i,
    input  logic [63:0] wb_mac_delta_i,

    // Accumulator read ports
    output logic [31:0] acc_lo_o,
    output logic [31:0] acc_hi_o
);

    // Fixed-point multiply (EX-stage, combinational)
    logic signed [63:0] mul_product;
    logic signed [63:0] mul_scaled;

    always_comb begin
        if (ex_mac_op_i == `MAC_OP_MAC) begin
            mul_product = signed'({{32{ex_rs1_val_i[31]}}, ex_rs1_val_i}) *
                          signed'({{32{ex_rs2_val_i[31]}}, ex_rs2_val_i});
            mul_scaled  = mul_product >>> FRAC_BITS;
        end
        else begin
            mul_product = 64'sd0;
            mul_scaled  = 64'sd0;
        end

        ex_mac_delta_o = mul_scaled;
    end

    // 64-bit saturating accumulator (WB-stage, sequential)
    logic signed [63:0] acc64;
    logic signed [63:0] sat_sum;
    logic               sat_overflow;

    always_comb begin
        sat_sum      = acc64 + wb_mac_delta_i;
        sat_overflow = (acc64[63] == wb_mac_delta_i[63]) &&
                       (acc64[63] != sat_sum[63]);
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            acc64 <= 64'sd0;
        end
        else if (wb_valid_i) begin
            case (wb_mac_op_i)
                `MAC_OP_MACCLR: acc64 <= 64'sd0;
                `MAC_OP_MAC: begin
                    if (sat_overflow)
                        acc64 <= acc64[63] ? 64'sh8000_0000_0000_0000
                                          : 64'sh7FFF_FFFF_FFFF_FFFF;
                    else
                        acc64 <= sat_sum;
                end
                default: ;
            endcase
        end
    end

    // Accumulator read ports
    assign acc_lo_o = acc64[31:0];
    assign acc_hi_o = acc64[63:32];

endmodule
