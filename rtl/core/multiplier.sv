import libdefine::*;
import libalu::*;
module multiplier (
		input  logic              clk,
		input  logic              rst,
		//control
		input  logic              mulit_en_i,
		input  logic [2:0]        funct3_32,
		output logic              mul_finish_o,
		//operand
		input  logic [31:0]       muldiv_a_i, // Multiplicand<< // Dividend
		input  logic [31:0]       muldiv_b_i, // multiplier>>   // divisor
		
		// alu interface
		input  logic [33:0]       adder_result_ext_i, //from alu
		output logic [31:0]       mult_operand_a_o,
		output logic [31:0]       mult_operand_b_o,
		// regfile interface
		output logic [31:0]       muldiv_result_o
		);
	
	logic [63:0]       product; // begin: [ multiplier | product ]//in division, [Dividend|Quotient]
	logic [63:0]       product_next;
	logic [63:0]       product_srl;

	logic [63:0]       product_start_mul;

	logic [63:0]       product_next_mul;

	logic [5:0]        round_record; // record mul rounds from 0 to 31
	logic [5:0]        round_record_next;
	assign product_srl       = product >> 1;

	assign round_record_next = mul_finish_o ? '0 : round_record + 1;
	assign mul_finish_o  = (round_record[5] == 1'b1); // 32 rounds, round_record == 6'b100000
	
	assign product_start_mul = { 32'b0, muldiv_operand_b };

	assign product_next_mul  = product[0] ? { adder_result_ext_i[33:1], product_srl[30:0] }
		                                  : product_srl;
	

    
    
	logic [31:0]       muldiv_operand_a;
	logic [31:0]       muldiv_operand_b;
		
	logic              a_negate;
	logic              b_negate;
	assign  a_negate     = muldiv_a_i[31];
	assign  b_negate     = muldiv_b_i[31];
	assign  mult_operand_a_o = mulit_en_i ? muldiv_operand_a : product[63:32];
	assign  mult_operand_b_o = mulit_en_i ? ({32{product[0]}} & product[63:32]) : muldiv_operand_b;
	

	logic [31:0]      mul_signed_a;
	logic [31:0]      mul_signed_b;
	assign mul_signed_a = a_negate ? { ~muldiv_a_i + 1 } : muldiv_a_i;
	assign mul_signed_b = b_negate ? { ~muldiv_b_i + 1 } : muldiv_b_i;
	
	always_comb begin : mul_to_alu
		case(funct3_32)
			MULHSU: begin //signed*unsigned
                muldiv_operand_a = mul_signed_a;
				muldiv_operand_b = muldiv_b_i;
			end
			
			MULL,
			MULHU   //unsigned
			: begin 
				muldiv_operand_a = muldiv_a_i;
				muldiv_operand_b = muldiv_b_i;
			end
			
			default: begin //	MULH  //signed, use default settings
                muldiv_operand_a = mul_signed_a;
		        muldiv_operand_b = mul_signed_b;
            end
        endcase
	end
	
	assign product_next = (round_record == '0) ? product_start_mul : product_next_mul;

	always_ff @(posedge clk) begin : multiply
		if(mulit_en_i) begin
			product      <= product_next;
			round_record <= round_record_next;
		end	else begin
			product      <= '0;
			round_record <= '0;
		end
	end
	
	logic        result_negate;
	logic [63:0] neg_result;
	assign result_negate    = a_negate ^ b_negate;
	assign neg_result       = ~product_next + 1;
	always_comb begin : muldiv_output
		case(funct3_32)
			
			MULL:    muldiv_result_o = product_next[31:0];
			MULH:    muldiv_result_o = result_negate ? neg_result[63:32] : product_next[63:32];
			MULHSU:  muldiv_result_o = a_negate  ? neg_result[63:32] : product_next[63:32];
			
			default: muldiv_result_o = product_next[63:32];//MULHU
		endcase
	end
	
endmodule