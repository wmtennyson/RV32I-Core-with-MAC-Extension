`timescale 1ns / 1ps

module mem_unit (
    input  logic        clk,
    input  logic        rst,

    // From EX/MEM pipeline regs
    input  logic        ex_mem_valid_i,
    input  logic [31:0] ex_mem_addr_i,     
    input  logic [31:0] ex_mem_store_data_i,
    input  logic [2:0]  ex_mem_funct3_i,
    input  logic        ex_mem_mem_read_i,
    input  logic        ex_mem_mem_write_i,

    // Data memory BRAM interface (sync read, byte-write enables)
    output logic [31:0] dmem_addr_o,
    output logic        dmem_en_o,
    output logic [3:0]  dmem_we_o,      
    output logic [31:0] dmem_wdata_o,
    input  logic [31:0] dmem_rdata_i,

    // To MEM/WB stage
    output logic        load_valid_o,    
    output logic [31:0] load_data_o
);

    assign dmem_addr_o = ex_mem_addr_i;

    // Always enable memory when valid instruction in MEM stage
    assign dmem_en_o = ex_mem_valid_i && (ex_mem_mem_read_i || ex_mem_mem_write_i);

    logic [1:0] addr_lsb;
    assign addr_lsb = ex_mem_addr_i[1:0];

    always_comb begin
        dmem_we_o    = 4'b0000;
        dmem_wdata_o = 32'd0;

        if (ex_mem_valid_i && ex_mem_mem_write_i) begin
            unique case (ex_mem_funct3_i)
                3'b000: begin // SB
                    dmem_we_o    = (4'b0001 << addr_lsb);
                    dmem_wdata_o = ex_mem_store_data_i << (8 * addr_lsb);
                end

                3'b001: begin // SH
                    // halfword aligned by addr[0]==0
                    if (addr_lsb[0] == 1'b0) begin
                        dmem_we_o    = (addr_lsb[1] == 1'b0) ? 4'b0011 : 4'b1100;
                        dmem_wdata_o = ex_mem_store_data_i << (16 * addr_lsb[1]);
                    end else begin
                        dmem_we_o    = 4'b0000; 
                        dmem_wdata_o = 32'd0;
                    end
                end

                3'b010: begin // SW
                    // word aligned by addr[1:0]==00
                    if (addr_lsb == 2'b00) begin
                        dmem_we_o    = 4'b1111;
                        dmem_wdata_o = ex_mem_store_data_i;
                    end else begin
                        dmem_we_o    = 4'b0000; 
                        dmem_wdata_o = 32'd0;
                    end
                end

                default: begin
                    dmem_we_o    = 4'b0000;
                    dmem_wdata_o = 32'd0;
                end
            endcase
        end
    end

    logic        rd_req_q;
    logic [1:0]  rd_addr_lsb_q;
    logic [2:0]  rd_funct3_q;

    // Request Tracking
    always_ff @(posedge clk) begin
        if (rst) begin
            rd_req_q       <= 1'b0;
            rd_addr_lsb_q  <= 2'b00;
            rd_funct3_q    <= 3'b000;
        end else begin
            rd_req_q       <= ex_mem_valid_i && ex_mem_mem_read_i;
            rd_addr_lsb_q  <= ex_mem_addr_i[1:0];
            rd_funct3_q    <= ex_mem_funct3_i;
        end
    end

    assign load_valid_o = rd_req_q;

    always_comb begin
        // default
        load_data_o = 32'd0;

        if(rd_req_q) begin
            logic [7:0]  byte_sel;
            logic [15:0] half_sel;
    
            // Select byte/half from the returned word based on saved addr bits
            byte_sel = (dmem_rdata_i >> (8  * rd_addr_lsb_q)) & 8'hFF;
            half_sel = (dmem_rdata_i >> (16 * rd_addr_lsb_q[1])) & 16'hFFFF;
    
            unique case (rd_funct3_q)
                3'b000: load_data_o = {{24{byte_sel[7]}}, byte_sel};    // LB
                3'b001: load_data_o = {{16{half_sel[15]}}, half_sel};   // LH
                3'b010: load_data_o = dmem_rdata_i;                     // LW
                3'b100: load_data_o = {24'd0, byte_sel};                // LBU
                3'b101: load_data_o = {16'd0, half_sel};                // LHU
                default: load_data_o = 32'd0;
            endcase
        end
    end

endmodule
