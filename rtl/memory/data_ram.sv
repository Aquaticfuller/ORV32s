

module data_ram 
		#(
		parameter AddressSize  = 32, 
		parameter WordSize     = 32 
		) 
		(
		input  logic                    clk,
		input  logic                    rst,
		input  logic [AddressSize-1:0]  data_addr_i, 
		input  logic [WordSize-1:0]     store_data_i, 
		output logic [WordSize-1:0]     load_data_o,
		//input  logic                    CS, 
		input  logic                    MemR_en_i, 
		input  logic                    MemW_en_i,
		input  logic [3:0]              byte_enable_i,
		output logic                    read_valid_o,  //together with load data
		output logic                    write_ready_o,  //ready to receive store data if set
		//////////////////////////////////////////////
		input  logic [31:0]             data_mem_i [0:4096-1]
		);


	//control signal(simplified)
	assign read_valid_o  = ENABLE;
	assign write_ready_o = ENABLE;
	
    //ram
	//logic [31:0] Mem [0:(1<<AddressSize)-1];
	logic [31:0]         Mem [0:4096-1];
	logic [31:0]         data_addr;
	assign data_addr = { 2'b0, data_addr_i[31:2] };

	//read
	assign load_data_o = MemR_en_i ? Mem[data_addr] : {WordSize{1'bz}};
	//write
	logic [3:0] write_en;
	assign      write_en = {4{MemW_en_i}} & byte_enable_i;

	always_ff @( posedge clk ) begin
		if (write_en[0])
			Mem[data_addr][7:0]   <= store_data_i[7:0];
		if (write_en[1])
			Mem[data_addr][15:8]  <= store_data_i[15:8];
		if (write_en[2])
			Mem[data_addr][23:16] <= store_data_i[23:16];
		if (write_en[3])
			Mem[data_addr][31:24] <= store_data_i[31:24];


		if(rst == RstEnable)
			Mem <= data_mem_i;
	end

	/*always @(WE or OE)
  if (!WE && !OE)
    $display("Operational error in RamChip: OE and WE both active");*/

endmodule