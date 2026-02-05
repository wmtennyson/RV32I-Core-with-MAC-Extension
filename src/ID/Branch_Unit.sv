`include "Def.vh"
`timescale 1ns / 1ps

module Branch_Unit(
    // Inputs
    input  logic [31:0] pc,
                        pc4,
                        rs1,
                        rs2,
                        imm,
    input  logic        branch,
                        jump,
                        pcsrc,      // 1 for JALR, 0 for JAL
    input  logic [2:0]  funct3,
    
    // Outputs
    output logic        redirect,
    output logic [31:0] target_pc,
                        link_register
);

    logic result;

    always_comb begin
        // Defaults
        redirect      = 1'b0;
        target_pc     = pc4;
        link_register = pc4;

        // Branch resultition (computed regardless, but not used unless branch=1)
        result = 1'b0;
        unique case (funct3)
            3'b000:  result = (rs1 == rs2);                               // BEQ
            3'b001:  result = (rs1 != rs2);                               // BNE
            3'b100:  result = ($signed(rs1) <  $signed(rs2));             // BLT
            3'b101:  result = ($signed(rs1) >= $signed(rs2));             // BGE
            3'b110:  result = ($unsigned(rs1) <  $unsigned(rs2));         // BLTU
            3'b111:  result = ($unsigned(rs1) >= $unsigned(rs2));         // BGEU
            default: result = 1'b0;
        endcase

        // Jumps override everything
        if (jump) begin
            redirect = 1'b1;
            if (pcsrc)  target_pc = (rs1 + imm) & ~32'd1;               // JALR
            else        target_pc = pc + imm;                           // JAL
        end
        
        // If branch signal and result are both high
        else if (branch && result) begin
            redirect  = 1'b1;
            target_pc = pc + imm;                                       // taken branch
        end
        
        // else
        else begin
            redirect  = 1'b0;
            target_pc = pc4;                                            // fall-through
        end
    end


endmodule

