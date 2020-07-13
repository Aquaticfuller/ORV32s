//#include "Vtestbench.h"
//#include "verilated.h"
//
//#include "../../sim/include/sim.h"
//#include <stdio.h>
//#include <stdlib.h>
//#include <vector>
//#include <string>
//#include <memory>
//
//#include<iostream>
//#include "../../sim/include/disasm.h"
//
//#include <dlfcn.h>
#include "func.h"

#include "svdpi.h"
#include <ctime>
//#include "inst_rom.h"
//#include "binlist.h"

#define PK_STEP_NUM 196
#define SPIKE_DEBUG 0
#define DB_DEBUG 0
#define STEP 0
#define BREAK_INCO 1
#define PRINT_REG 0
#define CORE_NUM_MAX 8  // 4, 8
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

u32 GetBinSize(char *filename);
int bin2cm(char source[], uint64_t *mem);
int judge_pass_fail(int core, long address, int mcycle, int minstret, int*prosFin);


//void processor_t::disasm(insn_t insn);
int main(int argc, char** argv, char** env)
{
    clock_t time_start=clock();
    int numP = 1;
    if (numP > CORE_NUM_MAX) numP = CORE_NUM_MAX;
    int loop_i;
    int prosFin_num = 0;
    int prosFin_en[CORE_NUM_MAX] = {0}; 
    int step_num;
    unsigned int program_loop_times = 8192;  // 64KB data set -> 4096 loop times
    
    //unsigned int max_time = CORE_NUM_MAX * 134 * program_loop_times / numP;  //47000000
    unsigned long int max_time = 1000000*5000*4*2; //20G ticks
#if DB_DEBUG
      step_num = 6;
#endif
#if SPIKE_DEBUG
      step_num = PK_STEP_NUM-1;
#endif

//load bin into memory
char source[CORE_NUM_MAX][200];
for(loop_i = 0; loop_i < numP; loop_i++)
{
    //strcpy(source[loop_i], "../test_programs/dhrystone.bin");
    strcpy(source[loop_i], "../../../riscv-coremark/coremark.bare.bin");
    //strcpy(source[loop_i], "../test_programs/matmul/load_2core.bin"); //false sharing/load_core4_nfs.bin"); //argv[1];
}
/*
strcpy(source[0], "../test_programs/matmul/load_8core.bin"); //false sharing/load_core4_nfs.bin"); //argv[1];
strcpy(source[1], "../test_programs/matmul/load_8core.bin"); //false sharing/load_4core_nfs.bin");
strcpy(source[2], "../test_programs/matmul/load_8core.bin"); //false sharing/load_4core_nfs.bin");
strcpy(source[3], "../test_programs/matmul/load_8core.bin"); //false sharing/load_4core_nfs.bin");
*/
//char* source1 = "../test_programs/load_2core.bin";//"../../isa_processor/rv32ui-p-lb.bin";
//char* source2 = "../test_programs/load_2core.bin";


int size[CORE_NUM_MAX];
for(loop_i=0;loop_i<numP;loop_i++)
{
    size[loop_i] = GetBinSize(source[loop_i]);
}
//int size0 = GetBinSize(source0);
//int size1 = GetBinSize(source1);
//uint64_t* mem0 =NULL;
//uint64_t* mem1 =NULL;
uint64_t* mem[CORE_NUM_MAX];
for(loop_i=0;loop_i<numP;loop_i++)
{
    mem[loop_i] = (uint64_t *)malloc(sizeof(uint64_t)*(size[loop_i]/sizeof(uint64_t)));
    memset(mem[loop_i], 0, sizeof(uint64_t)*(size[loop_i]/sizeof(uint64_t)));
    bin2cm(source[loop_i], mem[loop_i]);
}

//int round = 45;


    main_time = 0;
    Verilated::commandArgs(argc, argv);
    
    /*********hart init ********/
    //Vtestbench* top0 = new Vtestbench;
    Vtestbench** top = new Vtestbench*[CORE_NUM_MAX];

    for(loop_i=0;loop_i<numP;loop_i++)
    {
        top[loop_i] = new Vtestbench;
        top[loop_i]->mhartid_i = loop_i;
    }

    disassembler_t* disassembler = new disassembler_t(32);

    /** Create Coherence Controller Class Object Here with Constructor */
    int cache_size = 32768;  // 32byte*1024
    int cache_assoc= 1;      // direct map
    int blk_size   = 32;     // 32byte
    int num_processors = numP;  /*1, 2, 3, 4, 8*/

#if VM_TRACE
    // If verilator was invoked with --trace argument,
    // and if at run time passed the +trace argument, turn on tracing
    VerilatedVcdC** tfp = new VerilatedVcdC*[CORE_NUM_MAX];
    for(loop_i=0;loop_i<numP;loop_i++)
    {
        tfp[loop_i] = new VerilatedVcdC;
        top[loop_i]->trace(tfp[loop_i], 99);  // Trace 99 levels of hierarchy
    }
    //VerilatedVcdC* tfp = NULL;
    const char* flag = Verilated::commandArgsPlusMatch("trace");
    if (flag && 0==strcmp(flag, "+trace")) {
        Verilated::traceEverOn(true);  // Verilator must compute traced signals
#if PRINT_REG
        VL_PRINTF("Enabling waves into logs/vlt_dump.vcd...\n");
#endif
       // tfp = new VerilatedVcdC;
        //top[0]->trace(tfp, 99);  // Trace 99 levels of hierarchy
        Verilated::mkdir("../logs");
        for(loop_i=0;loop_i<numP;loop_i++)
        {
            char a[40];
            sprintf(a,"%s%d%s","../logs/vlt_dump", loop_i, ".vcd");

            tfp[loop_i]->open(a);  // Open the dump file
        }
    }
#endif


    unsigned long pc_last_core[CORE_NUM_MAX] = {0};
    unsigned long pc_last_core_2[CORE_NUM_MAX] = {0};
    long inst_last = 0;
    long inst_last1 = 0;
    long inst_last2 = 0;
    int count;
    int count2;
    /*********data back memory init********/
    unsigned int memory_size = pow(2,32-5);//pow(2,3+20-3-2);
    unsigned int** memory;
    memory = new unsigned int*[memory_size];
    for (count = 0; count < memory_size; count++)
    {
        memory[count] = new unsigned int[8];
        for(count2 = 0; count2 < 8; count2++)
        {
            memory[count][count2] = 0;
        }
    }

    int number = 0;
    //unsigned int memory[262144‬][8] = {0};  //back memory, 8MB pow(2,3+20-3-2)==262,144‬
/*  unsigned int memory_start_addr_load  = 0x100000/(8*sizeof(unsigned int));
    unsigned int memory_start_addr_store = 0x300000/(8*sizeof(unsigned int));
   for (count = memory_start_addr_load; count < memory_start_addr_store; count++)
    {
        for(count2 = 0; count2 < 8; count2++)
        {
            memory[count][count2] = number; //8;//count*8 + count2;
            ++number;
        }
    }
    */

    unsigned int memory_start_addr_load  = 0;
    unsigned int memory_start_addr_store = size[0] / 4;
    for (count = memory_start_addr_load; count < memory_start_addr_store; count++)
    {
        for(count2 = 0; count2 < 8; count2++)
        {
            memory[count][count2] = (mem[0][count*4+count2/2] >> (32*(count2%2)))%0x100000000;
   //         printf("memory[%d][%d]=0x%x\n", count, count2, memory[count][count2]);
   //         printf("mem   [0][%d] =0x%lx\n", count*4+count2/28, mem[0][count*4+count2/2]);
        }
    }


      int processor_start = 0;
      //inst rom loading from inst_rom.h file
      /**************trace cache*****************/
      unsigned int dcache[CORE_NUM_MAX][1024][8] = {0};  //data cache, up to 4 cores, each cache 1024 lines, each line 32 bytes
      unsigned int dcache_state[CORE_NUM_MAX][1024] = {0}; //d cache state, 1 per cache line, 3 states: 0I, 1S, 3M
      
      unsigned int readReqCount[CORE_NUM_MAX] = {0};
      unsigned int readReqMissCount[CORE_NUM_MAX] = {0};
      unsigned int writeReqCount[CORE_NUM_MAX] = {0};
      unsigned int writeReqMissCount[CORE_NUM_MAX] = {0};
      unsigned int writeBackCount[CORE_NUM_MAX] = {0};
      unsigned int memTransactionCount[CORE_NUM_MAX] = {0};
      unsigned int lineInvalidatedCount[CORE_NUM_MAX] = {0};
      unsigned int stallForBusTraffic[CORE_NUM_MAX] = {0};

    /*********inst memory init********/
     // pt = ROMimage0;
     for(loop_i=0;loop_i<numP;loop_i++)
     {
        for (count = 0; count<size[loop_i]/sizeof(uint64_t); count++)
        {
          top[loop_i]->inst_mem_i[count] = mem[loop_i][count];
        }
     }


  int bus_traffic_last = CORE_NUM_MAX;
  int readmiss_time[CORE_NUM_MAX] = {0};
  while (1)  /*!Verilated::gotFinish()*/
  {
      inst_last = inst_last1 | inst_last2;
     // main_time++;  // Time passes...
#if STEP
      fprintf(stderr, "main_time: %d\n", main_time);
#endif
      if (main_time<=3)
      {
          for(loop_i=0;loop_i<numP;loop_i++)
          {
              top[loop_i]->rst = 0;
          }
      }
      else 
      {
          for(loop_i=0;loop_i<numP;loop_i++)
          {
              top[loop_i]->rst = 1;
          }
      }
      
#if PRINT_REG
      for(loop_i = 0;loop_i < numP;loop_i++)
      {
          printf("readReqCount         [%d]=%d\n", loop_i, readReqCount[loop_i]);
          printf("readReqMissCount     [%d]=%d\n", loop_i, readReqMissCount[loop_i]);
          printf("writeReqCount        [%d]=%d\n", loop_i, writeReqCount[loop_i]);
          printf("writeReqMissCount    [%d]=%d\n", loop_i, writeReqMissCount[loop_i]);
          printf("TotalMissRate        [%d]=%f\%\n", loop_i, 
            ( (float)writeReqMissCount[loop_i] + (float)readReqMissCount[loop_i] )
           /( (float)writeReqCount[loop_i]     + (float)readReqCount[loop_i] ) * 100 );
          printf("writeBackCount       [%d]=%d\n", loop_i, writeBackCount[loop_i]);
          printf("memTransactionCount  [%d]=%d\n", loop_i, 
            writeBackCount[loop_i] + writeReqMissCount[loop_i] + readReqMissCount[loop_i]);
          printf("lineInvalidatedCount [%d]=%d\n", loop_i, lineInvalidatedCount[loop_i]);
          printf("stallForBusTraffic   [%d]=%d\n",loop_i, stallForBusTraffic[loop_i]);
          printf("\n");
          
      }

for(loop_i = 0;loop_i < numP;loop_i++)
{
 printf("core:%d  clk: %d   pc:0x%x\n",loop_i,top[loop_i]->clk, top[loop_i]->pc_stage2_ver);
      for(count=0; count<8; count++)
         {
              printf("Ls:%d cache[0x%x][%d]=0x%08x   ",
              top[loop_i]->cacheLineValid_o[0],
              0,
              count,top[loop_i]->cacheLine_o[0][count]);
              if(count%2 == 1) printf("\n");
         }
      for(count=0; count<8; count++)
         {
              printf("Ls:%d cache[0x%x][%d]=0x%08x   ",
              top[loop_i]->cacheLineValid_o[0+1],
              0+1,
              count,top[loop_i]->cacheLine_o[0+1][count]);
              if(count%2 == 1) printf("\n");
         }
}
#endif

      /*********data memory load in********/
      int readHit[CORE_NUM_MAX]   = {0};
      int readMiss[CORE_NUM_MAX]  = {0};
      int writeHit[CORE_NUM_MAX]  = {0};
      int writeMiss[CORE_NUM_MAX] = {0};
      int reqR[CORE_NUM_MAX];
      int reqW[CORE_NUM_MAX];
      svBitVecVal* cacheLine0; // a cache line has 256 bits
      svBitVecVal* cacheLine1 = new svBitVecVal(256);

        int run_core = bus_traffic_last;
        //bus_traffic_last = 0;
        
        int loop_m;

        if(bus_traffic_last != CORE_NUM_MAX)
        {
            for (loop_m = 0; loop_m < 1; loop_m++)
            {
                main_time++;
                top[bus_traffic_last]->clk = !top[bus_traffic_last]->clk;
                top[bus_traffic_last]->eval();
                //pc_last_core[bus_traffic_last] = top[bus_traffic_last]->pc_stage2_ver;
#if VM_TRACE
                // Dump trace data for this cycle
                for(loop_m = 0; loop_m < numP; loop_m++)
                {
                    if (tfp[loop_m]) tfp[loop_m]->dump(main_time);
                }
                //if (tfp[bus_traffic_last]) tfp[bus_traffic_last]->dump(main_time);
#endif
            }
        
        //    printf("double                                                                             cycle %d\n",bus_traffic_last);
            bus_traffic_last = CORE_NUM_MAX;
        }
 

        int start_cyc;
        if(run_core != CORE_NUM_MAX)
        {
            start_cyc = numP - 1;
        }
        else
        {
            start_cyc = 0;
        }
int trace_en[CORE_NUM_MAX] = {0};
for(loop_m = start_cyc; loop_m < numP; loop_m++)
{

    loop_i = loop_m;

    //for(loop_m = 0; loop_m < run_cycle; loop_m++)
    {
        if(prosFin_en[loop_i]==0) 
        { 
            top[loop_i]->clk = !top[loop_i]->clk;
            top[loop_i]->eval();
           // pc_last_core[loop_i] = top[loop_i]->pc_stage2_ver;
        }
        
    }
    //printf("top[loop_i]->reqIndex_o = %d\n",top[loop_i]->reqIndex_o);  
/*
printf("core:%d  clk: %d   pc:0x%x\n",loop_i,top[loop_i]->clk, top[loop_i]->pc_stage2_ver);
for(count=0; count<8; count++)
{
    printf("Linestate:%d cache[0x%x][%d]=0x%x\n",
    top[loop_i]->cacheLineValid_o[384],0x3000,count,top[loop_i]->cacheLine_o[384][count]);
}
*/
       /** Call the Coherence Controller Class Object with the processAddress method */
      readHit[loop_i]    = top[loop_i]->readHit_o;
      readMiss[loop_i]   = top[loop_i]->readMiss_o;
      writeHit[loop_i]   = top[loop_i]->writeHit_o;
      writeMiss[loop_i]  = top[loop_i]->writeMiss_o;
      reqR[loop_i]       = readHit[loop_i] | readMiss[loop_i];
      reqW[loop_i]       = writeHit[loop_i]| writeMiss[loop_i];

      /********************trace record***********************/

      trace_en[loop_i] = top[loop_i]->pc_stage2_ver != pc_last_core_2[loop_i];
      pc_last_core_2[loop_i] = top[loop_i]->pc_stage2_ver;

      if(trace_en[loop_i])
      {
          if(reqR[loop_i])      readReqCount[loop_i]++;
          if(readMiss[loop_i])  readReqMissCount[loop_i]++;
          if(reqW[loop_i])      writeReqCount[loop_i]++;
          if(writeMiss[loop_i]) writeReqMissCount[loop_i]++;
      }
      /*******************************************************/

      /************exe finish print mcycle & minstret*********/
      if(/*top[loop_i]->dff_ireg_ver[6] == 100 | */ /*top[loop_i]->pc_stage2_ver == 0x385a || top[loop_i]->pc_stage2_ver == 0x3978*/ 0) 
      {
          if(prosFin_en[loop_i] == 0)
          {
            printf("core%d %s: 0x%08x(%d)  %s: 0x%08x(%d)  CPI: %f\n",
                    loop_i,
                    "mcycle",
                    top[loop_i]->dff_csr_mcycle_ver,  top[loop_i]->dff_csr_mcycle_ver,
                    "minstret",
                    top[loop_i]->dff_csr_minstret_ver,top[loop_i]->dff_csr_minstret_ver,
                    (float)top[loop_i]->dff_csr_mcycle_ver/(float)top[loop_i]->dff_csr_minstret_ver);
          

              prosFin_en[loop_i] = 1;
              prosFin_num++;
              if(prosFin_num==numP) // if all cores have finished exe, finish
              {
                  main_time = max_time;
                  break;
              }
          }

      }
      /*******************************************************/

#if PRINT_REG
if(loop_i == 0)
{
    printf("\njudge0=%d, judge1=%d, judge2=%d, judge3=%d\n",top[loop_i]->pc_stage2_ver != pc_last_core[loop_i],(reqR[loop_i] | reqW[loop_i]), top[loop_i]->clk==1, bus_traffic_last == 0);
    printf("top[%d]->pc=0x%x, pc_last=0x%x\n",loop_i,top[loop_i]->pc_stage2_ver, pc_last_core[loop_i]);
}
#endif
      /********************trace record***********************/
      if((readMiss[loop_i] | writeMiss[loop_i]) && bus_traffic_last != CORE_NUM_MAX)
      {
          stallForBusTraffic[loop_i]++;
      }
      /*******************************************************/
      if( /*( (top[loop_i]->pc_stage2_ver != pc_last_core[loop_i])| (top[loop_i]->pc_stage2_ver==0) )
         &&*/ (reqR[loop_i] | reqW[loop_i])
         &&(writeHit[loop_i] | bus_traffic_last == CORE_NUM_MAX)/* && top[loop_i]->clk==0*/ )
        // && bus_traffic_last == 0)
      {
         // simController.processRequest(0, reqW[loop_i], top[loop_i]->data_addr_o);//reqRW:0read,1write
          unsigned int wb_addr;
          wb_addr = (top[loop_i]->data_addr_o >> 5); // req [Tag, Index]



          if(readMiss[loop_i]) // BusRd, Others M->S + write back
          {
#if PRINT_REG
printf("core%d readmiss, 0x%x\n",loop_i,top[loop_i]->data_addr_o);
#endif
              /*******others write back**********/
              for(count2 = 0; count2 < numP; count2++)
              {
/*
printf("judge0=%d,1=%d,2=%d\n\n",
count2 != loop_i,
top[count2]->cacheLineTag_o[top[loop_i]->reqIndex_o] == top[loop_i]->reqTag_o,
top[count2]->cacheLineValid_o[top[loop_i]->reqIndex_o] == 3);
*/
                if (count2 != loop_i
                    && top[count2]->cacheLineTag_o[top[loop_i]->reqIndex_o] == top[loop_i]->reqTag_o // Tag match
                    && top[count2]->cacheLineValid_o[top[loop_i]->reqIndex_o] == 3
                    /*&& dcache_state[count2][top[loop_i]->reqIndex_o] == 3*/)            // State M
                {

                    /********************trace record***********************/
                    if(trace_en[loop_i])
                    {
                        writeBackCount[count2]++;
                        memTransactionCount[count2]++;
                    }
                    /*******************************************************/
#if PRINT_REG
printf("core%d write back\n",count2);
#endif
                    cacheLine0 = top[count2]->cacheLine_o[top[loop_i]->reqIndex_o]; // get modified line from cache
                    for(count=0; count<8; count++)
                    {
                        memory[wb_addr][count]= cacheLine0[count]; // write back a cache line

                        /***********dcache trace***********/
                        //memory[wb_addr][count] = dcache[count2][top[loop_i]->reqIndex_o][count];
#if PRINT_REG
printf("readmiss, core%d writeback dcache[0x%x][%d]=0x%x\n",count2,top[loop_i]->reqIndex_o,count, memory[wb_addr][count]);
#endif
                    }
                    top[count2]->cacheLineValid_i[top[loop_i]->reqIndex_o] = 1; //M->S
                    
                    /***********dcache state trace***********/
                    //dcache_state[count2][top[loop_i]->reqIndex_o] = 1;
                }
                else if (count2 == loop_i
                 && top[count2]->cacheLineTag_o[top[loop_i]->reqIndex_o] != top[loop_i]->reqTag_o) // self Tag misMatch
                 {
                     if(top[count2]->cacheLineValid_o[top[loop_i]->reqIndex_o] == 3
                       /*dcache_state[count2][top[loop_i]->reqIndex_o] == 3*/)            // self State M, write back
                    {
                        unsigned int wb_addr_2; // addr for the line to be swapped out
                        wb_addr_2 = (top[count2]->cacheLineTag_o[top[loop_i]->reqIndex_o]<<10) + top[loop_i]->reqIndex_o; // req [Tag, Index]
#if PRINT_REG
printf("self tagmiss, self write back\n");
printf("self writeback memory[%d][%d] tag0x%x, index0x%x\n",wb_addr_2,count,top[count2]->cacheLineTag_o[top[loop_i]->reqIndex_o]<<10,top[loop_i]->reqIndex_o);
#endif    
                        /********************trace record***********************/
                        if(trace_en[loop_i])
                        {
                            writeBackCount[count2]++;
                            memTransactionCount[count2]++;
                        }
                        /*******************************************************/

                        cacheLine0 = top[count2]->cacheLine_o[top[loop_i]->reqIndex_o]; // get modified line from cache
                        for(count=0; count<8; count++)
                        {
                            memory[wb_addr_2][count] = cacheLine0[count]; // write back a cache line
#if PRINT_REG
printf("self writeback memory[%d][%d] 0x%08x\n",wb_addr_2,count, memory[wb_addr_2][count]);
#endif
                            /***********dcache trace***********/
                            //memory[wb_addr][count] = dcache[count2][top[loop_i]->reqIndex_o][count];
                        }
                    }
                 }






              }
               /*******self load from memory**********/


               /********************trace record***********************/
                if(trace_en[loop_i])
                {
                    memTransactionCount[loop_i]++;
                }
                /*******************************************************/

               for(count=0; count<8; count++)
               {
          //         printf("memory[%d][%d]=0x%x\n",wb_addr,count,memory[wb_addr][count]);
                   //memoryLine[count] = memory[wb_addr][count];
                   top[loop_i]->cacheLine_i[top[loop_i]->reqIndex_o][count] = memory[wb_addr][count];
                   //top[loop_i]->cacheLine_o[top[loop_i]->reqIndex_o][count] = memory[wb_addr][count];
 //                  top[0]->cacheLine_o[top[0]->reqIndex_o][count] = memory[wb_addr][count];
           //        printf("cacheLine_o 0x%x\n",top[loop_i]->cacheLine_o[top[loop_i]->reqIndex_o][count]);

                   /***********dcache trace***********/
                   //dcache[loop_i][top[loop_i]->reqIndex_o][count] = memory[wb_addr][count];
               }
               //top[0]->cacheLine_i[top[0]->reqIndex_o]      = memoryLine;
               top[loop_i]->cacheLineTag_i[top[loop_i]->reqIndex_o]   = wb_addr >> 10;
//printf("                                             tag0 0x%x\n",top[loop_i]->cacheLineTag_i[top[loop_i]->reqIndex_o]);


               top[loop_i]->cacheLineValid_i[top[loop_i]->reqIndex_o] = 1; // I->S

               /***********dcache state trace***********/
                //dcache_state[loop_i][top[loop_i]->reqIndex_o] = 1;
               //free(memoryLine);
               //top[loop_i]->eval();

               bus_traffic_last = loop_i;
/*
                for (loop_m = 0; loop_m < 10; loop_m++)
                {
                    main_time++;
                    top[loop_i]->clk = !top[loop_i]->clk;
                    top[loop_i]->eval();
#if VM_TRACE
                    // Dump trace data for this cycle
                    if (tfp) tfp->dump(main_time);
#endif
                }
                printf("double                                                                             cycle readmiss %d\n",bus_traffic_last);
*/


               //break;
          }
          else if(writeMiss[loop_i]) // BusRdX, Others M->I + write back; S->I
          {
#if PRINT_REG
              printf("writemiss, 0x%x\n",top[loop_i]->data_addr_o);
#endif
              /*******others write back**********/
              for(count2 = 0; count2 < numP; count2++)
              {
#if PRINT_REG
printf("writemiss, count2 != loop_i %d,   tag match %d\n",count2 != loop_i,top[count2]->cacheLineTag_o[top[loop_i]->reqIndex_o] == top[loop_i]->reqTag_o);
printf("cacheTag 0x%x, reqTag 0x%x\n",top[count2]->cacheLineTag_o[top[loop_i]->reqIndex_o], top[loop_i]->reqTag_o);
#endif
/*for(count=0; count<8; count++)
{
    top[count2]->cacheLineTag_o[top[loop_i]->reqIndex_o];
}*/
                if (count2 != loop_i
                 && top[count2]->cacheLineTag_o[top[loop_i]->reqIndex_o] == top[loop_i]->reqTag_o) // Tag match
                {
                    if(top[count2]->cacheLineValid_o[top[loop_i]->reqIndex_o] == 3
                       /*dcache_state[count2][top[loop_i]->reqIndex_o] == 3*/)            // State M, write back
                    {


                        /********************trace record***********************/
                        if(trace_en[loop_i])
                        {
                            writeBackCount[count2]++;
                            memTransactionCount[count2]++;
                        }
                        /*******************************************************/

                        cacheLine0 = top[count2]->cacheLine_o[top[loop_i]->reqIndex_o]; // get modified line from cache
                        for(count=0; count<8; count++)
                        {
                            memory[wb_addr][count] = cacheLine0[count]; // write back a cache line

                            /***********dcache trace***********/
                            //memory[wb_addr][count] = dcache[count2][top[loop_i]->reqIndex_o][count];
                        }
                    }
#if PRINT_REG                    
                    printf("write miss M/S->I\n");
#endif                    

                    /********************trace record***********************/
                    if(trace_en[loop_i])
                    {
                        if(top[count2]->cacheLineValid_i[top[loop_i]->reqIndex_o] != 0)// invalidate if it is M/S
                        {
                            lineInvalidatedCount[count2]++;
//printf("lineInvalidatedCount[%d] = %d\n", count2, lineInvalidatedCount[count2]);
                        }
                    }
                    /*******************************************************/

                    top[count2]->cacheLineValid_i[top[loop_i]->reqIndex_o] = 0; // M/S->I

                    /***********dcache state trace***********/
                    //dcache_state[count2][top[loop_i]->reqIndex_o] = 0;
                }
                else if (count2 == loop_i
                 && top[count2]->cacheLineTag_o[top[loop_i]->reqIndex_o] != top[loop_i]->reqTag_o) // self Tag misMatch
                 {
                     if(top[count2]->cacheLineValid_o[top[loop_i]->reqIndex_o] == 3
                       /*dcache_state[count2][top[loop_i]->reqIndex_o] == 3*/)            // self State M, write back
                    {
#if PRINT_REG
printf("self tagmiss, self write back\n");
#endif
                        unsigned int wb_addr_2; // addr for the line to be swapped out
                        wb_addr_2 = (top[count2]->cacheLineTag_o[top[loop_i]->reqIndex_o]<<10) + top[loop_i]->reqIndex_o; // req [Tag, Index]
                        /********************trace record***********************/
                        if(trace_en[loop_i])
                        {
                            writeBackCount[count2]++;
                            memTransactionCount[count2]++;
                        }
                        /*******************************************************/

                        cacheLine0 = top[count2]->cacheLine_o[top[loop_i]->reqIndex_o]; // get modified line from cache
                        for(count=0; count<8; count++)
                        {
                            memory[wb_addr_2][count] = cacheLine0[count]; // write back a cache line
#if PRINT_REG
printf("self writeback memory[%d][%d] 0x%08x\n",wb_addr_2,count, memory[wb_addr_2][count]);
#endif
                            /***********dcache trace***********/
                            //memory[wb_addr][count] = dcache[count2][top[loop_i]->reqIndex_o][count];
                        }
                    }
                 }



              }	   
               /*******self load from memory**********/
               /********************trace record***********************/
                if(trace_en[loop_i])
                {
                    if( !( (top[loop_i]->cacheLineTag_o[top[loop_i]->reqIndex_o] == top[loop_i]->reqTag_o)
                        &&  top[loop_i]->cacheLineValid_o[top[loop_i]->reqIndex_o] == 1) ) // if self tag match && state S, no need mem access
                        {
                            memTransactionCount[loop_i]++;
                        }
                }
                /*******************************************************/
               int offset = top[loop_i]->data_addr_o & 0x1f;
               offset = offset/4;
               for(count=0; count<8; count++)
               {
                   //memoryLine[count] = memory[wb_addr][count];
                   if(count!= offset)
                   {
                       top[loop_i]->cacheLine_i[top[loop_i]->reqIndex_o][count] = memory[wb_addr][count];
                   }
                  else
                  {
                      top[loop_i]->cacheLine_i[top[loop_i]->reqIndex_o][count] = top[loop_i]->store_data_o;
                  }
    //               top[0]->cacheLine_o[top[0]->reqIndex_o][count] = memory[wb_addr][count];

                   /***********dcache trace***********/
                   //dcache[loop_i][top[loop_i]->reqIndex_o][count] = memory[wb_addr][count];
               }
               //top[0]->cacheLine_i[top[0]->reqIndex_o]      = memoryLine;
               
              // top[loop_i]->cacheLine_i[top[loop_i]->reqIndex_o][offset] = top[loop_i]->store_data_o;
               top[loop_i]->cacheLineTag_i[top[loop_i]->reqIndex_o]   = wb_addr >> 10;
//printf("                                             tag1 0x%x\n",top[loop_i]->cacheLineTag_i[top[loop_i]->reqIndex_o]);
               top[loop_i]->cacheLineValid_i[top[loop_i]->reqIndex_o] = 3; // I->M
               /***********dcache state trace***********/
               //dcache_state[loop_i][top[loop_i]->reqIndex_o] = 3;
                
                /***********dcache trace***********/
               //dcache[loop_i][top[loop_i]->reqIndex_o][offset] = top[loop_i]->store_data_o;
#if PRINT_REG
printf("writemiss, core%d writeback dcache[0x%x][%d]=0x%x\n",loop_i,top[loop_i]->reqIndex_o,offset,dcache[loop_i][top[loop_i]->reqIndex_o][offset]);
#endif
//printf("write in 0x%x\n",top[loop_i]->store_data_o);
//printf("state change to %d %d\n",top[loop_i]->cacheLineValid_i[top[loop_i]->reqIndex_o],top[loop_i]->cacheLineValid_o[top[loop_i]->reqIndex_o]);
               bus_traffic_last = loop_i;
              // top[loop_i]->eval();
               //break;
          }

          /*****synchronize dcache in port to out port, prevent old data pollution***********/
          else if (writeHit[loop_i] )
          {
               /*******self store to cache**********/
               int offset = top[loop_i]->data_addr_o & 0x1f;
               offset = offset/4;

#if PRINT_REG
               printf("data:0x%x offset:%d\n",top[loop_i]->store_data_o, offset);
#endif
               
               top[loop_i]->cacheLine_i[top[loop_i]->reqIndex_o][offset] = top[loop_i]->store_data_o;

                /***********dcache trace***********/
               //dcache[loop_i][top[loop_i]->reqIndex_o][offset] = top[loop_i]->store_data_o;


               
            /******************print tohost******************/
               if(top[loop_i]->data_addr_o == 0x1000 && top[loop_i]->clk == 1 /*&& top[loop_i]->data_addr_o < 0x1040*/)
               {
                  // printf("tohost   addr: 0x%08x = 0x%04x\n",top[loop_i]->data_addr_o,top[loop_i]->store_data_o);

                   int fromhostadd = 0x1040;
                   int fromhostadd_index  = (fromhostadd>>5) & 0x3ff;
                   int fromhostadd_offset = fromhostadd & 0x1f;
                   int fromhostadd_tag    = fromhostadd >> 15;
                   top[loop_i]->cacheLine_i[fromhostadd_index][fromhostadd_offset] = 0xffff; // tohost 0x1040, index 0x82, offset 0
                   top[loop_i]->cacheLineValid_i[fromhostadd_index] = 1;
                   top[loop_i]->cacheLineTag_i[fromhostadd_index]   = fromhostadd_tag;
                 //  printf("fromhost addr: 0x%08x = 0x%04x\n",fromhostadd, top[loop_i]->cacheLine_o[fromhostadd_index][fromhostadd_offset]);
                   
                   int tohostbufaddr      = top[loop_i]->store_data_o + 0x10;
                   int tohostbuf         = top[loop_i]->cacheLine_o[ (tohostbufaddr>>5) & 0x3ff ][(tohostbufaddr & 0x1f)>>2];
                   int stackmemadd        = tohostbuf;//0x5d00; //top[loop_i]->store_data_o + 0x10;    //0x25940-4;//0x5d00;//0x25940 - 4;
                   int stackmemadd_index  = (stackmemadd>>5) & 0x3ff;
                   int stackmemadd_offset ;//= stackmemadd & 0x1f;
                   int stackmemadd_tag    ;//= stackmemadd >> 15;
                   int tohostlenadd  = top[loop_i]->store_data_o + (0x25958 - 0x25940);
                   int buflen        = top[loop_i]->cacheLine_o[ (tohostlenadd>>5) & 0x3ff ][(tohostlenadd & 0x1f)>>2];
                       buflen        = (buflen >> 1) + (buflen & 0x1);
                 //  printf("bufadd = 0x08%x\n",stackmemadd);
                 //  printf("len = 0x%x\n", buflen);
                   printf("%s",top[loop_i]->cacheLine_o[stackmemadd_index]); 
                   for (int i=0; i<buflen; i++)
                   {
                       stackmemadd_index  = (stackmemadd>>5) & 0x3ff;
                       stackmemadd_offset = (stackmemadd & 0x1f)>>2;
                       stackmemadd_tag    = stackmemadd >> 15;
                       //printf("dcache addr: 0x%08x =       0x%08x\n",stackmemadd, top[loop_i]->cacheLine_o[stackmemadd_index][stackmemadd_offset]);
                       
                       unsigned int mem_addr;
                       mem_addr = ( stackmemadd_tag << 10 ) + stackmemadd_index; // req [Tag, Index]
                       //printf("memory addr: 0x%08x =       0x%04x\n",stackmemadd, memory[mem_addr][i]);
                       stackmemadd += 4;
                   }   
                   
               }
            /************************************************/
          }

      }

}
   // printf("\n0x%8x require cache 0x%8x\n\n", top[0]->reqIndex_o, top[0]->cacheLine_o[top[0]->reqIndex_o][0]);
   // printf("s1 0x%8x\n", memory[0x25c40>>5][0]);

    run_core = CORE_NUM_MAX;

    //printf("pc: 0x%x\n",top[0]->pc_stage2_ver);

        if( /*!top[0]->clk && */(pc_last_core[0] != top[0]->pc_stage2_ver) && top[0]->inst_ver != 0 && top[0]->rst != 0
           /*&& trace_en[0]*/)
        {
          int r;
//printf("1111\n");
#if PRINT_REG
          fprintf(stderr, "\n\n%-4s: 0x%08x  ", "pc", pc_last_core[0]);//pc from processor
          fprintf(stderr, "%s: 0x%08x(%d)  %s: 0x%08x(%d)  CPI: %f\n",
                  "mcycle",
                  top[0]->dff_csr_mcycle_ver,  top[0]->dff_csr_mcycle_ver,
                  "minstret",
                  top[0]->dff_csr_minstret_ver,top[0]->dff_csr_minstret_ver,
                  (float)top[0]->dff_csr_mcycle_ver/(float)top[0]->dff_csr_minstret_ver);
#endif

          //processor
        //printf("pc0 0x%x\npc1 0x%x\n\n",pc_last_core[0],pc_last_core[1]);
    /*    
        if(prosFin_en[0] == 0)
        {
            //if(judge_pass_fail(top[0]->mhartid_o, pc_last_core[0], top[0]->dff_csr_mcycle_ver, top[0]->dff_csr_minstret_ver, &prosFin_num)!=0)//pass or fail
            {
                //prosFin_en[0] = 1;
            }
        }
        //printf("1\n");
        if(prosFin_en[1] == 0)
        {
            if(judge_pass_fail(top[1]->mhartid_o, pc_last_core[1], top[1]->dff_csr_mcycle_ver, top[1]->dff_csr_minstret_ver, &prosFin_num)!=0)//pass or fail
            {
                prosFin_en[1] = 1;
            }
        }
*/
        //judge_pass_fail(1, pc_last_core[1], top[1]->dff_csr_mcycle_ver, top[1]->dff_csr_minstret_ver, &prosFin);
//        printf("prosFin_num out %d\n", prosFin_num);
 //       if(prosFin_num == numP) break;

#if PRINT_REG
        fprintf(stderr, "processor: 0x%08" PRIx32 " (0x%08" PRIx32 ") %s\n",
                   pc_last_core[0], inst_last, disassembler->disassemble(inst_last).c_str());


        for ( r = 0; r < NXPR; ++r)
        {
            fprintf(stderr, "%-4s: 0x%08" PRIx32 "  ", xpr_name[r], top[0]->dff_ireg_ver[r]);
            if ((r + 1) % 4 == 0)
            {
              fprintf(stderr, "\n");
            }
        }
#endif
/*
    for(count=0; count<numP; count++)
    {
        //if(top[count]->clk==0)
        {
            // printf("refresh pc 0x%x count:%d\n", top[count]->pc_stage2_ver,count);
            pc_last_core[count] = top[count]->pc_stage2_ver;
        }
       
    }
*/

          inst_last1 = top[0]->inst_ver;
          step_num++;
#if PRINT_REG
        fprintf(stderr, "\n\n");
#endif


 }

 for(count=0; count<numP; count++)
    {
       if(top[count]->clk==1)
        {
            // printf("refresh pc 0x%x count:%d\n", top[count]->pc_stage2_ver,count);
            pc_last_core[count] = top[count]->pc_stage2_ver;
        }
       
    }

        main_time++;  // Time passes...
#if VM_TRACE
        // Dump trace data for this cycle
    for(loop_m = 0; loop_m < numP; loop_m++)
    {
        if (tfp[loop_m]) tfp[loop_m]->dump(main_time);
    }
        

#endif
        /************main clk max**************/
 /*       static int count_time_last = 0;
        int count_time = main_time >> 20;
        if(count_time > count_time_last)
        {
            //float percent = (float)main_time*100/max_time;
            //printf("%f%\n",percent);
            fprintf(stderr, "main_time %ld\n", main_time);
            count_time_last = count_time;
        }
*/
        if(main_time >= max_time) //47000000
        {
            printf("%dKB data producted, %d loops, %d core(s)\n", (program_loop_times>>6), program_loop_times, numP);
            for(loop_i = 0;loop_i < numP;loop_i++)
            {
                printf("readReqCount         [%d]=%d\n", loop_i, readReqCount[loop_i]);
                printf("readReqMissCount     [%d]=%d\n", loop_i, readReqMissCount[loop_i]);
                printf("writeReqCount        [%d]=%d\n", loop_i, writeReqCount[loop_i]);
                printf("writeReqMissCount    [%d]=%d\n", loop_i, writeReqMissCount[loop_i]);
                printf("TotalMissRate        [%d]=%f\%\n", loop_i, 
                    ( (float)writeReqMissCount[loop_i] + (float)readReqMissCount[loop_i] )
                /( (float)writeReqCount[loop_i]     + (float)readReqCount[loop_i] ) * 100 );
                printf("writeBackCount       [%d]=%d\n", loop_i, writeBackCount[loop_i]);
                printf("memTransactionCount  [%d]=%d\n", loop_i, memTransactionCount[loop_i]); 
                   // writeBackCount[loop_i] + writeReqMissCount[loop_i] + readReqMissCount[loop_i]);
                printf("lineInvalidatedCount [%d]=%d\n", loop_i, lineInvalidatedCount[loop_i]);
                printf("stallForBusTraffic   [%d]=%d\n", loop_i, stallForBusTraffic[loop_i]);
                printf("\n");
            }


            FILE* fp;
            char path[100] = "../logs/matmul.cache";
            if((fp=fopen(path,"wb+"))==NULL)  
            {  
                printf( "\nCan not open the path: %s \n", path);  
                exit(-1);  
            }  
            for(loop_i = 0; loop_i < numP; loop_i++)
            {
                fprintf(fp,"core:%d  clk: %d   pc:0x%x\n",loop_i,top[loop_i]->clk, top[loop_i]->pc_stage2_ver);
                for(count2 = 0;count2 < 1024; count2++) // dump the whole data cache, 1024lines
                {
                    for(count=0; count<8; count++)
                    {
                        fprintf(fp,"core:%d Ls:%d cache[0x%x][%d]=0x%08x   ",
                        loop_i,
                        top[loop_i]->cacheLineValid_o[count2],
                        count2,
                        count,top[loop_i]->cacheLine_o[count2][count]);
                        if(count%2 == 1) fprintf(fp,"\n");
                    }
                }
            }
            fclose(fp); fp = NULL;
            break;
        }

#if SPIKE_DEBUG
        if (err == 1)
        {
#if BREAK_INCO
          break
#endif
          ;
        }
#endif
delete cacheLine1;


}

    for(count=0; count<numP; count++)
    {
        top[count]->final();
    }
    

    // Close trace if opened
#if VM_TRACE
    for(count = 0; count < numP; count++)
    {
        if (tfp[count]) { tfp[count]->close(); tfp[count] = NULL; }
    }
    
#endif

    //  Coverage analysis (since test passed)
#if VM_COVERAGE
    Verilated::mkdir("logs");
    VerilatedCov::write("logs/coverage.dat");
#endif

    // Destroy model
    for(loop_i=0;loop_i<numP;loop_i++)
    {
        free(mem[loop_i]); mem[loop_i] = NULL;
        delete top[loop_i]; top[loop_i] = NULL;
    }
    delete top; top = NULL;
    //free(mem0); mem0 = NULL;
    //free(mem1); mem1 = NULL;


    //printf back memory image
    int offset;
    unsigned int result0, result1, result2, result3;
    unsigned int index[2];
    index[0] = 0x100000>>5;
    index[1] = 0x300000>>5;

    FILE* fp;
    char path[100] = "../logs/matmul.memory";
    if((fp=fopen(path,"wb+"))==NULL)  
    {  
        printf( "\nCan not open the path: %s \n", path);  
        exit(-1);  
    }  
    for(offset = 0; offset < program_loop_times/2; offset++) // dump 64KB(1MB) data memory from addr 0x300000
    {
        fprintf(fp,"line%3d ",offset);
        for(count = 0; count < 8; count++)
        {
            fprintf(fp," 0x%08x", memory[index[1]+offset][count]);
        }
        fprintf(fp,"\n");
    }
    fclose(fp); fp = NULL;
    

    for(offset = 0; offset < 2; offset++)
    {
        result0 = memory[index[0]+offset][0]*memory[index[0]+offset][4]
                + memory[index[0]+offset][1]*memory[index[0]+offset][4+2];
        result1 = memory[index[0]+offset][0]*memory[index[0]+offset][4+1]
                + memory[index[0]+offset][1]*memory[index[0]+offset][4+3];
        result2 = memory[index[0]+offset][2]*memory[index[0]+offset][4]
                + memory[index[0]+offset][3]*memory[index[0]+offset][4+2];
        result3 = memory[index[0]+offset][2]*memory[index[0]+offset][4+1]
                + memory[index[0]+offset][3]*memory[index[0]+offset][4+3];
        printf("reference:\nindex = 0x%x,\n [ 0x%08x,  0x%08x ]\n",index[0]+offset, result0, result1);
        printf(" [ 0x%08x,  0x%08x ]\n", result2, result3);
        printf("actual:\nindex = 0x%x,\n",index[1]+offset);
        for(count = 0; count < 2; count++)
        {
             printf(" [ 0x%08x,  0x%08x ]\n", memory[index[1]][4*offset + 2*count], memory[index[1]][4*offset + 2*count+1]);
        }

    }




    for (count = 0; count < memory_size; count++)
    {
        delete memory[count];
    }
    delete memory;

  clock_t time_end=clock();
  std::cout<<"time use:"<<1000*(time_end-time_start)/(double)CLOCKS_PER_SEC<<"ms"<<std::endl;
  exit(0);
}


int judge_pass_fail(int core, long address, int mcycle, int minstret, int*prosFin)
{
    if(address == 0x00000018)
          {
              printf("core:%d %s: 0x%08x(%d)  %s: 0x%08x(%d)  CPI: %f            pass\n",
                      core, "mcycle",
                      mcycle,  mcycle,
                    "minstret",
                    minstret, minstret,
                    (float)mcycle/(float)minstret);
            (*prosFin)++;
            //printf("prosFin %d\n", *prosFin);
            //if(prosFin == prosNum) 
              //	break;
            return 1;
          }
      else if(address == 0x00000004)
          {
              printf("core:%d %s: 0x%08x(%d)  %s: 0x%08x(%d)  CPI: %f            fail\n",
                      core, "mcycle",
                      mcycle,  mcycle,
                    "minstret",
                    minstret, minstret,
                    (float)mcycle/(float)minstret);
              (*prosFin)++;
            //printf("prosFin %d\n", *prosFin);
            //if(prosFin == prosNum) 
              return 2;
          }
    return 0;
}