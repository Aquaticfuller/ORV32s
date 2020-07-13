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

File:        inst_buffer.sv
Author:      Zhangxi Tan
Description: instruction buffer that handles 16-bit and 32-bit instructions.

 */

module inst_buffer #(parameter DEPTH=16, parameter LINEWIDTH=64) // Depth is in 16-bit RVC instructions
		(
		input logic                    clk, 
		input logic                    rst,
		input logic                    flush,      //flush instruction buffer
		
		//input logic [1:0]              order_when_flush,//00,01,10,11 for 1st, 2nd, 3rd, 4th in the block. after flush
		input logic [1:0]              order_when_flush_nextcnt,
		input logic [1:0]              order_when_flush_rdptr,
		
		input logic                    stall,      //pipeline stall
		input logic [LINEWIDTH-1:0]    line_in,    //instruction in
		input logic                    line_ready, //ready to receive addr. memory system is ready	//axi
		input logic                    line_valid, //respond data .instruction input to buffer enable

		output logic                   ld_line,    //prefetch a line (split transaction)
		output logic                   read_finish_o,
		//fetch interface
		//input logic                    inst_re,	//inst buff read enable
		output logic [31:0]            inst_out,
		output logic                   inst_valid
		);
        
	typedef logic [15:0] rvc_inst_t;
	localparam DEPTHMSB       = $clog2(DEPTH)-1;			//depth MSB 3 //means log2()
	localparam ENTRIESPERLINE =LINEWIDTH/16;			//entries per line 4
	localparam DEPTHMSB_3     = DEPTHMSB-3;

	//inst buffer pointers
	logic [DEPTHMSB:0]    rff_rd_ptr, rff_wr_ptr;	//read/write register pointer
	//logic [DEPTHMSB:0]    rff_wr_ptr_last;
	logic [DEPTHMSB+1:0]  rff_free_cnt, next_free_cnt;//, next_free_cnt_2;             //number of free entries (credit based flow control) //+1 bit cause the legal range is 0 to 16
	logic ld_line_last;
	rvc_inst_t dff_inst_buf[0:DEPTH-1];				//inst buff, 16 bits per entry, 16 entries total //typedef logic [15:0] rvc_inst_t;

	//synthesis translate_off
	//buffer pointer assertions go here

	//chk_inst_re: assert property (@(posedge clk) disable iff (rst) (stall | flush) |-> !inst_re) else $error("%m: instruction buffer is not supposed to be read during pipeline stall and flush");

	chk_free_cnt: assert property (@(posedge clk) disable iff (rst) rff_free_cnt <= DEPTH) else $error("%m: instruction buffer credit calculation overflow");

			//chk_overflow: assert property (@(posedge clk) disable iff (rst) line_valid |-> (rff_rd_ptr != rff_wr_ptr || rff_free_cnt == DEPTH)) else $error("%m: instruction buffer overflow");
			// because there is a limit in 'rff_free_cnt', so there are only 2 conditions where 'rff_rd_ptr == rff_wr_ptr':
			// fifo is empty or is full

			//synthesis translate_on

			//asynchronous fifo design

	logic [1:0] incr_rd_ptr;
	logic is_top_rvc, rd_ptr_en;
	//logic is_zero_inst;
	assign is_top_rvc   = is_inst_rvc(dff_inst_buf[rff_rd_ptr][1:0]);	//test the last 2 bit, if is rvc return 1
	//assign is_zero_inst = is_top_rvc ? is_zero_inst(inst[15:2]) : DISABLE;
	
	logic inst_re;
	assign inst_re = (rst == RstDisable) & ~stall & ~flush;
	
	always_comb begin     //LRM
		//read instruction from buffer
		inst_valid  = (rff_free_cnt <= DEPTH-2) | ((rff_free_cnt == DEPTH-1) & is_top_rvc); 	//num of the entries(per 16 bits) in the queue>=2 | 1 but a rvc
		incr_rd_ptr = is_top_rvc ? 1 : 2;	//if it's a rvc, read 1 entry(16 bits), else read 2
		rd_ptr_en   = inst_valid & inst_re;					

		inst_out    = inst_valid & ~flush ? { dff_inst_buf[rff_rd_ptr+1], dff_inst_buf[rff_rd_ptr] } : 32'b0;	//always sends 32 bits out, but with the 1 or 2 increase in rdptr, it can handle 16- and 32-bit insts
		//refill request
		//issue inst buffer refill request as long as there are free spaces
		ld_line     = (rff_free_cnt >= ENTRIESPERLINE) & ~flush & rst;// & ~stall;	//read 4 entries per time
      
		//buffer credit calculation
		next_free_cnt = rff_free_cnt  
			+ ( ((inst_valid & inst_re) ? incr_rd_ptr : 0) + (free_cnt_flush_flag ? order_when_flush_nextcnt : 0) )
			//- ( (rff_wr_ptr_last ^ rff_wr_ptr != '0)&(ld_line_last & line_ready) ? ENTRIESPERLINE : 0 );
			- ((ld_line_last & line_ready) ? ENTRIESPERLINE : 0);
     
	end
	
	//assign next_free_cnt_2 = (next_free_cnt[4:3]==2'b11) ? rff_free_cnt + ( ((inst_valid & inst_re) ? incr_rd_ptr : 0) + (free_cnt_flush_flag ? order_when_flush : 0) )
	//	                                                 : next_free_cnt;
	assign ld_line_last = ld_line;
	//assign rff_wr_ptr_last = rff_wr_ptr;
	logic [DEPTHMSB:0]    rff_rd_ptr_flush;
	logic free_cnt_flush_flag;  //to remove waste part of mem block after flush
	assign rff_rd_ptr_flush   = {{(DEPTHMSB-2){1'b0}} , order_when_flush_rdptr};
	
	always_ff @(posedge clk) begin
		if (~rst | flush) begin
			rff_free_cnt <= DEPTH;

			rff_rd_ptr <= rff_rd_ptr_flush; 
			rff_wr_ptr <= '0;
			free_cnt_flush_flag <= ENABLE;
			//ld_line_last  <= DISABLE;
		end
		else  begin
			if (rd_ptr_en) 
				rff_rd_ptr <= rff_rd_ptr + incr_rd_ptr;	//reg read pointer move to next //inst output

			if ((ld_line & line_valid) | rd_ptr_en)//if ((ld_line & line_ready) | rd_ptr_en)
				rff_free_cnt <= next_free_cnt;	//after a inst input/output, update the number of free entries

			//even if the pipeline is stalled, we cannot lose data 
			if (ld_line  & line_valid)
				rff_wr_ptr <= rff_wr_ptr + ENTRIESPERLINE;	//TODO: question: how to prevent the wr goes faster and catch the rd form behind? //the printer goes 0->4->8->12->0->...
              
			if(line_valid)
				free_cnt_flush_flag <= DISABLE;
			
			//ld_line_last    <= ld_line;
			
		end     
	end

	//refill response 
	//split transaction
	always_ff @(posedge clk) begin
		if (line_valid & ld_line) begin
			for (int i=0;i<ENTRIESPERLINE;i++) begin
				dff_inst_buf[rff_wr_ptr+i] <= line_in[i*16 +: 16]; 	//[BASE +: WIDTH]==[BASE+WIDTH-1 : BASE] //[BASE  -: WIDTH]==[BASE :  BASE-WIDTH+1]	
			end
		end
	end 

endmodule


