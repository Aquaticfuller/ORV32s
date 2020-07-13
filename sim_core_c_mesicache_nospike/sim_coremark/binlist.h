#ifndef BINLIST_H
#define BINLIST_H

char  binsource[47][50]= {
	                            //rv32ui-p-
															"add",
															"addi",
															"and",
															"andi",
															"auipc",
															"beq",
															"bge",
															"bgeu",
															"blt",
															"bltu",
															"bne",
															"fence_i",
															"jal",
															"jalr",
															"lb",
															"lbu",
															"lh",
															"lhu",
															"lw",
															"lui",
															"or",
															"ori",
															"sb",
															"sh",
															"sw",
															"sll",
															"slli",
															"slt",
															"slti",
															"sltiu",
															"sltu",
															"sra",
															"srai",
															"srl",
															"srli",
															"sub",
															"xor",
															"xori",
															
															//rv32um-p-
															"mul",
                              "mulh",
                              "mulhsu",
                              "mulhu",
															"div",
                              "divu",
                              "rem",
                              "remu",
                              
                              //rv32uc-p-
                              "rvc"
		
	};
	
	#define IMAGESIZE   411652

	#include"obj_dir/rv32ui-p-add.h"
	#include"obj_dir/rv32ui-p-bge.h"      
	#include"obj_dir/rv32ui-p-jal.h"   
	#include"obj_dir/rv32ui-p-lui.h"  
	#include"obj_dir/rv32ui-p-sll.h"    
	#include"obj_dir/rv32ui-p-sra.h"   
	#include"obj_dir/rv32ui-p-xor.h"
  #include"obj_dir/rv32ui-p-addi.h"   
  #include"obj_dir/rv32ui-p-bgeu.h"     
  #include"obj_dir/rv32ui-p-jalr.h"  
  #include"obj_dir/rv32ui-p-lw.h"   
  #include"obj_dir/rv32ui-p-slli.h"   
  #include"obj_dir/rv32ui-p-srai.h"  
  #include"obj_dir/rv32ui-p-xori.h"
  #include"obj_dir/rv32ui-p-and.h" 
  #include"obj_dir/rv32ui-p-blt.h"      
  #include"obj_dir/rv32ui-p-lb.h"    
  #include"obj_dir/rv32ui-p-or.h"   
  #include"obj_dir/rv32ui-p-slt.h"    
  #include"obj_dir/rv32ui-p-srl.h"
  #include"obj_dir/rv32ui-p-andi.h"   
  #include"obj_dir/rv32ui-p-bltu.h"     
  #include"obj_dir/rv32ui-p-lbu.h"   
  #include"obj_dir/rv32ui-p-ori.h"  
  #include"obj_dir/rv32ui-p-slti.h"   
  #include"obj_dir/rv32ui-p-srli.h"
  #include"obj_dir/rv32ui-p-auipc.h"  
  #include"obj_dir/rv32ui-p-bne.h"      
  #include"obj_dir/rv32ui-p-lh.h"    
  #include"obj_dir/rv32ui-p-sb.h"   
  #include"obj_dir/rv32ui-p-sltiu.h"  
  #include"obj_dir/rv32ui-p-sub.h"
  #include"obj_dir/rv32ui-p-beq.h"    
  #include"obj_dir/rv32ui-p-fence_i.h"  
  #include"obj_dir/rv32ui-p-lhu.h"   
  #include"obj_dir/rv32ui-p-sh.h"   
  #include"obj_dir/rv32ui-p-sltu.h"   
  #include"obj_dir/rv32ui-p-sw.h"
  
	#include"obj_dir/rv32um-p-div.h"
  #include"obj_dir/rv32um-p-divu.h"
  #include"obj_dir/rv32um-p-mul.h"
  #include"obj_dir/rv32um-p-mulh.h"
  #include"obj_dir/rv32um-p-mulhsu.h"
  #include"obj_dir/rv32um-p-mulhu.h"
  #include"obj_dir/rv32um-p-rem.h"
  #include"obj_dir/rv32um-p-remu.h"

  #include"obj_dir/rv32uc-p-rvc.h"
	
#endif