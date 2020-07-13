#include"memory_controller.h"
#include<string.h>
memory_controller::memory_controller(unsigned int memory_size_i, int cacheNum)
: /** bind cache interface (not inited, init by explicitly call changeBind() **/
  bind(NULL),
  bindNum(cacheNum),
  inFlight_core_state(MemoryMicroStageInFlight::NONE)
  inFlight_core(0),
  addrInFlight(0)
{
    /** bind cache interface **/
    bind = new cache_controller*[bindNum];
    /** unified back memory init **/
    memory_size = pow(2, memory_size_i);   //pow(2,3+20-5)
    memory = new unsigned int*[memory_size]; 
    memLineState = new MemorylineState[memory_size];
    for (int count = 0; count < memory_size; count++)
    {
        memory[count] = new unsigned int[8];
        memset(memory[count], 0, 8*sizeof(unsigned int));
        memLineState[count] = MemorylineState::I;
    }

    /** TL property **/
    int i;
    TL_channel_A_slave  = new TL_channel[bindNum];
    TL_channel_B_master = new TL_channel[bindNum];
    TL_channel_C_slave  = new TL_channel[bindNum];
    TL_channel_D_master = new TL_channel[bindNum];
    TL_channel_E_slave  = new TL_channel[bindNum];
    for(i = 0; i < bindNum; i++)
    {
        TL_channel_A_slave[i]  = new TL_channel(false, true);
        TL_channel_B_master[i] = new TL_channel(false, true);
        TL_channel_C_slave[i]  = new TL_channel(false, true);
        TL_channel_D_master[i] = new TL_channel(false, true);
        TL_channel_E_slave[i]  = new TL_channel(false, true);
    }
}

memory_controller::~memory_controller()
{
    int count;
    for (int count = 0; count < memory_size; count++)
    {
        delete[] memory[count];
        memory[count] = NULL;
    }
    delete[] memLineState;
    memLineState = NULL;
    delete[] memory;
    memory = NULL;

    for(int count = 0; count < bindNum; count++)
    {
        delete TL_channel_A_slave[count];
        TL_channel_A_slave[count] = NULL;

        delete TL_channel_B_master[count];
        TL_channel_B_master[count]  = NULL;

        delete TL_channel_C_slave[count];
        TL_channel_C_slave[count] = NULL;

        delete TL_channel_D_master[count];
        TL_channel_D_master[count]  = NULL;

        delete TL_channel_E_slave[count];
        TL_channel_E_slave[count] = NULL;
    }
    delete TL_channel_A_slave;
    TL_channel_A_slave = NULL;

    delete TL_channel_B_master;
    TL_channel_B_master  = NULL;

    delete TL_channel_C_slave;
    TL_channel_C_slave = NULL;

    delete TL_channel_D_master;
    TL_channel_D_master  = NULL;

    delete TL_channel_E_slave;
    TL_channel_E_slave = NULL;

    delete bind;
    bind = NULL;
}

void memory_controller::changeBind(cache_controller* bind_i, int bindNo)
{
    if(bindNo >= bindNum)
    {
        printf("bind cache No. error"\n);
        exit(0);
    }
    else
    {
        bind[bindNo] = bind_i;
    }

}

cache_controller* memory_controller::readBind(int bindNo)
{
    if(bindNo >= bindNum)
    {
        printf("bind cache No. error"\n);
        exit(0);
    }
    else
    {
        return bind[bindNo];
    }
}

/** cache controller state machine **/
// set up ready/valid of TL channel according to current micro stage inFlight
int memory_controller::channelPortStateRefresh(int ack_core)
{
    // read state machine for memory controller
    MemoryMicroStageInFlight controllerState_state;
    controllerState_state = readTransaction_state();
    // read which cache controller is interacting with
    int controllerState_core;
    controllerState_core  = readTransaction_core();
    // all prots to each cache controller
    enum CHANNEL{A = 0, B, C, D, E };
    bool allReady*[]
    switch(controllerState_state)
    {
        case MemoryMicroStageInFlight::NONE:

    }
}


/** memory controller state machine **/
int memory_controller::run(bool reverse_en)
 {
    int memoryState_core;

    memoryState = readTransaction();
    switch(memoryState)
    {
        // no transaction in flight
        case 0: 

            break;
    }

  }



 /** bus transaction functions **/
MemoryMicroStageInFlight  memory_controller::readTransaction_state()
{
    return inFlight_core_state;
}
int memory_controller::readTransaction_core()
{
   return inFlight_core;
}
bool memory_controller::startTransaction(int coreNumb)
{
    if( inFlight == 0) // no transaction in flight
    {
        inFlight = coreNumb + 1;
        return true;
    }
    else
    {
        return false;
    }   
}

