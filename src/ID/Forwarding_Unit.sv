`timescale 1ns / 1ps

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
    input logic     EX_MEM_RegWrite,            // Regwrite Signals
                    MEM_WB_RegWrite,
                    ID_EX_RegWrite,
                    ID_EX_mem_read,             // MemRead Signals
                    EX_MEM_mem_read,         
   
    // PC4 Selects for resolving JAL/JALR
    input  logic     ID_EX_wb_pc4_sel,    
    input  logic     EX_MEM_wb_pc4_sel,   
   
    // Outputs
    output logic       BrFwd_A_use_pc4,     
                       BrFwd_B_use_pc4,     
    output logic [1:0] BrFwd_A,
                       BrFwd_B,
                       RS1_Sel,
                       RS2_Sel
    );
    
    always_comb begin
        // Defaults: no forwarding
        BrFwd_A = 2'b00;
        BrFwd_B = 2'b00;
        RS1_Sel = 2'b00;
        RS2_Sel = 2'b00;
        BrFwd_A_use_pc4 = 1'b0;
        BrFwd_B_use_pc4 = 1'b0;

        // EX-stage forwarding selects (for Execute_Unit)
        // Encoding expected by Execute_Unit:
        // 00 = ID/EX
        // 01 = EX/MEM
        // 10 = MEM/WB

        // RS1 forward
        if (EX_MEM_RegWrite && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == ID_EX_rs1) && !EX_MEM_mem_read) begin
            RS1_Sel = 2'b01; // from EX/MEM (ALU result)
        end else if (MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == ID_EX_rs1)) begin
            RS1_Sel = 2'b10; // from MEM/WB (WB value)
        end

        // RS2 forward  ***CRITICAL FOR STORES***
        // stores still use RS2 as store_data.
        if (EX_MEM_RegWrite && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == ID_EX_rs2) && !EX_MEM_mem_read) begin
            RS2_Sel = 2'b01; // from EX/MEM (ALU result)
        end else if (MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == ID_EX_rs2)) begin
            RS2_Sel = 2'b10; // from MEM/WB (WB value)
        end

        // ID-stage branch compare forwarding (for Branch_Unit operands)
        // Decode_Unit expects:
        // 00 = regfile
        // 01 = MEM/WB value
        // 10 = EX/MEM alu_out
        // 11 = EX alu_out
        
        // rs1 for branch
        if (ID_EX_RegWrite && (ID_EX_rd != 5'd0) && (ID_EX_rd == IF_ID_rs1) && !ID_EX_mem_read && !ID_EX_wb_pc4_sel) begin   
            BrFwd_A = 2'b11;    // from EX stage ALU out
        end else if (EX_MEM_RegWrite && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == IF_ID_rs1) && !EX_MEM_mem_read) begin
            BrFwd_A = 2'b10;    // from MEM stage ALU out
            BrFwd_A_use_pc4  = EX_MEM_wb_pc4_sel; 
        end else if (MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == IF_ID_rs1)) begin
            BrFwd_A = 2'b01;    // from WB value
        end 

        // rs2 for branch
        if (ID_EX_RegWrite && (ID_EX_rd != 5'd0) && (ID_EX_rd == IF_ID_rs2) && !ID_EX_mem_read && !ID_EX_wb_pc4_sel) begin   
            BrFwd_B = 2'b11;
        end else if (EX_MEM_RegWrite && (EX_MEM_rd != 5'd0) && (EX_MEM_rd == IF_ID_rs2) && !EX_MEM_mem_read) begin
            BrFwd_B = 2'b10;
            BrFwd_B_use_pc4  = EX_MEM_wb_pc4_sel;
        end else if (MEM_WB_RegWrite && (MEM_WB_rd != 5'd0) && (MEM_WB_rd == IF_ID_rs2)) begin
            BrFwd_B = 2'b01;
        end
    end

endmodule
