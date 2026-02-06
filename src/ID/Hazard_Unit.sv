`timescale 1ns / 1ps
`include "Def.vh"

module Hazard_Unit(
    // Inputs - Signals from ID Stage
    input  logic        ID_regwrite,
                        ID_mem_read,
                        ID_mem_write,
                        ID_branch,
                        ID_jump,
                        ID_write_data,
                        ID_is_jalr,
    input  logic [2:0]  ID_alu_op,
    
    // Inputs - Register Addresses from various stages
    input logic [4:0]   IF_ID_rs1, 
                        IF_ID_rs2, 
                        ID_EX_rd,
                        EX_MEM_rd,
                        
    // Inputs - MemRead signals from interstage registers                    
    input logic         ID_EX_mem_read,
                        EX_MEM_mem_read_i,
                
   // Inputs - Inputs from Branch Unit
   input logic          redirect_taken,
   input logic [31:0]   redirect_target,             
                
    // Outputs - Signals sent to the fetch unit
   output logic         fetch_stall,
                        fetch_flush,
                        ID_EX_flush,
   output logic [31:0]  target,
  
                                 
    //Outputs - Control Signals to Interstage Register
    output logic        ID_EX_regwrite,
                        ID_EX_mem_read_o,
                        ID_EX_mem_write,
                        ID_EX_branch,
                        ID_EX_jump,
                        ID_EX_write_data,
    output logic [2:0]  ID_EX_alu_op

    );
    
    // Variables
    logic load_use_hazard,
          load_branch_hazard;
    
    always_comb begin
    
        // Set Defaults - Set Default Outputs
        fetch_stall = 1'b0;
        fetch_flush = 1'b0;
        target      = redirect_target;
        ID_EX_flush = 1'b0;
    
        // Set Defaults - Push ID stage control signals to ID/EX register
        ID_EX_regwrite   = ID_regwrite;
        ID_EX_mem_read_o = ID_mem_read; 
        ID_EX_mem_write  = ID_mem_write;
        ID_EX_branch     = ID_branch; 
        ID_EX_jump       = ID_jump; 
        ID_EX_write_data = ID_write_data; 
        ID_EX_alu_op     = ID_alu_op;
         
        // Check for Load-use Hazard
        load_use_hazard = ID_EX_mem_read && (ID_EX_rd != 5'd0) && ((ID_EX_rd == IF_ID_rs1) || (ID_EX_rd == IF_ID_rs2)); 
            
        // Check for Load-Branch Hazard 
        load_branch_hazard = (ID_branch || ID_is_jalr) && (ID_EX_mem_read && (ID_EX_rd != 5'd0) && (((ID_EX_rd == IF_ID_rs1) || (ID_EX_rd == IF_ID_rs2))) || (EX_MEM_mem_read_i && (EX_MEM_rd != 5'd0) && ((EX_MEM_rd == IF_ID_rs1) || (EX_MEM_rd == IF_ID_rs2))));

        // Hazard Unit Logic - If either hazard is high, then stall
        if (load_use_hazard || load_branch_hazard) begin
            
            // Send Stall signal back to IF stage
            fetch_stall = 1'b1;
            ID_EX_flush = 1'b1;            
            
            // Overide EX stage signals to NOOP
            ID_EX_regwrite   = 1'b0;
            ID_EX_mem_read_o = 1'b0; 
            ID_EX_mem_write  = 1'b0;
            ID_EX_branch     = 1'b0; 
            ID_EX_jump       = 1'b0; 
            ID_EX_write_data = 1'b0; 
            ID_EX_alu_op     = `NOP;      
             
        end
        // Hazard Unit Logic - If a Branch is taken then flush the pipeline
        else if(redirect_taken) begin
        
            fetch_flush = 1'b1;
        
        end
            
    end
    
endmodule
