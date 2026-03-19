`timescale 1ns / 1ps
 
module mem_unit (
    input  logic        clk,
    input  logic        rst,
 
    // From EX/MEM pipeline register
    input  logic        valid_i,
    input  logic [31:0] addr_i,
    input  logic [31:0] store_data_i,
    input  logic [2:0]  funct3_i,
    input  logic        mem_read_i,
    input  logic        mem_write_i,
 
    // Data memory BRAM interface
    output logic [31:0] dmem_addr_o,
    output logic        dmem_en_o,
    output logic [3:0]  dmem_we_o,
    output logic [31:0] dmem_wdata_o,
    input  logic [31:0] dmem_rdata_i,
 
    // To MEM/WB stage
    output logic        mem_stall_o,
    output logic        load_valid_o,
    output logic [31:0] load_data_o
);
 
    logic [1:0] addr_lsb;
    assign addr_lsb    = addr_i[1:0];
    assign dmem_addr_o = {addr_i[31:2], 2'b00};
 
    logic       rd_wait_q;
    logic [1:0] rd_lsb_q;
    logic [2:0] rd_funct3_q;
 
    // A new load request: valid load that hasn't already been issued
    logic       load_request;
    assign load_request = valid_i && mem_read_i && !rd_wait_q;
 
    assign dmem_en_o = valid_i && (mem_write_i || load_request);
 
    // Store logic
    always_comb begin
        dmem_we_o    = 4'b0000;
        dmem_wdata_o = 32'd0;
 
        if (valid_i && mem_write_i) begin
            unique case (funct3_i)
                3'b000: begin  // SB
                    dmem_we_o    = 4'b0001 << addr_lsb;
                    dmem_wdata_o = store_data_i << (8 * addr_lsb);
                end
                3'b001: begin  // SH
                    if (!addr_lsb[0]) begin
                        dmem_we_o    = addr_lsb[1] ? 4'b1100 : 4'b0011;
                        dmem_wdata_o = store_data_i << (16 * addr_lsb[1]);
                    end
                end
                3'b010: begin  // SW
                    if (addr_lsb == 2'b00) begin
                        dmem_we_o    = 4'b1111;
                        dmem_wdata_o = store_data_i;
                    end
                end
                default: ;
            endcase
        end
    end
 
    // Load request / response tracking
    always_ff @(posedge clk) begin
        if (rst) begin
            rd_wait_q   <= 1'b0;
            rd_lsb_q    <= 2'b00;
            rd_funct3_q <= 3'b000;
        end
        else begin
            if (rd_wait_q) begin
                // Response cycle: BRAM data is now valid, clear wait flag
                rd_wait_q <= 1'b0;
            end
            else if (load_request) begin
                // Request cycle: launch BRAM read, enter wait state
                rd_wait_q   <= 1'b1;
                rd_lsb_q    <= addr_i[1:0];
                rd_funct3_q <= funct3_i;
            end
        end
    end
 
    // Stall on the REQUEST cycle so EX/MEM metadata stays aligned
    assign mem_stall_o  = load_request;
    
    // Data is valid on the RESPONSE cycle (one cycle after request)
    assign load_valid_o = rd_wait_q;
 
    // Load result formatting 
    logic [7:0]  byte_sel;
    logic [15:0] half_sel;
 
    always_comb begin
        load_data_o = 32'd0;
        byte_sel    = (dmem_rdata_i >> (8  * rd_lsb_q))    & 8'hFF;
        half_sel    = (dmem_rdata_i >> (16 * rd_lsb_q[1])) & 16'hFFFF;
 
        if (rd_wait_q) begin
            unique case (rd_funct3_q)
                3'b000:  load_data_o = {{24{byte_sel[7]}},  byte_sel};   // LB
                3'b001:  load_data_o = {{16{half_sel[15]}}, half_sel};   // LH
                3'b010:  load_data_o = dmem_rdata_i;                     // LW
                3'b100:  load_data_o = {24'd0, byte_sel};                // LBU
                3'b101:  load_data_o = {16'd0, half_sel};                // LHU
                default: load_data_o = 32'd0;
            endcase
        end
    end
 
endmodule
