/**
 * Instruction Memory Access
 *
 * Maintain the next PC (PC+4/ALU/stall), and do the instruction memory read 
 * request when ld_line is enable
 */

import libdefine::*;

module im_access #(parameter DEPTH=16, parameter LINEWIDTH=64) // Depth is in 16-bit RVC instructions
		(
		input logic                    clk, 
		input logic                    rst,
		input logic [31:0]             rst_addr_i,
		// control signal
		input logic                    stall,
		input logic                    flush,
    //	input logic                    sys_call_en_i, //ecall
    //  input logic                    excep_en_i,
    //	input logic                    mret_en_i, //mret
		//		output logic                    line_ready, //memory system is ready
		//		output logic                    line_valid,  //instruction input to buffer enable
		//input logic                    imembusy_i,
		input logic                    ld_line,    //prefetch a line (split transaction) change instmem_addr
		//input logic                    inst_re,    //read a inst, change pc
		//input logic [31:0]             alu_result,
		//input logic [31:0]             mtvec_i,
		//input logic [31:0]             mepc_i,
        input logic [31:0]             inst_addr_flush_i,

		input logic                    inst_valid_i,
		inout logic                    is_rvc_i,
		// access to instr memory
		output logic                   inst_req_o,	//valid im request
		output logic [31:0]            inst_addr_o,	// pc+4 per time
		//output logic [31:0]            instmem_addr_o	// pc+8 per time for fetch a line from inst mem
		
        output logic [31:0]            pc_prev_o
		);
	
	logic [31:0]  pc;
    //logic [31:0]  pc_prev_stage1;
    logic [31:0]  pc_prev_stage2;
    assign pc_prev_o = pc_prev_stage2;

	assign inst_addr_o = pc;

	logic  inst_re;
	assign inst_re = (rst == RstDisable) & ~stall & ~flush;
	
	// inst memory chip enable
	always_ff @(posedge clk) begin
		if (rst == RstEnable) begin
			inst_req_o <= ChipDisable;
		end else begin
			inst_req_o <= ChipEnable;
		end
	end
	
	// instruction memory access
	//logic  instmem_addr_refresh;
	logic  pc_refresh_en;
	//assign instmem_addr_refresh = (ld_line & imembusy_i) | flush;
	assign pc_refresh_en           = (inst_valid_i | flush) & ~stall;
	always_ff @(posedge clk) begin
		/*if(instmem_addr_refresh)    // inst_buff sent a request for new inst line
			instmem_addr_o <= instmem_addr_next;*/
		//inst_addr_o <= pc;
		if(rst == RstEnable) begin
			pc              <=  rst_addr_i;
            pc_prev_stage2  <= pc;
            //pc_prev_stage1  <= pc_prev_stage2;
        end
		else if (pc_refresh_en) begin  // pc change
			pc              <=  pc_next;
            pc_prev_stage2  <=  pc;
            //pc_prev_stage1  <=  pc_prev_stage2;
        end
	end
	
	logic [31:0]           pc_next;
	logic [31:0]           pc_adder;
	logic [31:0]           pc_addout;
	assign pc_adder  = is_rvc_i ? 32'h2 : 32'h4;
    assign pc_addout = pc + pc_adder;
	// next pc
/*	assign pc_next = ~flush        ? pc_addout
		           : (sys_call_en_i || excep_en_i) ? mtvec_i
		           : mret_en_i     ? mepc_i
		           : alu_result;
*/
    assign pc_next = flush ? inst_addr_flush_i : pc_addout;

	
endmodule
