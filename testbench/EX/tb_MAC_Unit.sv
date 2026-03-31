`include "Def.vh"
`timescale 1ns / 1ps

// Isolated unit test for MAC_Unit — no pipeline required.
// Drives EX and WB ports directly, checks accumulator outputs.
//
// NOTE: The MAC defines below must match what gets added to Def.vh
// during integration (see MAC_Integration_Guide.md §5.1). They are
// duplicated here so this testbench compiles standalone before those
// changes are made.

`ifndef MAC_OP_NONE
    `define MAC_OP_NONE    3'b000
    `define MAC_OP_MAC     3'b001
    `define MAC_OP_MACCLR  3'b010
    `define MAC_OP_RDLO    3'b011
    `define MAC_OP_RDHI    3'b100
    `define MAC_FRAC_BITS  16
`endif

module tb_MAC_Unit;

    logic clk, rst;
    localparam time TCLK = 10ns;

    initial begin
        clk = 1'b0;
        forever #(TCLK/2) clk = ~clk;
    end

    // DUT signals
    logic [31:0] ex_rs1, ex_rs2;
    logic [2:0]  ex_mac_op;
    logic [63:0] ex_mac_delta;

    logic        wb_valid;
    logic [2:0]  wb_mac_op;
    logic [63:0] wb_mac_delta;

    logic [31:0] acc_lo, acc_hi;

    MAC_Unit dut (
        .clk            (clk),
        .rst            (rst),
        .ex_rs1_val_i   (ex_rs1),
        .ex_rs2_val_i   (ex_rs2),
        .ex_mac_op_i    (ex_mac_op),
        .ex_mac_delta_o (ex_mac_delta),
        .wb_valid_i     (wb_valid),
        .wb_mac_op_i    (wb_mac_op),
        .wb_mac_delta_i (wb_mac_delta),
        .acc_lo_o       (acc_lo),
        .acc_hi_o       (acc_hi)
    );

    // Test counters
    int pass_count, fail_count;

    task automatic check(input string name,
                         input logic [31:0] actual,
                         input logic [31:0] expected);
        if (actual === expected) begin
            $display("[PASS] %s: 0x%08x", name, actual);
            pass_count++;
        end else begin
            $display("[FAIL] %s: got 0x%08x, expected 0x%08x", name, actual, expected);
            fail_count++;
        end
    endtask

    // Compute EX multiply (combinational) and return the delta
    task automatic do_ex_multiply(input logic [31:0] rs1, input logic [31:0] rs2,
                                  output logic [63:0] delta);
        ex_rs1    = rs1;
        ex_rs2    = rs2;
        ex_mac_op = `MAC_OP_MAC;
        #1;
        delta     = ex_mac_delta;
        ex_mac_op = `MAC_OP_NONE;
    endtask

    // Commit a MAC accumulate at WB
    task automatic commit_mac(input logic [63:0] delta);
        @(posedge clk);
        wb_valid     = 1'b1;
        wb_mac_op    = `MAC_OP_MAC;
        wb_mac_delta = delta;
        @(posedge clk);
        wb_valid     = 1'b0;
        wb_mac_op    = `MAC_OP_NONE;
        wb_mac_delta = 64'd0;
    endtask

    // Commit a MACCLR at WB
    task automatic commit_macclr;
        @(posedge clk);
        wb_valid     = 1'b1;
        wb_mac_op    = `MAC_OP_MACCLR;
        wb_mac_delta = 64'd0;
        @(posedge clk);
        wb_valid     = 1'b0;
        wb_mac_op    = `MAC_OP_NONE;
    endtask

    // Q16.16 constants
    localparam logic [31:0] Q_1_0  = 32'h0001_0000;  // 1.0
    localparam logic [31:0] Q_2_0  = 32'h0002_0000;  // 2.0
    localparam logic [31:0] Q_3_0  = 32'h0003_0000;  // 3.0
    localparam logic [31:0] Q_4_0  = 32'h0004_0000;  // 4.0
    localparam logic [31:0] Q_NEG1 = 32'hFFFF_0000;  // -1.0

    logic [63:0] delta;

    initial begin
        pass_count = 0;
        fail_count = 0;

        // Init
        rst          = 1'b1;
        ex_rs1       = 32'd0;
        ex_rs2       = 32'd0;
        ex_mac_op    = `MAC_OP_NONE;
        wb_valid     = 1'b0;
        wb_mac_op    = `MAC_OP_NONE;
        wb_mac_delta = 64'd0;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        // TEST 1: Accumulator starts at zero after reset
        check("Reset acc_lo", acc_lo, 32'h0000_0000);
        check("Reset acc_hi", acc_hi, 32'h0000_0000);

        // TEST 2: EX multiply 1.0 * 2.0 = 0x0002_0000 (combinational)
        do_ex_multiply(Q_1_0, Q_2_0, delta);
        check("EX delta_lo (1.0*2.0)", delta[31:0], 32'h0002_0000);
        check("EX delta_hi (1.0*2.0)", delta[63:32], 32'h0000_0000);

        // TEST 3: Commit that MAC, read accumulator
        commit_mac(delta);
        check("ACC lo after 1.0*2.0", acc_lo, 32'h0002_0000);
        check("ACC hi after 1.0*2.0", acc_hi, 32'h0000_0000);

        // TEST 4: Accumulate 3.0 * 4.0 = 12.0, total = 14.0
        do_ex_multiply(Q_3_0, Q_4_0, delta);
        commit_mac(delta);
        check("ACC lo after +3.0*4.0 (14.0)", acc_lo, 32'h000E_0000);
        check("ACC hi after +3.0*4.0", acc_hi, 32'h0000_0000);

        // TEST 5: MACCLR resets accumulator
        commit_macclr();
        check("ACC lo after MACCLR", acc_lo, 32'h0000_0000);
        check("ACC hi after MACCLR", acc_hi, 32'h0000_0000);

        // TEST 6: Negative multiply: 1.0 * (-1.0) = -1.0
        do_ex_multiply(Q_1_0, Q_NEG1, delta);
        check("EX delta_lo (1.0*-1.0)", delta[31:0], Q_NEG1);
        check("EX delta_hi (1.0*-1.0)", delta[63:32], 32'hFFFF_FFFF);
        commit_mac(delta);
        check("ACC lo after 1.0*-1.0", acc_lo, Q_NEG1);
        check("ACC hi after 1.0*-1.0", acc_hi, 32'hFFFF_FFFF);

        // TEST 7: Non-MAC ops don't change accumulator
        commit_macclr();
        do_ex_multiply(Q_2_0, Q_3_0, delta);
        @(posedge clk);
        wb_valid  = 1'b1;
        wb_mac_op = `MAC_OP_RDLO;
        @(posedge clk);
        wb_valid  = 1'b0;
        wb_mac_op = `MAC_OP_NONE;
        check("ACC unchanged after MACRDLO", acc_lo, 32'h0000_0000);

        // TEST 8: wb_valid=0 prevents accumulator update
        do_ex_multiply(Q_1_0, Q_2_0, delta);
        @(posedge clk);
        wb_valid     = 1'b0;
        wb_mac_op    = `MAC_OP_MAC;
        wb_mac_delta = delta;
        @(posedge clk);
        wb_mac_op    = `MAC_OP_NONE;
        wb_mac_delta = 64'd0;
        check("ACC unchanged when valid=0", acc_lo, 32'h0000_0000);

        // TEST 9: Zero output when ex_mac_op != MAC
        ex_rs1    = Q_2_0;
        ex_rs2    = Q_3_0;
        ex_mac_op = `MAC_OP_NONE;
        #1;
        check("Delta=0 when op=NONE", ex_mac_delta[31:0], 32'h0000_0000);

        // Results
        $display("\n%0d / %0d tests passed.", pass_count, pass_count + fail_count);
        if (fail_count == 0)
            $display("ALL TESTS PASSED\n");
        else
            $display("%0d TEST(S) FAILED\n", fail_count);

        $finish;
    end

endmodule
