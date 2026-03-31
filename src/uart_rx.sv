`timescale 1ns/1ps
 
module uart_rx #(
    parameter int unsigned CLK_HZ = 100_000_000,
    parameter int unsigned BAUD   = 115200
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx_i,
    output logic [7:0] data_o,
    output logic       data_valid_o
);
    localparam int unsigned CLKS_PER_BIT  = CLK_HZ / BAUD;
    localparam int unsigned HALF_BIT_TICK = CLKS_PER_BIT / 2;
 
    typedef enum logic [1:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP
    } rx_state_t;
 
    rx_state_t state;
    logic [$clog2(CLKS_PER_BIT+1)-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] shift_reg;
 
    always_ff @(posedge clk) begin
        if (rst) begin
            state        <= RX_IDLE;
            clk_count    <= '0;
            bit_index    <= 3'd0;
            shift_reg    <= 8'd0;
            data_o       <= 8'd0;
            data_valid_o <= 1'b0;
        end else begin
            data_valid_o <= 1'b0;
 
            case (state)
                RX_IDLE: begin
                    clk_count <= '0;
                    bit_index <= 3'd0;
                    if (!rx_i)
                        state <= RX_START;
                end
 
                RX_START: begin
                    if (clk_count == HALF_BIT_TICK-1) begin
                        if (!rx_i) begin
                            clk_count <= '0;
                            state     <= RX_DATA;
                        end else begin
                            state <= RX_IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
 
                RX_DATA: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count           <= '0;
                        shift_reg[bit_index] <= rx_i;
                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= RX_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
 
                RX_STOP: begin
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count    <= '0;
                        data_o       <= shift_reg;
                        data_valid_o <= 1'b1;
                        state        <= RX_IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
 
                default: state <= RX_IDLE;
            endcase
        end
    end
endmodule
