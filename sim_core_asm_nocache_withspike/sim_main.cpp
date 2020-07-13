#include "Vtestbench.h"
#include "verilated.h"

#include "include/sim.h"
#include <stdio.h>
#include <stdlib.h>
#include <vector>
#include <string>
#include <memory>

#include<iostream>
#include "include/disasm.h"

#include <dlfcn.h>
#include "inst_rom.h"
#define PK_STEP_NUM 599  //588
#define PRO_STEP_NUM 7
#define SPIKE_DEBUG 1
#define DB_DEBUG 0
#define STEP 0
#define BREAK_INCO 1
// If "verilator --trace" is used, include the tracing class
#if VM_TRACE
# include <verilated_vcd_c.h>
#endif

// Current simulation time (64-bit unsigned)
vluint64_t main_time = 0;
// Called by $time in Verilog
double sc_time_stamp() {
    return main_time;  // Note does conversion to real, to match SystemC
}
int spikeaaa(int argc, char** argv, int step_num,
		std::vector<state_t> &reg_record, std::vector<insn_t> &inst_record);
//void processor_t::disasm(insn_t insn);
int main(int argc, char** argv, char** env)
{

	  char** command = new char*[4];
	  char str0[] = "./spike";
	  char str1[] = "--isa=RV32IMAFDC";
	  char str2[] = "-d";
	 // char str3[] = "pk";
	  char str4[] = "../mine.riscv";
	  //char str4[] = "../dhrystone.riscv";

	  command[0] = str0;
	  command[1] = str1;
	  command[2] = str2;
	 // command[3] = str3;
	  command[3] = str4;
	  int command_num = 4;


      int step_num;
#if DB_DEBUG
      step_num = 6;
#endif
#if SPIKE_DEBUG
      step_num = PK_STEP_NUM-1;
#endif

      std::vector<state_t> reg_record;
      std::vector<insn_t>  inst_record;
#if SPIKE_DEBUG
	  spikeaaa(command_num, command, 500, reg_record, inst_record);

	std::cout<<"spike finished!"<<std::endl;
#endif

	Verilated::commandArgs(argc, argv);
    Vtestbench* top = new Vtestbench;

	disassembler_t* disassembler = new disassembler_t(32);

	#if VM_TRACE
    // If verilator was invoked with --trace argument,
    // and if at run time passed the +trace argument, turn on tracing
    VerilatedVcdC* tfp = NULL;
    const char* flag = Verilated::commandArgsPlusMatch("trace");
    if (flag && 0==strcmp(flag, "+trace")) {
        Verilated::traceEverOn(true);  // Verilator must compute traced signals
        VL_PRINTF("Enabling waves into logs/vlt_dump.vcd...\n");
        tfp = new VerilatedVcdC;
        top->trace(tfp, 99);  // Trace 99 levels of hierarchy
        Verilated::mkdir("../logs");
        tfp->open("../logs/vlt_dump.vcd");  // Open the dump file
    }
#endif

    long pc_last   = 0;
    long inst_last = 0;
    long inst_last1 = 0;
    long inst_last2 = 0;

	#define CSRNUM 8
    char csrNames[CSRNUM][50]=
    {
		"misa",
        "mhartid",
        "mstatus",
        "mtvec",
        "mscratch",
        "mepc",
        "mcause",
        "mtval"
    };
    unsigned int csrValues[CSRNUM];

#if SPIKE_DEBUG
    int err = 0;
#endif
	  int processor_start = 0;

	  //inst rom loading from inst_rom.h file
	  int count;
	  for (count = 0; count<1024; count++)
		  top->inst_mem_i[count/*+0x10000000*/] = SPIflashimage[count];

	 // top->inst_mem_i[0] = 0x0000000082826285;//li t0,0x00001000//jr t0



  while (!Verilated::gotFinish())
  	 {
	  inst_last = inst_last1 | inst_last2;
	  main_time++;  // Time passes...
#if STEP
	  fprintf(stderr, "main_time: %d\n", main_time);
#endif
	  if (main_time<=3)
		  {
		     top->rst = 0;
		  }
	  else top->rst = 1;

	  top->clk = !top->clk;
  	  top->eval();
#if STEP
std::cout<<top->inst_ver<<std::endl;
  	  if(top->inst_ver == 0x47851141) processor_start = 1;
#endif

      //printf("%d %d %d %d %d\n", pc_last != top->pc_stage2_ver, top->inst_ver != 0, top->rst != 0, top->pc_stage2_ver>=0x54, inst_last != top->inst_ver);

  	  if( (pc_last != top->pc_stage2_ver) && top->inst_ver != 0 && top->rst != 0
#if STEP
  	     && processor_start
#endif
#if DB_DEBUG
  		 && top->pc_stage2_ver>=0x4
#endif
#if SPIKE_DEBUG
  		 && (top->pc_stage2_ver>= PRO_STEP_NUM ) && (inst_last != top->inst_ver) //&& top->pc_stage2_ver>=0x54)
#endif
		 )
  	  {
  		int r;
  		fprintf(stderr, "\n\n%-4s: 0x%08x\n", "pc", pc_last);//pc from processor


  		//processor

		fprintf(stderr, "processor: 0x%08" PRIx32 " (0x%08" PRIx32 ") %s\n",
  	             pc_last, inst_last, disassembler->disassemble(inst_last).c_str());


		for ( r = 0; r < NXPR; ++r)
		{
			fprintf(stderr, "%-4s: 0x%08" PRIx32 "  ", xpr_name[r], top->dff_ireg_ver[r]);
			if ((r + 1) % 4 == 0)
			{
			  fprintf(stderr, "\n");
			}
		}

		csrValues[0] = top->dff_csr_misa_ver;
        csrValues[1] = top->dff_csr_mhartid_ver;
        csrValues[2] = top->dff_csr_mstatus_ver;
        csrValues[3] = top->dff_csr_mtvec_ver;
        csrValues[4] = top->dff_csr_mscratch_ver;
        csrValues[5] = top->dff_csr_mepc_ver;
        csrValues[6] = top->dff_csr_mcause_ver;
        csrValues[7] = top->dff_csr_mtval_ver;

        for ( r = 0; r < CSRNUM; ++r)
        {
            fprintf(stderr, "%-4s: 0x%08" PRIx32 "  ", csrNames[r], csrValues[r]);
            if ((r + 1) % 4 == 0)
            {
              fprintf(stderr, "\n");
            }
        }
        printf("privilege level %d (0=user, 1=superviser, 2=hyperviser, 3=machine)\n", top->priv_lvl_ver);

#if SPIKE_DEBUG | DB_DEBUG
  		//spike simulator
		//disasm from spike

	  		uint64_t bits = inst_record[step_num-1].bits() & ((1ULL << (8 * insn_length(inst_record[step_num-1].bits()))) - 1);
			fprintf(stderr, "\nsimulator: 0x%08" PRIx32 " (0x%08" PRIx32 ") %s\n",
	  	             /* pc_last*/(reg_record.begin()+step_num-1)->pc, bits, disassembler->disassemble(inst_record[step_num-1]).c_str());

		//fprintf(stderr, "\nspike:\n");
  		for ( r = 0; r < NXPR; ++r)
  		{
  	      // regfile_t.h:   template <class T, size_t N, bool zero_reg> class regfile_t
  	        fprintf(stderr, "%-4s: 0x%08" PRIx32 "  ", xpr_name[r], (reg_record.begin()+step_num)->XPR[r] );
  	        if ((r + 1) % 4 == 0)
  	        {
               fprintf(stderr, "\n");
  	        }
	    }

  		for ( r = 0; r < NXPR; ++r)
  		{
  			// processor inconsistent against spike sim
  			if(unsigned(top->dff_ireg_ver[r]) != unsigned((reg_record.begin()+step_num)->XPR[r])
  					/*&& r != 2*/
#if SPIKE_DEBUG
				/*	&& r != 5 && r != 11 && r != 9 && r != 10 && r != 11 
					&& r != 14 && r!=15 && r != 19 && r != 20 && r != 23 && r != 25 && r != 26 */ //ignore gp temporarily
#endif
  				)
  			{
  			    //fprintf(stderr, "inconsistency found, reg:%-4s\nprocessor:0x%08" PRIx32 "\nspike    :0x%08" PRIx32 "\n",
  				fprintf(stderr, "inconsistency found, reg:%-4s\nprocessor:0x%08llx\nspike    :0x%08llx\n",
  			  	        xpr_name[r], unsigned(top->dff_ireg_ver[r]), unsigned((reg_record.begin()+step_num)->XPR[r]) );
  			    err = 1;
  			}
  		}

#endif
		pc_last = top->pc_stage2_ver;
  		inst_last1 = top->inst_ver;
  		step_num++;
		fprintf(stderr, "\n\n");
#if STEP
		getchar();
#endif

  	  }
  	inst_last2 = top->inst_ver;


#if VM_TRACE
        // Dump trace data for this cycle
        if (tfp) tfp->dump(main_time);
#endif
        if(main_time == 8192) break;

#if SPIKE_DEBUG
		if (err == 1)
	    {
#if BREAK_INCO
		  break
#endif
		  ;
		}
#endif
  	 }


	top->final();

    // Close trace if opened
#if VM_TRACE
    if (tfp) { tfp->close(); tfp = NULL; }
#endif

    //  Coverage analysis (since test passed)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    VerilatedCov::write("logs/coverage.dat");
#endif

    // Destroy model
    delete top; top = NULL;

  exit(0);
}
