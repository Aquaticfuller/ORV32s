
/**
 * Load Store Unit
 *
 * Load Store Unit, used to eliminate multiple access during processor stalls,
 * 
 */
 
module load_store_unit #(parameter DEPTH=16, parameter LINEWIDTH=32)
		(
		input  logic                   clk,
		input  logic                   rst,
		//EX stage interface
		input  logic                   MemR_i,   //mem read enable
		input  logic                   MemW_i,   //mem write enable
		input  logic [1:0]             load_length_i,   //L8,L16,L32
		input  logic                   load_signed_i,   //0: unsigned ext,1: sext
		input  logic [31:0]            dm_addr_i,	// data mem w/r address
		input  logic [31:0]            data_i,    // data to mem
		output logic [31:0]            result_o,  //data to regfile 
		
		// Control interface
		input   logic                  read_valid_i,  //together with load data
		input   logic                  write_ready_i, //ready to receive store data if set
		output  logic                  load_finish_o,
		output  logic                  store_finish_o,

		//input  logic                   miss_aligned_stall_i,
		
		// data mem interface
		input   logic [31:0]           line_in,    // data from mem
		output  logic [31:0]           data_o,    // data to mem
		//input   logic                  data_return_valid, //stay high for 1 cycle if get result
		//input   logic                  data_return_err,   //stay high if get error
		output  logic                  MemR_o,   // mem read enable
		output  logic                  MemW_o,   // mem write enable
		
		output  logic [31:0]           data_addr_o,	// r/w addr
		output  logic [3:0]            byte_enable_o
		//input logic                    line_ready, //memory system is ready
		

		);
	//to control simplified
	assign store_finish_o = write_ready_i;
	assign load_finish_o  = read_valid_i;
	/////////////
	assign MemR_o = MemR_i;
	assign MemW_o = MemW_i;
	
	assign data_addr_o        = { dm_addr_i[31:2], 2'b00 };
	
	logic [1:0]             store_length_i;   //L8,L16,L32
	assign store_length_i = load_length_i;
	//store
	always_comb begin: store_result
		unique case(store_length_i)
			L8: data_o = {4{data_i[7:0]}};// lb, L8
			L16: begin 
				case(dm_addr_i[1:0]) //lh, L16
					2'b00: data_o = { 16'b0, data_i[15:0]        };
					2'b01: data_o = { 8'b0,  data_i[15:0], 8'b0  };
					2'b10: data_o = {        data_i[15:0], 16'b0 };
					default:;//TODO misaligned, exception
				endcase
			end
			L32: begin 
				data_o =   data_i;//TODO misaligned, exception
			end
		endcase
	end


	//load
	always_comb begin: load_result
		unique case(load_length_i)
			L8: unique case(dm_addr_i[1:0]) // lb, L8
					2'b00: result_o = { {24{load_signed_i&line_in[7]} }, line_in[7:0]  };
					2'b01: result_o = { {24{load_signed_i&line_in[15]}}, line_in[15:8] };
					2'b10: result_o = { {24{load_signed_i&line_in[23]}}, line_in[23:16]};
					2'b11: result_o = { {24{load_signed_i&line_in[31]}}, line_in[31:24]};
				endcase
			L16: unique case(dm_addr_i[1:0]) //lh, L16
					2'b00: result_o = { {24{load_signed_i&line_in[15]}}, line_in[15:0] };
					2'b01: result_o = { {24{load_signed_i&line_in[23]}}, line_in[23:8] };
					2'b10: result_o = { {24{load_signed_i&line_in[31]}}, line_in[31:16]};
					2'b11: ;//TODO load half exception
				endcase
			L32: unique case(dm_addr_i[1:0]) //lw, L32
					2'b00: result_o =    line_in[31:0];
					2'b01,
					2'b10,
					2'b11: ; //TODO load word exception
				endcase
		endcase
	end
	
	
	//store
	logic [3:0]        byte_enable;
	assign byte_enable_o  = byte_enable;

	//store byte enable
	always_comb begin: store_byte_enable 
		unique case(load_length_i)// L8,L16,L32
			L8: unique case(dm_addr_i[1:0]) //sb, L8
					2'b00: byte_enable = 4'b0001;
					2'b01: byte_enable = 4'b0010;
					2'b10: byte_enable = 4'b0100;
					2'b11: byte_enable = 4'b1000;
				endcase
			L16:begin //sh, L16
				unique case(dm_addr_i[1:0]) 
					2'b00: byte_enable = 4'b0011;
					2'b01: byte_enable = 4'b0110;
					2'b10: byte_enable = 4'b1100;
					2'b11: ;//TODO load half exception
				endcase
			end
			L32:begin 
				unique case(dm_addr_i[1:0]) //sw, L32
					2'b00: byte_enable = 4'b1111;
					2'b01,
					2'b10,
					2'b11: ;//TODO load word exception
				endcase
			end
		endcase
	end

endmodule