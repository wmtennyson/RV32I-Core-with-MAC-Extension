`include "Def.vh"
`timescale 1ns / 1ps

module Control_Unit(
    // Inputs 
    input  logic [6:0] opcode,
    
    // Output Signals
    output logic regwrite,
                 mem_read,
                 mem_write,
                 branch,
                 jump,
                 write_data,
                 wb_pc4_sel,
                 OpA_sel,
                 OpB_sel,
                 lui,
                 is_jalr,
    output logic [2:0] alu_op
    );
    
    always_comb begin
        // Set Default Control Signals
        regwrite =      1'b0; 
        mem_read =      1'b0; 
        mem_write =     1'b0; 
        branch =        1'b0; 
        jump =          1'b0; 
        write_data =    1'b0;
        wb_pc4_sel =    1'b0; 
        OpA_sel =       1'b0; 
        OpB_sel =       1'b0; 
        lui =           1'b0; 
        is_jalr =       1'b0; 
        alu_op =        `NOP;
        
        // Set Control Signals Depending on OPCODE
        unique case (opcode)
        
            // R-type
            7'b0110011: begin 
                regwrite = 1'b1;
                OpA_sel  = 1'b1;        // RS1
                alu_op   = `R_TYPE;
            end
            
            // I-type
            7'b0010011: begin 
                regwrite  = 1'b1;
                OpA_sel   = 1'b1;       // RS1
                OpB_sel   = 1'b1;       //imm
                alu_op    = `I_TYPE;
            end
            
            // Load
            7'b0000011: begin
                regwrite   = 1'b1;
                mem_read   = 1'b1;
                OpA_sel    = 1'b1;       // RS1 base
                OpB_sel    = 1'b1;       // Imm offset
                write_data = 1'b1;       // Mem -> WB
                alu_op     = `LOAD;
            end
            
            // Store
            7'b0100011: begin 
                mem_write = 1'b1;
                OpA_sel   = 1'b1;       // RS1 base
                OpB_sel   = 1'b1;       // Imm offset
                alu_op    = `STORE;
            end
            
            // Branch
            7'b1100011: begin 
                branch   = 1'b1;
                OpA_sel  = 1'b1;       // RS1 for Compare
                alu_op   = `BRANCH;
            end
            
            // JAL and JALR
            7'b1101111, 7'b1100111: begin 
                regwrite  = 1'b1;        
                jump      = 1'b1;
                wb_pc4_sel = 1'b1;
                OpA_sel   = (opcode == 7'b1100111) ? 1 : 0;     // For JALR immediate offset
                is_jalr   = (opcode == 7'b1100111) ? 1 : 0;     // JALR only
                alu_op    = `JUMP;
            end
            
            // LUI and AUIPC
            7'b0110111, 7'b0010111: begin 
                regwrite = 1;
                OpB_sel  = 1;   // imm
                if (opcode == 7'b0010111) begin
                    // AUIPC
                    OpA_sel = 1'b0; // PC
                    lui     = 1'b0;
                end else begin
                    // LUI
                    OpA_sel = 1'b0; 
                    lui     = 1'b1;
                end 
                alu_op    = `U_TYPE;
            end
            
            default: ; // Do nothing; defaults already set
        endcase 
    end
   
endmodule

