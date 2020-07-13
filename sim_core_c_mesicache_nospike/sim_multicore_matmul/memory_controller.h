#ifndef _MEMORY_CONTROLLER_H
#define _MEMORY_CONTROLLER_H

//#include "Vtestbench.h"
#include "tilelink_channel.h"
#include "cache_controller.h"

enum class MemorylineState {  I, S, EorM,

                              I_EorM_GrantAck, 
                                // following 2 are combined //
                              EorM_S_WriteBack,
                              EorM_S_GrantAck,
                                //////////////////////////////
                              EorM_I_GrantAck,
                              S_EorM_GrantAck
                            };

/*Micro stages for memory controller
  I_EorM_GrantAck   : stage I->EorM, wait for GrantAck
    // following 2 are combined //
  EorM_S_WriteBack  : stage EorM->EorM_S_GrantAck, wait for WriteBack
  EorM_S_GrantAck   : stage EorM_S_WriteBack->S, wait for GrantAck
    //////////////////////////////
  EorM_I_GrantAck   : stage EorM->I, wait for GrantAck
  S_EorM_GrantAck   : stage S->EorM, wait for GrantAck
*/
enum class MemoryMicroStageInFlight{  
                                      I_EorM_GrantAck, 
                                        // following 2 are combined //
                                      EorM_S_WriteBack,
                                      EorM_S_GrantAck,
                                        //////////////////////////////
                                      EorM_I_GrantAck,
                                      S_EorM_GrantAck,
                                        // no transaction in flight
                                      NONE 
                                    };

/*unified back memory controller*/
class memory_controller: public TL_channel
{
public:
  memory_controller(unsigned int memory_size_i);
  ~memory_controller();
/** bind cache interface( not called in init, must be called after the init of cache entity) **/
  void changeBind(cache_controller::cache_controller* bind_i, int bindNo);
  memory_controller* readBind(int bindNo);

/** cache controller state machine **/
// set up ready/valid of TL channel according to current micro stage inFlight
  int channelPortStateRefresh(int ack_core); 

  int run(bool reverse_en); // enable for reversing the polling order 
  

/** unified back memory functions (suffix: _i put into rtl, _o get from rtl) **/
   // get a memory line
   void readMem(unsigned int addr, unsigned int* buffer_o);
   MemorylineState readMemState(unsigned int addr, unsigned int* buffer);
   // modify a memory line
   void writeMem(unsigned int addr, unsigned int* buffer_i, MemorylineState memState_i);
   void writeMemState(unsigned int addr, MemorylineState memState_i);

/** bus transaction functions **/
  MemoryMicroStageInFlight  readTransaction_state(); // state machine for memory controller
  int  readTransaction_core(); // and which cache controller is interacting with
  bool startTransaction(int coreNumb);
  bool finishTransaction(int coreNumb);

/** TL functions **/
   /** channel A slave activity (caution: only the Receive_req_msg_i checks the valid signal) **/
   // get req_data_o from master
   void Receive_req_data_i
   ( int coreNo, void (*pf_master_readData_o)(unsigned int* buffer), unsigned int* buffer_i ); // coreNo: specify the core interact with
   // get req_addr_o from master
   unsigned int Receive_req_addr_i
   ( unsigned int (*pf_master_readAddr_o)() );
   // get req_msg_o from master
   TL_msg Receive_req_msg_i
   ( bool (*pf_master_readValid_o)(), TL_msg (*pf_master_readMsg_o)() );
   
   /** channel B master activity **/
   // modify Own_req_addr_o
   int Bus_req_addr_w
   (bool (*pf_slave_readReady_o)(), unsigned int addr);
   // modify Own_req_msg_o
   int Bus_req_msg_w
   (bool (*pf_slave_readReady_o)(), Own_req ownReq);
   
   /** channel C slave activity (caution: only the Receive_req_msg_i checks the valid signal) **/
   // get SnoopAckData_data_o from master
   int Receive_Snoop_ack_data_i
   ( void (*pf_master_readData_o)(unsigned int* buffer), unsigned int* buffer_i );
   // get SnoopAck_addr_o from master
   unsigned int Receive_Snoop_ack_addr_i
   ( unsigned int (*pf_master_readAddr_o)() );
   // get SnoopAck_msg_o from master
   TL_msg Receive_Snoop_ack_msg_i
   ( bool (*pf_master_readValid_o)(), TL_msg (*pf_master_readMsg_o)() );

   /** channel D master activity **/
   // modify PutM_data from slave
   int Grant_data_w
   (bool (*pf_slave_readReady_o)(), unsigned int line[8]);
   // modify grant_addr_o from slave
   int Grant_addr_w
   (bool (*pf_slave_readReady_o)(), unsigned int addr);
   // modify grant_msg_o from slave
   int Grant_msg_w
   (bool (*pf_slave_readReady_o)(), TL_msg busReq);

   /** channel E slave activity **/
   // get GrantAck_msg_o from master
   TL_msg Receive_Grank_ack_msg_w
   ( bool (*pf_master_readValid_o)(), TL_msg (*pf_master_readMsg_o)() );




private:
  /** bind memory interface **/
  cache_controller::cache_controller** bind;
  int bindNum;
  /** unified back memory **/
  unsigned int     memory_size;
  unsigned int**   memory;
  MemorylineState* memLineState;

  /** bus transaction **/
  MemoryMicroStageInFlight inFlight_core_state;
  int inFlight_core;  // record with which cache(1-8) the transaction is in flight, 0 means no transaction
  unsigned int addrInFlight;  // the address that the current transaction is requesting on
  
  /** TL property **/
  TL_channel **TL_channel_A_slave;
  TL_channel **TL_channel_B_master;
  TL_channel **TL_channel_C_slave;
  TL_channel **TL_channel_D_master;
  TL_channel **TL_channel_E_slave;


};

#endif