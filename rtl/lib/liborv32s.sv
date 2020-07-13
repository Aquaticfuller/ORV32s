/*
Copyright (c) 2019, RiVAI Techologies(Shenzhen) Co., Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

 * Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

File:        liborv32s.sv
Author:      Zhangxi Tan
Description: pipeline data structures

 */

package liborv32s;
	import libopcode::*;
	typedef logic [15:0] rvc_inst_t;
	
	//****************************judge if is rvc**************************//
	function logic is_inst_rvc(logic [1:0] inst_msb);   //is rvc inst return 1
		return (inst_msb != 2'b11);
	endfunction
		
	//****************************judge if is zero**************************//
	function logic is_zero_inst(logic [13:0] inst); //if it is zero inst, it has to be a rvc first
		return (inst[13:0]  == 14'b0);
	endfunction

	//****************************judge if is rvc16_imm**************************//
	function logic is_inst_rvc_imm(logic [15:0] inst);  //is rvc_imm return 1
	logic imm = 0;
	case(inst [1:0])
		2'b00: begin          //quadrant 0
			imm = '1;
		end
		2'b01: begin          //quadrant 1
			case(inst [15:13])
				3'b000,3'b001,3'b010,3'b011,3'b101,3'b110,3'b111: begin
					imm = '1;
				end
				3'b100: begin
					if(inst [11:10] == 2'b11) begin   //without imm
						imm = '0;
					end else begin
						imm = '1;
					end
				end
				default: begin
					//error 
				end
			endcase
		end
		2'b10: begin          //quadrant 2
			if(inst[15:13] == 3'b100) imm = 0;
			else imm = 1;
		end
		default: imm = 0;//error
	endcase
	return imm;
	endfunction

	//****************************judge if is rv32_imm**************************//
	function logic is_inst_rv32_imm(logic [31:0] inst);  //is rv32_imm return 1
	logic imm = 0;
	case(inst [6:2])
		OP_IMM: begin
			imm = 1;
		end
		OP,FENCE,SYSTEM: imm = 0;
		LUI,AUIPC,JAL,JALR,BRANCH,LOAD,STORE: imm = 1;
		default: imm = 0;//error
	endcase
	return imm;
	endfunction
	
	
		typedef struct {
			logic [4:0]  addr;
			logic        valid;
			logic        is_float;           //is a floating point register (regfile select)
		}regaddr_t;

	//TODO alu
	/*typedef enum logic [1:0]  {
	
} alu_op_t;*/

	//pipeline registers between fetch and execute
	typedef struct {
		logic [31:0] imm;			//decode imm
		//adder pre-decode
		logic  	   is_alu_sub;		//is alu sub
		logic	   is_rs1_pc;
		logic 	   is_rs2_imm;		//second input is imm
      
	}if2ex_tp;

endpackage


