`timescale 1ns/1ps

module Hazard_Unit (

    // Inputs - Current instruction in IF/ID (Decode stage)
    input  logic        instr_valid_i,
    input  logic [6:0]  opcode_i,
    input  logic [4:0]  rs1_i,
                        rs2_i,

    // Inputs - Instruction currently in EX stage (ID/EX regs)
    input  logic        id_ex_mem_read_i,
    input  logic [4:0]  id_ex_rd_i,

    // Inputs - Instruction currently in MEM stage (EX/MEM regs)
    input  logic        ex_mem_mem_read_i,
    input  logic [4:0]  ex_mem_rd_i,

    // Output -  stall request (freeze PC + IF/ID)
    output logic        stall_o
);

    // Decode which source regs are *actually used* by current opcode
    // (prevents false stalls on I-type where instr[24:20] is imm[4:0], not rs2)
    logic uses_rs1, uses_rs2;

    always_comb begin
        uses_rs1 = 1'b0;
        uses_rs2 = 1'b0;

        if (instr_valid_i) begin
            unique case (opcode_i)
                7'b0110111: begin uses_rs1 = 1'b0; uses_rs2 = 1'b0; end // LUI
                7'b0010111: begin uses_rs1 = 1'b0; uses_rs2 = 1'b0; end // AUIPC
                7'b1101111: begin uses_rs1 = 1'b0; uses_rs2 = 1'b0; end // JAL
                7'b1100111: begin uses_rs1 = 1'b1; uses_rs2 = 1'b0; end // JALR
                7'b1100011: begin uses_rs1 = 1'b1; uses_rs2 = 1'b1; end // BRANCH
                7'b0100011: begin uses_rs1 = 1'b1; uses_rs2 = 1'b1; end // STORE
                7'b0000011: begin uses_rs1 = 1'b1; uses_rs2 = 1'b0; end // LOAD (base in rs1)
                7'b0010011: begin uses_rs1 = 1'b1; uses_rs2 = 1'b0; end // I-type ALU
                7'b0110011: begin uses_rs1 = 1'b1; uses_rs2 = 1'b1; end // R-type ALU
                default:    begin uses_rs1 = 1'b0; uses_rs2 = 1'b0; end
            endcase
        end
    end

    // Hazard detection
    logic hazard_ex_load;   // classic load-use (ID/EX is load)
    logic hazard_mem_load;  // only for branch/jalr needing operand in ID (EX/MEM is load)

    always_comb begin
        hazard_ex_load  = 1'b0;
        hazard_mem_load = 1'b0;

        // Load-Use Hazard -  producer is a load in ID/EX.
        if (instr_valid_i && id_ex_mem_read_i && (id_ex_rd_i != 5'd0)) begin
            if ((uses_rs1 && (id_ex_rd_i == rs1_i)) || (uses_rs2 && (id_ex_rd_i == rs2_i))) begin
                hazard_ex_load = 1'b1;
            end
        end

        // EX/MEM load hazard - only stall when current instruction needs the value in ID
        if (instr_valid_i && ex_mem_mem_read_i && (ex_mem_rd_i != 5'd0)) begin
            if ((uses_rs1 && (ex_mem_rd_i == rs1_i)) || (uses_rs2 && (ex_mem_rd_i == rs2_i))) begin
                hazard_mem_load = 1'b1;
            end
        end
    end

    assign stall_o = hazard_ex_load | hazard_mem_load;

endmodule
