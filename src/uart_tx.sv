`timescale 1ns/1ps
 
module uart_tx #(
    parameter int unsigned CLK_HZ = 100_000_000,
    parameter int unsigned BAUD   = 115200
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       start_i,
    input  logic [7:0] data_i,
    output logic       tx_o,
    output logic       ready_o
);
    localparam int unsigned CLKS_PER_BIT = CLK_HZ / BAUD;
 
    typedef enum logic [1:0] {
        TX_IDLE,
        TX_START,
        TX_DATA,
        TX_STOP
    } tx_state_t;
 
    tx_state_t state;
    logic [$clog2(CLKS_PER_BIT+1)-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] shift_reg;
 
    always_ff @(posedge clk) begin
        if (rst) begin
            state     <= TX_IDLE;
            clk_count <= '0;
            bit_index <= 3'd0;
            shift_reg <= 8'd0;
            tx_o      <= 1'b1;
            ready_o   <= 1'b1;
        end else begin
            case (state)
                TX_IDLE: begin
                    tx_o    <= 1'b1;
                    ready_o <= 1'b1;
                    clk_count <= '0;
                    bit_index <= 3'd0;
                    if (start_i) begin
                        shift_reg <= data_i;
                        ready_o   <= 1'b0;
                        state     <= TX_START;
                    end
                end
 
                TX_START: begin
                    tx_o <= 1'b0;
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= '0;
                        state     <= TX_DATA;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
 
                TX_DATA: begin
                    tx_o <= shift_reg[bit_index];
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= '0;
                        if (bit_index == 3'd7) begin
                            bit_index <= 3'd0;
                            state     <= TX_STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
 
                TX_STOP: begin
                    tx_o <= 1'b1;
                    if (clk_count == CLKS_PER_BIT-1) begin
                        clk_count <= '0;
                        state     <= TX_IDLE;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end
 
                default: state <= TX_IDLE;
            endcase
        end
    end
endmodule
