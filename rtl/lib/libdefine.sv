

package libdefine;

	parameter logic        ENABLE            = 1'b1;
	parameter logic        DISABLE           = 1'b0;
	parameter logic        RstEnable         = 1'b0;
	parameter logic        RstDisable        = 1'b1;
	parameter logic        ChipEnable        = 1'b1;
	parameter logic        ChipDisable       = 1'b0;
	
	//pc select mux//flush
	parameter logic        PC4               = 1'b0;//PC+4
	parameter logic        PCALU             = 1'b1;//ALU
	
	//load length from data mem control
	parameter logic [1:0]  L8                = 2'b00;//load byte
	parameter logic [1:0]  L16               = 2'b01;//load half word
	parameter logic [1:0]  L32               = 2'b10;//load word

	//regfile select between alu_result and load_data
	parameter logic [2:0]  REG_PC4           = 3'b000;//PC+4/2 result, from stage 1
	parameter logic [2:0]  REG_LOAD          = 3'b001;//load data
	parameter logic [2:0]  REG_MULDIV        = 3'b010;//multiplier result
	parameter logic [2:0]  REG_CSR           = 3'b011;//csr read
	parameter logic [2:0]  REG_ALU           = 3'b100;//alu result

    //exception code
    parameter logic [1:0]  NO_EXCEP          = 2'b00;
    parameter logic [1:0]  INST_EXCEP        = 2'b01;
    parameter logic [1:0]  BUBBLE_EXCEP      = 2'b10;

	endpackage