`timescale 1ns / 1ps

module ex_mem_reg(
    
    // Inputs
    // EX/MEM Pipeline Register - Inputs (from EX stage)
    input  logic        clk,
                        rst,
                        
    input  logic        flush,
                        stall,
    
    input  logic        ex_valid,
    input  logic [31:0] ex_instr,
    
    // Data into MEM stage
    input  logic [31:0] ex_alu_out,        // ALU result / load-store address
                        ex_store_data,     // store write data (after forwarding)
                        ex_pc4,            // for JAL/JALR link writeback (optional)
    input  logic [4:0]  ex_rd,
    
    // MEM control
    input  logic        ex_mem_read,
                        ex_mem_write,
    input  logic [2:0]  ex_funct3,     // size/sign for loads; size for stores
    
    // WB control
    input  logic        ex_regwrite,
                        ex_write_data,         // 1- Memory Result, 0 = alu result
    
    // Outputs
    // EX/MEM Pipeline Register - Inputs (from EX stage)
    output  logic        ex_mem_valid,
    output  logic [31:0] ex_mem_instr_o,
    
    // Data into MEM stage
    output  logic [31:0] ex_mem_alu_out,        
                         ex_mem_store_data,     
                         ex_mem_pc4,           
    output  logic [4:0]  ex_mem_rd,
    
    // MEM control
    output  logic        ex_mem_mem_read,
                         ex_mem_mem_write,
    output  logic [2:0]  ex_mem_funct3,     
    
    // WB control
    output  logic       ex_mem_regwrite,
                        ex_mem_write_data          
    
    );
   // NOTE: Only Asser this Stall for EX/MEM reg when downstream backpressure is needed.
   // DO NOT stall EX/MEM for Load-Use Hazards
   
   always_ff @(posedge clk) begin
        if (rst || flush) begin
            // Flush/reset kills side effects (NOP bubble)
            ex_mem_valid          <= 1'b0;
            ex_mem_instr_o        <= 32'h00000013; // NOP
    
            ex_mem_alu_out        <= 32'd0;   
            ex_mem_store_data     <= 32'd0;
            ex_mem_pc4            <= 32'd0;
            ex_mem_rd             <= 5'd0;      
    
            ex_mem_mem_read       <= 1'b0;
            ex_mem_mem_write      <= 1'b0;
            ex_mem_funct3         <= 3'd0;     
    
            ex_mem_regwrite       <= 1'b0;
            ex_mem_write_data     <= 1'b0;     
    
        end
        else if (!stall) begin
            ex_mem_valid          <= ex_valid;
            ex_mem_instr_o        <= ex_instr;
    
            ex_mem_alu_out        <= ex_alu_out;   
            ex_mem_store_data     <= ex_store_data;
            ex_mem_pc4            <= ex_pc4;
            ex_mem_rd             <= ex_rd;      
    
            ex_mem_mem_read       <= ex_mem_read  & ex_valid;
            ex_mem_mem_write      <= ex_mem_write & ex_valid;
            ex_mem_funct3         <= ex_valid ? ex_funct3 : 3'd0;
        
            ex_mem_regwrite       <= ex_regwrite  & ex_valid;
            ex_mem_write_data     <= ex_write_data & ex_valid;    
    
        end
    // else: stall -> hold state (do nothing)
    end
    
endmodule
