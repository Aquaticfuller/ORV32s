module inst_rom 
		#(
		parameter DEPTH     = 32, 
		parameter LINEWIDTH = 64, 
		parameter LINEHIGHT = 65536 + 4096,//2048,
		parameter WIDTH     = 32,
		parameter BlockNumLog2  = $clog2(LINEHIGHT)
		) 
		(
		input  logic                   clk,
		input  logic                   rst,
		input  logic [31:0]            rst_addr_i,
		input  logic                   flush,
		input  logic                   ld_line_i,
		input  logic                   read_finish_i,
		input  logic                   inst_req_i,
		input  logic [31:0]            inst_addr_flush_i,	// alu
		//input  logic [31:0]            instmem_addr,	// pc+8
		
		output logic [LINEWIDTH-1:0]   line_out,    //instruction in
		output logic                   line_ready, //memory system is ready for next fetch
		output logic                   line_valid, //instruction input to buffer enable
		//output logic                   busy        // mem is busy reading
		//////////////////////////////////////
		input  logic [LINEWIDTH-1:0]   inst_mem_i [0:LINEHIGHT-1]
		);
	
	
	initial begin
		//$readmemh("../inst_rom.data", inst_mem);
		line_ready     = ENABLE;
		instmem_addr = '0;
		
	end
	
	
	
	logic [LINEWIDTH-1:0]  inst_mem [0:LINEHIGHT-1];
	assign inst_mem = inst_mem_i;
	logic [31:0]           instmem_addr;	// pc+8
	

	
	

	
	always_ff @(posedge clk) begin
		if(rst == RstEnable)
			instmem_addr <= rst_addr_i;
		else if(flush)    // inst_buff sent a request for new inst line
			instmem_addr <= inst_addr_flush_i;
		else if(line_ready & line_valid)
			instmem_addr <= instmem_addr + 8;
	end
	
	

	
	
	
	//stage 3, output

	logic                line_zero; // line is zero
	logic                line_notzero; // line is not zero
	logic                line_out_en;  // line is read and valid
	logic                line_out_zero;//line out to be zero
	logic[31:0]          inst_mem_addr;
	logic[LINEWIDTH-1:0] inst_mem_line;

	assign inst_mem_addr = {3'b0, instmem_addr[31:3]};
	
	assign inst_mem_line =  inst_mem[inst_mem_addr];
	assign line_zero     =  ( inst_mem_line == {LINEWIDTH{1'b0}} );
	assign line_notzero  = ~line_zero;
	assign line_out_en   = ~flush;// &  line_notzero;
	assign line_out_zero = ~flush & ~line_notzero;
	
	assign line_out      = line_valid ? inst_mem[inst_mem_addr] : {LINEWIDTH{1'bz}};
	assign line_ready    = line_notzero;
	assign line_valid    = flush ? DISABLE : (line_out_en & ld_line_i & line_notzero);
	
	
	
	
endmodule
	
