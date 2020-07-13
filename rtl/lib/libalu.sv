
package libalu;

	// alu_input_mux
	//a
	parameter logic[1:0]   ASEL_RS1          = 2'b00;
	parameter logic[1:0]   ASEL_PC           = 2'b01;
	parameter logic[1:0]   ASEL_IM0          = 2'b10;// imm 0 //lui
	parameter logic[1:0]   ASEL_MULA         = 2'b11;// Multiplicand
	//b
	parameter logic[1:0]   BSEL_RS2          = 2'b00;
	parameter logic[1:0]   BSEL_IMM          = 2'b01;
	parameter logic[1:0]   BSEL_IM4          = 2'b10; // imm 4 //jal/jalr
	parameter logic[1:0]   BSEL_MULB         = 2'b11; // multiplier
	
	// alu_mode_sel
	parameter logic[4:0]   ALU_ADD           = 5'b10000;
	parameter logic[4:0]   ALU_SUB           = 5'b10001;
	parameter logic[4:0]   ALU_JAL           = 5'b10010;
	
	parameter logic[4:0]   ALU_SLL           = 5'b01000; //shift left logic
	parameter logic[4:0]   ALU_SRL           = 5'b01001; //shift right logic
	parameter logic[4:0]   ALU_SRA           = 5'b01010; //shift right arithmetic
	
	parameter logic[4:0]   ALU_XOR           = 5'b00100;
	parameter logic[4:0]   ALU_OR            = 5'b00101;
	parameter logic[4:0]   ALU_AND           = 5'b00110;
	
	parameter logic[4:0]   ALU_SLT           = 5'b00010; //set if less than
	parameter logic[4:0]   ALU_SLTU          = 5'b00011; //compare unsigned
	
	parameter logic[4:0]   ALU_CMP           = 5'b00000;
	parameter logic[4:0]   ALU_CMPU          = 5'b00001; //compare unsigned
	
	
	//branch compare
	//0:r1-r2>0, 1:r1-r2<0 ,2:r1-r2==0, 3:error
	parameter logic[1:0]   BRAN_GT           = 2'b00;
	parameter logic[1:0]   BRAN_LT           = 2'b01;
	parameter logic[1:0]   BRAN_EQ           = 2'b10;
	parameter logic[1:0]   BRAN_ERROR        = 2'b11;
endpackage