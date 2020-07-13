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

File:        libopcode.sv
Author:      Zhangxi Tan
Description: RISC-V 32-bit opcode definition, spec v2.2

*/

package libopcode;

//RV32I base instruction opcode 
parameter logic [4:0] LUI    = 5'b01101;
parameter logic [4:0] AUIPC  = 5'b00101;
parameter logic [4:0] JAL    = 5'b11011;
parameter logic [4:0] JALR   = 5'b11001;
parameter logic [4:0] BRANCH = 5'b11000;
parameter logic [4:0] LOAD   = 5'b00000;
parameter logic [4:0] STORE  = 5'b01000;
parameter logic [4:0] OP_IMM = 5'b00100;
parameter logic [4:0] OP     = 5'b01100; 
parameter logic [4:0] FENCE  = 5'b00011;
parameter logic [4:0] SYSTEM = 5'b11100;        //ECALL, EBREAK, MRET

//RV32/RV64 Zicsr 
parameter logic [4:0] CSR    = 5'b11100;

//RV32A/RV64A 
parameter logic [4:0] AMO    = 5'b01011;


//RV32 flush bubble
parameter logic [4:0] BUBBLE = 5'b00000;


//RV32I base instruction funct3_32
//B BRANCH
parameter logic [2:0] BEQ    = 3'b000;
parameter logic [2:0] BNE    = 3'b001;
parameter logic [2:0] BLT    = 3'b100;
parameter logic [2:0] BGE    = 3'b101;
parameter logic [2:0] BLTU   = 3'b110;
parameter logic [2:0] BGEU   = 3'b111;
//I load
parameter logic [2:0] LB     = 3'b000;
parameter logic [2:0] LH     = 3'b001;
parameter logic [2:0] LW     = 3'b010;
parameter logic [2:0] LBU    = 3'b100;
parameter logic [2:0] LHU    = 3'b101;
//S store
parameter logic [2:0] SB     = 3'b000;
parameter logic [2:0] SH     = 3'b001;
parameter logic [2:0] SW     = 3'b010;
// I OP_IMM
parameter logic [2:0] ADDI     = 3'b000;
parameter logic [2:0] SLTI     = 3'b010;
parameter logic [2:0] SLTIU    = 3'b011;
parameter logic [2:0] XORI     = 3'b100;
parameter logic [2:0] ORI      = 3'b110;
parameter logic [2:0] ANDI     = 3'b111;
parameter logic [2:0] SLLI     = 3'b001;
parameter logic [2:0] SRLI_SRAI= 3'b101;//

// R OP
parameter logic [2:0] ADD_SUB= 3'b000;//
parameter logic [2:0] SLL    = 3'b001;
parameter logic [2:0] SLT    = 3'b010;
parameter logic [2:0] SLTU   = 3'b011;
parameter logic [2:0] XOR    = 3'b100;
parameter logic [2:0] SRL_SRA= 3'b101;//
parameter logic [2:0] OR     = 3'b110;
parameter logic [2:0] AND    = 3'b111;

// SYS
parameter logic [2:0] ECALL = 3'b000;
parameter logic [2:0] CSRRW = 3'b001;
parameter logic [2:0] CSRRS = 3'b010;
parameter logic [2:0] CSRRC = 3'b011;
parameter logic [2:0] CSRRWI= 3'b101;
parameter logic [2:0] CSRRSI= 3'b110;
parameter logic [2:0] CSRRCI= 3'b111;

//RV32I base instruction funct7_32
//R OP  // I OP_IMM
parameter logic       ADD    = 1'b0;//INST[30]
parameter logic       SUB    = 1'b1;
parameter logic       SRL    = 1'b0;//srl/srli
parameter logic       SRA    = 1'b1;//sra/srai

//AMO funct5
parameter logic [4:0] LR     = 5'b00010;
parameter logic [4:0] SC     = 5'b00011;
parameter logic [4:0] AMOSWAP= 5'b00001;
parameter logic [4:0] AMOADD = 5'b00000;
parameter logic [4:0] AMOXOR = 5'b00100;
parameter logic [4:0] AMOAND = 5'b01100;
parameter logic [4:0] AMOOR  = 5'b01000;
parameter logic [4:0] AMOMIN = 5'b10000;
parameter logic [4:0] AMOMAX = 5'b10100;
parameter logic [4:0] AMOMINU= 5'b11000;
parameter logic [4:0] AMOMAXU= 5'b11100;

//RV32M 
parameter logic [4:0] MULDIV32 = 5'b01100;//equal to OP under RVI
//RV32M funct3_32
parameter logic [2:0] MULL     = 3'b000; //mul
parameter logic [2:0] MULH     = 3'b001; //mulh
parameter logic [2:0] MULHSU   = 3'b010; //mulsu
parameter logic [2:0] MULHU    = 3'b011; //mulhu
parameter logic [2:0] DIV      = 3'b100; //div
parameter logic [2:0] DIVU     = 3'b101; //divu
parameter logic [2:0] REM      = 3'b110; //rem
parameter logic [2:0] REMU     = 3'b111; //remu

//RV32FD/RV64FD bit[4] = 1 indicates FP operations
parameter logic [4:0] LOAD_FP  = 5'b00001;	//bit[0] = 1 FP , = 0 integer
parameter logic [4:0] STORE_FP = 5'b01001;
parameter logic [4:0] FMADD    = 5'b10000;
parameter logic [4:0] FMSUB    = 5'b10001;
parameter logic [4:0] FNMSUB   = 5'b10010;
parameter logic [4:0] FNMADD   = 5'b10011;
parameter logic [4:0] OP_FP    = 5'b10100;


endpackage

