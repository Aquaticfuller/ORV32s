/* data L1 cache implemented with MESI protocol and micro stages */

module data_cache_mesi
        #(
        parameter AddressSize  = 32, 
        parameter WordSize     = 32
        ) 
        (
        input  logic                    clk,
        input  logic                    rst,
        input  logic [AddressSize-1:0]  data_addr_i, 
        input  logic [WordSize-1:0]     store_data_i, 
        output logic [WordSize-1:0]     load_data_o,
        //input  logic                    CS, 
        input  logic                    MemR_en_i, 
        input  logic                    MemW_en_i,
        input  logic [3:0]              byte_enable_i,
        output logic                    read_valid_o,  // read hit        
        output logic                    write_ready_o, // write hit
        output logic                    readMiss_o,    // read miss
        output logic                    writeMiss_o,   // write miss
        
        //////////////////////////////////////////////
        input  logic [31:0]             data_mem_i [0:4096-1],

        // if no other transaction in the bus(memory controller), the bus is ready, 
        // TODO: so the wire should connect to the mem controller and set only if no transaction in mem
        input  logic                    transInFlight_en_i  
        );

    /*  Micro stages for cache controller
        I_G_D_M : At stage I, get data & stage M
        I_G_D_SE: At stage I, get data & stage S or E
        S_G_D_M : At stage S, get data & stage M
        E_P_I   : At stage E, put stage E, wait for stage I
        M_P_D_I : At stage M, put data & stage M, wait for stage I
        M_P_D_S : At stage M, put data & stage M, wait for stage S
    */
    typedef enum logic[3:0] {Invalid=4'b0, Shared, Exclusive, Modified, 
                             I_G_D_M, I_G_D_SE, S_G_D_M, E_P_I, E_P_S, M_P_D_I, M_P_D_S
                              } lineStage; 
/*    localparam logic  [3:0] Invalid  = 2'b00;
    localparam logic  [3:0] Shared   = 2'b01;
    localparam logic  [3:0] Modified = 2'b11;
*/
    //control signal 
    assign read_valid_o  = MemR_en_i & readHit;
    assign write_ready_o = MemW_en_i & writeHit;
    //assign write_ready_o = writeHit & ~transInFlight_en_i; // if no other transaction in bus, the bus is ready
    
    //ram
    //logic [31:0] Mem [0:(1<<AddressSize)-1];
    logic [255:0]        cacheLine [0:1024-1];
    logic [16:0]         cacheLineTag[0:1024-1];  // Tag 17bits, Index 10 bits, Offset 5 bits
    lineStage            cacheLineValid[0:1024-1]; 
    lineStage            cacheLineValid_next;
    logic                cacheLineValid_refresg_en;

    logic [16:0]         reqTag;
    logic [9:0]          reqIndex;
    logic [4:0]          reqOffset;
    assign reqTag    =  data_addr_i[31:15];
    assign reqIndex  =  data_addr_i[14:5];
    assign reqOffset =  data_addr_i[4:0];
    
    logic TagHit;
    logic readHit;
    logic writeHit;
    logic atMESstage;
    logic [16:0]         localTag;
    logic cacheModified;
    logic cacheInvalid;
    logic cacheShared;
    assign localTag      = cacheLineTag[reqIndex];
    assign TagHit        = reqTag == localTag;
    assign atMESstage    = cacheModified | cacheExclusive | cacheShared;
    assign readHit       = TagHit && atMESstage;    // read hit when S/E/M
    assign cacheModified = cacheLineValid[reqIndex] == Modified;
    assign cacheExclusive= cacheLineValid[reqIndex] == Exclusive;
    assign cacheShared   = cacheLineValid[reqIndex] == Shared;
    assign cacheInvalid  = cacheLineValid[reqIndex] == Invalid;
    assign writeHit      = TagHit && (cacheModified | cacheExclusive); // write hit when M
    
    assign readMiss_o    = MemR_en_i & ~readHit;
    assign writeMiss_o   = MemW_en_i & ~writeHit;
    logic writeMiss_ItoM;
    logic writeMiss_StoM;
    logic writeHit_EtoM;
    assign writeMiss_ItoM = writeMiss_o & cacheInvalid;
    assign writeMiss_StoM = writeMiss_o & cacheShared;
    assign writeHit_EtoM  = MemW_en_i & TagHit & cacheExclusive;

    logic[7:0]  reqAddrInLine; // present 0-255bit in line
    assign reqAddrInLine = { reqOffset[4:2], 5'b0 };
    
    //read
    assign load_data_o   = MemR_en_i /*& readHit*/ ? cacheLine[reqIndex][reqAddrInLine +: 32] : {WordSize{1'bz}};
    //write
    logic [3:0] write_en;
    assign      write_en = {4{MemW_en_i & writeHit}} & byte_enable_i ;

    always_comb begin: cache_line_state_next
        cacheLineValid_next = cacheLineValid[reqIndex];
        if(TagHit) begin
            if(writeHit_EtoM)  
                cacheLineValid_next = Modified;
        end else begin
            if     (readMiss_o & cacheModified)  // M, tag mismatch, write back data/state
                cacheLineValid_next = M_P_D_I;
            else if(readMiss_o & cacheExclusive) // E, tag mismatch, write back state
                cacheLineValid_next = E_P_I;
            else if(readMiss_o & cacheShared)    // S, tag mismatch, read
                cacheLineValid_next = I_G_D_SE;
            
            if     (writeMiss_o & cacheModified) // M, tag mismatch, write back data/state
                cacheLineValid_next = M_P_D_I;
            else if(writeMiss_o & cacheExclusive)// E, tag mismatch, write back state
                cacheLineValid_next = E_P_I;
        end

        if     (readMiss_o & cacheInvalid)  
            cacheLineValid_next = I_G_D_SE;
        else if(writeMiss_ItoM) 
            cacheLineValid_next = I_G_D_M;
        else if(writeMiss_StoM) 
            cacheLineValid_next = S_G_D_M;

    end
    assign cacheLineValid_refresg_en  =   readMiss_o      // I->S, I->E
                                        | writeMiss_ItoM  // I->M
                                        | writeMiss_StoM  // S->M
                                        | writeHit_EtoM   // E->M // shift silently 

    always_ff @( posedge clk ) begin
        if (write_en[0])
            cacheLine[reqIndex][ reqAddrInLine     +: 8]   <= store_data_i[7:0];
        if (write_en[1])
            cacheLine[reqIndex][(reqAddrInLine+8)  +: 8]   <= store_data_i[15:8];
        if (write_en[2])
            cacheLine[reqIndex][(reqAddrInLine+16) +: 8]   <= store_data_i[23:16];
        if (write_en[3])
            cacheLine[reqIndex][(reqAddrInLine+24) +: 8]   <= store_data_i[31:24];
        
        /************local request state transition************/
        if (cacheLineValid_refresg_en)
            cacheLineValid[reqIndex] <= cacheLineValid_next;

        if(rst == RstEnable) begin
            cacheLine      <= '0;
            cacheLineTag   <= '0;
            cacheLineValid <= '0;
        end
    end


    //logic [31:0] the_cacheLine;
    //assign the_cacheLine = cacheLine[130][31:0];
endmodule