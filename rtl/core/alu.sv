
/**
 * Arithmetic logic unit
 */
import libdefine::*;
import libalu::*;
module alu (
		input  logic              rst,	
		//operand
		input  logic              is_rvc_i,
		input  logic [31:0]       r1_i, //r1 or rd
		input  logic [31:0]       r2_i,
		input  logic [31:0]       pc_i,
		input  logic [31:0]       imm_i,
		//multi/div operand
		//input  logic              multdiv_en_i,
		input  logic [31:0]       multdiv_operand_a_i,
		input  logic [31:0]       multdiv_operand_b_i,
		//operand select
		input  logic [1:0]        ASel_i,
		input  logic [1:0]        BSel_i,
		//alu select
		input  logic [4:0]        aluSel_i,    //alu mode choose
		//output
		output logic [33:0]       adder_result_ext_o, //to multiplier
		output logic [31:0]       result_o,   //alu result
		//output logic              carry_o,
		//output logic [31:0]       adder_result_o,
		//output logic [31:0]       shift_result
		
		//alu->control
		output logic [1:0]        rs1_rs2_eqz_o
		);

	//alu_mux_a
	logic  [31:0]         operand_a_i;
	logic  [31:0]         operand_b_i;

	always_comb begin : alu_mux_a
		case (ASel_i)
			ASEL_RS1:  operand_a_i = r1_i; //rs1
			ASEL_PC :  operand_a_i = pc_i;  //pc_idex
			ASEL_IM0:  operand_a_i = 32'b0; //imm '0
			ASEL_MULA: operand_a_i = multdiv_operand_a_i;
		default:;
		endcase
	end
	
	always_comb begin : alu_mux_b
		case (BSel_i)
			BSEL_RS2:  operand_b_i = r2_i; //rs2
			BSEL_IMM:  operand_b_i = imm_i; //imm
			BSEL_IM4:  operand_b_i = is_rvc_i ? 32'h2 : 32'h4; //imm '4
			BSEL_MULB: operand_b_i = multdiv_operand_b_i;
			default:;
		endcase
	end
	
	logic  [32:0]	operand_b_neg;
