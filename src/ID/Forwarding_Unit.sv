`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: William Tennyson
// 
// Create Date: 01/26/2026 11:58:54 AM
// Design Name: 
// Module Name: Forwarding_Unit
// Project Name: 32 Bit CPU 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module Forwarding_Unit(
    // Inputs
    // Register Addresses From Different Stages
    input logic [4:0] IF_ID_rs1,            // IF/ID Registers
                      IF_ID_rs2,            
                      ID_EX_rd,             // ID/EX Registers
                      ID_EX_rs1,
                      ID_EX_rs2,
                      EX_MEM_rd,            // EX/MEM Registers
                      MEM_WB_rd,            // MEM/WB Registers
    
    // Control Signals from Different Stages
    input logic EX_MEM_RegWrite,            // Regwrite Signals
                MEM_WB_RegWrite,
                ID_EX_RegWrite,
                ID_EX_mem_read,             // MemRead Signals
                EX_MEM_mem_read,         
   
    // Outputs
    output logic [1:0] BrFwd_A,
                       BrFwd_B,
                       RS1_Sel,
                       RS2_Sel
    );
    
    // Variables - EX Forwarding Logic
    logic ex_match_rs1, 
          ex_match_rs2,
          mem_match_rs1, 
          mem_match_rs2;
          
    // Variables - ID Forwarding Logic
    logic ex_alu_valid,       // EX result exists now (exclude loads)
          exmem_alu_valid;    // EX/MEM has a usable value (exclude loads)

    logic id_ex_match_br_rs1,       // ID/EX Branch Matches 
          id_ex_match_br_rs2,
          exmem_match_br_rs1,       // EX/MEM Branch Matches
          exmem_match_br_rs2,
          memwb_match_br_rs1,       // MEM/WB Branch Matches
          memwb_match_br_rs2;

    
    // Begin Logic for the Forwarding Unit
    always_comb begin
        
        // Assign  a default 00 priority
        BrFwd_A = 2'b00;  // 00=regfile, 01=from MEM/WB, 10=from EX/MEM, 11=from EX(alu_out)
        BrFwd_B = 2'b00;
        RS1_Sel = 2'b00;
        RS2_Sel = 2'b00;
        
        // EX forwarding logic - Compute Conditions
        //-------------------------------------------
        ex_match_rs1  = EX_MEM_RegWrite && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == ID_EX_rs1);
        ex_match_rs2  = EX_MEM_RegWrite && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == ID_EX_rs2);
         
        mem_match_rs1 = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == ID_EX_rs1);
        mem_match_rs2 = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == ID_EX_rs2);
        
        // RS1 forwarding priority: EX/MEM > MEM/WB
        if (ex_match_rs1)       RS1_Sel = 2'b10;
        else if (mem_match_rs1) RS1_Sel = 2'b01;
        
        // RS2 forwarding priority: EX/MEM > MEM/WB
        if (ex_match_rs2)       RS2_Sel = 2'b10;
        else if (mem_match_rs2) RS2_Sel = 2'b01;
        
        // ID (Branch) Forwarding Logic - Compute Conditions
        //--------------------------------------------
        // Valid when ALU computes a value and writes to Register (Load Automatically Invalid)
        ex_alu_valid    = ID_EX_RegWrite && !ID_EX_mem_read;

        // Only claim EX/MEM has a usable value for branch compare if it's NOT a load.
        exmem_alu_valid = EX_MEM_RegWrite && !EX_MEM_mem_read;

        // Match checks for IF/ID.rs1
        id_ex_match_br_rs1  = ex_alu_valid    && (ID_EX_rd  != 5'd0) && (ID_EX_rd  == IF_ID_rs1);
        exmem_match_br_rs1  = exmem_alu_valid && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == IF_ID_rs1);
        memwb_match_br_rs1  = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == IF_ID_rs1);

        // Match checks for IF/ID.rs2
        id_ex_match_br_rs2  = ex_alu_valid    && (ID_EX_rd  != 5'd0) && (ID_EX_rd  == IF_ID_rs2);
        exmem_match_br_rs2  = exmem_alu_valid && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == IF_ID_rs2);
        memwb_match_br_rs2  = MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == IF_ID_rs2);

        // Priority: EX (11) > EX/MEM (10) > MEM/WB (01) > Regfile (00)
        if (id_ex_match_br_rs1)        BrFwd_A = 2'b11;
        else if (exmem_match_br_rs1)   BrFwd_A = 2'b10;
        else if (memwb_match_br_rs1)   BrFwd_A = 2'b01;

        if (id_ex_match_br_rs2)        BrFwd_B = 2'b11;
        else if (exmem_match_br_rs2)   BrFwd_B = 2'b10;
        else if (memwb_match_br_rs2)   BrFwd_B = 2'b01;
    end
    
endmodule 
