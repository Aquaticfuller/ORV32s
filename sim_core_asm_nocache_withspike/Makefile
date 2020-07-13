#VERILATOR = verilator
RTL_CORE_PATH = ../rtl/core
RTL_LIB_PATH  = ../rtl/lib
RTL_MEM_PATH  = ../rtl/memory
VERILATOR_FILES = testbench.sv \
	$(RTL_LIB_PATH)/libcsr.sv $(RTL_LIB_PATH)/libopcode.sv $(RTL_LIB_PATH)/liborv32s.sv $(RTL_LIB_PATH)/libdecode.sv \
	$(RTL_LIB_PATH)/libalu.sv $(RTL_MEM_PATH)/inst_rom.sv $(RTL_MEM_PATH)/data_ram.sv  \
	$(RTL_CORE_PATH)/orv32s_top.sv $(RTL_LIB_PATH)/libdefine.sv \
	$(RTL_CORE_PATH)/if_stage.sv $(RTL_CORE_PATH)/ex_stage.sv $(RTL_CORE_PATH)/decode.sv  \
	$(RTL_CORE_PATH)/load_store_unit.sv $(RTL_CORE_PATH)/im_access.sv \
	$(RTL_CORE_PATH)/inst_buffer.sv  \
	$(RTL_CORE_PATH)/regfile.sv  $(RTL_CORE_PATH)/cs_registers.sv  $(RTL_CORE_PATH)/alu.sv $(RTL_CORE_PATH)/branch_compare.sv \
	$(RTL_CORE_PATH)/multiplier_fast.sv $(RTL_CORE_PATH)/divider_nonrestoring.sv \
	$(RTL_CORE_PATH)/controller.sv      --exe sim_main.cpp

LIB_PATH = ../mine_spike/riscv-isa-sim/build

LIB_FILES = ../$(LIB_PATH)/libspike.a  ../$(LIB_PATH)/libspike_main.a  ../$(LIB_PATH)/libriscv.a ../$(LIB_PATH)/libsoftfloat.a ../$(LIB_PATH)/libfesvr.a  #$(LIB_PATH)/spike.o

SPIKE_FILE_PATH = ./code_run_by_sim
PROC_FILE_PATH  = ./code_run_by_proc

default:
	riscv32-unknown-elf-as $(PROC_FILE_PATH)/inst_rom.S -o inst_rom.o
	riscv32-unknown-elf-ld -T $(PROC_FILE_PATH)/ram.ld inst_rom.o -o inst_rom.om
	riscv32-unknown-elf-objcopy -O binary inst_rom.om inst_rom.bin
	riscv32-unknown-elf-objdump -d inst_rom.o -M no-aliases,numeric 

	gcc bin2c.c -o bin2c
	./bin2c

	riscv32-unknown-elf-gcc -I$(SPIKE_FILE_PATH)/../env -I$(SPIKE_FILE_PATH)/common -I$(SPIKE_FILE_PATH)/mine \
	-DPREALLOCATE=1 -mcmodel=medany -static -std=gnu99  \
	-ffast-math -fno-common -fno-builtin-printf -o mine.riscv \
	$(SPIKE_FILE_PATH)/mine/mine.c  $(SPIKE_FILE_PATH)/common/syscalls.c $(SPIKE_FILE_PATH)/common/crt.S \
	-static -nostdlib -nostartfiles -lm -lgcc -T $(SPIKE_FILE_PATH)/common/test.ld
	
	
	riscv32-unknown-elf-objdump --disassemble-all --disassemble-zeroes mine.riscv > mine.riscv.dump

	ar rcs $(LIB_PATH)/libspike.a $(LIB_PATH)/spike.o  $(LIB_PATH)/libspike_main.a  \
	$(LIB_PATH)/libriscv.a  $(LIB_PATH)/libsoftfloat.a  $(LIB_PATH)/libfesvr.a

	verilator  -Wno-fatal  --cc --trace  $(VERILATOR_FILES)  $(LIB_FILES) -LDFLAGS "-ldl -lpthread"
	
	make  -j -C obj_dir -f Vtestbench.mk Vtestbench
	cd obj_dir/ && ./Vtestbench +trace

	
wall:
	riscv32-unknown-elf-as inst_rom.S -o inst_rom.o
	riscv32-unknown-elf-ld -T ram.ld inst_rom.o -o inst_rom.om
	riscv32-unknown-elf-objcopy -O binary inst_rom.om inst_rom.bin
	riscv32-unknown-elf-objdump -d inst_rom.o -M no-aliases,numeric
	gcc bin2Mem.c -o bin2Mem
	./bin2Mem
	od -Ax -tx1 inst_rom.data3
	od -An -tx1 inst_rom.data3

	verilator  -Wall  --cc --trace $(VERILATOR_FILES)
	
mem:
	riscv32-unknown-elf-as inst_rom.S -o inst_rom.o
	riscv32-unknown-elf-ld -T ram.ld inst_rom.o -o inst_rom.om
	riscv32-unknown-elf-objcopy -O binary inst_rom.om inst_rom.bin
	riscv32-unknown-elf-objdump -d inst_rom.o -M no-aliases,numeric
	gcc bin2Mem.c -o bin2Mem
	./bin2Mem
	od -Ax -tx1 inst_rom.data3
	od -An -tx1 inst_rom.data3
	
debug:
	riscv32-unknown-elf-as inst_rom.S -o inst_rom.o
	riscv32-unknown-elf-ld -T ram.ld inst_rom.o -o inst_rom.om
	riscv32-unknown-elf-objcopy -O binary inst_rom.om inst_rom.bin
	riscv32-unknown-elf-objdump -d inst_rom.o -M no-aliases,numeric
	gcc bin2Mem.c -o bin2Mem
	./bin2Mem
	od -Ax -tx1 inst_rom.data3
	od -An -tx1 inst_rom.data3

	verilator  -Wno-fatal  --cc --trace  $(VERILATOR_FILES)
	
	make  -j -C obj_dir -f Vtestbench.mk Vtestbench
	obj_dir/Vtestbench +trace
	spike  --isa=RV32IMAFDC -d   pk inst_rom.om \
	#until pc 0 0 #until pc 0 0 #r 1 #reg 0
	
clean:
	-rm -r obj_dir logs
	-rm bin2c inst_rom.h *.bin \
	*.riscv *.dump *.o *.om
