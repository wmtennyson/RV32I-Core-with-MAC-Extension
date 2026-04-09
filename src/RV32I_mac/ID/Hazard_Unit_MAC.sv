`timescale 1ns / 1ps

module Hazard_Unit (
    // Current instruction in ID (Decode stage)
    input  logic        instr_valid_i,
    input  logic [6:0]  opcode_i,
    input  logic [4:0]  rs1_i,
    input  logic [4:0]  rs2_i,

    // Instruction in EX stage (ID/EX register)
    input  logic        id_ex_mem_read_i,
    input  logic        id_ex_regwrite_i,
    input  logic        id_ex_wb_pc4_sel_i,  // JAL/JALR in EX writes PC+4
    input  logic [4:0]  id_ex_rd_i,
    input  logic [2:0]  id_ex_MAC_op_i,

    // Instruction in MEM stage (EX/MEM register)
    input  logic        ex_mem_mem_read_i,
    input  logic [4:0]  ex_mem_rd_i,
    input  logic [2:0]  ex_mem_MAC_op_i,

    output logic        stall_o
);

    logic uses_rs1, uses_rs2;

    always_comb begin
        uses_rs1 = 1'b0;
        uses_rs2 = 1'b0;
        if (instr_valid_i) begin
            unique case (opcode_i)
                7'b0110011: begin uses_rs1 = 1'b1; uses_rs2 = 1'b1; end // R-type
                7'b0010011: begin uses_rs1 = 1'b1;                  end // I-type ALU
                7'b0000011: begin uses_rs1 = 1'b1;                  end // Load
                7'b0100011: begin uses_rs1 = 1'b1; uses_rs2 = 1'b1; end // Store
                7'b1100011: begin uses_rs1 = 1'b1; uses_rs2 = 1'b1; end // Branch
                7'b1100111: begin uses_rs1 = 1'b1;                  end // JALR
               `MAC_OPCODE: begin uses_rs1 = 1'b1; uses_rs2 = 1'b1; end // MAC Opcode
                default:    ;  // LUI, AUIPC, JAL use no source regs
            endcase
        end
    end

    // Does the ID instruction need operands for branch/jump compare in ID?
    logic needs_id_operands;
    assign needs_id_operands = instr_valid_i &&
                               ((opcode_i == 7'b1100011) ||   // Branch
                                (opcode_i == 7'b1100111));     // JALR
                                
    // Producer-is-MAC-read flags
    logic id_ex_is_macrd, ex_mem_is_macrd;
    assign id_ex_is_macrd  = (id_ex_MAC_op_i  == `MAC_OP_RDLO) ||
                             (id_ex_MAC_op_i  == `MAC_OP_RDHI);
    assign ex_mem_is_macrd = (ex_mem_MAC_op_i == `MAC_OP_RDLO) ||
                             (ex_mem_MAC_op_i == `MAC_OP_RDHI);

    // Hazard 1: Classic load-use
    logic hz_load_use;
    assign hz_load_use = instr_valid_i
                      && id_ex_mem_read_i
                      && (id_ex_rd_i != 5'd0)
                      && ((uses_rs1 && (id_ex_rd_i == rs1_i)) ||
                          (uses_rs2 && (id_ex_rd_i == rs2_i)));

    // Hazard 2: MEM-stage load - branch/JALR in ID
    logic hz_mem_load_branch;
    assign hz_mem_load_branch = needs_id_operands
                             && ex_mem_mem_read_i
                             && (ex_mem_rd_i != 5'd0)
                             && ((uses_rs1 && (ex_mem_rd_i == rs1_i)) ||
                                 (uses_rs2 && (ex_mem_rd_i == rs2_i)));

    // Hazard 3: EX-stage JAL/JALR - branch/JALR in ID
    logic hz_pc4_link;
    assign hz_pc4_link = needs_id_operands
                      && id_ex_regwrite_i
                      && id_ex_wb_pc4_sel_i
                      && (id_ex_rd_i != 5'd0)
                      && ((uses_rs1 && (id_ex_rd_i == rs1_i)) ||
                          (uses_rs2 && (id_ex_rd_i == rs2_i)));

    // Hazard 4: MAC-read-use, EX-stage producer
    logic hz_macrd_use_ex;
    assign hz_macrd_use_ex = instr_valid_i
                          && id_ex_is_macrd
                          && (id_ex_rd_i != 5'd0)
                          && ((uses_rs1 && (id_ex_rd_i == rs1_i)) ||
                              (uses_rs2 && (id_ex_rd_i == rs2_i)));

    // Hazard 5: MAC-read-use, MEM-stage producer
    logic hz_macrd_use_mem;
    assign hz_macrd_use_mem = instr_valid_i
                           && ex_mem_is_macrd
                           && (ex_mem_rd_i != 5'd0)
                           && ((uses_rs1 && (ex_mem_rd_i == rs1_i)) ||
                               (uses_rs2 && (ex_mem_rd_i == rs2_i)));

    assign stall_o = hz_load_use
                   | hz_mem_load_branch
                   | hz_pc4_link
                   | hz_macrd_use_ex
                   | hz_macrd_use_mem;

endmodule


