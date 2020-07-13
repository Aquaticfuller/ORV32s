

module data_cache
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
		output logic                    read_valid_o,  // read hit		
		output logic                    write_ready_o, // write hit
		output logic                    readMiss_o,    // read miss
		output logic                    writeMiss_o,   // write miss
		
		//////////////////////////////////////////////
		input  logic [31:0]             data_mem_i [0:4096-1]
		);
	localparam logic [1:0] Invalid  = 2'b00;
	localparam logic [1:0] Shared   = 2'b01;
	localparam logic [1:0] Modified = 2'b11;

	//control signal
	assign read_valid_o  = MemR_en_i & readHit;
	assign write_ready_o = MemW_en_i & writeHit;
	
	//ram
	//logic [31:0] Mem [0:(1<<AddressSize)-1];
	logic [255:0]        cacheLine [0:1024-1];
	logic [16:0]         cacheLineTag[0:1024-1];  // Tag 17bits, Index 10 bits, Offset 5 bits
	logic [1:0]          cacheLineValid[0:1024-1]; // Valid bits, 00:Invalid, 01:Shared. 11:Modified
	
	logic [16:0]         reqTag;
	logic [9:0]          reqIndex;
	logic [4:0]          reqOffset;
	assign reqTag    = data_addr_i[31:15];
	assign reqIndex  = data_addr_i[14:5];
	assign reqOffset = data_addr_i[4:0];
	
	logic TagHit;
	logic readHit;
	logic writeHit;
	logic [16:0]         localTag;
	logic cacheModified;
	logic cacheInvalid;
	logic cacheShared;
	assign localTag      = cacheLineTag[reqIndex];
	assign TagHit        = reqTag == localTag;
	assign readHit       = TagHit &&  cacheLineValid[reqIndex][0]; // read hit when S/M
	assign cacheModified = cacheLineValid[reqIndex] == Modified;
	assign cacheInvalid  = cacheLineValid[reqIndex] == Invalid;
	assign cacheShared   = cacheLineValid[reqIndex] == Shared;
	assign writeHit      = TagHit && cacheModified; // write hit when M
	
	assign readMiss_o    = MemR_en_i & ~readHit;
	assign writeMiss_o   = MemW_en_i & ~writeHit;

	logic[7:0]  reqAddrInLine; // present 0-255bit in line
	assign reqAddrInLine = { reqOffset[4:2], 5'b0 };
	
	//read
	assign load_data_o   = MemR_en_i /*& readHit*/ ? cacheLine[reqIndex][reqAddrInLine +: 32] : {WordSize{1'bz}};
	//write
	logic [3:0] write_en;
	assign      write_en = {4{MemW_en_i & writeHit}} & byte_enable_i ;

	
	always_ff @( posedge clk ) begin
		if (write_en[0])
			cacheLine[reqIndex][ reqAddrInLine     +: 8]   <= store_data_i[7:0];
		if (write_en[1])
			cacheLine[reqIndex][(reqAddrInLine+8)  +: 8]   <= store_data_i[15:8];
		if (write_en[2])
			cacheLine[reqIndex][(reqAddrInLine+16) +: 8]   <= store_data_i[23:16];
		if (write_en[3])
			cacheLine[reqIndex][(reqAddrInLine+24) +: 8]   <= store_data_i[31:24];
		
		/************local request state transition************/
		if (readMiss_o)  // I->S
			cacheLineValid[reqIndex] <= Shared;
		if (writeMiss_o) // I->M, S->M
			cacheLineValid[reqIndex] <= Modified;
		
	/*	if(rst == RstEnable)
			Mem <= data_mem_i;*/
	end

	/*always @(WE or OE)
  if (!WE && !OE)
    $display("Operational error in RamChip: OE and WE both active");*/

	//logic [31:0] the_cacheLine;
	//assign the_cacheLine = cacheLine[130][31:0];
endmodule