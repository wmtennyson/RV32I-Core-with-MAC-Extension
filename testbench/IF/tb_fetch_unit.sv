`timescale 1ns / 1ps

module tb_fetch_unit;

    // 1. Signals
    logic        clk;
    logic        rst;
    logic        stall_i;
    logic        flush_i;
    logic [31:0] branch_target_i;
    
    // Outputs from DUT
    logic [31:0] bram_addr_o;
    logic        bram_en_o;
    logic [31:0] bram_rdata_i;
    
    logic        instr_valid_o;
    logic [31:0] instr_o;
    logic [31:0] pc_o;
    logic [31:0] pc_plus4_o;

    // 2. Instantiate the DUT (Device Under Test)
    fetch_unit DUT (
        .clk(clk),
        .rst(rst),
        .stall_i(stall_i),
        .flush_i(flush_i),
        .branch_target_i(branch_target_i),
        .bram_addr_o(bram_addr_o),
        .bram_en_o(bram_en_o),
        .bram_rdata_i(bram_rdata_i),
        .instr_valid_o(instr_valid_o),
        .instr_o(instr_o),
        .pc_o(pc_o),
        .pc_plus4_o(pc_plus4_o)
    );

    // 3. Clock Generation (100MHz = 10ns period)
    always #5 clk = ~clk;

    // 4. Mimic BRAM Behavior (Fake Memory)
    // We create a small array to act as memory for testing
    logic [31:0] test_mem [0:255]; 

    always_ff @(posedge clk) begin
        if (bram_en_o) begin
            // Simulates 1-cycle read latency
            // Use [9:2] to handle word alignment and keep array small
            bram_rdata_i <= test_mem[bram_addr_o[9:2]];
        end
    end

    // 5. Test Procedure
    initial begin
        // Initialize Signals
        clk = 0;
        rst = 1;
        stall_i = 0;
        flush_i = 0;
        branch_target_i = 0;

        // Fill "Memory" with recognizable patterns
        // PC 0x00 -> 0xAAAA_0000
        // PC 0x04 -> 0xAAAA_0004
        // ...
        for (int i = 0; i < 256; i++) begin
            test_mem[i] = 32'hAAAA_0000 + (i * 4); 
        end

        // --- RESET SEQUENCE ---
        $display("Applying Reset...");
        #20;
        rst = 0;
        #10; // Wait for valid data to flow through pipe

        // --- TEST 1: Normal Execution ---
        $display("Test 1: Normal Execution");
        // We expect PC to increment: 0, 4, 8, 12...
        // We expect Instr to match: AAAA0000, AAAA0004...
        #50; 

        // --- TEST 2: Stall Injection ---
        $display("Test 2: Assert Stall");
        // At this point, let's say PC is at 0x14.
        // We assert stall. 
        // 1. The PC should freeze.
        // 2. The memory will return data for 0x18 (requested previous cycle).
        // 3. The SKID BUFFER should catch 0x18.
        @(posedge clk);
        stall_i = 1; 
        
        #30; // Hold stall for 3 clocks. output should remain constant.
        
        $display("Test 2: Release Stall");
        @(posedge clk); 
        stall_i = 0; // Release. The output should immediately be the skid data (0x18)
        
        #20; // Resume normal

        // --- TEST 3: Flush (Branch) ---
        $display("Test 3: Flush / Branch");
        @(posedge clk);
        flush_i = 1;
        branch_target_i = 32'h0000_0040; // Jump to 0x40
        
        @(posedge clk);
        flush_i = 0;
        
        // Output should be NOP during flush
        // Then PC should jump to 0x40, and data AAAA0040 should appear a cycle later
        #50;

        $display("Test Complete");
        $finish;
    end

endmodule
