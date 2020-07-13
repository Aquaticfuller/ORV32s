import libalu::*;
module branch_compare
		(
		input  logic     [31:0] rs1,
		input  logic     [31:0] rs2,
		output logic     [1:0]  rs1_rs2_eqz_u,//unsigned, 0:r1-r2>0, 1:r1-r2<0 ,2:r1-r2==0, 3:error
		output logic     [1:0]  rs1_rs2_eqz   //signed,   0:r1-r2>0, 1:r1-r2<0 ,2:r1-r2==0, 3:error
		);
	logic         diff_sign; //0:same sidn, 1:different sign
	logic         rs1_rs2_abs_gt;
	logic         rs1_rs2_abs_lt;
	logic         rs1_rs2_abs_eq;
	
	assign   diff_sign      = rs1[31]^rs2[31];
	assign   rs1_rs2_abs_gt = rs1[30:0] >  rs2[30:0];
	assign   rs1_rs2_abs_eq = rs1[30:0] == rs2[30:0];
	assign   rs1_rs2_abs_lt = ~rs1_rs2_abs_gt & ~rs1_rs2_abs_eq;
/*	
	logic    rs1_zero_en;
	logic    rs2_zero_en;
	logic    rs1_rs2_zero_en;
	assign   rs1_zero_en     = rs1[30:0] == 0;
	assign   rs2_zero_en     = rs2[30:0] == 0;
	assign   rs1_rs2_zero_en = rs1_zero_en & rs2_zero_en;
	
	logic    rs1_rs2_eqz_signed_same_sign;
	assign   rs1_rs2_eqz_signed_same_sign = rs1_rs2_zero_en ? BRAN_EQ 
		                                                    : {1'b0,rs1[31]};
*/	
	always_comb begin : sign_comp
		//if(sign) begin
		if(diff_sign) begin	             //different sign
			rs1_rs2_eqz = {1'b0,rs1[31]}; //rs1_rs2_eqz_signed_same_sign;      //0:r1-r2>0, 1:r1-r2<0
		end else begin                   //same sign
			if(rs1_rs2_abs_eq) begin           //rs-rs2 == 0
				rs1_rs2_eqz = BRAN_EQ;
			end else if(rs1_rs2_abs_gt) begin //rs1-rs2 > 0
				rs1_rs2_eqz = BRAN_GT;
			end else begin                     //rs1-rs2 < 0
				rs1_rs2_eqz = BRAN_LT;
			end
		end
		//end
	end
	//unsigned compare
	always_comb begin : unsign_comp
		//if(!sign) begin
		if(diff_sign) begin	             //different sign
			rs1_rs2_eqz_u = {1'b0,rs2[31]};      //0:r1-r2>0, 1:r1-r2<0
		end else begin                   //same msb
			if(rs1_rs2_abs_eq) begin           //rs-rs2 == 0
				rs1_rs2_eqz_u = BRAN_EQ;
			end else if(rs1_rs2_abs_gt) begin  //rs1-rs2 > 0
				rs1_rs2_eqz_u = BRAN_GT;
			end else begin                     //rs1-rs2 < 0
				rs1_rs2_eqz_u = BRAN_LT;
			end 
		end
		//end
	end
endmodule