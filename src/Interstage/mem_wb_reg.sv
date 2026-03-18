`timescale 1ns / 1ps
module mem_wb_reg #(
    parameter int XLEN = 32
) (
    input  logic             clk,
    input  logic             rst,

    input  logic             flush_i,
    input  logic             stall_i,

    // Inputs from EX/MEM
    input  logic             ex_mem_valid_i,
    input  logic [31:0]      ex_mem_instr_i,
    input  logic [4:0]       ex_mem_rd_i,
    input  logic             ex_mem_regwrite_i,
    input  logic             ex_mem_write_data_i, // 1=mem->wb, 0=alu->wb
    input  logic [XLEN-1:0]  ex_mem_alu_out_i,
    input  logic [XLEN-1:0]  ex_mem_pc4_i,            
    input  logic             ex_mem_wb_pc4_sel_i,     


    // Inputs from mem_unit (asserted on DMEM response cycle)
    input  logic             mem_load_valid_i,
    input  logic [XLEN-1:0]  mem_load_data_i,

    // Outputs to WB stage
    output logic             mem_wb_valid_o,
    output logic [31:0]      mem_wb_instr_o,
    output logic [4:0]       mem_wb_rd_o,
    output logic             mem_wb_regwrite_o,
    output logic             mem_wb_write_data_o,
    output logic [XLEN-1:0]  mem_wb_alu_out_o,
    output logic [XLEN-1:0]  mem_wb_pc4_o,            
    output logic             mem_wb_wb_pc4_sel_o,     
    output logic             mem_wb_load_valid_o,
    output logic [XLEN-1:0]  mem_wb_load_data_o,
    
    output logic             stall_req_o
);

    // Shadow regs: EX/MEM metadata from previous cycle
    logic            sh_valid;
    logic [31:0]     sh_instr;
    logic [4:0]      sh_rd;
    logic            sh_regwrite;
    logic            sh_write_data;
    logic [XLEN-1:0] sh_alu_out;
    logic [XLEN-1:0] sh_pc4;             
    logic            sh_wb_pc4_sel;      

    // 1-entry buffer for the next instruction
    logic            buf_valid;
    logic [31:0]     buf_instr;
    logic [4:0]      buf_rd;
    logic            buf_regwrite;
    logic            buf_write_data;
    logic [XLEN-1:0] buf_alu_out;
    logic [XLEN-1:0] buf_pc4;            
    logic            buf_wb_pc4_sel;     

    always_ff @(posedge clk) begin
        if (rst || flush_i) begin
            // Outputs bubble
            mem_wb_valid_o      <= 1'b0;
            mem_wb_instr_o      <= 32'h00000013;
            mem_wb_rd_o         <= 5'd0;
            mem_wb_regwrite_o   <= 1'b0;
            mem_wb_write_data_o <= 1'b0;
            mem_wb_alu_out_o    <= '0;
            mem_wb_pc4_o        <= '0;       
            mem_wb_wb_pc4_sel_o <= 1'b0;        
            mem_wb_load_valid_o <= 1'b0;
            mem_wb_load_data_o  <= '0;

            // Shadow + buffer clear
            sh_valid      <= 1'b0;
            sh_instr      <= 32'h00000013;
            sh_rd         <= 5'd0;
            sh_regwrite   <= 1'b0;
            sh_write_data <= 1'b0;
            sh_alu_out    <= '0;
             sh_pc4       <= '0;    
            sh_wb_pc4_sel <= 1'b0;   

            buf_valid      <= 1'b0;
            buf_instr      <= 32'h00000013;
            buf_rd         <= 5'd0;
            buf_regwrite   <= 1'b0;
            buf_write_data <= 1'b0;
            buf_alu_out    <= '0;
            buf_pc4        <= '0;     
            buf_wb_pc4_sel <= 1'b0;   
        end
        else if (!stall_i) begin
            // Update shadow with current EX/MEM metadata every cycle
            sh_valid      <= ex_mem_valid_i;
            sh_instr      <= ex_mem_instr_i;
            sh_rd         <= ex_mem_rd_i;
            sh_regwrite   <= ex_mem_regwrite_i;
            sh_write_data <= ex_mem_write_data_i;
            sh_alu_out    <= ex_mem_alu_out_i;
            sh_pc4        <= ex_mem_pc4_i;            
            sh_wb_pc4_sel <= ex_mem_wb_pc4_sel_i;     

            // Priority 1: If a buffered instruction to emit and no load response collision, emit it
            if (buf_valid && !mem_load_valid_i) begin
                mem_wb_valid_o      <= buf_valid;
                mem_wb_instr_o      <= buf_instr;
                mem_wb_rd_o         <= buf_rd;
                mem_wb_regwrite_o   <= buf_regwrite;
                mem_wb_write_data_o <= buf_write_data;
                mem_wb_alu_out_o    <= buf_alu_out;
                mem_wb_pc4_o        <= buf_pc4;         
                mem_wb_wb_pc4_sel_o <= buf_wb_pc4_sel;  

                mem_wb_load_valid_o <= 1'b0;
                // keep last load data for waveform readability
                mem_wb_load_data_o  <= mem_wb_load_data_o;

                buf_valid <= 1'b0; // consumed
            end
            
            // Priority 2: load response cycle
            else if (mem_load_valid_i) begin
                // Buffer current EX/MEM metadata - because this cycle's WB slot is used to retire the load response.
                if (ex_mem_valid_i & !buf_valid) begin
                    buf_valid      <= ex_mem_valid_i;
                    buf_instr      <= ex_mem_instr_i;
                    buf_rd         <= ex_mem_rd_i;
                    buf_regwrite   <= ex_mem_regwrite_i;
                    buf_write_data <= ex_mem_write_data_i;
                    buf_alu_out    <= ex_mem_alu_out_i;
                    buf_pc4        <= ex_mem_pc4_i;            
                    buf_wb_pc4_sel <= ex_mem_wb_pc4_sel_i;     
                end

                // Retire the load using previous-cycle shadow metadata
                mem_wb_valid_o      <= sh_valid;
                mem_wb_instr_o      <= sh_instr;
                mem_wb_rd_o         <= sh_rd;
                mem_wb_regwrite_o   <= sh_regwrite;

                // Critical: on a load response, WB must select memory
                mem_wb_write_data_o <= 1'b1;

                mem_wb_alu_out_o    <= sh_alu_out;
                mem_wb_pc4_o        <= sh_pc4;        
                mem_wb_wb_pc4_sel_o <= 1'b0; 

                mem_wb_load_valid_o <= 1'b1;
                mem_wb_load_data_o  <= mem_load_data_i;
            end
            
            // Priority 3: normal pass-through
            else begin
                mem_wb_valid_o      <= ex_mem_valid_i;
                mem_wb_instr_o      <= ex_mem_instr_i;
                mem_wb_rd_o         <= ex_mem_rd_i;
                mem_wb_regwrite_o   <= ex_mem_regwrite_i;
                mem_wb_write_data_o <= ex_mem_write_data_i;
                mem_wb_alu_out_o    <= ex_mem_alu_out_i;
                mem_wb_pc4_o        <= ex_mem_pc4_i;         
                mem_wb_wb_pc4_sel_o <= ex_mem_wb_pc4_sel_i; 

                mem_wb_load_valid_o <= 1'b0;
                mem_wb_load_data_o  <= mem_wb_load_data_o; // hold for waveform readability
            end
        end
        // else: stall -> hold everything (outputs, shadow, buffer)
    end
    
    // Drive Stall Req
    assign stall_req_o = buf_valid && mem_load_valid_i;
endmodule

