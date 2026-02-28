`timescale 1ns / 1ps

module Execute_Unit(
    // Inputs for Operand A
    input logic [31:0] PC,
                       RS1_IDEXE,
                       RS1_EXEMEM,
                       RS1_MEMWB,
    
    // Inputs for Operand B
    input  logic [31:0] RS2_IDEXE,
                        RS2_EXEMEM,
                        RS2_MEMWB,
                        imm,
    
    // Inputs for ALU Control Unit
    input logic [2:0]   func3,
    input logic [6:0]   func7,
    input logic [2:0]   alu_op,
    
    // Control Signals for Muxltiplexers
    input logic [1:0] RS1_sel,
                      RS2_sel,
    input logic       OpA_sel,
                      OpB_sel,
    
    // Execute Unit Output
    output logic [31:0] alu_out,        // ALU result
                        store_data      // Forwarded rs2 for lw/sw ops
   
    );
    
    // Variables
    logic [31:0] RS1,
                 RS2,
                 OpA,
                 OpB;
    logic [3:0]  alu_ctrl;
    
    // Operand Selection Logic
    always_comb begin
    
        // Safe defaults (no forwarding, normal operand usage)
        RS1        = RS1_IDEXE;
        RS2        = RS2_IDEXE;
        OpA        = RS1_IDEXE;
        OpB        = RS2_IDEXE;
        store_data = RS2_IDEXE;
            
        // First-Layer Forwarding Multiplexers - Inputs from Multiplexer for RS1 and RS2
        // Select the Input for RS1_Sel Mux
        unique case(RS1_sel)
            2'b00 : RS1 = RS1_IDEXE;
            2'b01 : RS1 = RS1_EXEMEM;
            2'b10 : RS1 = RS1_MEMWB;
            default : RS1 = RS1_IDEXE;
        endcase
        
        // Select the Input for RS2_Sel Mux
        unique case(RS2_sel)
            2'b00 : RS2 = RS2_IDEXE;
            2'b01 : RS2 = RS2_EXEMEM;
            2'b10 : RS2 = RS2_MEMWB;
            default : RS2 = RS2_IDEXE;
        endcase
        
        store_data = RS2;
        
        // Second-Layer Operand Multiplexers - Input from Multiplexer for OpA and OpB
        // Select the Input for OpA_Sel Mux
        unique case(OpA_sel)
            1'b0 : OpA = PC;
            1'b1 : OpA = RS1;
            default : OpA = RS1;
        endcase
        
        // Select the Input for OpB_Sel Mux
        unique case(OpB_sel)
            1'b0 : OpB = RS2;
            1'b1 : OpB = imm;
            default : OpB = RS2;
        endcase
    end 
      
    // Instantiate ALU Control to Send to ALU
    EXE_Control ALU_ctrl(
        .func3      (func3),
        .func7      (func7),
        .alu_op     (alu_op),
        .alu_ctrl   (alu_ctrl)
    );
      
    // Instantiate the ALU for final ALU_Out      
    EXE_ALU ALU(
        .OpA        (OpA),
        .OpB        (OpB),
        .alu_ctrl   (alu_ctrl),
        .alu_out    (alu_out)
    );
  
endmodule
