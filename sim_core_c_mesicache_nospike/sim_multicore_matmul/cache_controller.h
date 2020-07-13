#ifndef _CACHE_CONTROLLER_H
#define _CACHE_CONTROLLER_H

#include <stdio.h>
//#include "Vtestbench.h"
#include "tilelink_channel.h"
#include "memory_controller.h"

enum class CachelineState  { I, S, E, M,
                             
                             I_G_D_M, I_G_D_SE, S_G_D_M, E_P_I, E_P_S, M_P_D_I, M_P_D_S };

/*Micro stages for cache controller
  I_G_D_M : At stage I, get data & stage M
  I_G_D_SE: At stage I, get data & stage S or E
  S_G_D_M : At stage S, get data & stage M
  E_P_I   : At stage E, put stage E, wait for stage I
  E_P_S   : At STAGE E, put stage E, wait for stage S
  M_P_D_I : At stage M, put data & stage M, wait for stage I
  M_P_D_S : At stage M, put data & stage M, wait for stage S
*/
enum class CacheMicroStageInFlight{ // upgrade transaction, wait for state & data
                                    I_G_D_M, I_G_D_SE, S_G_D_M, 
                                    // downgrade transaction, put state
                                    E_P_I, E_P_S, 
                                    // downgrade transaction, put state & data    
                                    M_P_D_I, M_P_D_S, 
                                    // no transaction in flight
                                    NONE 
                                    };


/*cache controller + L1 dcache for each L1 data cache*/
class cache_controller: public TL_channel
{
public:
  cache_controller(Vtestbench* dcache_i, char code_source_i[200], int code_size_i, uint64_t* code_mem_i);
  ~cache_controller();
  /** bind memory interface( not called in init, must be called after the init of back memory entity) **/
  void changeBind(memory_controller::memory_controller* bind_i, int bindNo);
  memory_controller* readBind(int bindNo);


  /** cache controller state machine **/
  // set up ready/valid of TL channel according to current micro stage inFlight
  // channel E is not included
  int channelPortStateRefresh(bool fromLocal_en); 
  // main run
  int run(); 
  

  /** cpu property functions **/
  


  /** rtl L1 data cache functions (suffix: _i put into rtl, _o get from rtl) **/
   // get cache read hit/miss
   bool readHit_o();
   bool readMiss_o();
   // get cache write hit/miss
   bool writeHit_o();
   bool writeMiss_o();
   // read reqed (readHit | readMiss)
   bool readReq_o();
   // write reqed (writeHit | writeMiss)
   bool writeReq_o();
   // get reqed data addr
   unsigned int reqAddr_o(); //top[loop_i]->data_addr_o
   // get cache Line Tag
   unsigned int lineTag_o(unsigned int Index_i);
   bool matchTag(unsigned int Index_i, unsigned int Tag2_i);
   // get cache Line Index
   unsigned int lineIndex();
   unsigned int lineIndex(unsigned int Addr);
   // get cache Line Offest
   unsigned int lineOffset();
   unsigned int lineOffset(unsigned int Addr)
   // get cache Line State
   CachelineState transferStage_rlt_cpp(int cacheLineValid);
   int transferStage_cpp_rtl(CachelineState cacheLineValid);
   CachelineState lineState_o(); // top[count2]->cacheLineValid_o[top[loop_i]->reqIndex_o]
   CachelineState lineState_o(unsigned int Addr);
   CachelineState lineState_next_o(); // for channel A where have to get the state before syn into the register
   bool matchState(CachelineState State1, CachelineState State2);
   // get data[cache line] to write(to write into back memory simed in cpp)
   void lineToMem_o(unsigned int reqAddr, unsigned int* buffer); //top[count2]->cacheLine_o[top[loop_i]->reqIndex_o]
   
   // change state of certain cache line
   void changeCachelineState(unsigned int Index_i, CachelineState State_i);

  /** bus transaction stages **/
   CacheMicroStageInFlight  readTransaction();
   bool startTransaction(CacheMicroStageInFlight trans);
   bool finishTransaction();


