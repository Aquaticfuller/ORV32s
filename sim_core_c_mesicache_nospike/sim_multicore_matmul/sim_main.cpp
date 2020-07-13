#include "func.h"

#include "svdpi.h"
#include <ctime>

#include "tilelink_channel.h"
#include "cache_controller.h"
#include "memory_controller.h"
#include "bus_interaction.h"

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


u32 GetBinSize(char *filename);
int bin2cm(char source[], uint64_t *mem);

//void processor_t::disasm(insn_t insn);
int main(int argc, char** argv, char** env)
{
    clock_t time_start=clock();
    int numP = 2; // processor number
    if (numP > CORE_NUM_MAX) numP = CORE_NUM_MAX;
    int numM = 1; // back memory number
    int loop_i;

    unsigned int program_loop_times = 8192;  // 64KB data set -> 4096 loop times
    unsigned int max_time = CORE_NUM_MAX * 134 * program_loop_times / numP;  //47000000

    main_time = 0;
    Verilated::commandArgs(argc, argv);
    
    /********* hart init *******************/
    Vtestbench** top = new Vtestbench*[numP];

    for(loop_i=0; loop_i<numP; loop_i++)
    {
        top[loop_i] = new Vtestbench;
        top[loop_i]->mhartid_i = loop_i;
        top[loop_i]->transInFlight_en_i = 0;
    }

    disassembler_t* disassembler = new disassembler_t(32);


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


    /********* cache_controller init *********/
    char source[CORE_NUM_MAX][200];
    for(loop_i = 0; loop_i < numP; loop_i++)
    {
        strcpy(source[loop_i], "../test_programs/matmul/load_2core.bin"); //false sharing/load_core4_nfs.bin"); //argv[1];
    }

    int size[CORE_NUM_MAX];
    for(loop_i=0;loop_i<numP;loop_i++)
    {
        size[loop_i] = GetBinSize(source[loop_i]);
    }

    cache_controller** cache = new cache_controller*[numP]
    for(loop_i = 0; loop_i < numP; loop_i++)
    {
        cache[loop_i] = new cache_controller(top[loop_i], source[loop_i], size[loop_i]);
    }


    /** (not used)Create Coherence Controller Class Object Here with Constructor */
    int cache_size = 32768;  // 32byte*1024
    int cache_assoc= 1;      // direct map
    int blk_size   = 32;     // 32byte
    int num_processors = numP;  /*1, 2, 3, 4, 8*/
    /*********************************************************/


    int count;
    int count2;
    /*********data back memory init********/
    unsigned int memory_size = 3+20-5; //pow(2,3+20-5);
    memory_controller** memory = new memory_controller*[1];
    for(loop_i = 0; loop_i < numM; loop_i++)
    {
        memory[loop_i] = new memory_controller(memory_size);
    }

    int number = 0;
    //unsigned int memory[262144‬][8] = {0};  //back memory, 8MB pow(2,3+20-3-2)==262,144‬
    unsigned int memory_start_addr_load  = 0x100000>>5;
    unsigned int memory_start_addr_store = 0x300000>>5;
    unsigned int memLine_temp[8] = {0};
    for(loop_i = 0; loop_i < numM; loop_i++)
    {
        for (count = memory_start_addr_load; count < memory_start_addr_store; count++)
        {
            for(count2 = 0; count2 < 8; count2++)
            {
                memLine_temp[count2] = number;
                ++number;
            }
            memory[loop_i]->writeMem(count<<5, memLine_temp, MemorylineState::I);
        }
    }
    /****************************************************/


    /********* inst memory init ********/
     for(loop_i=0;loop_i<numP;loop_i++)
     {
        for (count = 0; count<size[loop_i]/sizeof(uint64_t); count++)
        {
          top[loop_i]->inst_mem_i[count] = mem[loop_i][count];
        }
     }
    /***********************************/

    unsigned int main_time = 0;
    while (1)  /*!Verilated::gotFinish()*/
    {
        
        bus_interaction(top, cache, memory, numP, numM);
    }
 