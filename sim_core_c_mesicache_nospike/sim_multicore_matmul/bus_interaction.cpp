#include "bus_interaction.h"

int bus_interaction(Vtestbench** top, 
                    cache_controller** cache, 
                    memory_controller** memory, 
                    int coreNum, int memoryNum,
                    unsigned int main_time)
{
    int trans = memory[0]->readTransaction();
    for(int i = 0; i < coreNum; i++)
    {
        if(trans == 0 || trans == i) //no trans or trans for this core
        {
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
            top[i]->clk = !top[i]->clk;
            top->eval();                    // Evaluate model
            cout << top->out << endl;       // Read a output
            main_time++;                    // Time passes...
        }
    }
}