bool memory_controller::finishTransaction(int coreNumb)
{
    if( inFlight == 0) // no transaction in flight
    {
        return false;
    }
    else
    {
        inFlight = 0;
        return true;
    }   
}

  /** unified back memory functions (suffix: _i put into rtl, _o get from rtl) **/
   // get a memory line
   void memory_controller::readMem(unsigned int addr, unsigned int* buffer_o)
   {
       unsigned int memAddr = addr >> 5; // remove offset
       for (int i = 0; i < 8; i++)
       {
           buffer_o[i] = memory[memAddr][i];
       }
   }

   MemorylineState memory_controller::readMemState(unsigned int addr)
   {
       unsigned int memAddr = addr >> 5; // remove offset
       return memLineState[memAddr];
   }

   // modify a memory line
   void memory_controller::writeMem(unsigned int addr, unsigned int* buffer_i, MemorylineState memState_i)
   {
       unsigned int memAddr = addr >> 5; // remove offset
       for (int i = 0; i < 8; i++)
       {
           memory[memAddr][i] = buffer_i[i];
       }
       memLineState[memAddr] = memState_i;
   }

   void memory_controller::writeMemState(unsigned int addr, MemorylineState memState_i)
   {
       unsigned int memAddr = addr >> 5; // remove offset
       memLineState[memAddr] = memState_i;
   }




  /** TL functions **/
   /** channel A slave activity (caution: only the Receive_req_msg_i checks the valid signal) **/
   // get req_data_o from master
   void memory_controller::Receive_req_data_i
   ( int coreNo, void (*pf_master_readData_o)(unsigned int* buffer), unsigned int* buffer_i )
   {
       TL_channel::fetchData_i(pf_master_readData_o, buffer_i);
   }
   // get req_addr_o from master
   unsigned int memory_controller::Receive_req_addr_i
   ( unsigned int (*pf_master_readAddr_o)() )
   {
       return TL_channel::fetchAddr_i( pf_master_readAddr_o );
   }
   // get req_msg_o from master
   TL_msg memory_controller::Receive_req_msg_i
   ( bool (*pf_master_readValid_o)(), TL_msg (*pf_master_readMsg_o)() )
   {
       return TL_channel::fetchMsg_i( pf_master_readValid_o, pf_master_readMsg_o );
   }
   
   /** channel B master activity **/
   // modify Own_req_addr_o
   int memory_controller::Bus_req_addr_w
   (bool (*pf_slave_readReady_o)(), unsigned int addr)
   {
       TL_channel::sendAddr_w( pf_slave_readReady_o, addr);
   }
   // modify Own_req_msg_o
   int memory_controller::Bus_req_msg_w
   (bool (*pf_slave_readReady_o)(), TL_msg busReq)
   {
        return TL_channel::sendMsg_w( pf_slave_readReady_o, busReq);
   }
   
   /** channel C slave activity (caution: only the Receive_req_msg_i checks the valid signal) **/
   // get SnoopAckData_data_o from master
   int memory_controller::Receive_Snoop_ack_data_i
   ( void (*pf_master_readData_o)(unsigned int* buffer), unsigned int* buffer_i )
   {
       TL_channel::fetchData_i(pf_master_readData_o, buffer_i);
   }
   // get SnoopAck_addr_o from master
   unsigned int memory_controller::Receive_Snoop_ack_addr_i
   ( unsigned int (*pf_master_readAddr_o)() )
   {
       return TL_channel::fetchAddr_i( pf_master_readAddr_o );
   }
   // get SnoopAck_msg_o from master
   TL_msg memory_controller::Receive_Snoop_ack_msg_i
   ( bool (*pf_master_readValid_o)(), TL_msg (*pf_master_readMsg_o)() )
   {
       return TL_channel::fetchMsg_i( pf_master_readValid_o, pf_master_readMsg_o );
   }

   /** channel D master activity **/
   // modify PutM_data from slave
   int memory_controller::Grant_data_w
   (bool (*pf_slave_readReady_o)(), unsigned int line[8])
   {
       return TL_channel::sendData_w( pf_slave_readReady_o, line);
   }
   // modify grant_addr_o from slave
   int memory_controller::Grant_addr_w
   (bool (*pf_slave_readReady_o)(), unsigned int addr)
   {
       TL_channel::sendAddr_w( pf_slave_readReady_o, addr);
   }
   // modify grant_msg_o from slave
   int memory_controller::Grant_msg_w
   (bool (*pf_slave_readReady_o)(), TL_msg busReq)
   {
       return TL_channel::sendMsg_w( pf_slave_readReady_o, busReq);
   }

   /** channel E slave activity **/
   // get GrantAck_msg_o from master
   TL_msg memory_controller::Receive_Grank_ack_msg_w
   ( bool (*pf_master_readValid_o)(), TL_msg (*pf_master_readMsg_o)() )
   {
       return TL_channel::fetchMsg_i( pf_master_readValid_o, pf_master_readMsg_o );
   }



