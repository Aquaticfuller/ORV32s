#ifndef _BUS_INTERACTION_H
#define _BUS_INTERACTION_H

#include "cache_controller.h"
int bus_interaction(Vtestbench** top, 
                    cache_controller** cache, 
                    memory_controller** memory, 
                    int coreNum, int memoryNum, 
                    unsigned int main_time);


#endif