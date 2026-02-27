`timescale 1ns / 1ps

// UNFINISHED
module RV32I_Core(
  input  logic        clk,
  input  logic        rst,

  // instruction memory (read-only)
  output logic [31:0] imem_addr,
  output logic        imem_en,
  input  logic [31:0] imem_rdata,

  // data memory / MMIO
  output logic [31:0] dmem_addr,
  output logic [31:0] dmem_wdata,
  output logic [3:0]  dmem_wstrb,   // byte enables
  output logic        dmem_we,
  output logic        dmem_re,
  input  logic [31:0] dmem_rdata,

  // demo/debug
  output logic        done_o,
  output logic        trap_o
);
    
    // ---------------------- Instruction Fetch Stage ----------------------
    // ID <- IF Stage (Control)
    logic            if_stall,
                     if_flush;
    logic [31:0]     if_branch_target;

    // IF -> ID Stage
    logic            if_instr_valid;
    logic [31:0]     if_instr,
                     if_pc,
                     if_pc4;
                    
    fetch_unit FeU (
        // Top Level Input
        .clk             (clk),
        .rst             (rst),
        
        // Control (from hazard/branch logic later)
        .stall_i         (if_stall),
        .flush_i         (if_flush),
        .branch_target_i (if_branch_target),
        
        // BRAM / Instruction memory interface
        .bram_addr_o     (imem_addr),
        .bram_en_o       (imem_en),
        
        
        // Fetch outputs (to IF/ID next)
        .instr_valid_o   (if_instr_valid),
        .instr_o         (if_instr),
        .pc_o            (if_pc),
        .pc_plus4_o      (if_pc4)
    );
    
    // ---------------------- IF/ID Interstage Register ----------------------
    // IF -> ID
    logic           id_instr_valid;
    logic [31:0]    id_instr,
                    id_pc,
                    id_pc4;
                    
    // ID -> IF 
    logic           id_stall,
                    id_flush;
    
    if_id_reg IF_ID_REG (
        .clk            (clk),
        .rst            (rst),
    
        // Inputs - Hazard and pipeline control
        .stall          (id_stall),   // from Decode (Hazard Unit)
        .flush          (id_flush),   // from Decode (Branch taken)
    
        // Inputs - Data coming from Fetch Stage
        .if_pc          (if_pc),
        .if_pc4         (if_pc4),
    
        // Inputs - Data coming from Instruction Memory (BRAM 1-cycle latency output)
        .bram_rdata_i   (imem_rdata),
    
        // Outputs - Data going to Decode Stage
        .id_instr_valid (id_instr_valid),
        .id_instr       (id_instr),
        .id_pc          (id_pc),
        .id_pc4         (id_pc4)
    
    );
         
    // ---------------------- Instruction Decode Stage ----------------------
    // ID -> IF Stage
    logic [31:0]    id_branch_target;

    // EX -> ID Stage 
    logic           id_instr_valid;
    logic [31:0]    id_instr,
                    id_pc,
                    id_pc4;
                     
    // WB -> ID Stage
    logic           id_we;
    logic [4:0]     id_rd;
    logic [31:0]    id_wdata;
    
    // ID/EX -> ID
    logic [4:0]     id_ex_rd_i,
                    id_ex_rs1_i,
                    id_ex_rs2_i;
    logic           id_ex_regwrite_i,
                    id_ex_mem_read_i;
    logic [31:0]    ex_alu_out_i;   
    
    // EX/MEM -> ID Stage
    logic [4:0]     ex_mem_rd_i;
    logic           ex_mem_regwrite_i,
                    ex_mem_mem_read_i;
    logic [31:0]    ex_mem_alu_out_i;   
    
    // MEM/WB -> ID Stage
    logic [4:0]     mem_wb_rd_i;
    logic           mem_wb_regwrite_i;
    logic [31:0]    mem_wb_value_i;  
    
    // ID -> ID/EX Stage
    logic           id_ex_valid_o;

    logic [31:0]    id_ex_pc_o,
                    id_ex_pc4_o,
                    id_ex_rs1_val_o,
                    id_ex_rs2_val_o,
                    id_ex_imm_o;

    logic [4:0]     id_ex_rs1_o,
                    id_ex_rs2_o,
                    id_ex_rd_o;
    logic [2:0]     id_ex_funct3_o;
    logic [6:0]     id_ex_funct7_o;

    // ID -> EX, MEM, WB Stages (Control)
    logic           id_ex_regwrite_o,
                    id_ex_mem_read_o,
                    id_ex_mem_write_o,
                    id_ex_branch_o,
                    id_ex_jump_o,
                    id_ex_write_data_o,  
                    id_ex_lui_o,
                    id_ex_is_jalr_o;
    logic [2:0]     id_ex_alu_op_o;

    // Mux Selects
    logic [1:0]     id_ex_opA_sel_o;    
    logic           id_ex_opB_sel_o;     
    logic [1:0]     id_ex_rs1_sel_o,   
                    id_ex_rs2_sel_o; 
    
    Decode_Unit DeU (
        .clk                (clk),
        .rst                (rst),
        
        //Inputs 
        // From Fetch (IF/ID)
        .instr_valid_i      (id_instr_valid),
        .instr_i            (id_instr),
        .pc_i               (id_pc),
        .pc4_i              (id_pc4),
        
        // From Writeback (WB -> Regfile)
        .wb_we_i            (id_we),
        .wb_rd_i            (id_rd),
        .wb_wdata_i         (id_wdata),
        
        // From pipeline (for forwarding/hazard)
        // Instruction currently in EX stage (ID/EX regs)
        .id_ex_rd_i         (id_ex_rd_i),
        .id_ex_rs1_i        (id_ex_rs1_i),
        .id_ex_rs2_i        (id_ex_rs2_i),
        .id_ex_regwrite_i   (id_ex_regwrite_i),
        .id_ex_mem_read_i   (id_ex_mem_read_i),
        .ex_alu_out_i       (ex_alu_out_i),
        
        // Instruction currently in MEM stage (EX/MEM regs)
        .ex_mem_rd_i        (ex_mem_rd_i),
        .ex_mem_regwrite_i  (ex_mem_regwrite_i),
        .ex_mem_mem_read_i  (ex_mem_mem_read_i),
        .ex_mem_alu_out_i   (ex_mem_alu_out_i),
        
        // WB stage (MEM/WB regs)
        .mem_wb_rd_i        (mem_wb_rd_i),
        .mem_wb_regwrite_i  (mem_wb_regwrite_i),
        .mem_wb_value_i     (mem_wb_value_i),
        
        // To Fetch (hazard / redirect)
        .stall_o            (id_stall),            
        .flush_o            (id_flush),             
        .branch_target_o    (id_branch_target),  
        
        // Outputs
        // ID -> ID/EX pipeline(to Execute stage and beyond)
        .id_ex_rs1_val_o    (id_ex_rs1_val_o),
        .id_ex_rs2_val_o    (id_ex_rs2_val_o),
        .id_ex_imm_o        (id_ex_imm_o),
    
        .id_ex_rs1_o        (id_ex_rs1_o),
        .id_ex_rs2_o        (id_ex_rs2_o),
        .id_ex_rd_o         (id_ex_rd_o),
        .id_ex_funct3_o     (id_ex_funct3_o),
        .id_ex_funct7_o     (id_ex_funct7_o),
    
        // Control to later stages
        .id_ex_regwrite_o   (id_ex_regwrite_o),
        .id_ex_mem_read_o   (id_ex_mem_read_o),
        .id_ex_mem_write_o  (id_ex_mem_write_o),
        .id_ex_branch_o     (id_ex_branch_o),
        .id_ex_jump_o       (id_ex_jump_o),
        .id_ex_write_data_o (id_ex_write_data_o),  
        .id_ex_lui_o        (id_ex_lui_o),
        .id_ex_is_jalr_o    (id_ex_is_jalr_o),
        .id_ex_alu_op_o     (id_ex_alu_op_o),
    
        // Execute operand selects / forwarding selects
        .id_ex_opA_sel_o    (id_ex_opA_sel_o),    
        .id_ex_opB_sel_o    (id_ex_opB_sel_o),     
        .id_ex_rs1_sel_o    (id_ex_rs1_sel_o),   
        .id_ex_rs2_sel_o    (id_ex_rs2_sel_o)    
    );
    
    
    // ---------------------- ID/EX Interstage Register ----------------------
    id_ex_reg ID_EX_REG (
        .clk                (clk),
        .rst                (rst),

        // Inputs
        .flush_i            (flush_o),
        .stall_i            (stall_o),
        .instr_valid_i      (instr_valid_i),

        // data
        .pc_i               (pc_i),
        .pc4_i              (pc4_i),
        .rs1_val_i          (rs1_rf),
        .rs2_val_i          (rs2_rf),
        .imm_i              (imm_d),

        .rs1_i              (rs1),
        .rs2_i              (rs2),
        .rd_i               (rd),
        .funct3_i           (funct3),
        .funct7_i           (funct7),

        // control (use your gated versions if you have them)
        .regwrite_i         (regwrite_g),
        .mem_read_i         (mem_read_g),
        .mem_write_i        (mem_write_g),
        .branch_i           (branch_g),
        .jump_i             (jump_g),
        .write_data_i       (write_data_g),
        .lui_i              (lui_g),
        .is_jalr_i          (is_jalr_g),
        .alu_op_i           (alu_op_g),

        // execute selects
        .opA_sel_bit_i      (opA_sel_bit_d),
        .opB_sel_i          (opB_sel_d),
        .rs1_sel_i          (RS1_Sel_d),
        .rs2_sel_i          (RS2_Sel_d),

        // Outputs (these are decode_unit outputs)
        .id_ex_valid_o      (id_ex_valid_o),

        .id_ex_pc_o         (id_ex_pc_o),
        .id_ex_pc4_o        (id_ex_pc4_o),
        .id_ex_rs1_val_o    (id_ex_rs1_val_o),
        .id_ex_rs2_val_o    (id_ex_rs2_val_o),
        .id_ex_imm_o        (id_ex_imm_o),

        .id_ex_rs1_o        (id_ex_rs1_o),
        .id_ex_rs2_o        (id_ex_rs2_o),
        .id_ex_rd_o         (id_ex_rd_o),
        .id_ex_funct3_o     (id_ex_funct3_o),
        .id_ex_funct7_o     (id_ex_funct7_o),

        .id_ex_regwrite_o   (id_ex_regwrite_o),
        .id_ex_mem_read_o   (id_ex_mem_read_o),
        .id_ex_mem_write_o  (id_ex_mem_write_o),
        .id_ex_branch_o     (id_ex_branch_o),
        .id_ex_jump_o       (id_ex_jump_o),
        .id_ex_write_data_o (id_ex_write_data_o),
        .id_ex_lui_o        (id_ex_lui_o),
        .id_ex_is_jalr_o    (id_ex_is_jalr_o),
        .id_ex_alu_op_o     (id_ex_alu_op_o),

        .id_ex_opA_sel_o    (id_ex_opA_sel_o),
        .id_ex_opB_sel_o    (id_ex_opB_sel_o),
        .id_ex_rs1_sel_o    (id_ex_rs1_sel_o),
        .id_ex_rs2_sel_o    (id_ex_rs2_sel_o)
    );
        
        
    // ---------------------- Execute Stage ----------------------
    Execute_Unit EU (
        // Inputs
        // Inputs for Operand A
        .PC,
        .PC4,
        .RS1_IDEXE,
        .RS1_EXEMEM,
        .RS1_MEMWB,
        
        // Inputs for Operand B
        .RS2_IDEXE,
        .RS2_EXEMEM,
        .RS2_MEMWB,
        .imm,
        
        // Inputs for ALU Control Unit
        .func3,
        .func7,
        .alu_op,
        
        // Control Signals for Muxltiplexers
        .RS1_sel,
        .RS2_sel,
        .OpA_sel,
        .OpB_sel,
        
        //Outputs
        // Execute Unit Output
        .alu_out
   
    );
    
    // ---------------------- EX/MEM Interstage Register ----------------------
    ex_mem_reg EX_MEM_REG (
        .clk                (clk),
        .rst                (rst),
        
        // Inputs
        // EX/MEM Pipeline Register - Inputs (from EX stage)
        .flush,
        .stall,
        
        .ex_valid,
        
        // Data into MEM stage
        .ex_alu_out,        // ALU result / load-store address
        .ex_store_data,     // store write data (after forwarding)
        .ex_pc4,            // for JAL/JALR link writeback (optional)
        .ex_rd,
        
        // MEM control
        .ex_mem_read,
        .ex_mem_write,
        .ex_funct3,     // size/sign for loads; size for stores
        
        // WB control
        .ex_regwrite,
        .ex_write_data,         // 1- Memory Result, 0 = alu result
        
        // Outputs
        // EX/MEM Pipeline Register - Inputs (from EX stage)
        .ex_mem_valid,
        
        // Data into MEM stage
        .ex_mem_alu_out,
        .ex_mem_store_data,
        .ex_mem_pc4,           
        .ex_mem_rd,
        
        // MEM control
        .ex_mem_mem_read,
        .ex_mem_mem_write,
        .ex_mem_funct3,     
        
        // WB control
        .ex_mem_regwrite,
        .ex_mem_write_data  
    );
    
    // ---------------------- Memory Stage ----------------------
    mem_unit MU (
        .clk                (clk),
        .rst                (rst),
    
        // Inputs
        // From EX/MEM pipeline regs
        .ex_mem_valid_i,
        .ex_mem_addr_i,     
        .ex_mem_store_data_i,
        .ex_mem_funct3_i,
        .ex_mem_mem_read_i,
        .ex_mem_mem_write_i,
    
        //Outputs
        // Data memory BRAM interface (sync read, byte-write enables)
        .dmem_addr_o,
        .dmem_en_o,
        .dmem_we_o,      
        .dmem_wdata_o,
        .dmem_rdata_i,
    
        // To MEM/WB stage
        .load_valid_o,    
        .load_data_o
    );
    
    // ---------------------- MEM/WB Interstage Register ----------------------
    mem_wb_reg MEM_WB_REG(
        .clk                (clk),
        .rst                (rst),
        
        // Inputs
        .flush_i            (1'b0),    // optional (set 0 if unused)
        .stall_i,           (1'b0),    // optional (set 0 if unused)
    
        // Inputs from EX/MEM (control + rd + calc/alu result)
        .ex_mem_valid_i     (,
        .ex_mem_rd_i,
        .ex_mem_regwrite_i,
        .ex_mem_write_data_i, // 1=mem->wb, 0=alu->wb
        .ex_mem_alu_out_i,
    
        // Inputs from mem_unit (formatted load result)
        .mem_load_valid_i,
        .mem_load_data_i,
    
        // Outputs to WB stage
        .mem_wb_valid_o,
        .mem_wb_rd_o,
        .mem_wb_regwrite_o,
        .mem_wb_write_data_o,
        .mem_wb_alu_out_o,
        .mem_wb_load_valid_o,
        .mem_wb_load_data_o
    );
    
    // ---------------------- Writeback Stage ----------------------
    writeback_unit WbU (
        //Inputs
        // from mem/wb pipeline register
        .mem_wb_valid,
        .mem_wb_rd,
        .mem_wb_regwrite,
        .mem_wb_write_data,   // 1 = memory result, 0 = alu result
        .mem_wb_alu_out,
        .mem_wb_load_valid,
        .mem_wb_load_data,
    
        // register file write port
        .rf_we,
        .rf_waddr,
        .rf_wdata,
        
        // Outputs
        // writeback stage outputs (forwarding / debug visibility)
        .wb_valid,
        .wb_regwrite_eff,     // regwrite after gating
        .wb_rd,
        .wb_value
    );


endmodule
