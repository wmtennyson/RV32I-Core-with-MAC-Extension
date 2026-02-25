`timescale 1ns / 1ps

module tb_fetch_unit();

    // System signals
    logic        clk;
    logic        rst;

    // Inputs to fetch_unit
    logic        stall_i;
    logic        flush_i;
    logic [31:0] branch_target_i;

    // Outputs from fetch_unit
    logic [31:0] bram_addr_o;
    logic        bram_en_o;
    logic [31:0] if_pc_o;
    logic [31:0] if_pc_plus4_o;

    // Error counter for self-verification
    int error_count = 0;

    // Instantiate the Unit Under Test (UUT)
    fetch_unit #(
        .RESET_VECTOR(32'h0000_0000)
    ) uut (
        .clk(clk),
        .rst(rst),
        .stall_i(stall_i),
        .flush_i(flush_i),
        .branch_target_i(branch_target_i),
        .bram_addr_o(bram_addr_o),
        .bram_en_o(bram_en_o),
        .if_pc_o(if_pc_o),
        .if_pc_plus4_o(if_pc_plus4_o)
    );

    // Clock Generation (100MHz)
    always #5 clk = ~clk;

    // Helper task to check outputs
    task check_outputs(input logic [31:0] exp_pc, input string test_name);
        #1; // Wait a tiny bit for combinational logic to settle
        if (if_pc_o !== exp_pc || bram_addr_o !== exp_pc || if_pc_plus4_o !== (exp_pc + 4) || bram_en_o !== 1'b1) begin
            $error("[%s] FAILED. Expected PC: %0h | Got PC: %0h, BRAM Addr: %0h, PC+4: %0h, BRAM EN: %b", 
                   test_name, exp_pc, if_pc_o, bram_addr_o, if_pc_plus4_o, bram_en_o);
            error_count++;
        end else begin
            $display("[%s] PASSED. PC = %0h", test_name, if_pc_o);
        end
    endtask

    // Main Test Sequence
    initial begin
        $display("==================================================");
        $display("Starting self-verifying testbench for fetch_unit");
        $display("==================================================");

        // Initialization
        clk = 0;
        rst = 1;
        stall_i = 0;
        flush_i = 0;
        branch_target_i = 32'h0000_0000;

        // Test 1: Reset behavior
        @(negedge clk);
        check_outputs(32'h0000_0000, "Reset State");

        // Test 2: Normal Execution (PC increments by 4)
        rst = 0;
        @(negedge clk); check_outputs(32'h0000_0004, "Normal Exec Cycle 1");
        @(negedge clk); check_outputs(32'h0000_0008, "Normal Exec Cycle 2");
        @(negedge clk); check_outputs(32'h0000_000C, "Normal Exec Cycle 3");

        // Test 3: Stall (PC should freeze at 0x0000_000c)
        stall_i = 1;
        @(negedge clk); check_outputs(32'h0000_000C, "Stall Cycle 1");
        @(negedge clk); check_outputs(32'h0000_000C, "Stall Cycle 2");
        @(negedge clk); check_outputs(32'h0000_000C, "Stall Cycle 3");

        // Test 4: Resume from Stall
        stall_i = 0;
        @(negedge clk); check_outputs(32'h0000_0010, "Resume Exec Cycle 1");
        @(negedge clk); check_outputs(32'h0000_0014, "Resume Exec Cycle 2");

        // Test 5: Flush (Branch taken)
        flush_i = 1;
        branch_target_i = 32'h0000_0100;
        // The PC updates to branch target on the *next* clock edge
        @(negedge clk); check_outputs(32'h0000_0100, "Flush/Branch Taken");

        // Test 6: Normal Execution after Branch
        flush_i = 0;
        @(negedge clk); check_outputs(32'h0000_0104, "Post-Branch Exec Cycle 1");
        @(negedge clk); check_outputs(32'h0000_0108, "Post-Branch Exec Cycle 2");

        // Final Report
        $display("==================================================");
        if (error_count == 0) begin
            $display("SUCCESS: All fetch_unit tests passed!");
        end else begin
            $display("FAILED: %0d tests failed in fetch_unit.", error_count);
        end
        $display("==================================================");
        $finish;
    end
endmodule