/*	logic  [31:0] 	operand_a_rev;
	// bit reverse operand_a for left shifts and bit counting
	for (genvar k = 0; k < 32; k++) begin : gen_rev_operand_a
		assign operand_a_rev[k] = operand_a_i[31-k];
	end*/
	
	/////////////////////
	//Adder(Subtractor)//
	/////////////////////
	logic  [31:0]         adder_result_o;
	logic                 adder_op_b_negate;
	logic  [32:0]         adder_in_a;
	logic  [32:0]         adder_in_b;

	logic  [31:0]         adder_result;
	
	
	always_comb begin: subtract
		adder_op_b_negate = 1'b0;
		unique case (aluSel_i)
			// Adder OPs
			ALU_SUB, //: adder_op_b_negate = 1'b1;

				// Comparator OPs
			ALU_CMP, ALU_CMPU,
			ALU_SLT, ALU_SLTU
				//			ALU_EQ,   ALU_NE,
				//			ALU_GE,   ALU_GEU,
				//			ALU_LT,   ALU_LTU,
				//			ALU_SLT,  ALU_SLTU
				: adder_op_b_negate = 1'b1;

			default:;
		endcase
	end
	//logic  multdiv_en;
	//assign multdiv_en = (ASel_i == ASEL_MULA);
	// prepare operand a
	assign adder_in_a   =  {operand_a_i,1'b1};

	// prepare operand b
	assign operand_b_neg       = {operand_b_i,1'b0} ^ {33{adder_op_b_negate}};
	assign adder_in_b          = operand_b_neg ;

	// actual adder
	assign adder_result_ext_o = $unsigned(adder_in_a) + $unsigned(adder_in_b);
	assign adder_result       = adder_result_ext_o[32:1];
	assign adder_result_o     = adder_result;
	//assign carry_o            = adder_result_ext_o[33];
	//assign result_o           = adder_result_o;
	
	
	///////////
	// Shift //
	///////////
	logic [31:0] shift_result_high;
	logic [31:0] shift_result_low;
	logic [31:0] shift_result;
	// flags
	logic          shift_left;
	logic          shift_arithmetic;
	
	assign  shift_left       = ( aluSel_i == ALU_SLL );
	assign  shift_arithmetic = ( aluSel_i == ALU_SRA );
	
	//operand_b, operand_a
	logic [4:0]    shift_amt;    //shift amount
	logic [4:0]    shift_amt_right;
	logic [4:0]    shift_amt_left;
	logic          shift_amt_zero;
	logic [31:0]   shift_op_a;   //shift operand_a
	
	assign  shift_amt_right  = operand_b_i[4:0];
	assign  shift_amt_left   = ~shift_amt_right + 1;// == 32 - shift_amt_right
	assign  shift_amt        = shift_left ? shift_amt_left : shift_amt_right;
	assign  shift_amt_zero   = ( shift_amt_left == '0);
	assign  shift_op_a       = operand_a_i;
	
	// do shift right arithmetic to cover all situations
	logic        [64:0] shift_op_a_64; //origin lies in upper 32, shift right result in upper32, shift left result in lower32
	logic signed [64:0] shift_right_result_signed;
	logic        [64:0] shift_right_result_ext;
	
	assign shift_op_a_64             = { shift_arithmetic & shift_op_a[31] , shift_op_a , 32'b0 };
	assign shift_right_result_signed = $signed(shift_op_a_64) >>> shift_amt;
	assign shift_right_result_ext    = $unsigned(shift_right_result_signed);
	assign shift_result_high         = shift_right_result_ext[63:32];
	assign shift_result_low          = shift_right_result_ext[31:0];
	
	// do the shift left by reverse the shift right result
/*	for (genvar j = 0; j<32; j++) begin
		assign shift_left_result[j] = shift_right_result[31-j];
	end
	*/
	assign shift_result = shift_left & ~shift_amt_zero ? shift_result_low : shift_result_high;
	
	
	////////////////
	// Comparison //
	////////////////
	logic  [1:0]  rs1_rs2_eqz;
	logic         diff_sign; //0:same sidn, 1:different sign
	logic  [31:0] minus_result;
	logic         sign;
	logic         equal;
	
	assign   diff_sign    = operand_a_i[31]^operand_b_i[31];
	assign   minus_result = adder_result;
	assign   sign         = (aluSel_i == ALU_CMP | aluSel_i == ALU_SLT) ? ENABLE : DISABLE;
	assign   equal        = (minus_result == 32'b0);
	
	
	always_comb begin : sign_comp
		//if(sign) begin
		if(diff_sign) begin	             //different sign
			rs1_rs2_eqz = sign ? {1'b0,operand_a_i[31]} : {1'b0,operand_b_i[31]} ;  //0:r1-r2>0, 1:r1-r2<0
		end else begin                   //same sign
			rs1_rs2_eqz = {1'b0, minus_result[31]};
		end
		
		if(equal) rs1_rs2_eqz = BRAN_EQ;
		
	end
	//unsigned compare
	
	assign rs1_rs2_eqz_o = rs1_rs2_eqz;
	
	
	
	
	
	
	always_comb begin : alu_out_select
		unique casex (aluSel_i)
			//ALU_ADD, ALU_SUB, ALU_JAL
			5'b1???? : result_o    = adder_result_o;
			
			//ALU_SLL, ALU_SRL, ALU_SRA
			5'b01??? : result_o    = shift_result;
			
			/*ALU_CMP,
			ALU_CMPU
			: result_o    = {30'b0, rs1_rs2_eqz};*/

			ALU_XOR: result_o = operand_a_i ^ operand_b_i;
			ALU_OR : result_o = operand_a_i | operand_b_i;
			ALU_AND: result_o = operand_a_i & operand_b_i;
			
			//ALU_SLT, ALU_SLTU
			5'b0001?: result_o    = {31'b0, rs1_rs2_eqz[0]}; //if rs1<rs2,32'b1,else,32'b0
			
		endcase
	end	
	
endmodule
