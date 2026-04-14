`timescale 1ns/1ps

module top_fpga #(
    parameter int unsigned CLK_HZ         = 50_000_000,
    parameter int unsigned UART_BAUD      = 115200,
    parameter int unsigned BOOT_ROM_WORDS = 2048,
    parameter int unsigned RAM_WORDS      = 16384
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       uart_rx,
    output logic       uart_tx,
    output logic [3:0] led
);

    logic clk_50;
    logic pll_locked;

    clk_wiz_0 pll_inst (
        .clk_in1  (clk),
        .resetn   (rst),
        .clk_out1 (clk_50),
        .locked   (pll_locked)
    );

    logic rst_int;
    (* shreg_extract = "no" *) logic [2:0] rst_sync = 3'b111;
    logic [63:0] cycle_ctr;

    always_ff @(posedge clk_50) begin
        // Reset synchronizer
        rst_sync <= {rst_sync[1:0], ~pll_locked | ~rst};

        // Free-running cycle counter
        if (rst_int)
            cycle_ctr <= 64'd0;
        else
            cycle_ctr <= cycle_ctr + 64'd1;
    end

    assign rst_int = rst_sync[2];

    localparam logic [31:0] NOP           = 32'h0000_0013;
    localparam logic [31:0] BOOT_BASE     = 32'h0000_0000;
    localparam logic [31:0] RAM_BASE      = 32'h2000_0000;
    localparam logic [31:0] RAM_BYTES     = RAM_WORDS * 4;
    localparam logic [31:0] UART_BASE     = 32'h4000_0000;
    localparam logic [31:0] CYCLE_LO_ADDR = 32'h4000_0008;
    localparam logic [31:0] CYCLE_HI_ADDR = 32'h4000_000C;

    logic [31:0] imem_addr;
    logic        imem_en;
    logic [31:0] imem_rdata;

    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic [3:0]  dmem_wstrb;
    logic        dmem_we;
    logic        dmem_re;
    logic [31:0] dmem_rdata;

    logic done_o;
    logic trap_o;

    RV32I_Core cpu (
        .clk        (clk_50),
        .rst        (rst_int),
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

    // Boot ROM (dual-port: Port A = instruction fetch, Port B = data read)
    // Strings in .text are read via the data path; without it, reads return 0 and uart_puts exits immediately
    (* ram_style = "block" *) logic [31:0] boot_rom [0:BOOT_ROM_WORDS-1];
    initial begin
        $readmemh("D:/Vivado/senior_proj_components/senior_proj_components.srcs/sources_1/imports/bootloader/bootloader.mem", boot_rom);
    end

    // Port A: instruction fetch
    logic [31:0] boot_rdata_q;
    always_ff @(posedge clk_50) begin
        if (imem_en)
            boot_rdata_q <= boot_rom[imem_addr[$clog2(BOOT_ROM_WORDS)+1:2]];
    end

    // Port B: data read (for bootloader string constants)
    logic [31:0] boot_dmem_rdata_q;
    always_ff @(posedge clk_50) begin
        if (dmem_re)
            boot_dmem_rdata_q <= boot_rom[dmem_addr[$clog2(BOOT_ROM_WORDS)+1:2]];
    end

    // Executable RAM - dual-port: Port A = imem, Port B = dmem
    (* ram_style = "block" *) logic [31:0] ram [0:RAM_WORDS-1];

    wire [$clog2(RAM_WORDS)-1:0] imem_ram_idx = (imem_addr - RAM_BASE) >> 2;
    wire [$clog2(RAM_WORDS)-1:0] dmem_ram_idx = (dmem_addr - RAM_BASE) >> 2;

    // Port A: instruction fetch (read-only)
    logic [31:0] ram_imem_rdata_q;
    always_ff @(posedge clk_50) begin
        if (imem_en)
            ram_imem_rdata_q <= ram[imem_ram_idx];
    end

    // Port B: data memory (read/write)
    logic [31:0] ram_dmem_rdata_q;
    always_ff @(posedge clk_50) begin
        if (dmem_we && is_ram_addr(dmem_addr)) begin
            if (dmem_wstrb[0]) ram[dmem_ram_idx][7:0]   <= dmem_wdata[7:0];
            if (dmem_wstrb[1]) ram[dmem_ram_idx][15:8]  <= dmem_wdata[15:8];
            if (dmem_wstrb[2]) ram[dmem_ram_idx][23:16] <= dmem_wdata[23:16];
            if (dmem_wstrb[3]) ram[dmem_ram_idx][31:24] <= dmem_wdata[31:24];
        end
        if (dmem_re)
            ram_dmem_rdata_q <= ram[dmem_ram_idx];
    end

    // Address-decode helpers
    function automatic logic is_boot_addr(input logic [31:0] addr);
        is_boot_addr = (addr >= BOOT_BASE) && (addr < (BOOT_BASE + BOOT_ROM_WORDS*4));
    endfunction

    function automatic logic is_ram_addr(input logic [31:0] addr);
        is_ram_addr = (addr >= RAM_BASE) && (addr < (RAM_BASE + RAM_BYTES));
    endfunction

    function automatic logic is_uart_data_addr(input logic [31:0] addr);
        is_uart_data_addr = (addr == UART_BASE);
    endfunction

    function automatic logic is_uart_status_addr(input logic [31:0] addr);
        is_uart_status_addr = (addr == (UART_BASE + 32'h4));
    endfunction

    function automatic logic is_cycle_lo_addr(input logic [31:0] addr);
        is_cycle_lo_addr = (addr == CYCLE_LO_ADDR);
    endfunction

    function automatic logic is_cycle_hi_addr(input logic [31:0] addr);
        is_cycle_hi_addr = (addr == CYCLE_HI_ADDR);
    endfunction

    // Instruction fetch output mux
    logic imem_was_boot, imem_was_ram;

    always_ff @(posedge clk_50) begin
        if (rst_int) begin
            imem_was_boot <= 1'b1;
            imem_was_ram  <= 1'b0;
        end else if (imem_en) begin
            imem_was_boot <= is_boot_addr(imem_addr);
            imem_was_ram  <= is_ram_addr(imem_addr);
        end
    end

    always_comb begin
        imem_rdata = NOP;
        if (imem_was_boot)
            imem_rdata = boot_rdata_q;
        else if (imem_was_ram)
            imem_rdata = ram_imem_rdata_q;
    end

    // UART
    logic [7:0] uart_rx_data;
    logic       uart_rx_pulse;
    logic [7:0] uart_rx_hold;
    logic       uart_rx_valid;

    logic [7:0] uart_tx_data;
    logic       uart_tx_start;
    logic       uart_tx_ready;

    uart_rx #(
        .CLK_HZ (CLK_HZ),
        .BAUD   (UART_BAUD)
    ) u_uart_rx (
        .clk         (clk_50),
        .rst         (rst_int),
        .rx_i        (uart_rx),
        .data_o      (uart_rx_data),
        .data_valid_o(uart_rx_pulse)
    );

    uart_tx #(
        .CLK_HZ (CLK_HZ),
        .BAUD   (UART_BAUD)
    ) u_uart_tx (
        .clk     (clk_50),
        .rst     (rst_int),
        .start_i (uart_tx_start),
        .data_i  (uart_tx_data),
        .tx_o    (uart_tx),
        .ready_o (uart_tx_ready)
    );

    // Data memory control
    logic        dmem_re_q;
    logic [31:0] dmem_addr_q;
    logic [31:0] cycle_rdata_q;

    always_ff @(posedge clk_50) begin
        if (rst_int) begin
            dmem_re_q     <= 1'b0;
            dmem_addr_q   <= 32'd0;
            uart_rx_hold  <= 8'd0;
            uart_rx_valid <= 1'b0;
            uart_tx_start <= 1'b0;
            uart_tx_data  <= 8'd0;
        end else begin
            uart_tx_start <= 1'b0;

            dmem_re_q <= dmem_re;
            if (dmem_re)
                dmem_addr_q <= dmem_addr;

            // Clear rx_valid when CPU reads the data register
            if (dmem_re && is_uart_data_addr(dmem_addr) && uart_rx_valid)
                uart_rx_valid <= 1'b0;

            // Sticky RX register
            if (uart_rx_pulse) begin
                uart_rx_hold  <= uart_rx_data;
                uart_rx_valid <= 1'b1;
            end

            if (dmem_we && is_uart_data_addr(dmem_addr) && uart_tx_ready) begin
                uart_tx_data  <= dmem_wdata[7:0];
                uart_tx_start <= 1'b1;
            end
        end
    end

    // Registered cycle counter read data (same 1-cycle read behavior as other DMEM reads)
    always_ff @(posedge clk_50) begin
        if (rst_int) begin
            cycle_rdata_q <= 32'd0;
        end else if (dmem_re) begin
            if (is_cycle_lo_addr(dmem_addr))
                cycle_rdata_q <= cycle_ctr[31:0];
            else if (is_cycle_hi_addr(dmem_addr))
                cycle_rdata_q <= cycle_ctr[63:32];
        end
    end

    // DMEM read output mux
    always_comb begin
        dmem_rdata = 32'h0000_0000;
        if (dmem_re_q) begin
            if (is_boot_addr(dmem_addr_q))
                dmem_rdata = boot_dmem_rdata_q;   // Boot ROM data read
            else if (is_ram_addr(dmem_addr_q))
                dmem_rdata = ram_dmem_rdata_q;
            else if (is_uart_data_addr(dmem_addr_q))
                dmem_rdata = {24'h0, uart_rx_hold};
            else if (is_uart_status_addr(dmem_addr_q))
                dmem_rdata = {30'h0, uart_tx_ready, uart_rx_valid};
            else if (is_cycle_lo_addr(dmem_addr_q) || is_cycle_hi_addr(dmem_addr_q))
                dmem_rdata = cycle_rdata_q;
        end
    end

    // LEDs
    // Stretch done_o into a visible pulse (~0.5 sec)
    logic [24:0] done_stretch;
    logic        done_led;
    always_ff @(posedge clk_50) begin
        if (rst_int) begin
            done_stretch <= '0;
            done_led     <= 1'b0;
        end else if (done_o) begin
            done_stretch <= 25'h1FFFFFF;
            done_led     <= 1'b1;
        end else if (done_stretch != '0) begin
            done_stretch <= done_stretch - 1;
        end else begin
            done_led <= 1'b0;
        end
    end

    // Stretch trap_o into a visible pulse (~0.5 sec)
    logic [24:0] trap_stretch;
    logic        trap_led;
    always_ff @(posedge clk_50) begin
        if (rst_int) begin
            trap_stretch <= '0;
            trap_led     <= 1'b0;
        end else if (trap_o) begin
            trap_stretch <= 25'h1FFFFFF;
            trap_led     <= 1'b1;
        end else if (trap_stretch != '0) begin
            trap_stretch <= trap_stretch - 1;
        end else begin
            trap_led <= 1'b0;
        end
    end

    // Stretch uart_rx_valid into a visible pulse (~0.2 sec)
    logic [23:0] rx_stretch;
    logic        rx_led;
    always_ff @(posedge clk_50) begin
        if (rst_int) begin
            rx_stretch <= '0;
            rx_led     <= 1'b0;
        end else if (uart_rx_pulse) begin
            rx_stretch <= 24'hFFFFFF;
            rx_led     <= 1'b1;
        end else if (rx_stretch != '0) begin
            rx_stretch <= rx_stretch - 1;
        end else begin
            rx_led <= 1'b0;
        end
    end

    assign led[0] = done_led;
    assign led[1] = trap_led;
    assign led[2] = rx_led;
    assign led[3] = uart_tx_ready;

endmodule