  /** TL functions **/
   /** channel A master activity (suffix _w = write the value, _r = read the value) **/
   // modify Own_PutM_data_o
   int Own_PutM_data_w
   (TL_channel* channel, unsigned int line[8]);
   // modify Own_req_addr_o
   int Own_req_addr_w
   (TL_channel* channel, unsigned int addr);
   // modify Own_req_msg_o
   int Own_req_msg_w
   (TL_channel* channel, Own_req ownReq);
    //channel A integrated handling function
    int runChannelA(
        memory_controller* bind, 
        Own_req own_req, 
        CacheMicroStageInFlight cacheMicroStageInFlight,
        CachelineState cachelineState,
        unsigned int addrReqFromCore,
        bool sendLine_en
    );
   
   /** channel B slave activity (caution: only the Receive_req_msg_i checks the valid signal) **/
   // get req_addr_o from master
   unsigned int Receive_req_addr_i
   ( TL_channel* channel );
   // get req_msg_o from master
   TL_msg Receive_req_msg_i
   ( TL_channel* channel );
   //channel B integrated handling function
   int runChannelB(
      memory_controller* bind, 
      Snoop_ack snoop_ack, 
      CacheMicroStageInFlight cacheMicroStageInFlight,
      CachelineState cachelineState,
      unsigned int addrReceivedFromB,
      bool sendLine_en
    );
   
   /** channel C master activity **/
   // modify SnoopAckData_data_o
   int Snoop_ack_data_w
   (TL_channel* channel, unsigned int line[8]);
   // modify SnoopAck_addr_o
   int Snoop_ack_addr_w
   (TL_channel* channel, unsigned int addr);
   // modify SnoopAck_msg_o
   int Snoop_ack_msg_w
   (TL_channel* channel, Snoop_ack snoopAck);

   /** channel D slave activity **/
   // get PutM_data from master
   void Receive_grant_data_i
   ( TL_channel* channel, unsigned int* buffer );
   // get grant_addr_o from master
   unsigned int Receive_grant_addr_i
   ( TL_channel* channel );
   // get grant_msg_o from master
   TL_msg Receive_grant_msg_i
   ( TL_channel* channel );
   // channel D integrated handling function
   int runChannelD(
      memory_controller* bind, 
      Grant_ack grant_ack, 
      CachelineState cachelineState,
      unsigned int addrReceivedFromD,
      bool getLine_en
    );

   /** channel E master activity **/
   // modify GrantAck_msg_o
   int Grant_ack_msg_w
   (TL_channel* channel, Grant_ack grantAck);


  /** performance counters function **/
   void readReqCount_add();
   void readReqMissCount_add();
   void writeReqCount_add();
   void writeReqMissCount_add();
   void writeBackCount_add();
   void memTransactionCount_add();
   void lineInvalidatedCount_add();
   void stallForBusTraffic_add();

   int readReqCount_read();
   int readReqMissCount_read();
   int writeReqCount_read();
   int writeReqMissCount_read();
   float TotalMissRate_read();
   int writeBackCount_read();
   int memTransactionCount_read();
   int lineInvalidatedCount_read();
   int stallForBusTraffic_read();

private:
  /** bind memory interface **/
  memory_controller** bind;
  int bindNum;
  /** cpu property **/
  char      code_source[200];
  int       code_size; // program code size(byte) for the core
  uint64_t* code_mem;
  
  /** pointer to the rtl part of L1 data cache **/
  Vtestbench* dcache;
  CachelineState transferStag_rlt_cpp(int cacheLineValid);
  
  /** bus transaction **/
  CacheMicroStageInFlight inFlight;  // record transaction in flight
  
  /** TL property **/
  TL_channel *TL_channel_A_master;
  TL_channel *TL_channel_B_slave;
  TL_channel *TL_channel_C_master;
  TL_channel *TL_channel_D_slave;
  TL_channel *TL_channel_E_master;

  /** performance counters **/
  int readReqCount;
  int readReqMissCount;
  int writeReqCount;
  int writeReqMissCount;
  int writeBackCount;
  int memTransactionCount;
  int lineInvalidatedCount;
  int stallForBusTraffic;
};

#endif