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

File:        regfile.sv
Author:      Zhangxi Tan
Description: 32-bit register files

 */

module iregfile #(parameter WIDTH = 32,
		parameter DEPTH = 32, parameter DEPTHMSB = $clog2(DEPTH)-1) 
		(
		input  logic                            clk,
		input  logic          [1:0]             re, //read enable
		input  logic          [1:0][DEPTHMSB:0] ra,	//[4:0]  read address
		input  logic                            reg_write_back_en_i, //for jal, jalr, load to chose right write back cycle
		output logic          [1:0][WIDTH-1:0]  rs,	//[31:0] rs1, rs2
		input  logic                            we, //write enable
		input  logic          [DEPTHMSB:0]      wa, //[4:0] write address
		input  logic          [WIDTH-1:0]       wd //[31:0] write data
		
		//input  logic          [31:0]            inst_in
		);

	 	
	
	typedef logic [WIDTH-1:0] regf_data_t;
	regf_data_t               dff_ireg[1:31];        // 32 user registers, reg0 = 0 
    
	logic [DEPTH-1:1]         ireg_clk = {(DEPTH-1) {'0}};
	logic [DEPTH-1:1]	      ireg_clk_en; //gated
	logic [DEPTH-1:1]         write_reg_en;
	 

	genvar i;
	generate 
		for (i=1;i<DEPTH;i++) begin : rf
			//clock gater   					//ucb EE40  //cs250
			assign ireg_clk_en[i] = (re[0] & (ra[0] == i)) | (re[1] & (ra[1] == i)) | (we & (wa == i));
			begin : label
				icg cg_i(
						.clk                 ( clk                     ),
						.clk_en              ( ireg_clk_en[i]          ),
						.clkg                ( ireg_clk[i]             ) 
					);	// icg: inst clock gater
			end
			assign      write_reg_en[i] = we & (wa == i) & reg_write_back_en_i;
			always_ff @(posedge ireg_clk[i]) begin
				if (write_reg_en[i])
					dff_ireg[wa] <= wd;	//reg write
			end
		end
			
		always_comb begin : r1_read
			if(re[0] != 1'b0) begin
				if(ra[0] ==  {(DEPTHMSB+1) {1'b0}} ) begin
					rs[0] = { WIDTH {1'b0} };  //x0 = 0
				end else begin
					rs[0] = dff_ireg[ra[0]];	//reg read
				end	
			end
		end
			
		always_comb begin : r2_read
			if(re[1] != 1'b0) begin
				if(ra[1] ==  {(DEPTHMSB+1) {1'b0}} ) begin
					rs[1] = { WIDTH {1'b0} };  //x0 = 0
				end else begin
					rs[1] = dff_ireg[ra[1]];	//reg read
				end	
			end
		end
  
		//		assign rs[0] = dff_ireg[ra[0]];	//reg read
		//		assign rs[1] = dff_ireg[ra[1]];
	endgenerate  

	
	
	
endmodule



module icg #(parameter WIDTH = 32,
		parameter DEPTH = 32, parameter DEPTHMSB = $clog2(DEPTH)-1)
		(
		input  logic                    clk,
		input  logic            	    clk_en,
		output logic                    clkg
		);
/*	always_ff @(posedge clk or negedge clk) begin : clk_gater
		if(clk_en) begin
			clkg <= clk;
		end
	end*/
	assign clkg = clk_en ? clk : '1;
	//assign clkg = clk_en ? ~clk : 0;
	
endmodule

