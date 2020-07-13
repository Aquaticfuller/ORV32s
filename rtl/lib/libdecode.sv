/*
Copyright (c) 2019, RiVAI Techologies(Shenzhen) Co., Ltd.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

 * Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

 * Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

File:        decode.sv
Author:      Zhangxi Tan
Description: Decode modules, regaddr, imm 
 */
 
//import libopcode::*;
//import liborv32s::*;

package libdecode;
    import libcsr::*;
	import libopcode::*;
	import liborv32s::*;
	
	function logic [1:0] decode_regaddr_16(input logic [15:0] inst, output regaddr_t rs1_addr, rs2_addr, rd_addr);
	logic [1:0] illegal;
	regaddr_t   rs1;
	regaddr_t   rs2;
	regaddr_t   rd;
 
	illegal = 2'b00;
	case (inst[1:0])
		2'b00:   begin                           //quadrant 0                          
			rd.addr = {2'b01,inst[4:2]};
			rs1.addr = {2'b01, inst[9:7]};
			rs2.addr = {2'b01, inst[4:2]};
                                

			rd.valid = ~inst[15];
			rs1.valid = '0;
			rs2.valid = '0; 
			rd.is_float = '0; rs2.is_float = '0; rs1.is_float ='0;                              
 
			case(inst [15:13]) 
				3'b000: begin
					//C.ADDI4SPN                                                                                                                          
					rs1.addr = 2;             //implicit x2
					rd.valid = '1;
					rs1.valid = '1; 
                                           
					if (inst[12:0]  == 0) begin
						illegal = 2'b10;
						rd.valid = '0;
					end                                                                                  
				end
				3'b001: begin
					//C.FLD                                        
					rd.valid = '1; rs1.valid = '1;
					rd.is_float = '1; 
				end
				3'b010: begin
					//C.LW
					rs1.valid = '1; rd.valid ='1;
				end
				3'b011: begin
					//C.LD (RV64C) / C.FLW (RV32C)
					rs1.valid = '1; rd.valid ='1;
					//C.FLW (32-bit only)
					rd.is_float = '1;
				end
				3'b100: begin //reserved
					illegal = 2'b01;
				end
				3'b101: begin
					//C.FSD
					rs1.valid = '1; rs2.valid = '1;
					rs2.is_float = '1;                                        
				end
				3'b110: begin
					//C.SW
					rs1.valid = '1; rs2.valid = '1;
				end
				3'b111: begin
					//C.SD (RV64C) / C.FSW (RV32C)
					rs1.valid = '1; rs2.valid ='1;
					//C.FSW  (32-bit only)
					rs2.is_float = '1;
				end
			endcase
                                
		end
		2'b01:   begin                          //quadrant 1
			rd.addr  = inst[11:7];
			rs1.addr = inst[11:7];
			rs2.addr = {2'b01, inst[4:2]};

			rd.valid = ~inst[15];
			rs1.valid = '0; rs2.valid = '0;
			rd.is_float  = '0; rs2.is_float = '0; rs1.is_float = '0;

			case (inst[15:13])
				3'b000: begin
					//C.ADDI
					rs1.valid = '1;
				end
				3'b001: begin
					//C.ADDIW (RV64C)
					//signed extend 
					//rs1.valid = '1;
					//C.JAL (RV32C)
					rd.valid = '1;
					rd.addr  = 1;   //implicit x1
				end
				3'b010: begin
					//C.LI
					//default settings
					//changed by fu
					rs1.valid = '1;
					rs1.addr = 0;
				end
				3'b011: begin
					//C.ADDI16SP, ADDI x2, x2, imm
					//default settings                                        
					if (inst[11:7] == 2)
						rs1.valid = '1;                     
					//else C.LUI, LUI rd, imm, default settings             
				end
				3'b100: begin   //compressed simple ALU operations
					//i-imm with default
					rs1.addr[4:3] = 2'b01;
					rd.addr[4:3] = 2'b01; 
                                        
					case (inst[11:10])
						2'b00: begin //C.SRLI64 (RV64C) / C.SRLI (RV32C)
							rs1.valid = '1; rd.valid = '1;                                
						end                                                
						2'b01: begin //C.SRAI
							rs1.valid = '1; rd.valid = '1;
						end
						2'b10: begin //C.ANDI
							rs1.valid = '1; rd.valid = '1;
						end
						2'b11: begin   //R-format ALU operations
							illegal[0] = &inst[12:10] /*& inst[6]*/; //inst[6] is for RV64C
							rs1.valid = ~illegal[0]; rs2.valid = ~illegal[0];            
							rd.valid  = ~illegal[0];
						end                                     
					endcase

				end
				3'b101: begin   
					//C.J (unconditional)                               
				end
				3'b110: begin
					//C.BEQZ rs1', offset
					rs1.addr[4:3] = 2'b01;
					rs1.valid = '1; 
					rs2.addr      = 5'b0;  //x0
					rs2.valid = '1; 
				end
				3'b111: begin
					//C.BNEZ rs1', offset
					rs1.addr[4:3] = 2'b01;
					rs1.valid = '1;
					rs2.addr      = 5'b0;  //x0
					rs2.valid = '1; 
				end                                
			endcase

		end
		default: //quadrant 2
		begin
			rs1.addr = inst[11:7]; rd.addr = inst[11:7]; rs2.addr = inst[6:2];
			rs1.valid ='0; rd.valid = ~inst[15]; rs2.valid = '0;
			rs1.is_float = '0; rs2.is_float = '0; rd.is_float = '0;
                        
			case (inst[15:13])
				3'b000: begin
					//C.SLLI64 (RV64C) / C.SLLI (RV32C)
					rs1.valid = '1;                                
				end
				3'b001: begin 
					//C.FLDSP rd, uimm(x2)
					rd.is_float = '1; rs1.valid ='1;                                  
					rs1.addr = 2;         //stack register  //implicit x2
					//no need: rd.valid = '1;
				end
				3'b010: begin
					//C.LWSP rd, uimm(x2)
					rd.valid = '1;  rs1.valid = '1;
					rs1.addr =  2;
				end
				3'b011: begin
					//C.LDSP (RV64C) / C.FLWSP (RV32C) rd, uimm(x2)
					// no need: rd.valid = '1;
					rs1.valid = '1; rs1.addr = 2; 	//implicit  x2
					//C.FLWSP (RV32C) only
					rd.is_float = '1;
				end
				3'b100: begin
					logic rs1_zero, rs2_zero;
					rs1_zero = (inst[11:7] == 0); 
					rs2_zero = (inst[6:2]  == 0);                              
					if (!inst[12]) begin
						if (rs2_zero) 
							//C.JR rs1
							rs1.valid = '1;
						else begin
							//C.MV rd, rs2
							rs2.valid = '1; rd.valid = '1;
							rs1.valid = '1;
							rs1.addr = 0;
						end
					end
					else begin
						if (!rs1_zero & rs2_zero) begin //C.JALR rs1 //jalr x1, 0(rs1)
							rs1.valid = '1;
							rd.valid  = '1;  rd.addr = 1; //implicit x1
						end
						if (!rs1_zero & !rs2_zero) begin//C.ADD //add rd, rd, rs2
							rs2.valid = '1; rs1.valid = '1; rd.valid = '1;
						end
					end
				end
				3'b101: begin
					//C.FSDSP rs2, uimm(x2)
					rs2.valid = '1; rs2.is_float = '1;
					rs1.valid = '1; rs1.addr = 2;  //implicit x2
				end
				default: begin
					//C.SDSP, C.SWSP rs2, uimm(x2)
					rs2.valid = '1; 
					rs1.valid = '1; rs1.addr = 2; //implicit x2
				end
			endcase                       
		end
	endcase         


	rs1_addr = rs1; rs2_addr = rs2; rd_addr = rd;
                
	return illegal;
	endfunction


	//decode regular instruction register address
    function logic [1:0] decode_regaddr_32(input logic [31:0] inst, [1:0] priv_lvl_i, output regaddr_t rs1_addr, rs2_addr, rd_addr); 
	regaddr_t rs1, rs2, rd;
	logic [1:0] illegal;
	illegal = 2'b00;
    // TODO output different exception illegal code
	rs1.valid = '0;rs2.valid = '0; rd.valid = '0;
	rs1.is_float = '0; rs2.is_float ='0; rd.is_float = '0;
	rs1.addr = inst[19:15]; rs2.addr = inst[24:20]; rd.addr = inst[11:7];  

	unique case (inst[6:2])
		LUI, AUIPC, JAL: rd.valid = '1;
		JALR:   begin rd.valid = '1; rs1.valid ='1; end
		BRANCH: begin
			case (inst[14:12]) 
				3'b000, 3'b001,3'b100, 3'b101, 3'b110, 3'b111: begin rs1.valid = '1; rs2.valid = '1; end
				default: illegal = 2'b01;
			endcase
		end
		LOAD:   begin
			if (inst[14:12] != 3'b111 && inst[14:12] != 3'b011 && inst[14:12] != 3'b110) begin 
				rd.valid = '1; rs1.valid = '1;                          
			end
			else 
				illegal = 2'b01;
		end
		STORE:  begin
			if (inst[14:12] == 3'b000 || inst[14:12] == 3'b001 || inst[14:12] == 3'b010) begin
				rs1.valid = '1; rs2.valid = '1; 
			end
			else
				illegal = 2'b01;
		end
		OP_IMM: begin
            if (inst[14:12] == SLLI && inst[31:25] != '0) begin
                illegal = 2'b01;
            end
            else if (inst[14:12] == SRLI_SRAI && {inst[31], inst[29:25]} != '0) begin
                illegal = 2'b01;
            end
            else begin
                rd.valid = '1; rs1.valid = '1; 
            end
        end
		OP:     begin rd.valid = '1; rs1.valid = '1; rs2.valid = '1; end
		FENCE: begin 
			if (inst[14:12] == 3'b0 || inst[14:12] == 3'b1) begin
				rd.valid = '1; rs1.valid = '1; 
			end
			else
				illegal = 2'b01;
		end
	/*	SYSTEM: begin
			//TODO move part of illegal instruction dection (illegal imm) to the imm decoder
			if ((inst[19:7] != 0) || (inst[31:21] !=0))
				illegal = '1;
		end*/
		CSR: begin // TODO: COMBINE ECALL EBREAK MRET
			if (inst[13:12] == 0  && inst != 32'h30200073 && inst != 32'h00000073 && inst != 32'h00100073) begin // let mret, ecall, ebreak legal
				illegal = 2'b01;
			end
            else if(inst[13:12] == CSR_OP_WRITE && (inst[31:20] == CSR_CYCLE || inst[31:20] == CSR_MCYCLE || inst[31:20] == CSR_MCYCLEH)) begin
                illegal = 2'b01;
            end
            else if(priv_lvl_i == PRIV_LVL_U && inst[31:20] == CSR_MSTATUS) begin
                illegal = 2'b01;
            end
			else begin             
				rd.valid = '1;          
				if (~inst[14]) 
					rs1.valid = '1; 
			end 
		end
		//MULDIV32: begin rd.valid ='1; rs1.valid = '1; rs2.valid = '1; end // same as OP
		AMO : begin
			if (inst[14:12] == 3'b010) begin
				rd.valid ='1; rs1.valid ='1;

				rs2.valid = 1;
			end
			else
				illegal = 2'b01;
		end

        SYSTEM: begin
            // TODO 
        end
        /*BUBBLE: begin
            illegal = 2'b10;
        end*/
		default: ;//illegal = 2'b01;                          
	endcase
    /*
    if (inst[1:0] == 2'b00) begin
        illegal = 2'b10;
    end
    */
	rs1_addr = rs1; rs2_addr = rs2; rd_addr = rd;
	return illegal;
	endfunction
 

	//decode imm for RVC
		function logic decode_imm_16(input logic [15:0] inst, output logic [17:0] imm, output logic sign_ext);
	logic illegal;
	logic [17:0]    imm_c; 
	logic           sign, imm_zero;      

	illegal = '0;               
	imm_c = '0;
	imm_zero =~|{inst[12],inst[6:2]};        //imm_field zero

	case(inst[1:0])
		2'b00: begin     //quadrant 0
			sign = '0;
			imm_c[2]   = inst[6];
			imm_c[5:3] = inst[12:10];
			case (inst[15:13])     //funct3
				3'b000: begin //C.ADDI4SPN
					imm_c[3]   = inst[5];
					imm_c[9:6] = inst[10:7];
				end
				3'b010, 3'b011, 3'b110, 3'b111: begin//C.LW, C.FLW, C.SW, C.FSW
					imm_c[6]   = inst[5];
				end
				default: begin          //C.FLD, C.FSD
					imm_c[2]   = '0;
					imm_c[7:6] = inst[6:5];
				end
			endcase
		end
		2'b01: begin     //quadrant 1
			sign = inst[12];                      
			imm_c[5:0] = {inst[12],inst[6:2]};
			case (inst[15:13])   //funct3
				3'b001, 3'b101: //C.JAL, C.J
				begin
					imm_c[17:12] = signed'(sign);
					imm_c[0] = 1'b0;  
					imm_c[11:4] = {inst[12],inst[8], inst[10:9], inst[6], inst[7], inst[2], inst[11]};                                 
				end
				3'b011: begin 
					illegal = imm_zero;     //reserved, nzimm
					if (inst[11:7] == 2) begin
						//C.ADDI16SP
						imm_c[3:0] = '0;
						imm_c[9:5] = {inst[12], inst[4:3],inst[5], inst[2]};
						imm_c[17:10] = signed'(sign);
					end
					else begin
						//C.LUI
						imm_c[5:0] = '0;
						imm_c[17:12] = {inst[12], inst[6:2]};
					end    
				end
				3'b100: begin   //C.SRLI, C.SRLA
					if(inst[11:10] != 2'b10)
						illegal = sign;   //shamt[5] must be 0 for RV32
					else
						imm_c[17:6] = signed'(sign); //C.ANDI
				end                       
				3'b110, 3'b111: begin //C.BEQZ, C.BNEZ
					imm_c[0] = '0;
					imm_c[8:3] = {inst[12],inst[6:5],inst[2],inst[11:10]};
					imm_c[17:9] = signed'(sign);
				end 

				default : //C.ADDI, C.LI
					imm_c[17:6] = signed'(sign); 
			endcase
		end
		default: //quadrant 2 (Note: FP instruction imm decode is not supported)
		begin
			sign = '0;
			imm_c[5:0] = {inst[12], inst[6:2]};
			case(inst[15:13])
				3'b000: //C.SLLI 
					illegal = inst[12];  //shamt[5] must be 0 for RV32
				3'b001: begin //C.FLDSP
					imm_c[2:0] = '0;
					imm_c[8:6] = inst[4:2];
				end
				3'b010,3'b011: begin // C.LWSP
					imm_c[1:0] = '0;
					imm_c[7:6] = inst[3:2];
				end
				3'b100: begin  //C.JR, C.JALR
					imm_c[5:0] = '0;
				end
				3'b101: begin  //C.FSDSP
					imm_c[2:0] = '0;
					imm_c[4:3] = inst[11:10];
					imm_c[8:6] = inst[9:7];
				end
				default: begin //C.SWSP
					imm_c[1:0] = '0;
					imm_c[4:2] = inst[11:9];
					imm_c[7:6] = inst[8:7];
				end
			endcase
		end
	endcase 

	imm = imm_c;
	sign_ext = sign; 
	return illegal;
	endfunction

	//decode imm for RV32
	//B-type imm is for PC offset
		function logic [31:0] decode_imm_32(input logic [31:0] inst);
	logic [31:0] imm;
	imm = '0; 
	case(inst[6:2])
		LUI, 
		AUIPC:   imm[31:12]  = inst[31:12];                                          //U-type
		JAL:     imm[31:1]   = signed'({inst[31],inst[19:12],inst[20],inst[30:21]}); //J-type  
		JALR,
		LOAD:    imm[31:0]   = signed'({inst[31:20]});
		STORE:   imm[31:0]   = signed'({inst[31:25],inst[11:7]});                    //S-type
		BRANCH:  imm[31:1]	 = signed'({inst[31],inst[7],inst[30:25],inst[11:8]});   //B-type
		CSR:     imm[4:0]    = inst[19:15];
		default:;
	endcase

	if(inst[6:2] == OP_IMM) begin: shift_imm
		case(inst[14:12])
			SLLI,
			SRLI_SRAI: imm = unsigned'(inst[24:20]);
			default:   imm = signed'(inst[31:20]); //addi,slti,sltiu,xori,ori,andi //I-type except shift imm
		endcase
	end
	
	return imm;
	endfunction
endpackage
