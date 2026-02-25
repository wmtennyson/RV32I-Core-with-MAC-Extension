`timescale 1ns / 1ps

module if_id_reg #(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
)(
    input  logic        clk,
    input  logic        rst,
    
    // Hazard and pipeline control
    input  logic        stall,   // from Decode (Hazard Unit)
    input  logic        flush,   // from Decode (Branch taken)
    
    // Data coming from Fetch Stage
    input  logic [31:0] if_pc,
    input  logic [31:0] if_pc4,
    
    // Data coming from Instruction Memory (BRAM 1-cycle latency output)
    input  logic [31:0] bram_rdata_i,
    
    // Data going to Decode Stage
    output logic        id_instr_valid,
    output logic [31:0] id_instr,
    output logic [31:0] id_pc,
    output logic [31:0] id_pc4
);

    localparam logic [31:0] NOP_INSTR = 32'h0000_0013;

    // Parallel IF/ID Registers
    logic [31:0] pc_d;
    logic [31:0] pc4_d;
    logic        valid_d;

    // Skid Buffer (moved from fetch unit)
    logic        skid_valid;
    logic [31:0] skid_instr;

    /* Main 'register' for:
    pc/+4 
    instruction validity bit
    skid buffer for BRAM delay
    */
    always_ff @(posedge clk) begin
        if (rst || flush) begin
            pc_d       <= RESET_VECTOR;
            pc4_d      <= RESET_VECTOR + 32'd4;
            valid_d    <= 1'b0; 
            
            skid_valid <= 1'b0;
            skid_instr <= NOP_INSTR;
        end 
        else if (stall) begin
            //In a stall we need to save the instr coming from mem
            //Might add cycle delay?
            if (!skid_valid && valid_d) begin
                skid_valid <= 1'b1;
                skid_instr <= bram_rdata_i;
            end
        end 
        else begin
            // Normal 
            pc_d       <= if_pc;
            pc4_d      <= if_pc4;
            valid_d    <= 1'b1;
            skid_valid <= 1'b0; // clear skid buffer once stall drops
        end
    end

    // Direct assignments for Decode Stage PC tracking
    assign id_pc  = pc_d;
    assign id_pc4 = pc4_d;

    // Instruction Muxing (Bubble, Skid Buffer, or BRAM pass-through)
    always_comb begin
        if (!valid_d) begin
            id_instr       = NOP_INSTR;
            id_instr_valid = 1'b0;
        end else if (skid_valid) begin
            id_instr       = skid_instr;
            id_instr_valid = 1'b1;
        end else begin
            id_instr       = bram_rdata_i;
            id_instr_valid = 1'b1;
        end
    end

endmodule
