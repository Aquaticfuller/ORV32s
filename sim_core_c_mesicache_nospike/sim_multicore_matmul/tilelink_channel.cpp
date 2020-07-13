#include "tilelink_channel.h"
/****** TL_channel ******/
TL_channel::TL_channel(bool vaild_i, bool ready_i)
: /** init channel communication value **/
  valid(vaild_i), ready(ready_i), 
  /** init channel data, wait to be pushed outside **/
  TL_msg_o(TL_msg::MsgFetchFailed), 
  TL_req_addr_o(0)
{
  /** init channel data, wait to be pushed outside **/
    for(int i = 0; i < 8; i++)
    {
        TL_data_o[i] = 0;
    }
}
TL_channel::TL_channel(){}
TL_channel::~TL_channel(){}

bool TL_channel::readValid_o()
{
    return valid;
}

void TL_channel::writeValid_i(bool valid_i)
{
    valid = valid_i;
}

bool TL_channel::readReady_o()
{
    return ready;
}

void TL_channel::writeReady_i(bool ready_i)
{
    ready = ready_i;
}


TL_msg TL_channel::readMsg_o()
{
    return TL_msg_o;
}

unsigned int TL_channel::readAddr_o()
{
    return TL_req_addr_o;
}

void TL_channel::readData_o(unsigned int* buffer)
{
    for(int i = 0; i < 8; i++)
    {
        buffer[i] = TL_data_o[i];
    }
 
}


int TL_channel::sendMsg_w
    ( bool (*pf_slave_readReady_o)(), TL_msg msg_i )
{
    if (pf_slave_readReady_o() == false)
    {
        valid = false;
        return 0;
    }
    else
    {
        TL_msg_o = msg_i;
        valid = true;
        return 1;
    }
}

int TL_channel::sendAddr_w
    ( bool (*pf_slave_readReady_o)(), unsigned int addr_i )
{
    if (pf_slave_readReady_o() == false)
    {
        return 0;
    }
    else
    {
        TL_req_addr_o = addr_i;
        return 1;
    }
}

int TL_channel::sendData_w
    ( bool (*pf_slave_readReady_o)(), unsigned int data_i[8] )
{
    if (pf_slave_readReady_o() == false)
    {
        return 0;
    }
    else
    {
        for(int i = 0; i < 8; i++)
        {
            TL_data_o[i] = data_i[i];
        }
        return 1;
    }
}


TL_msg TL_channel::fetchMsg_i
    ( bool (*pf_master_readValid_o)(), TL_msg (*pf_master_readMsg_o)() )
{
    if (pf_master_readValid_o() == false)
    {
        return TL_msg::MsgFetchFailed;
    }
    else
    {
        return pf_master_readMsg_o();
    }
}

unsigned int TL_channel::fetchAddr_i(unsigned int (*pf_master_readAddr_o)())
{
    return pf_master_readAddr_o();
}

void TL_channel::fetchData_i(void (*pf_master_readData_o)(unsigned int* buffer), unsigned int* buffer)
{
    pf_master_readData_o(buffer);
}
