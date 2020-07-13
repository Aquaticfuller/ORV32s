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
	
	//division logic
	logic [63:0]       product; // begin: in division, [Dividend|Quotient]
	logic [63:0]       product_next;

	logic [63:0]       product_start_div;

	logic [63:0]      product_next_div;
	logic [63:0]      product_next1_div;
	//logic [63:0]      product_next2_div;
	//logic [63:0]      product_restore_div;
	logic [6:0]       round_record; // record mul rounds from 0 to 31
	logic [6:0]       round_record_next;
	logic             round_finish;
	logic             div_finish;
	logic             divu_finish;
	logic             rem_finish;
	
	//assign alu_result_sub    = adder_result_ext_i[32] | (adder_result_ext_i[33] & muldiv_operand_b[31] & div_sub_o);
	
	assign div_finish        = (round_record == 7'd33) | (signed_en & (dividend_zero_signed | divisor_zero_signed));
	assign divu_finish       = divu_small_large | divu_large_large | (~signed_en & (dividend_zero_unsigned | divisor_zero_unsigned));
	assign round_finish      = divu_finish | div_finish;
	assign round_record_next = div_finish_o ? 0 : round_record + 1;
	
	assign div_finish_o      = round_finish;
	

	assign product_start_div = { 32'b0, muldiv_operand_a };

	assign product_next1_div   = { adder_result_ext_i[32:1], product[30:0], ~product[63] };
	//assign product_restore_div = product[63] ? product_next1_div : product;//if remander is minus, recover, else, remain
	//assign product_next2_div   = { product_restore_div[62:0], ~product[63] };
	//assign product_next2_div   = { product_next1_div[63:1], ~product[63] };
	
	assign product_next_div    = product_next1_div;
	
	logic signed_en;
	logic rem_en; //differentiate rem from div
	logic dividend_zero_signed;
	logic divisor_zero_signed;
	logic dividend_zero_unsigned;
	logic divisor_zero_unsigned;
	
	assign rem_en                 =  funct3_32[1];
	assign signed_en              = ~funct3_32[0];
	assign dividend_zero_signed   = (muldiv_a_i[30:0] == '0);
	assign divisor_zero_signed    = (muldiv_b_i[30:0] == '0);
	assign dividend_zero_unsigned = ~muldiv_a_i[31] & dividend_zero_signed;
	assign divisor_zero_unsigned  = ~muldiv_b_i[31] & divisor_zero_signed;
	
	
	//DIVU special logics
	//logic             is_divu;
	logic             divu_small_large;//when <0x80000000 / >=0x80000000
	logic             divu_large_large;//when >=0x80000000 / >=0x80000000
	
	//assign is_divu           = funct3_32 == DIVU;
	assign divu_small_large  = ~muldiv_operand_a[31] & muldiv_operand_b[31];
    assign divu_large_large  =  muldiv_operand_a[31] & muldiv_operand_b[31];
	
	
    
	//operand to alu
	logic [31:0]       muldiv_operand_a;
	logic [31:0]       muldiv_operand_b;
		
	logic              a_negate;
	logic              b_negate;
	assign  a_negate         = muldiv_a_i[31];
	assign  b_negate         = muldiv_b_i[31];
	
	assign  div_operand_a_o  = div_finish ? ( rem_en ? product[63:32] : product[31:0]) : ( divu_large_large ? muldiv_operand_a : product[63-1:32-1]);  //R = 2 * R +/- D//when div finish, Convert quotient digits {-1,1} to the digit set {0,1} 
	assign  div_operand_b_o  = div_finish & ~rem_en ? ~product[31:0] : muldiv_operand_b;
	assign  div_sub_o        = div_finish ? ~rem_en : ( divu_large_large ? ENABLE : ~product[63]); //if R<0, add; if R>=0, sub
  
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
	
	//divisor refresh
	assign product_next  = (round_record == 0) ? product_start_div : product_next_div;

	always_ff @(posedge clk) begin : division
		if(div_en_i) begin
			product      <= product_next;
			round_record <= round_record_next;
		end	else begin
			product      <= '0;
			round_record <= '0;
		end
	end

	//division output
	logic        rem_neg;
	logic        quo_neg_en;//quotient
	logic        rem_neg_en;//the sign of remainder is the same as operand_a
	assign rem_neg       = product[63];
	assign quo_neg_en    = a_negate ^ b_negate;
	assign rem_neg_en    = a_negate;
	
	logic [31:0] quo_result_ori;
	logic [31:0] quo_result_neg;
	logic [31:0] rem_result_neg;
	assign quo_result_ori = adder_result_ext_i[32:1] - rem_neg;
	assign quo_result_neg = ~quo_result_ori + 1;
	assign rem_result_neg = ~product[63:32] + 1;
	
	logic [31:0] quo_result_signed;
	logic [31:0] quo_result_unsigned;
	logic        quo_result_special_signed_en;
	logic        quo_result_special_unsigned_en;
	logic [31:0] quo_result_special;
	
	logic [31:0] rem_result_signed;
	logic [31:0] rem_result_unsigned;
	logic        rem_result_special_signed_en;
	logic        rem_result_special_unsigned_en;
	logic [31:0] rem_result_special;
	//logic special_num;
	//assign special_num = 
	assign quo_result_special_signed_en   = divisor_zero_signed | dividend_zero_signed;
	assign quo_result_special_unsigned_en = divisor_zero_unsigned | dividend_zero_unsigned;
	assign quo_result_special             = divisor_zero_signed ? '1 : ( dividend_zero_unsigned ? '0 : 32'h80000000 );
	assign quo_result_signed   = quo_result_special_signed_en ? quo_result_special
		                       : (quo_neg_en ? quo_result_neg : quo_result_ori);
	assign quo_result_unsigned = quo_result_special_unsigned_en  ? quo_result_special
		                       : divu_small_large ? '0
		                       : divu_large_large ? {31'b0, ~adder_result_ext_i[32]}
		                       : product_next[31:0];
	
	assign rem_result_special_signed_en   = quo_result_special_signed_en;
	assign rem_result_special_unsigned_en = quo_result_special_unsigned_en;
	assign rem_result_special             = divisor_zero_signed ? muldiv_a_i : '0;
	
	assign rem_result_signed   = rem_result_special_signed_en ? rem_result_special
	          	               : rem_neg_en ? rem_result_neg
	          	               : product[63] ? adder_result_ext_i[32:1] : product[63:32];
	assign rem_result_unsigned = rem_result_special_unsigned_en ? rem_result_special
		                       : divu_small_large ? muldiv_a_i
		                       : divu_large_large ? (adder_result_ext_i[32] ? muldiv_a_i : adder_result_ext_i[32:1]) 
		                       : product[63] ? adder_result_ext_i[32:1] : product[63:32];
		
	

	always_comb begin : muldiv_output
		case(funct3_32)
			DIV//signed
			: muldiv_result_o = quo_result_signed;
			
			DIVU
			: muldiv_result_o = quo_result_unsigned;
			
			REM//signed
			: muldiv_result_o = rem_result_signed;
			default//REMU
			: muldiv_result_o = rem_result_unsigned;
		endcase
	end
	
	
	
endmodule