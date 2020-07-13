//`timescale 1ns/1ps
module testbench
        #(
        parameter DEPTH     = 32, 
        parameter LINEWIDTH = 64, 
        parameter LINEHIGHT = 65536 + 4096,//2048,
        parameter WIDTH     = 32,
        parameter BlockNumLog2  = $clog2(LINEHIGHT)
        ) (
        //verifying port
        output logic          [31:0]      dff_ireg_ver[0:31],
        output logic          [31:0]      pc_stage2_ver,
        output logic          [31:0]      inst_ver,
        
        output logic          [63:0]      dff_csr_mcycle_ver,
        output logic          [63:0]      dff_csr_minstret_ver,
        
        output logic          [31:0]      dff_csr_misa_ver,
        output logic          [31:0]      dff_csr_mhartid_ver,
        output logic          [31:0]      dff_csr_mstatus_ver,
        output logic          [31:0]      dff_csr_mtvec_ver,
        output logic          [31:0]      dff_csr_mscratch_ver,
        output logic          [31:0]      dff_csr_mepc_ver,
        output logic          [31:0]      dff_csr_mcause_ver,
        output logic          [31:0]      dff_csr_mtval_ver,
        output logic          [2:0]       priv_lvl_ver,
        input  logic [LINEWIDTH-1:0]      inst_mem_i [0:LINEHIGHT-1],
        //////////////////////////////////////////////
        input logic clk,
        input logic rst
        );

    // LSU to data ram interface
    logic [31:0]             data_addr_t2dr;
    logic [31:0]             store_data_t2dr; 
    logic [31:0]             load_data_dr2t;
    logic                    MemR_en_t2dr; 
    logic                    MemW_en_t2dr;
    logic [3:0]              byte_enable_t2dr;
    
    logic                    read_valid_dr2t;
    logic                    write_ready_dr2t;
    // IF to inst rom interface
    logic                    flush;

    logic [63:0]             line_in_ir2t;    //instruction in
    logic                    line_ready_ir2t; //memory system is ready
    logic                    line_valid_ir2t; //instruction   to buffer enable

    logic                    ld_line_t2ir;    //prefetch a line (split transaction)
    logic                    read_finish_t2ir;

    logic                    inst_req_t2ir;    //valid im request
    logic [31:0]             inst_addr_flush_t2ir;
    
    //logic [31:0]             inst_debug;
    //assign inst_debug = $root.orv32s_top0.inst_f2e_stage2;
    //assign inst_debug = $unit::top.orv32s_top0.inst_f2e_stage2;

    assign dff_ireg_ver[1:31]   = orv32s_top0.EX.ir.dff_ireg;
    assign dff_ireg_ver[0]      = '0;
    assign pc_stage2_ver        = orv32s_top0.pc_f2e_stage2;
    assign inst_ver             = orv32s_top0.inst_f2e_stage2;

    assign dff_csr_mcycle_ver   = orv32s_top0.csr0.mct[0][63:0];
    assign dff_csr_minstret_ver = orv32s_top0.csr0.mct[1][63:0];
    
    assign dff_csr_misa_ver     = orv32s_top0.csr0.MISA_VALUE;
    assign dff_csr_mhartid_ver  = orv32s_top0.csr0.mhartid;
    always_comb begin
        dff_csr_mstatus_ver  = '0;
        dff_csr_mstatus_ver[CSR_MSTATUS_MIE_BIT]  = orv32s_top0.csr0.mstatus.mie;
        dff_csr_mstatus_ver[CSR_MSTATUS_MPIE_BIT] = orv32s_top0.csr0.mstatus.mpie;
        dff_csr_mstatus_ver[CSR_MSTATUS_MPP_HBIT
                           :CSR_MSTATUS_MPP_LBIT] = {2{orv32s_top0.csr0.mstatus.mpp}};
        dff_csr_mstatus_ver[CSR_MSTATUS_MPRV_BIT] = orv32s_top0.csr0.mstatus.mprv;
    end
    assign dff_csr_mtvec_ver    = orv32s_top0.csr0.mtvec;
    assign dff_csr_mscratch_ver = orv32s_top0.csr0.mscratch;
    assign dff_csr_mepc_ver     = orv32s_top0.csr0.mepc;
    assign dff_csr_mcause_ver   = orv32s_top0.csr0.mcause;
    assign dff_csr_mtval_ver    = orv32s_top0.csr0.mtval;
    assign priv_lvl_ver         = orv32s_top0.csr0.priv_lvl_o;
    
    orv32s_top orv32s_top0
        (
            .clk                    ( clk                    ), 
            .rst                    ( rst                    ),
            // LSU to data ram interface
            .data_addr_o            ( data_addr_t2dr         ), 
            .data_o                 ( store_data_t2dr        ),
            .line_in_d              ( load_data_dr2t         ), 
            .MemR_o                 ( MemR_en_t2dr           ), 
            .MemW_o                 ( MemW_en_t2dr           ),
            .byte_enable_o          ( byte_enable_t2dr       ),
            
            .read_valid_i           ( read_valid_dr2t        ),  //together with load data
            .write_ready_i          ( write_ready_dr2t       ), //ready to receive store data if set
            // IF to inst rom interface
            .flush_o                ( flush                  ),
        
            .line_in_im2i           ( line_in_ir2t           ),    //instruction in
            .line_ready_im2i        ( line_ready_ir2t        ), //memory system is ready
            .line_valid_im2i        ( line_valid_ir2t        ), //instruction   to buffer enable

            .ld_line_i2im           ( ld_line_t2ir           ),    //prefetch a line (split transaction)
            .read_finish_i2im       ( read_finish_t2ir       ),
    
            .inst_req_i2im          ( inst_req_t2ir          ),    //valid im request
            .inst_addr_flush_i2im   ( inst_addr_flush_t2ir   )
        );
    
    logic [31:0]               data_mem [0:4096-1];
    always_comb  begin
        for (int i=1536;i<1536+18;i++) begin//1536==0x600, accord to data address starts from 0x3000
            data_mem[i*2  ] = inst_mem_i[i][31:0];
            data_mem[i*2+1] = inst_mem_i[i][63:32];
        end
        for (int i=1027;i<1027+18;i++) begin//1027==0x403, accord to data address starts from 0x2018 in rvc
            data_mem[i*2  ] = inst_mem_i[i][31:0];
            data_mem[i*2+1] = inst_mem_i[i][63:32];
        end
    end 

    
    
    
    data_ram ram(
            .clk                    ( clk                    ),
            .rst                    ( rst                    ),
            .data_addr_i            ( data_addr_t2dr         ), 
            .store_data_i           ( store_data_t2dr        ),
            .load_data_o            ( load_data_dr2t         ),
            .MemR_en_i              ( MemR_en_t2dr           ),
            .MemW_en_i              ( MemW_en_t2dr           ),
            .byte_enable_i          ( byte_enable_t2dr       ),
            .read_valid_o           ( read_valid_dr2t        ),  //together with load data
            .write_ready_o          ( write_ready_dr2t       ), //ready to receive store data if set
            /////////////////////////////////////
            .data_mem_i             ( data_mem               )        
        );
    
    inst_rom inst_rom
        (
            .clk                           ( clk                 ),
            .rst                           ( rst                 ),
            .flush                         ( flush               ),
            .ld_line_i                     ( ld_line_t2ir        ),
            .read_finish_i                 ( read_finish_t2ir    ),//buff has finish reading
            .inst_req_i                    ( inst_req_t2ir       ),
            .inst_addr_flush_i             ( inst_addr_flush_t2ir),// pc
            //.instmem_addr_i                ( instmem_addr_t2ir   ), 
        
            .line_out                      ( line_in_ir2t        ),    //instruction in
            .line_ready                    ( line_ready_ir2t     ), //memory system is ready for next fetch
            .line_valid                    ( line_valid_ir2t     ),//instruction input to buffer enable
            //.busy                          ( busy_ir2t           )
            /////////////////////////////////////
            .inst_mem_i                    ( inst_mem_i          )
        );
            
    
    
endmodule