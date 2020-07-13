#ifndef _TILELINK_CHANNEL_H
#define _TILELINK_CHANNEL_H

enum class Own_req    { Own_PutM, Own_GetS, Own_GetM };
enum class Other_req  { Other_PutM, Other_GetS, Other_GetM };
enum class Snoop_ack  { FoundM, FoundE, FoundNone };           // ack to respond SCU if valid cache line was found
enum class Grant_iack { GrantE, GrantS, GrantM, GrantI, GrantFailed }; // response for own_req
enum class Grant_ack  { Completed, GrantAckFailed };              // response for Grant

enum class TL_msg     
                       { 
                           /* BUS REQ,  channel A, B*/
                           PutM, GetS, GetM, 
                           /* SnoopAck, channel C*/
                           FoundM, FoundE, FoundNone, 
                           /* Grant,    channel D*/
                           GrantE, GrantS, GrantM, GrantFailed,
                           /* GrantAck, channel E*/
                           Completed, GrantAckFailed, 
                           /* msg fetch filed */
                           MsgFetchFailed
                       };


/*common properties per TL channel*/
class TL_channel
{
public:
   TL_channel(bool vaild_i, bool ready_i);
   TL_channel();
   ~TL_channel();
  /** valid & ready wire **/
   bool          readValid_o();
   bool          readReady_o();
   void          writeValid_i(bool valid_i);
   void          writeReady_i(bool ready_i);

  /** read channel property **/
   TL_msg        readMsg_o();
   unsigned int  readAddr_o();
   void          readData_o(unsigned int* buffer);

  /** channel activity **/
   // push out info, master interface
   int           sendMsg_w( bool (*pf_slave_readReady_o)(), TL_msg msg_i); //pfslave
   int           sendAddr_w( bool (*pf_slave_readReady_o)(), unsigned int addr_i);
   int           sendData_w( bool (*pf_slave_readReady_o)(), unsigned int data_i[8]);
   //fetch info from others, slave interface (caution: only the fetchMsg_i checks the valid signal)
   TL_msg        fetchMsg_i( bool (*pf_master_readValid_o)(), TL_msg (*pf_master_readMsg_o)() );
   unsigned int  fetchAddr_i( unsigned int (*pf_master_readAddr_o)() );
   void          fetchData_i(void (*pf_master_readData_o)(unsigned int* buffer), unsigned int* buffer);

private:
  /** channel communication value **/
   bool          valid;
   bool          ready;
  /** channel data, wait to be pushed outside **/
   TL_msg        TL_msg_o;
   unsigned int  TL_req_addr_o;
   unsigned int  TL_data_o[8];
};


#endif