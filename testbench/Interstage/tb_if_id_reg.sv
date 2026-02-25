`timescale 1ns / 1ps

module tb_if_id_reg();

    // System signals
    logic        clk;
    logic        rst;

    // Inputs to if_id_reg
    logic        stall;
    logic        flush;
    logic[31:0] if_pc;
    logic [31:0] if_pc4;
    logic[31:0] bram_rdata_i;

    // Outputs from if_id_reg
    logic        id_instr_valid;
    logic [31:0] id_instr;
    logic[31:0] id_pc;
    logic [31:0] id_pc4;

    // Constants & Error counter
    localparam logic [31:0] NOP_INSTR = 32'h0000_0013;
    localparam logic [31:0] RESET_VEC = 32'h0000_0000;
    int error_count = 0;

    // Instantiate UUT
    if_id_reg #(
        .RESET_VECTOR(RESET_VEC)
    ) uut (
        .clk(clk),
        .rst(rst),
        .stall(stall),
        .flush(flush),
        .if_pc(if_pc),
        .if_pc4(if_pc4),
        .bram_rdata_i(bram_rdata_i),
        .id_instr_valid(id_instr_valid),
        .id_instr(id_instr),
        .id_pc(id_pc),
        .id_pc4(id_pc4)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Helper task to check outputs
    task check_outputs(
        input logic        exp_valid,
        input logic [31:0] exp_instr,
        input logic [31:0] exp_pc,
        input string       test_name
    );
        #1; // Allow comb logic to propagate
        if (id_instr_valid !== exp_valid || id_instr !== exp_instr || id_pc !== exp_pc) begin
            $error("[%s] FAILED. Expected Valid: %b, Instr: %0h, PC: %0h | Got Valid: %b, Instr: %0h, PC: %0h",
                   test_name, exp_valid, exp_instr, exp_pc, id_instr_valid, id_instr, id_pc);
            error_count++;
        end else begin
            $display("[%s] PASSED.", test_name);
        end
    endtask

    // Main Test Sequence
    initial begin
        $display("==================================================");
        $display("Starting self-verifying testbench for if_id_reg");
        $display("==================================================");

        // Init
        clk = 0;
        rst = 1;
        stall = 0;
        flush = 0;
        if_pc = 32'h0;
        if_pc4 = 32'h4;
        bram_rdata_i = 32'h0;

        // Test 1: Reset behavior
        @(negedge clk);
        // Valid should be 0, instr should be NOP_INSTR
        check_outputs(1'b0, NOP_INSTR, RESET_VEC, "Reset State");

        // Test 2: Normal Pass-Through
        rst = 0;
        if_pc  = 32'h100;
        if_pc4 = 32'h104;
        @(negedge clk);
        // Now BRAM delivers data fetched from 0x100
        bram_rdata_i = 32'hAABBCCDD; 
        check_outputs(1'b1, 32'hAABBCCDD, 32'h100, "Normal Pass-Through Cycle 1");

        // Test 3: Normal Pass-Through Sequence
        if_pc  = 32'h104;
        if_pc4 = 32'h108;
        @(negedge clk);
        bram_rdata_i = 32'h11223344;
        check_outputs(1'b1, 32'h11223344, 32'h104, "Normal Pass-Through Cycle 2");

        // Test 4: Stall occurs (Testing Skid Buffer logic)
        // At this edge, IF fetched 0x108. The BRAM delivers data for 0x108 exactly now.
        // Decode is stalling, so it asserts stall.
        stall = 1; 
        if_pc = 32'h108; // Fetch freezes, holds IF_PC
        if_pc4 = 32'h10C;
        bram_rdata_i = 32'hDEADBEEF; // Data arriving from BRAM right as stall starts
        check_outputs(1'b1, 32'hDEADBEEF, 32'h104, "Stall Cycle 0 (Pass-through BRAM data)");
        
        // Next cycle: BRAM might output junk/changing data because fetch addresses might wiggle or we want to prove we locked it
        @(negedge clk); 
        bram_rdata_i = 32'hBADBAD00; 
        // We expect the skid buffer to have caught DEADBEEF and PC to freeze at 0x104
        check_outputs(1'b1, 32'hDEADBEEF, 32'h104, "Stall Cycle 1 (Skid Buffer Active)");

        // Stalling for another cycle
        @(negedge clk);
        bram_rdata_i = 32'hBADBAD11; 
        check_outputs(1'b1, 32'hDEADBEEF, 32'h104, "Stall Cycle 2 (Skid Buffer Active)");

        // Test 5: Stall drops, normal execution resumes
        stall = 0;
        bram_rdata_i = 32'hBEEFCAFE; // BRAM returning to returning the suspended instruction
        @(negedge clk);
        check_outputs(1'b1, 32'hBEEFCAFE, 32'h108, "Resume Post-Stall");

        // Test 6: Flush Priority
        if_pc = 32'h200;
        if_pc4 = 32'h204;
        flush = 1;
        // Even if stall is asserted with flush, flush should win (checking RTL: if(rst || flush)...)
        stall = 1; 
        @(negedge clk);
        bram_rdata_i = 32'hFFFFFFFF; // Irrelevant due to flush
        check_outputs(1'b0, NOP_INSTR, RESET_VEC, "Flush (Bubble introduced)");

        // Flush drops, back to normal
        flush = 0;
        stall = 0;
        if_pc = 32'h300;
        if_pc4 = 32'h304;
        @(negedge clk);
        bram_rdata_i = 32'h99999999;
        check_outputs(1'b1, 32'h99999999, 32'h300, "Normal Exec Post-Flush");

        // Final Report
        $display("==================================================");
        if (error_count == 0) begin
            $display("SUCCESS: All if_id_reg tests passed!");
        end else begin
            $display("FAILED: %0d tests failed in if_id_reg.", error_count);
        end
        $display("==================================================");
        $finish;
    end
endmodule
