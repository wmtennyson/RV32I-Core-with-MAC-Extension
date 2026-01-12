`timescale 1ns / 1ps

module fetch_unit#(
    parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
    )(
    input logic     clk,
    input logic     rst, //active high reset
    
    //hazard and pipeline ctrl
    input logic     stall_i, //freeze pc and hold output
    input logic     flush_i, //branch taken, need to flush
    //32 bit address
    input logic [31:0] branch_target_i, //branch address
    
    //memory interface (BRAM, synchronus)
    output logic [31:0] bram_addr_o, //addr to mem
    output logic    bram_en_o, //enable for read
    input logic [31:0] bram_rdata_i, //data back from mem
    
    //output to decode (ALEX)
    output logic    instr_valid_o, //is instruction on bus to decode valid?
    output logic [31:0] instr_o, //instruction data
    output logic [31:0] pc_o, //program counter associated with instr_o
    output logic [31:0] pc_plus4_o
    );
    
    //risc-v noop
    //addi x0, x0, 0
    localparam logic [31:0] NOP_INSTR = 32'h0000_0013;
    
    //pc registers
    logic [31:0] pc_next;
    logic [31:0] pc_f; //fetch stage pc
    logic [31:0] pc_d; //decode stage pc
    
    //skid buffer for 2 cycle mem reads (synchronus bram)
    //for if instructions are lost during stalls
    logic   skid_valid; //is stuff in skid
    logic [31:0] skid_instr; //instr in skid
    logic [31:0] skid_pc; //pc of instr in skid
    logic [31:0] skid_pc_plus4; 
    
    logic valid_d_q; //valid bit for decode stage
    logic skid_valid_data; //does skid contain valid instr
    
    //next pc logic
    
    always_comb begin //no sequential, or no memory
        if(flush_i) begin //if flush needed (branch taken)
            pc_next = branch_target_i;    //jump to branch target
        end else begin
            pc_next = pc_f + 32'd4; //normal step
        end
     end


    //register/flipflop to hold pc update
    always_ff @(posedge clk) begin 
        if(rst) begin
            pc_f <= RESET_VECTOR;
        end else if(!stall_i) begin
            pc_f <= pc_next; 
        end //only update if not stalled
    end
    
    
    //outputs to memory
    assign bram_addr_o = pc_f;
    assign bram_en_o = 1'b1; //will always have read enabled
    
    //data alignment
    /*since bram has 1 cycle latency, we gotta delay the pc
    */
    //keep a buffer flip flop to hold instr in case of stalls
    always_ff @(posedge clk) begin
        if(rst) begin
            pc_d <= RESET_VECTOR;
            valid_d_q <= 1'b0;
        end else if(flush_i) begin
            pc_d <= branch_target_i;
            valid_d_q <= 1'b0;    
        end else if (!stall_i) begin
            pc_d <= pc_f; //pc continues down pipelines
            valid_d_q <= 1'b1;
        end
        //if stalled do nothing, hold value of pc
    end
    
    //logic for skid buffer
    //will capture the instruction from memory when a stall occurs
    always_ff @(posedge clk) begin
        if(rst || flush_i) begin
            skid_valid <= 1'b0;
            skid_valid_data <= 1'b0;
            skid_instr <= NOP_INSTR;
            skid_pc <= 32'd0;
            skid_pc_plus4 <= 32'd0;
        end else begin
            if(stall_i && !skid_valid) begin
                //stall detected
                skid_valid <= 1'b1;
                skid_instr <= bram_rdata_i;
                skid_pc <= pc_d;
                skid_pc_plus4 <= pc_d + 32'd4;
                skid_valid_data <= valid_d_q;
            end else begin
                if (!stall_i) begin
                // stall
                skid_valid <= 1'b0;
                end
            end
        end
    end    
    //output logic
    always_comb begin
    //check flush first
        if(flush_i) begin
            instr_valid_o = 1'b0;
            instr_o = NOP_INSTR;
            pc_o = 32'd0;
            pc_plus4_o = 32'd0;
        end
        //check skid second
        else if(skid_valid) begin
            instr_valid_o = skid_valid_data;
            instr_o = skid_instr;
            pc_o = skid_pc;
            pc_plus4_o = skid_pc_plus4;
        end
        //last is normal run
        else begin
            instr_valid_o = valid_d_q;
            instr_o = bram_rdata_i; 
            pc_o = pc_d;
            pc_plus4_o = pc_d + 32'd4;
        end
    end
endmodule
