`timescale 1ns / 1ps

module regfile (
    input  logic        clk,
    input  logic        rst,

    // Write port (from WB)
    input  logic        we_i,
    input  logic [4:0]  waddr_i,
    input  logic [31:0] wdata_i,

    // Read ports (combinational)
    input  logic [4:0]  raddr1_i,
    input  logic [4:0]  raddr2_i,
    output logic [31:0] rdata1_o,
    output logic [31:0] rdata2_o
);

    logic [31:0] regs [31:0];

    integer k;
    always_ff @(posedge clk) begin
        if (rst) begin
            for (k = 0; k < 32; k++) regs[k] <= 32'd0;
        end
        else if (we_i && (waddr_i != 5'd0)) begin
            regs[waddr_i] <= wdata_i;
        end
    end

    assign rdata1_o = (raddr1_i == 5'd0) ? 32'd0 : regs[raddr1_i];
    assign rdata2_o = (raddr2_i == 5'd0) ? 32'd0 : regs[raddr2_i];

endmodule
