import libdefine::*;
import libalu::*;
module divider (
		input  logic              clk,
		input  logic              rst,
		//control
		input  logic              div_en_i,  ///
		input  logic [2:0]        funct3_32,
		output logic              div_finish_o,
		output logic              div_sub_o, /// division step need do Subtraction
		//operand
		input  logic [31:0]       muldiv_a_i, // Multiplicand<< // Dividend
		input  logic [31:0]       muldiv_b_i, // multiplier>>   // divisor
		
		// alu interface
		input  logic [33:0]       adder_result_ext_i, //from alu
		output logic [31:0]       div_operand_a_o,
		output logic [31:0]       div_operand_b_o,
		// regfile interface
		output logic [31:0]       muldiv_result_o
		);
	
	logic [63:0]       product; // begin: [ multiplier | product ]//in division, [Dividend|Quotient]
	logic [63:0]       product_next;

	logic [63:0]       product_start_div;

	logic [63:0]      product_next_div;
	logic [63:0]      product_next1_div;
	logic [63:0]      product_next2_div;
	logic [63:0]      product_recover_div;
	logic [6:0]       round_record; // record mul rounds from 0 to 31
	logic [6:0]       round_record_next;

	assign round_record_next = div_finish_o ? '0 : round_record + 1;
	assign div_finish_o  = (round_record == 7'b1000010);
	

	assign product_start_div = { 32'b0, muldiv_operand_a };

	assign product_next1_div   = { adder_result_ext_i[32:1], product[31:0] };
	assign product_recover_div = product[63] ? product_next1_div : product;//if remander is minus, recover, else, remain
	assign product_next2_div   = { product_recover_div[62:0], ~product[63] };
	assign div_sub_o           = round_record[0];
	assign product_next_div    = div_sub_o ? product_next1_div : product_next2_div;
    
    
	logic [31:0]       muldiv_operand_a;
	logic [31:0]       muldiv_operand_b;
		
	logic              a_negate;
	logic              b_negate;
	assign  a_negate         = muldiv_a_i[31];
	assign  b_negate         = muldiv_b_i[31];
	assign  div_operand_a_o  = product[63:32];
	assign  div_operand_b_o  = muldiv_operand_b;
	


	logic [31:0]      div_signed_a;
	logic [31:0]      div_signed_b;
	logic [31:0]      div_neg_a;
	logic [31:0]      div_neg_b;
	assign div_neg_a    = ~muldiv_a_i + 1;
	assign div_neg_b    = ~muldiv_b_i + 1;
	assign div_signed_a = a_negate ? div_neg_a : muldiv_a_i;
	assign div_signed_b = b_negate ? div_neg_b : muldiv_b_i;
	
	always_comb begin : div_to_alu
		case(funct3_32)
			DIVU,
			REMU  //unsigned
			: begin 
				muldiv_operand_a = muldiv_a_i;
				muldiv_operand_b = muldiv_b_i;
			end
			
			default   //	DIV,REM  //signed
			: begin
				muldiv_operand_a = div_signed_a;
				muldiv_operand_b = div_signed_b;
			end
		endcase
	end
	
	assign product_next  = (round_record == '0) ? product_start_div : product_next_div;

	always_ff @(posedge clk) begin : division
		if(div_en_i) begin
			product      <= product_next;
			round_record <= round_record_next;
		end	else begin
			product      <= '0;
			round_record <= '0;
		end
	end
	
	logic        quo_neg_en;//quotient
	logic        rem_neg_en;//the sign of remainder is the same as operand_a
	assign quo_neg_en    = a_negate ^ b_negate;
	assign rem_neg_en    = a_negate;
	
	logic [31:0] quo_result_neg;
	logic [31:0] rem_result_neg;
	assign quo_result_neg = ~product_next[31:0] + 1;
	assign rem_result_neg = ~{1'b0, product_next[63:33]} + 1;
	
	logic [31:0] quo_result;
	logic [31:0] rem_result;
    assign quo_result = quo_neg_en ? quo_result_neg : product_next[31:0];
    assign rem_result = rem_neg_en ? rem_result_neg : {1'b0, product_next[63:33]};
	

	always_comb begin : muldiv_output
		case(funct3_32)
			DIV//signed
			: muldiv_result_o = quo_result;
			
			DIVU
			: muldiv_result_o = product_next[31:0];
			
			REM//signed
			: muldiv_result_o = rem_result;
			default//REMU
			: muldiv_result_o = {1'b0, product_next[63:33]};//remainder has been sll once more, so shift back
		endcase
	end
	
	
	
endmodule