
package libcsr;
// CSR operations
typedef enum logic [1:0] {
	CSR_OP_READ,
	CSR_OP_WRITE,
	CSR_OP_SET,
	CSR_OP_CLEAR
} csr_op_e;

// Privileged mode
typedef enum logic[1:0] {
	PRIV_LVL_M = 2'b11, // MACHINE
	PRIV_LVL_H = 2'b10, // HYPERVISOR
	PRIV_LVL_S = 2'b01, // SUPERVISOR
	PRIV_LVL_U = 2'b00  // USER
} priv_lvl_e;

// CSRs
typedef enum logic[11:0] {
	// Machine information
	CSR_MHARTID   = 12'hF14,

	// Machine trap setup
	CSR_MSTATUS   = 12'h300,// Machine status register.
	CSR_MISA      = 12'h301,// ISA and extensions
	CSR_MTVEC     = 12'h305,// trap-vector base address

	// Machine trap handling
	CSR_MSCRATCH  = 12'h340,// Scratch register for machine trap handlers.
	CSR_MEPC      = 12'h341,// Machine exception pc
	CSR_MCAUSE    = 12'h342,// Machine trap cause.
	CSR_MTVAL     = 12'h343,// Machine bad address or instruction.

	// Machine Counter/Timers
	CSR_MCYCLE         = 12'hB00,
	CSR_MINSTRET       = 12'hB02,	
	CSR_MCYCLEH        = 12'hB80,
	CSR_MINSTRETH      = 12'hB82,
	
	// User Counter/Timers
	CSR_CYCLE          = 12'hC00

} csr_add_e;

parameter int unsigned CSR_MSTATUS_MIE_BIT      = 3; //machine interrupt enable
parameter int unsigned CSR_MSTATUS_MPIE_BIT     = 7; 
parameter int unsigned CSR_MSTATUS_MPP_LBIT     = 11;
parameter int unsigned CSR_MSTATUS_MPP_HBIT     = 12;
parameter int unsigned CSR_MSTATUS_MPRV_BIT     = 17;

endpackage