#include"cache_controller.h"
#include<string.h>
cache_controller::cache_controller
(Vtestbench* dcache_i, char code_source_i[200], int code_size_i, int memoryNum)
: /** bind memory interface (not inited, init by explicitly call changeBind() **/
  bind(NULL),
  bindNum(memoryNum),
  /** cpu property **/
  code_size(code_size_i),
  /** pointer to the rtl part of L1 data cache **/
  dcache(dcache_i),
  /** bus transaction **/
  inFlight(CacheMicroStageInFlight::NONE),
  /** performance counters **/
  readReqCount(0),
  readReqMissCount(0),
  writeReqCount(0),
  writeReqMissCount(0),
  writeBackCount(0),
  memTransactionCount(0),
  lineInvalidatedCount(0),
  stallForBusTraffic(0)
{
    /** bind memory interface **/
    bind = new memory_controller*[bindNum];
    /** cpu property **/
    strcpy(code_source, code_source_i);
    code_mem = (uint64_t *)malloc(code_size_i);
    memset(code_mem, 0, code_size_i);
    bin2cm(code_source_i, code_mem);
    /** TL property **/
    TL_channel_A_master = new TL_channel(false, true);
    TL_channel_B_slave  = new TL_channel(false, true);
    TL_channel_C_master = new TL_channel(false, true);
    TL_channel_D_slave  = new TL_channel(false, true);
    TL_channel_E_master = new TL_channel(false, true);
}

cache_controller::~cache_controller()
{
    free(code_mem);
    code_mem = NULL;
    delete TL_channel_A_master;
    TL_channel_A_master = NULL;
    delete TL_channel_B_slave;
    TL_channel_B_slave  = NULL;
    delete TL_channel_C_master;
    TL_channel_C_master = NULL;
    delete TL_channel_D_slave;
    TL_channel_D_slave  = NULL;
    delete TL_channel_E_master;
    TL_channel_E_master = NULL;

    delete bind;
    bind = NULL;
}

void cache_controller::changeBind(memory_controller* bind_i, int bindNo)
    {
        if(bindNo >= bindNum)
        {
            printf("bind memory No. error"\n);
            exit(0);
        }
        else
        {
            bind[bindNo] = bind_i;
        }
    }

