`timescale 1ns / 1ps

module Execute_Unit (
    // From ID/EX register
    input  logic [31:0] pc_i,
    input  logic [31:0] rs1_val_i,
    input  logic [31:0] rs2_val_i,
    input  logic [31:0] imm_i,
    input  logic [2:0]  funct3_i,
    input  logic [6:0]  funct7_i,
    input  logic [2:0]  alu_op_i,

    // Operand select controls (from ID/EX register)
    input  logic        opA_sel_i,   // 0=PC, 1=RS1
    input  logic        opB_sel_i,   // 0=RS2, 1=IMM
    input  logic        lui_i,

    // Forwarding selects (from Forwarding_Unit, combinational)
    //   00=ID/EX value, 01=MEM forward, 10=WB forward
    input  logic [1:0]  fwd_a_i,
    input  logic [1:0]  fwd_b_i,

    // Forwarded values
    input  logic [31:0] mem_fwd_i,   // from EX/MEM (ALU result or PC+4)
    input  logic [31:0] wb_fwd_i,    // from MEM/WB (writeback value)

    // Outputs
    output logic [31:0] alu_out_o,
    output logic [31:0] store_data_o,   // forwarded RS2 for stores
    output logic [31:0] rs1_fwd_o,
    output logic [31:0] rs2_fwd_o
);

    // Layer 1: Forwarding muxes
    logic [31:0] rs1_fwd, rs2_fwd;

    always_comb begin
        unique case (fwd_a_i)
            2'b01:   rs1_fwd = mem_fwd_i;
            2'b10:   rs1_fwd = wb_fwd_i;
            default: rs1_fwd = rs1_val_i;
        endcase

        unique case (fwd_b_i)
            2'b01:   rs2_fwd = mem_fwd_i;
            2'b10:   rs2_fwd = wb_fwd_i;
            default: rs2_fwd = rs2_val_i;
        endcase
    end

    assign store_data_o = rs2_fwd;
    
    // Expose Fowarded Operands to MAC Unit
    assign rs1_fwd_o = rs1_fwd;
    assign rs2_fwd_o = rs2_fwd;

    // Layer 2: Operand selection for ALU
    logic [31:0] OpA, OpB;

    always_comb begin
        OpA = opA_sel_i ? rs1_fwd : pc_i;
        if (lui_i) OpA = 32'd0;              // LUI: 0 + imm
        OpB = opB_sel_i ? imm_i   : rs2_fwd;
    end

    // ALU control decoder
    logic [3:0] alu_ctrl;

    EXE_Control CTRL (
        .alu_op     (alu_op_i), 
        .func7      (funct7_i), 
        .func3      (funct3_i),
        .alu_ctrl   (alu_ctrl)
    );

    // ALU
    EXE_ALU ALU (
        .OpA        (OpA), 
        .OpB        (OpB), 
        .alu_ctrl   (alu_ctrl),
        .alu_out    (alu_out_o)
        
    );

endmodule
