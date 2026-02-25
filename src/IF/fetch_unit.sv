`timescale 1ns / 1ps

module fetch_unit#(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
)(
    input  logic        clk,
    input  logic        rst, // active high reset
    
    // Hazard and pipeline ctrl
    input  logic        stall_i, // freeze pc
    input  logic        flush_i, // branch taken, update pc to target
    input  logic [31:0] branch_target_i, // branch address
    
    // Memory interface (BRAM, synchronous)
    output logic [31:0] bram_addr_o, 
    output logic        bram_en_o,   
    // (bram_rdata_i now goes straight to if_id_reg.sv)
    
    // Outputs to IF/ID Pipeline Register
    output logic [31:0] if_pc_o,
    output logic [31:0] if_pc_plus4_o
);
    
    // Fetch PC Register
    logic [31:0] pc_next;
    logic [31:0] pc_f;
    
    // Next PC logic (Combinational)
    always_comb begin
        if(flush_i) begin 
            pc_next = branch_target_i;    // jump to branch target
        end else begin
            pc_next = pc_f + 32'd4;       // normal step
        end
    end

    // PC Register Update
    always_ff @(posedge clk) begin 
        if(rst) begin
            pc_f <= RESET_VECTOR;
        end else if(!stall_i) begin
            pc_f <= pc_next; 
        end 
        // If stalled, pc_f freezes 
    end
    
    // Continuous outputs
    assign bram_addr_o   = pc_f;
    assign bram_en_o     = 1'b1; // Always enable read for instruction memory
    
    assign if_pc_o       = pc_f;
    assign if_pc_plus4_o = pc_f + 32'd4;
    
endmodule