memory_controller* cache_controller::readBind(int bindNo)
    {
        if(bindNo >= bindNum)
        {
            printf("bind memory No. error"\n);
            exit(0);
        }
        else
        {
            return bind[bindNo];
        }
    }

    // set up ready/valid of TL channel according to current micro stage inFlight
    // channel E is not included
    int cache_controller::channelPortStateRefresh(bool fromLocal_en) 
    {
        CacheMicroStageInFlight controllerState;
        controllerState = readTransaction();
        enum CHANNEL{A = 0, B, C, D, E };
        bool allReady[5] = {false}; // 0=a, 1=b...
        bool allValid[5] = {false};

        switch(inFlight)
        {
            case CacheMicroStageInFlight::NONE:
                allReady[B] = true;
                break;
            case CacheMicroStageInFlight::I_G_D_M:
            case CacheMicroStageInFlight::I_G_D_SE:
            case CacheMicroStageInFlight::S_G_D_M:
                allValid[A] = true;
                allReady[D] = true;
                break;
            case CacheMicroStageInFlight::E_P_I:
            case CacheMicroStageInFlight::M_P_D_I:
                if(fromLocal_en)
                {
                    allValid[A] = true;
                    allReady[D] = true;
                }
                else
                {
                    allValid[C] = true;
                }
                break;
            case CacheMicroStageInFlight::E_P_S:
            case CacheMicroStageInFlight::M_P_D_S:
                allValid[C] = true;
                break;
            default: return 0;
        }
        TL_channel_A_master->writeValid_i(allValid[A]);
        TL_channel_C_master->writeValid_i(allValid[C]);
        // TL_channel_E_master->writeValid_i(allValid[E]);
        TL_channel_B_slave->writeReady_i(allReady[B]);
        TL_channel_D_slave->writeReady_i(allReady[D]);
        return 1;
    }

    int cache_controller::run()
    {
        CacheMicroStageInFlight controllerState;
        controllerState = readTransaction();

        /****** receive from channel B, reply by channel C **********/
        TL_msg msgReceivedFromB; // msg from channel B: PutM, GetS, GetM
        msgReceivedFromB = Receive_req_msg_i(bind[0]->TL_channel_B_master );
                
        unsigned int addrReceivedFromB;// addr from channel B
        addrReceivedFromB = Receive_req_addr_i(bind[0]->TL_channel_B_master );
        /************************************************************/

        /****** receive from local core, send req by channel A ******/
        unsigned int addrReqFromCore;
        addrReqFromCore = reqAddr_o();
        /************************************************************/

        /****** receive data from channel D, reply by channel E ******/
        TL_msg msgReceivedFromD; // msg from channel D: GrantE, GrantS, GrantM,GrantI, GrantFailed,
        msgReceivedFromD = Receive_grant_msg_i(bind[0]->TL_channel_D_master );
                
        unsigned int addrReceivedFromD;// addr from channel D
        addrReceivedFromD = Receive_grant_addr_i(bind[0]->TL_channel_D_master);
        /************************************************************/

        switch(controllerState)
        {
            // no transaction in flight, only handle channel B & A, channel B has priority over A
            case CacheMicroStageInFlight::NONE:
                
                int channelB_enabled = 0;

                if ( matchTag(lineIndex(addrReceivedFromB), lineTag_o(addrReceivedFromB) ) // Tag match
                {
                    CachelineState lineState;
                    lineState = lineState_o(addrReceivedFromB);

                    channelB_enabled = 1;

                    switch (msgReceivedFromB)
                    {
                        // receive GetS from bus, M->S, E->S
                        case TL_msg::GetS  
                            switch(lineState)
                            {
                                // if Tag matched && Line state M , then write back data/state & M->M_P_D_S->S
                                case CachelineState::M:
                                    
                                    runChannelB(
                                        bind[0],                            // memory_controller* bind, 
                                        Snoop_ack::FoundM,                  // Snoop_ack snoop_ack, 
                                        CacheMicroStageInFlight::M_P_D_S,    // CacheMicroStageInFlight cacheMicroStageInFlight,
                                        CachelineState::M_P_D_S,             // CachelineState cachelineState,
                                        addrReceivedFromB,                  // unsigned int addrReceivedFromB,
                                        true                                // bool sendLine_en
                                    );
                                    break;
                                       
                                // if Tag matched && Line state E , then write back state & E->E_P_S->S
                                case CachelineState::E:
                                    runChannelB(
                                        bind[0],                            // memory_controller* bind, 
                                        Snoop_ack::FoundE,                  // Snoop_ack snoop_ack, 
                                        CacheMicroStageInFlight::E_P_S,     // CacheMicroStageInFlight cacheMicroStageInFlight,
                                        CachelineState::E_P_S,              // CachelineState cachelineState,
                                        addrReceivedFromB,                  // unsigned int addrReceivedFromB,
                                        false                               // bool sendLine_en
                                    );
                                    break;
                                default: channelB_enabled = 0;
                            }
                            break;
                        // receive GetM from bus, M->I, E->I, S->I
                        case TL_msg::GetM
                            switch(lineState)
                            {
                                // if Tag matched && Line state M, then write back data/state & M->M_P_D_I->I
                                case CachelineState::M:
                                    runChannelB(
                                        bind[0],                            // memory_controller* bind, 
                                        Snoop_ack::FoundM,                  // Snoop_ack snoop_ack, 
                                        CacheMicroStageInFlight::M_P_D_I,   // CacheMicroStageInFlight cacheMicroStageInFlight,
                                        CachelineState::M_P_D_I,            // CachelineState cachelineState,
                                        addrReceivedFromB,                  // unsigned int addrReceivedFromB,
                                        true                                // bool sendLine_en
                                    );
                                    break;
                                // if Tag matched && Line state E, then write back state & E->E_P_I->I
                                case CachelineState::E:
                                    runChannelB(
                                        bind[0],                            // memory_controller* bind, 
                                        Snoop_ack::FoundE,                  // bus request to send. Snoop_ack snoop_ack, 
                                        CacheMicroStageInFlight::E_P_I,     // CacheMicroStageInFlight cacheMicroStageInFlight,
                                        CachelineState::E_P_I,              // CachelineState cachelineState,
                                        addrReceivedFromB,                  // unsigned int addrReceivedFromB,
                                        false                               // bool sendLine_en
                                    );
                                    break;
                                // if Tag matched && Line state S, S->I silently
                                case CachelineState::S:
                                    // change cache line state into I
                                    changeCachelineState(lineIndex(addrReceivedFromB), CachelineState::I);
                                    break;
                                default: channelB_enabled = 0;
                            }
                            break;
                        default: channelB_enabled = 0;
                        
                    }
                    // refersh TL channel port state(valid/ready)
                    if ( channelPortStateRefresh(false) == 0 )
                    {
                        printf("channelPortStateRefresh, channel B error");
                        exit(0);
                    }
                }// end: channel B send out msg
                
                // no bus msg from channel B, do channel A req // PutM by core haven't been implemented
                if(channelB_enabled == 0)
                {
                    CachelineState lineState;
                    lineState = lineState_next_o();// for channel A where have to get the state before syn into the register
                    /** channel A send out msg **/
                    if(readMiss_o())       // channel A send busRd msg
                    {
                        switch (lineState)
                        {
                            case CachelineState::I_G_D_SE:            // I->S, I->E
                                // channel A send busRd msg
                                runChannelA(
                                    bind[0],                            // memory_controller* bind, 
                                    Own_req::Own_GetS,                  // Own_req own_req, 
                                    CacheMicroStageInFlight::I_G_D_SE,  // CacheMicroStageInFlight cacheMicroStageInFlight,
                                    CachelineState::I_G_D_SE,           // CachelineState cachelineState,
                                    addrReqFromCore,                    // unsigned int addrReqFromCore,
                                    false                               // bool sendLine_en
                                );
                                break;
                            default:;
                        }
                        
                        // Tag mismatch read miss, Own PutM
                        if ( matchTag(lineIndex(addrReqFromCore), lineTag_o(addrReqFromCore) == 0 ) // Tag mismatch
                        {
                            switch (lineState)
                            {
                                case CachelineState::M_P_D_I:            // M->I(->SE)
                                    // channel A send write back msg
                                    runChannelA(
                                        bind[0],                            // memory_controller* bind, 
                                        Own_req::Own_PutM,                  // Own_req own_req, 
                                        CacheMicroStageInFlight::M_P_D_I,   // CacheMicroStageInFlight cacheMicroStageInFlight,
                                        CachelineState::M_P_D_I,            // CachelineState cachelineState,
                                        addrReqFromCore,                    // unsigned int addrReqFromCore,
                                        true                                // bool sendLine_en
                                    );
                                    break;
                                case CachelineState::E_P_I:             // E->I(->SE)
                                    // channel A send write back msg
                                    runChannelA(
                                        bind[0],                            // memory_controller* bind, 
                                        Own_req::Own_PutM,                  // Own_req own_req, 
                                        CacheMicroStageInFlight::E_P_I,     // CacheMicroStageInFlight cacheMicroStageInFlight,
                                        CachelineState::E_P_I,              // CachelineState cachelineState,
                                        addrReqFromCore,                    // unsigned int addrReqFromCore,
                                        true                                // bool sendLine_en
                                    );
                                    break;
                                case CachelineState::I_G_D_SE:             // S(->I)->SE
                                    // channel A send write back msg
                                    runChannelA(
                                        bind[0],                            // memory_controller* bind, 
                                        Own_req::Own_PutM,                  // Own_req own_req, 
                                        CacheMicroStageInFlight::I_G_D_SE,  // CacheMicroStageInFlight cacheMicroStageInFlight,
                                        CachelineState::I_G_D_SE,           // CachelineState cachelineState,
                                        addrReqFromCore,                    // unsigned int addrReqFromCore,
                                        true                                // bool sendLine_en
                                    );
                                    break;
                                default:;
                            }
                        }
                    }
                    else if (writeMiss_o()) // channel A send busRdX msg
                    {
                        switch (lineState)
                        {
                            case CachelineState::I_G_D_M:            // I->M
                                // channel A send busRdX msg
                                runChannelA(
                                    bind[0],                            // memory_controller* bind, 
                                    Own_req::Own_GetM,                  // Own_req own_req, 
                                    CacheMicroStageInFlight::I_G_D_M,   // CacheMicroStageInFlight cacheMicroStageInFlight,
                                    CachelineState::I_G_D_M,            // CachelineState cachelineState,
                                    addrReqFromCore,                    // unsigned int addrReqFromCore,
                                    false                               // bool sendLine_en
                                );
                            break;

                            case CachelineState::S_G_D_M:              // S->M 
                                // channel A send busRdX msg
                                runChannelA(
                                    bind[0],                            // memory_controller* bind, 
                                    Own_req::Own_GetM,                  // Own_req own_req, 
                                    CacheMicroStageInFlight::S_G_D_M,   // CacheMicroStageInFlight cacheMicroStageInFlight,
                                    CachelineState::S_G_D_M,            // CachelineState cachelineState,
                                    addrReqFromCore,                    // unsigned int addrReqFromCore,
                                    false                               // bool sendLine_en
                                );
                            break;
                            default:;
                        }

                        // Tag mismatch write miss, Own PutM
                        if ( matchTag(lineIndex(addrReqFromCore), lineTag_o(addrReqFromCore) == 0 ) // Tag mismatch
                        {
                            switch (lineState)
                            {
                                case CachelineState::M_P_D_I:            // M->I(->M)
                                    // channel A send write back msg
                                    runChannelA(
                                        bind[0],                            // memory_controller* bind, 
                                        Own_req::Own_PutM,                  // Own_req own_req, 
                                        CacheMicroStageInFlight::M_P_D_I,   // CacheMicroStageInFlight cacheMicroStageInFlight,
                                        CachelineState::M_P_D_I,            // CachelineState cachelineState,
                                        addrReqFromCore,                    // unsigned int addrReqFromCore,
                                        true                                // bool sendLine_en
                                    );
                                    break;
                                case CachelineState::E_P_I:             // E->I(->M)
                                    // channel A send write back msg
                                    runChannelA(
                                        bind[0],                            // memory_controller* bind, 
                                        Own_req::Own_PutM,                  // Own_req own_req, 
                                        CacheMicroStageInFlight::E_P_I,     // CacheMicroStageInFlight cacheMicroStageInFlight,
                                        CachelineState::E_P_I,              // CachelineState cachelineState,
                                        addrReqFromCore,                    // unsigned int addrReqFromCore,
                                        false                               // bool sendLine_en
                                    );
                                    break;
                                default:;
                            }
                        }
                    }
                    // refersh TL channel port state(valid/ready)
                    if ( channelPortStateRefresh(true) == 0 )
                    {
                        printf("channelPortStateRefresh, channel A error");
                        exit(0);
                    }
                }// end: channel A send out msg
                break;
            //end: case CacheMicroStageInFlight::NONE


            // upgrade, wait for state SE & data
            case CacheMicroStageInFlight::I_G_D_SE: 
            // receive data from channel D
             
                switch (msgReceivedFromD)
                {
                    // receive GrantS from bus, I->S, reply by channel E
                    case GrantS:
                        runChannelD(
                            bind[0],                        // memory_controller* bind, 
                            Grant_ack::Completed            // Grant_ack grant_ack, 
                            CachelineState::S,              // CachelineState cachelineState,
                            addrReceivedFromD,              // unsigned int addrReceivedFromD,
                            true                            // bool getLine_en
                        );
                        break;
                    // receive GrantE from bus, I->E, reply by channel E
                    case GrantE:
                        runChannelD(
                            bind[0],                        // memory_controller* bind, 
                            Grant_ack::Completed            // Grant_ack grant_ack, 
                            CachelineState::E,              // CachelineState cachelineState,
                            addrReceivedFromD,              // unsigned int addrReceivedFromD,
                            true                            // bool getLine_en
                        );
                        break;
                    default:;
                }
                // refersh TL channel port state(valid/ready)
                if ( channelPortStateRefresh(false) == 0 )
                {
                    printf("channelPortStateRefresh, channel B error");
                    exit(0);
                }
                break;
            //end: case CacheMicroStageInFlight::I_G_D_SE

            // upgrade, wait for state M & data
            case CacheMicroStageInFlight::I_G_D_M:
            case CacheMicroStageInFlight::S_G_D_M:
            // receive data from channel D

                switch (msgReceivedFromD)
                {
                    // receive GrantM from bus, I->M, reply by channel E
                    case GrantM:
                        runChannelD(
                            bind[0],                        // memory_controller* bind, 
                            Grant_ack::Completed            // Grant_ack grant_ack, 
                            CachelineState::M,              // CachelineState cachelineState,
                            addrReceivedFromD,              // unsigned int addrReceivedFromD,
                            true                            // bool getLine_en
                        );
                        break;
                    default:;
                }
                // refersh TL channel port state(valid/ready)
                if ( channelPortStateRefresh(false) == 0 )
                {
                    printf("channelPortStateRefresh, channel B error");
                    exit(0);
                }
                break;
            //end: case CacheMicroStageInFlight::I_G_D_M, S_G_D_M
            
            // downgrade transaction, put state (& data in M_P_D_I), wait for I
            case CacheMicroStageInFlight::E_P_I:
            case CacheMicroStageInFlight::M_P_D_I:
                switch (msgReceivedFromD)
                {
                    // receive GrantI from bus, E->I, reply by channel E
                    case GrantI:
                        runChannelD(
                            bind[0],                        // memory_controller* bind, 
                            Grant_ack::Completed            // Grant_ack grant_ack, 
                            CachelineState::I,              // CachelineState cachelineState,
                            addrReceivedFromD,              // unsigned int addrReceivedFromD,
                            false                           // bool getLine_en
                        );
                        break; 
                    default:;
                }
                // refersh TL channel port state(valid/ready)
                if ( channelPortStateRefresh(false) == 0 )
                {
                    printf("channelPortStateRefresh, channel B error");
                    exit(0);
                }
                break;
            //end: case CacheMicroStageInFlight::E_P_I, M_P_D_I

            // downgrade transaction, put state (& data in M_P_D_S), wait for state S
            case CacheMicroStageInFlight::E_P_S:
            case CacheMicroStageInFlight::M_P_D_S:
                switch (msgReceivedFromD)
                {
                    // receive GrantS from bus, E->S, reply by channel E
                    case GrantS:
                        runChannelD(
                            bind[0],                        // memory_controller* bind, 
                            Grant_ack::Completed            // Grant_ack grant_ack, 
                            CachelineState::S,              // CachelineState cachelineState,
                            addrReceivedFromD,              // unsigned int addrReceivedFromD,
                            false                           // bool getLine_en
                        );
                        break;
                    default:;
                }
                // refersh TL channel port state(valid/ready)
                if ( channelPortStateRefresh(false) == 0 )
                {
                    printf("channelPortStateRefresh, channel B error");
                    exit(0);
                }
                break;
            //end: case CacheMicroStageInFlight::E_P_S, M_P_D_S

            default:;
        }// end: switch(controllerState)
    } // end: cache controller run

    /** rtl L1 data cache functions (suffix: _i put into rtl, _o get from rtl) **/
    // get cache read hit/miss
    bool cache_controller::readHit_o()
    {
        return dcache->readHit_o;
    }

    bool cache_controller::readMiss_o()
    {
        return dcache->readMiss_o;
    }

    // get cache write hit/miss
    bool cache_controller::writeHit_o()
    {
        return dcache->writeHit_o;
    }

    bool cache_controller::writeMiss_o()
    {
        return dcache->writeMiss_o;
    }

    // read reqed (readHit | readMiss)
    bool cache_controller::readReq_o()
    {
        return ( readHit_o() | readMiss_o() );
    }
    // write reqed (writeHit | writeMiss)
    bool cache_controller::writeReq_o()
    {
        return ( writeHit_o() | writeMiss_o() );
    }

    // get reqed data addr
    unsigned int cache_controller::reqAddr_o()  //top[loop_i]->data_addr_o
    {
        return dcache->data_addr_o;
    }

    // get cache Line Tag
    unsigned int cache_controller::lineTag_o(unsigned int Index_i) // addr[31:15]
    {
        return dcache->cacheLineTag_o[Index_i];
    }
    
    bool cache_controller::matchTag(unsigned int Index_i, unsigned int Tag2_i)
    {
        return lineTag_o(Index_i) == Tag2_i;
    }

    // get cache Line Index
    unsigned int cache_controller::lineIndex()  // addr[14:5] 
    {
        return ( reqAddr_o() >> 5 ) & 0x3ff;
    }
    
    unsigned int cache_controller::lineIndex(unsigned int Addr)  // addr[14:5] 
    {
        return ( Addr >> 5 ) & 0x3ff;
    }
    // get cache Line Offest
    unsigned int cache_controller::lineOffset() // addr[4:0]
    {
        return reqAddr_o() & 0x1f;
    }

    unsigned int cache_controller::lineOffset(unsigned int Addr) // addr[4:0]
    {
        return Addr & 0x1f;
    }

    // get cache Line State
    CachelineState cache_controller::transferStage_rlt_cpp(int cacheLineValid)
    {
        CachelineState rlt_cpp;
        switch(cacheLineValid)
        {
                case 0:
                rlt_cpp = CachelineState::I;
                break;
                case 1:
                rlt_cpp = CachelineState::S;
                break;
                case 2:
                rlt_cpp = CachelineState::E;
                break;
                case 3:
                rlt_cpp = CachelineState::M;
                break;
                case 4:
                rlt_cpp = CachelineState::I_G_D_M;
                break; 
                case 5:
                rlt_cpp = CachelineState::I_G_D_SE;
                break;
                case 6:
                rlt_cpp = CachelineState::S_G_D_M;
                break;
                case 7:
                rlt_cpp = CachelineState::E_P_I;
                break;
                case 8:
                rlt_cpp = CachelineState::M_P_D_I;
                break;
                case 9:
                rlt_cpp = CachelineState::M_P_D_S;
                break;
                default:
                rlt_cpp = CachelineState::I;
        }
        return rlt_cpp;
    }

    int cache_controller::transferStage_cpp_rtl(CachelineState cacheLineValid)
    {
        int cpp_rtl;
        switch(cacheLineValid)
        {
                case CachelineState::I:
                cpp_rtl = 0;
                break;
                case CachelineState::S:
                cpp_rtl = 1;
                break;
                case CachelineState::E:
                cpp_rtl = 2;
                break;
                case CachelineState::M:
                cpp_rtl = 3;
                break;
                case CachelineState::I_G_D_M:
                cpp_rtl = 4;
                break; 
                case CachelineState::I_G_D_SE:
                cpp_rtl = 5;
                break;
                case CachelineState::S_G_D_M:
                cpp_rtl = 6;
                break;
                case CachelineState::E_P_I:
                cpp_rtl = 7;
                break;
                case CachelineState::M_P_D_I:
                cpp_rtl = 8;
                break;
                case CachelineState::M_P_D_S:
                cpp_rtl = 9;
                break;
                default:
                cpp_rtl = 0;
        }
        return cpp_rtl;
    }

    CachelineState cache_controller::lineState_o() // top[count2]->cacheLineValid_o[top[loop_i]->reqIndex_o]
    {
        return transferStage_rlt_cpp(dcache->cacheLineValid_o[lineIndex()]);
    }

    CachelineState cache_controller::lineState_o(unsigned int Addr) // top[count2]->cacheLineValid_o[top[loop_i]->reqIndex_o]
    {
        return transferStage_rlt_cpp(dcache->cacheLineValid_o[lineIndex(Addr)]);
    }

    CachelineState cache_controller::lineState_next_o() // for channel A where have to get the state before syn into the register
    {
        return transferStage_rlt_cpp(dcache->cacheLineValid_next_o);
    }

    bool cache_controller::matchState(CachelineState State1, CachelineState State2)
    {
        return State1 == State2;
    }

    // get data[cache line] to write(to write into back memory simed in cpp)
    void cache_controller::lineToMem_o(unsigned int reqAddr, unsigned int* buffer)  //top[count2]->cacheLine_o[top[loop_i]->reqIndex_o]
    {
        for (int i = 0; i < 8; i++)
        {
            buffer[i] = dcache->cacheLine_o[lineIndex(reqAddr)][i];
        }
    }

    // change state of certain cache line
    void cache_controller::changeCachelineState(unsigned int Index_i, CachelineState State_i)
    {
        dcache->cacheLineValid_i[Index_i] = transferStage_cpp_rtl(State_i);
    }
    



    /** bus transaction stages **/
    CacheMicroStageInFlight cache_controller::readTransaction()
    {
        return inFlight;
    }

    bool cache_controller::startTransaction(CacheMicroStageInFlight trans)
    {
        if(inFlight == CacheMicroStageInFlight::NONE)
        {
            inFlight = trans;
            return true;
        }
        else  // having other transaction in flight
        {
            return false;
        }
    }

    bool cache_controller::finishTransaction()
    {
        if(inFlight == CacheMicroStageInFlight::NONE) // no transaction in flight
        {
            return false;
        }
        else
        {
            inFlight = CacheMicroStageInFlight::NONE;
            return true;
        }
    }



    /** TL functions **/
    /** channel A master activity (suffix _w = write the value, _r = read the value) **/
    // modify Own_PutM_data_o
    int cache_controller::Own_PutM_data_w
    ( TL_channel* channel, unsigned int line[8])
    {
        return sendData_w( channel->readReady_o(), line);
    }
    // modify Own_req_addr_o
    int cache_controller::Own_req_addr_w
    ( TL_channel* channel, unsigned int addr)
    {
        return sendAddr_w( channel->readReady_o(), addr);
    }
    // modify Own_req_msg_o
    int cache_controller::Own_req_msg_w
    ( TL_channel* channel, Own_req ownReq)
    {
            TL_msg local_to_bus; // transfer local msg to TLbus msg
            switch(ownReq)
            {
                case Own_req::Own_PutM :
                local_to_bus = TL_msg::PutM;
                break;
                case Own_req::Own_GetS :
                local_to_bus = TL_msg::GetS;
                break;
                case Own_req::Own_GetM :
                local_to_bus = TL_msg::GetM;
                break;
                default:
                return 0;
            }
            return sendMsg_w( channel->readReady_o(), local_to_bus);
    }
    //channel A integrated handling function
    int cache_controller::runChannelA(
        memory_controller* bind, 
        Own_req own_req, 
        CacheMicroStageInFlight cacheMicroStageInFlight,
        CachelineState cachelineState,
        unsigned int addrReqFromCore,
        bool sendLine_en
    )
    {
        // modify Own_req_msg_o
        if( Own_req_msg_w((bind->TL_channel_A_slave, own_req) == 0 )
        {
            // ready port of receiver is down, can't send msg
            return 0;
        }
        // start transaction
        if (!startTransaction(cacheMicroStageInFlight))
        {
            printf("start transaction conflict"\n);
            exit(0);
        }
        // change cache line state, no need in channel A because cache controller has already do this
        changeCachelineState(lineIndex(addrReqFromCore), cachelineState);

        // send write back req by channel A (putM) if needed
        if(sendLine_en) // if need to send a cache line
        {
            // get the line for writing back
            unsigned int cacheLine_temp[8];
            lineToMem_o(addrReqFromCore, cacheLine_temp);
            // modify Own_PutM_data_o
            Own_PutM_data_w(bind->TL_channel_A_slave, cacheLine_temp);
        }
        // modify Own_req_addr_o
        Own_req_addr_w(bind->TL_channel_A_slave, addrReqFromCore);// modify SnoopAck_msg_o
    }
    
    /** channel B slave activity (caution: only the Receive_req_msg_i checks the valid signal) **/
    // get req_addr_o from master
    unsigned int cache_controller::Receive_req_addr_i
    ( TL_channel* channel )
    {
        return fetchAddr_i( channel->readAddr_o() );
    }
    // get req_msg_o from master
    TL_msg cache_controller::Receive_req_msg_i
    ( TL_channel* channel )
    {
        return fetchMsg_i( channel->readValid_o, channel->readMsg_o );
    }
    //channel B integrated handling function
    int cache_controller::runChannelB(
        memory_controller* bind, 
        Snoop_ack snoop_ack, 
        CacheMicroStageInFlight cacheMicroStageInFlight,
        CachelineState cachelineState,
        unsigned int addrReceivedFromB,
        bool sendLine_en
    )
    {
        // modify SnoopAck_msg_o
        if( Snoop_ack_msg_w((bind->TL_channel_C_slave, snoop_ack) == 0 )
        {
            // ready port of receiver is down, can't send msg
            return 0;
        }
        // start transaction
        if (!startTransaction(cacheMicroStageInFlight))
        {
            printf("start transaction conflict"\n);
            exit(0);
        }
        // change cache line state into
        changeCachelineState(lineIndex(addrReceivedFromB), cachelineState);
        // send write back req by channel C
        if(sendLine_en) // if need to send a cache line
        {
            // get the line for writing back
            unsigned int cacheLine_temp[8];
            lineToMem_o(addrReceivedFromB, cacheLine_temp);
            // modify SnoopAckData_data_o
            Snoop_ack_data_w(bind->TL_channel_C_slave, cacheLine_temp);
        }
        // modify SnoopAck_addr_o
        Snoop_ack_addr_w(bind->TL_channel_C_slave, addrReceivedFromB);// modify SnoopAck_msg_o
    }
    
    /** channel C master activity **/
    // modify SnoopAckData_data_o
    int cache_controller::Snoop_ack_data_w
    ( TL_channel* channel, unsigned int line[8])
    {
        return sendData_w( channel->readReady_o(), line);
    }
    // modify SnoopAck_addr_o
    int cache_controller::Snoop_ack_addr_w
    ( TL_channel* channel, unsigned int addr)
    {
        return sendAddr_w( channel->readReady_o(), addr);
    }
    // modify SnoopAck_msg_o
    int cache_controller::Snoop_ack_msg_w
    ( TL_channel* channel, Snoop_ack snoopAck)
    {
        TL_msg local_to_bus; // transfer local msg to TLbus msg
            switch(snoopAck)
            {
                case Snoop_ack::FoundM :
                local_to_bus = TL_msg::FoundM;
                break;
                case Snoop_ack::FoundE :
                local_to_bus = TL_msg::FoundE;
                break;
                case Snoop_ack::FoundNone :
                local_to_bus = TL_msg::FoundNone;
                break;
                default:
                return 0;
            }
            return sendMsg_w( channel->readReady_o(), local_to_bus);
    }

    /** channel D slave activity **/
    // get PutM_data from master
    void cache_controller::Receive_grant_data_i
    ( TL_channel* channel, unsigned int* buffer )
    {
        fetchData_i( channel->readData_o(unsigned int *buffer), buffer);
    }
    // get grant_addr_o from master
    unsigned int cache_controller::Receive_grant_addr_i
    ( TL_channel* channel )
    {
        return fetchAddr_i( channel->readAddr_o() );
    }
    // get grant_msg_o from master
    TL_msg cache_controller::Receive_grant_msg_i
    ( TL_channel* channel )
    {
        return fetchMsg_i( channel->readValid_o(), channel->readMsg_o() );
    }
    //channel D integrated handling function
    int cache_controller::runChannelD(
        memory_controller* bind, 
        Grant_ack grant_ack, 
        CachelineState cachelineState,
        unsigned int addrReceivedFromD,
        bool getLine_en
    )
    {
        // modify Grant_ack_msg_o
        if( Grant_ack_msg_w((bind->TL_channel_E_slave, grant_ack) == 0 )
        {
            // ready port of receiver is down, can't send msg
            return 0;
        }

        // change cache line state into
        changeCachelineState(lineIndex(addrReceivedFromD), cachelineState);
        // send write back req by channel E
        if(getLine_en) // if need to get a cache line
        {
            // get the line for writing back
            unsigned int cacheLine_temp[8];
            Receive_grant_data_i(bind->TL_channel_D_master, cacheLine_temp);
            // modify local cache line
            lineToMem_o(addrReceivedFromD, cacheLine_temp);
        }

        // finish transaction
        if (!finishTransaction())
        {
            printf("end transaction error"\n);
            exit(0);
        }
    }

    /** channel E master activity **/
    // modify GrantAck_msg_o
    int cache_controller::Grant_ack_msg_w
    ( TL_channel* channel, Grant_ack grantAck)
    {
        TL_msg local_to_bus; // transfer local msg to TLbus msg
            switch(grantAck)
            {
                case Grant_ack::Completed :
                local_to_bus = TL_msg::Completed;
                break;
                case Grant_ack::GrantAckFailed :
                local_to_bus = TL_msg::GrantAckFailed;
                break;
                default:
                return 0;
            }
            return sendMsg_w( channel->readReady_o(), local_to_bus);
    }




    /** performance counters function **/
    void cache_controller::readReqCount_add()
    {
        ++readReqCount;
    }
    void cache_controller::readReqMissCount_add()
    {
        ++readReqMissCount;
    }
    void cache_controller::writeReqCount_add()
    {
        ++writeReqCount;
    }
    void cache_controller::writeReqMissCount_add()
    {
        ++writeReqMissCount;
    }
    void cache_controller::writeBackCount_add()
    {
        ++writeBackCount;
    }
    void cache_controller::memTransactionCount_add()
    {
        ++memTransactionCount;
    }
    void cache_controller::lineInvalidatedCount_add()
    {
        ++lineInvalidatedCount;
    }
    void cache_controller::stallForBusTraffic_add()
    {
        ++stallForBusTraffic;
    }

    int cache_controller::readReqCount_read()
    {
        return readReqCount;
    }
    int cache_controller::readReqMissCount_read()
    {
        return readReqMissCount;
    }
    int cache_controller::writeReqCount_read()
    {
        return writeReqCount;
    }
    int cache_controller::writeReqMissCount_read()
    {
        return writeReqMissCount;
    }
    float cache_controller::TotalMissRate_read()
    {
        return (float)writeReqMissCount + (float)readReqMissCount )
                /( (float)writeReqCount  + (float)readReqCount ) * 100 );
    }
    int cache_controller::writeBackCount_read()
    {
        return writeBackCount;
    }
    int cache_controller::memTransactionCount_read()
    {
        return memTransactionCount;
    }
    int cache_controller::lineInvalidatedCount_read()
    {
        return lineInvalidatedCount;
    }
    int cache_controller::stallForBusTraffic_read()
    {
        return stallForBusTraffic;
    }