`include "Def.vh"
`timescale 1ns / 1ps

// Full-pipeline testbench for the MAC extension.
// Instantiates RV32I_Core with IMEM/DMEM models, loads a test program
// that exercises all 4 MAC instructions, stores results to DMEM,
// and checks against expected values.
//
// Requires all integration changes from MAC_Integration_Guide.md.

module tb_RV32I_Core_MAC;

    // Clock / reset
    logic clk, rst;
    localparam time TCLK = 10ns;

    initial begin
        clk = 1'b0;
        forever #(TCLK/2) clk = ~clk;
    end

    initial begin
        rst = 1'b1;
        repeat (8) @(posedge clk);
        rst = 1'b0;
    end

    // DUT interface
    logic [31:0] imem_addr;
    logic        imem_en;
    logic [31:0] imem_rdata;

    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_wstrb;
    logic        dmem_we;
    logic        dmem_re;
    logic [31:0] dmem_rdata;

    logic done_o, trap_o;

    RV32I_Core dut (
        .clk        (clk),
        .rst        (rst),
        .imem_addr  (imem_addr),
        .imem_en    (imem_en),
        .imem_rdata (imem_rdata),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_wstrb (dmem_wstrb),
        .dmem_we    (dmem_we),
        .dmem_re    (dmem_re),
        .dmem_rdata (dmem_rdata),
        .done_o     (done_o),
        .trap_o     (trap_o)
    );

    // IMEM model (1-cycle latency BRAM)
    localparam int IMEM_WORDS = 256;
    logic [31:0] imem [0:IMEM_WORDS-1];
    logic [31:0] imem_addr_q;

    localparam logic [31:0] NOP    = 32'h0000_0013;
    localparam logic [31:0] EBREAK = 32'h0010_0073;

    always_ff @(posedge clk) begin
        if (rst) imem_addr_q <= 32'd0;
        else if (imem_en) imem_addr_q <= imem_addr;
    end

    always_comb begin
        int unsigned idx;
        idx = imem_addr_q[31:2];
        if (idx < IMEM_WORDS) imem_rdata = imem[idx];
        else                  imem_rdata = NOP;
    end

    // DMEM model (byte-addressed, 1-cycle read latency)
    localparam int DMEM_BYTES = 4096;
    byte dmem [0:DMEM_BYTES-1];
    logic        dmem_re_q;
    logic [31:0] dmem_addr_q;

    function automatic logic [31:0] read_word(input logic [31:0] addr);
        int unsigned a;
        begin
            a = addr;
            read_word = {dmem[a+3], dmem[a+2], dmem[a+1], dmem[a+0]};
        end
    endfunction

    initial begin : init_dmem
        int i;
        for (i = 0; i < DMEM_BYTES; i++) dmem[i] = 8'h00;
    end

    always_ff @(posedge clk) begin
        if (!rst && dmem_we) begin
            int unsigned a;
            a = dmem_addr;
            if (a + 3 < DMEM_BYTES) begin
                if (dmem_wstrb[0]) dmem[a+0] <= dmem_wdata[7:0];
                if (dmem_wstrb[1]) dmem[a+1] <= dmem_wdata[15:8];
                if (dmem_wstrb[2]) dmem[a+2] <= dmem_wdata[23:16];
                if (dmem_wstrb[3]) dmem[a+3] <= dmem_wdata[31:24];
            end
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            dmem_re_q   <= 1'b0;
            dmem_addr_q <= 32'd0;
        end else begin
            dmem_re_q <= dmem_re;
            if (dmem_re) dmem_addr_q <= dmem_addr;
        end
    end

    always_comb begin
        if (dmem_re_q) begin
            int unsigned a;
            a = dmem_addr_q;
            if (a + 3 < DMEM_BYTES) dmem_rdata = {dmem[a+3], dmem[a+2], dmem[a+1], dmem[a+0]};
            else                    dmem_rdata = 32'h0;
        end else begin
            dmem_rdata = 32'h0;
        end
    end

    // MAC instruction encoders
    function automatic logic [31:0] enc_MAC(input logic [4:0] rs1, input logic [4:0] rs2);
        enc_MAC = {7'b0000000, rs2, rs1, 3'b000, 5'b00000, 7'b0001011};
    endfunction

    function automatic logic [31:0] enc_MACCLR();
        enc_MACCLR = {7'b0000000, 5'b00000, 5'b00000, 3'b001, 5'b00000, 7'b0001011};
    endfunction

    function automatic logic [31:0] enc_MACRDLO(input logic [4:0] rd);
        enc_MACRDLO = {7'b0000000, 5'b00000, 5'b00000, 3'b010, rd, 7'b0001011};
    endfunction

    function automatic logic [31:0] enc_MACRDHI(input logic [4:0] rd);
        enc_MACRDHI = {7'b0000000, 5'b00000, 5'b00000, 3'b011, rd, 7'b0001011};
    endfunction

    // RV32I helpers
    function automatic logic [31:0] enc_LUI(input logic [4:0] rd, input logic [19:0] imm20);
        enc_LUI = {imm20, rd, 7'b0110111};
    endfunction

    function automatic logic [31:0] enc_SW(input logic [4:0] rs2, rs1,
                                           input logic [11:0] imm);
        enc_SW = {imm[11:5], rs2, rs1, 3'b010, imm[4:0], 7'b0100011};
    endfunction

    // Test program
    //   x1 = 1.0 (0x0001_0000)    x2 = 2.0 (0x0002_0000)
    //   x3 = 3.0 (0x0003_0000)    x4 = 4.0 (0x0004_0000)
    //
    //   Test 1: MACCLR -> MACRDLO x10 -> sw x10, 0(x0)    expect 0x0000_0000
    //   Test 2: MAC x1,x2 -> MACRDLO x11 -> sw x11, 4(x0) expect 0x0002_0000
    //   Test 3: MAC x3,x4 -> MACRDLO x12 -> sw x12, 8(x0) expect 0x000E_0000
    //   Test 4: MACRDHI x13 -> sw x13, 12(x0)              expect 0x0000_0000
    //   Test 5: MACCLR -> MACRDLO x14 -> sw x14, 16(x0)   expect 0x0000_0000

    initial begin : init_imem
        int i;
        for (i = 0; i < IMEM_WORDS; i++) imem[i] = NOP;

        // Load Q16.16 constants
        imem[0]  = enc_LUI(5'd1, 20'h00010);   // x1 = 0x0001_0000 (1.0)
        imem[1]  = enc_LUI(5'd2, 20'h00020);   // x2 = 0x0002_0000 (2.0)
        imem[2]  = enc_LUI(5'd3, 20'h00030);   // x3 = 0x0003_0000 (3.0)
        imem[3]  = enc_LUI(5'd4, 20'h00040);   // x4 = 0x0004_0000 (4.0)

        // Test 1: MACCLR then read
        imem[4]  = enc_MACCLR();
        imem[5]  = NOP;
        imem[6]  = NOP;
        imem[7]  = enc_MACRDLO(5'd10);
        imem[8]  = NOP;
        imem[9]  = NOP;
        imem[10] = NOP;
        imem[11] = enc_SW(5'd10, 5'd0, 12'h000);  // sw x10, 0(x0)

        // Test 2: MAC 1.0*2.0 then read
        imem[12] = enc_MACCLR();
        imem[13] = NOP;
        imem[14] = enc_MAC(5'd1, 5'd2);
        imem[15] = NOP;
        imem[16] = NOP;
        imem[17] = NOP;
        imem[18] = enc_MACRDLO(5'd11);
        imem[19] = NOP;
        imem[20] = NOP;
        imem[21] = NOP;
        imem[22] = enc_SW(5'd11, 5'd0, 12'h004);  // sw x11, 4(x0)

        // Test 3: Accumulate 3.0*4.0 (acc = 2.0 + 12.0 = 14.0)
        imem[23] = enc_MAC(5'd3, 5'd4);
        imem[24] = NOP;
        imem[25] = NOP;
        imem[26] = NOP;
        imem[27] = enc_MACRDLO(5'd12);
        imem[28] = NOP;
        imem[29] = NOP;
        imem[30] = NOP;
        imem[31] = enc_SW(5'd12, 5'd0, 12'h008);  // sw x12, 8(x0)

        // Test 4: Read upper 32 bits
        imem[32] = enc_MACRDHI(5'd13);
        imem[33] = NOP;
        imem[34] = NOP;
        imem[35] = NOP;
        imem[36] = enc_SW(5'd13, 5'd0, 12'h00C);  // sw x13, 12(x0)

        // Test 5: Clear and verify
        imem[37] = enc_MACCLR();
        imem[38] = NOP;
        imem[39] = NOP;
        imem[40] = enc_MACRDLO(5'd14);
        imem[41] = NOP;
        imem[42] = NOP;
        imem[43] = NOP;
        imem[44] = enc_SW(5'd14, 5'd0, 12'h010);  // sw x14, 16(x0)

        // Done
        imem[45] = EBREAK;
    end

    // Result checking
    localparam int MAX_CYCLES = 10000;
    int cycles;
    bit timed_out;
    int pass_count, fail_count;

    task automatic check(input string name,
                         input logic [31:0] addr,
                         input logic [31:0] expected);
        logic [31:0] actual;
        actual = read_word(addr);
        if (actual === expected) begin
            $display("[PASS] %s: mem[0x%04x] = 0x%08x", name, addr, actual);
            pass_count++;
        end else begin
            $display("[FAIL] %s: mem[0x%04x] = 0x%08x, expected 0x%08x",
                     name, addr, actual, expected);
            fail_count++;
        end
    endtask

    initial begin
        cycles     = 0;
        timed_out  = 0;
        pass_count = 0;
        fail_count = 0;

        @(negedge rst);

        fork
            begin : timeout_thread
                repeat (MAX_CYCLES) begin
                    @(posedge clk);
                    cycles++;
                end
                timed_out = 1;
            end
            begin : trap_thread
                @(posedge trap_o);
            end
            begin : done_thread
                @(posedge done_o);
            end
        join_any
        disable fork;

        #1ps;

        if (timed_out) begin
            $display("\nFAIL: Timeout after %0d cycles. done=%b trap=%b\n",
                     MAX_CYCLES, done_o, trap_o);
            $finish;
        end

        if (trap_o) begin
            $display("\nFAIL: trap_o asserted at cycle %0d\n", cycles);
            $finish;
        end

        // Check stored results
        $display("\n======== MAC Pipeline Test Results ========");
        check("MACCLR->MACRDLO (expect 0)",            32'h0000, 32'h0000_0000);
        check("MAC 1.0*2.0->MACRDLO (expect 2.0)",     32'h0004, 32'h0002_0000);
        check("Accum 3.0*4.0->MACRDLO (expect 14.0)",  32'h0008, 32'h000E_0000);
        check("MACRDHI (expect 0)",                     32'h000C, 32'h0000_0000);
        check("MACCLR reset->MACRDLO (expect 0)",       32'h0010, 32'h0000_0000);

        $display("\n%0d / %0d tests passed.  (cycle %0d)",
                 pass_count, pass_count + fail_count, cycles);

        if (fail_count == 0)
            $display("========     ALL TESTS PASSED     ========\n");
        else
            $display("========   %0d TEST(S) FAILED    ========\n", fail_count);

        $finish;
    end

endmodule
