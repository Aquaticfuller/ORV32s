
import libcsr::*;
import libopcode::*;
module cs_registers #(
)(
    input  logic                 clk,
    input  logic                 rst,
    input  logic                 stall_i,
    input  logic                 flush_i,
    input  logic                 sys_call_en_i, //ecall
    input  logic                 excep_en_i,
    input  logic                 mret_en_i, //mret
    
    input  logic [31:0]          pc_idex_i,
    input  logic [6:0]           opcode_idex_i,
    input  logic [2:0]           fun3_rvc_idex_i,
    input  logic                 inst_zero_en_i,
    // mtvec
    output logic [31:0]          csr_mtvec_o,
    
    // Interface to registers
    //input  logic                 csr_access_i, // instruction to read/modify CSR
    input  libcsr::csr_add_e     csr_addr_i,
    input  logic [31:0]          csr_wdata_i,
    input  libcsr::csr_op_e      csr_op_i,
    output logic [31:0]          csr_rdata_o,
    
    // interrupts
    output logic [31:0]          csr_mepc_o,

    // csr->controller->ex_stage->decode
    output logic [1:0]           priv_lvl_o  //mstatus.mpp
);
    localparam logic [31:0] MISA_VALUE =
          (0          <<  0)  // A - Atomic Instructions extension
        | (1          <<  2)  // C - Compressed extension
        | (0          <<  3)  // D - Double precision floating-point extension
        | (0          <<  4)  // E - RV32E base ISA
        | (0          <<  5)  // F - Single precision floating-point extension
        | (1          <<  8)  // I - RV32I/64I/128I base ISA
        | (1          << 12)  // M - Integer Multiply/Divide extension
        | (0          << 13)  // N - User level interrupts supported
        | (0          << 18)  // S - Supervisor mode implemented
        | (1          << 20)  // U - User mode implemented
        | (0          << 23); // X - Non-standard extensions present
    
    
    // mstatus
    typedef struct packed {
        logic      mie;
        logic      mpie;
        logic      mpp;  //0 user(=2'b00), 1 machine(=2'b11)
        logic      mprv;
    } Mstatus_t;
    
    // CSRs
    logic [31:0] mhartid;
    priv_lvl_e   priv_lvl, priv_lvl_next;
    Mstatus_t    mstatus;
    logic [31:0] mtvec;
    logic [31:0] mscratch;
    logic [31:0] mepc;
    logic [5:0]  mcause; //1bit for interrupt, 5bits for Exception Code
    logic [31:0] mtval;

    
    // Hardware performance monitor signals
    logic        mctcounter;
    assign       mctcounter  = csr_addr_i[1]; //Machine Counter/Timers address
    
    logic [63:0] mct [0:1]; //0 {mcycleh, mcycle, cycle}; 1 {minstreth, minstret};

    assign csr_rdata_o = csr_rdata_tmp;
    assign priv_lvl_o = {2{mstatus.mpp}};

    //CSR read
    logic [31:0]       csr_rdata_tmp;
    always_comb begin : csr_read
        csr_rdata_tmp = '0;
        case (csr_addr_i)
        // Machine trap setup
            //mstatus
            CSR_MSTATUS: begin
                csr_rdata_tmp                       = '0;
                csr_rdata_tmp[CSR_MSTATUS_MIE_BIT]  = mstatus.mie;
                csr_rdata_tmp[CSR_MSTATUS_MPIE_BIT] = mstatus.mpie;
                csr_rdata_tmp[CSR_MSTATUS_MPP_HBIT
                             :CSR_MSTATUS_MPP_LBIT] = {2{mstatus.mpp}};
                csr_rdata_tmp[CSR_MSTATUS_MPRV_BIT] = mstatus.mprv;
            end
            
            //misa
            CSR_MISA: begin
                csr_rdata_tmp = MISA_VALUE;
            end
            
            //mtvec: trap-vector base address
            CSR_MTVEC    : csr_rdata_tmp = mtvec;
            
        // Machine trap handling
            //mstratch
            CSR_MSCRATCH : csr_rdata_tmp = mscratch;
            
            //mepc: Machine exception pc
            CSR_MEPC     : csr_rdata_tmp = mepc;
            
            //mcause: Machine trap cause
            CSR_MCAUSE   : csr_rdata_tmp = {mcause[5], 26'b0, mcause[4:0]};
            
            //mtval: Machine bad address or instruction
            CSR_MTVAL    : csr_rdata_tmp = mtval;
            
        // Machine Counter/Timers
            //mcycle, minstret
            CSR_MCYCLE,
            CSR_MINSTRET,
            CSR_CYCLE    : csr_rdata_tmp = mct[mctcounter][31:0];
            //mcycleh, minstreth
            CSR_MCYCLEH,
            CSR_MINSTRETH: csr_rdata_tmp = mct[mctcounter][63:32];
            
            //CSR_MHARTID //mhartid
            default      : csr_rdata_tmp = mhartid; 
        endcase
    end
    
    
    //CSR write
    Mstatus_t    mstatus_next;
    logic [31:0] mtvec_next;
    logic [31:0] mscratch_next;
    logic [31:0] mepc_next;
    logic [5:0]  mcause_next; //1bit for interrupt, 5bits for Exception Code
    logic [31:0] mtval_next;
    logic [63:0] mcycle_next;
    logic [63:0] minstret_next;
    
/*    assign mstatus_next = '{
            mie:  csr_wdata_tmp[CSR_MSTATUS_MIE_BIT],
            mpie: csr_wdata_tmp[CSR_MSTATUS_MPIE_BIT],
            mpp:  {2{csr_wdata_tmp[CSR_MSTATUS_MPP_HBIT]
                    |csr_wdata_tmp[CSR_MSTATUS_MPP_LBIT]}},//00 is u-mode, others are m-mode
            mprv: csr_wdata_tmp[CSR_MSTATUS_MPRV_BIT]
        };
    
    // mtvec
    // mtvec.MODE set to vectored
    // mtvec.BASE must be 256-byte aligned
    assign mtvec_next    = {csr_wdata_tmp[31:8], 6'b0, 2'b01};
    
    assign mscratch_next =  csr_wdata_tmp;
    
    // mepc: exception program counter
    assign mepc_next     = {csr_wdata_tmp[31:1], 1'b0};
    
    assign mcause_next   = {csr_wdata_tmp[31], csr_wdata_tmp[4:0]};*/

    logic instret_en;
    assign instret_en    = ~stall_i & /*~flush_i &*/ ~inst_zero_en_i;
    logic cycle_en;
    logic load_store_en;
    logic rvc_en;
    logic rvc_ls_en; //c.lw, c.sw, c.swsp, c.lwsp
    logic rv32_ls_en;
    
    assign rvc_en        = ~(opcode_idex_i[1:0] == 2'b11);
    assign rvc_ls_en     = ~opcode_idex_i[0] & ( fun3_rvc_idex_i==3'b010 | fun3_rvc_idex_i==3'b110 );
    assign rv32_ls_en    = opcode_idex_i[6:2] == LOAD || opcode_idex_i[6:2] == STORE;
    assign load_store_en = rvc_en ? rvc_ls_en : rv32_ls_en;
    
    assign cycle_en      = ~(load_store_en & stall_i) & ~inst_zero_en_i;
    
    assign mcycle_next   =  mct [0] + {cycle_en};//64'b1;
    assign minstret_next =  mct [1] + {instret_en};
    
    
    
    logic [31:0]       csr_wdata_tmp;
    always_comb begin : csr_write
        mstatus_next  = mstatus;
        mtvec_next    = mtvec;
        mscratch_next = mscratch;
        mepc_next     = mepc;
        mcause_next   = mcause;
        mtval_next    = mtval;
        
        if (csr_we_int) begin
          case (csr_addr_i)
              CSR_MSTATUS: begin
                  mstatus_next = '{
                    mie:  csr_wdata_tmp[CSR_MSTATUS_MIE_BIT],
                    mpie: csr_wdata_tmp[CSR_MSTATUS_MPIE_BIT],
                    mpp:  {2{csr_wdata_tmp[CSR_MSTATUS_MPP_HBIT]
                          |csr_wdata_tmp[CSR_MSTATUS_MPP_LBIT]}},//00 is u-mode, others are m-mode
                    mprv: csr_wdata_tmp[CSR_MSTATUS_MPRV_BIT]
                  };
              end
              
                  // mtvec
                  // mtvec.MODE set to direct
              CSR_MTVEC: begin
                  mtvec_next    = {csr_wdata_tmp[31:2], 2'b00}; //2'b01};
              end
    
              CSR_MSCRATCH: begin
                  mscratch_next =  csr_wdata_tmp;
              end
    
              // mepc: exception program counter
              CSR_MEPC: begin
                  mepc_next     = {csr_wdata_tmp[31:1], 1'b0};
              end
    
              CSR_MCAUSE: begin
                  mcause_next   = {csr_wdata_tmp[31], csr_wdata_tmp[4:0]};
              end
              
              CSR_MTVAL: begin
                  mtval_next    = csr_wdata_tmp;
              end
              default:;
          endcase
        end
        
        // exception controller
        if(sys_call_en_i) begin   //ecall
            priv_lvl_next = PRIV_LVL_M;
                
            mepc_next   = pc_idex_i;
            mcause_next = {1'b0, 5'd11}; //Environment call from M-mode
            
            mstatus_next.mie  = 1'b0;
            mstatus_next.mpie = mstatus.mie;
            mstatus_next.mpp  = priv_lvl;
        end
        
        if(excep_en_i) begin
            priv_lvl_next = PRIV_LVL_M;
                
            mepc_next   = pc_idex_i; //32'h0000213c;
            mcause_next = {1'b0, 5'd2}; 
            
            mstatus_next.mie  = 1'b0;
            mstatus_next.mpie = mstatus.mie;
            mstatus_next.mpp  = priv_lvl;
        end

        if(mret_en_i) begin   //mret
            priv_lvl_next = mstatus.mpp;
            
            mstatus_next.mie  = mstatus.mpie;
            mstatus_next.mpie = 1'b1;
            mstatus_next.mpp  = PRIV_LVL_U;

        end

    end
    
    // CSR operation logic
    logic csr_wreq;
    always_comb begin
        csr_wreq = 1'b1;
        unique case (csr_op_i)
            CSR_OP_WRITE: csr_wdata_tmp =  csr_wdata_i;
            CSR_OP_SET:   csr_wdata_tmp =  csr_wdata_i | csr_rdata_o;
            CSR_OP_CLEAR: csr_wdata_tmp = ~csr_wdata_i & csr_rdata_o;
            CSR_OP_READ: begin
                csr_wdata_tmp = csr_wdata_i;
                csr_wreq      = 1'b0;
            end
            default: begin
                csr_wdata_tmp = 'X;
                csr_wreq      = 1'bX;
            end
        endcase
    end
    
    // only write CSRs during one clock cycle
    logic csr_we_int; //write csr enable
    assign csr_we_int  = csr_wreq;// & ~illegal_csr_insn_o & instr_new_id_i;
    
    // directly output
    assign csr_mtvec_o = mtvec;
    assign csr_mepc_o  = mepc;
    
    
    //update
    always_ff @(posedge clk) begin
        if(rst == RstEnable) begin
            // Privileged mode
            priv_lvl       <= PRIV_LVL_M;
            // Machine trap setup
            mstatus        <= '{
                    mie:  1'b0,
                    mpie: 1'b1,
                    mpp:  PRIV_LVL_U,
                    mprv: 1'b0
                };
            mtvec          <= 32'b00; // 32'b01
            // Machine trap handling
            mscratch       <= '0;
            mepc           <= '0;
            mcause         <= '0;
            mtval          <= '0;
            //mcycle, minstret
            mct [0] <= '0;
            mct [1] <= '0;
        end else begin
            // Privileged mode
            //priv_lvl       <= priv_lvl_next;
            // Machine trap setup
            mstatus        <= mstatus_next;
            mtvec          <= mtvec_next;
            // Machine trap handling
            mscratch       <= mscratch_next;
            mepc           <= mepc_next;
            mcause         <= mcause_next;
            mtval          <= mtval_next;
            //mcycle, minstret
            mct [0]        <= mcycle_next;
            mct [1]        <= minstret_next;
        end
    end
endmodule