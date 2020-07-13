#VERILATOR = verilator
RTL_CORE_PATH = ../../rtl/core
RTL_LIB_PATH  = ../../rtl/lib
RTL_MEM_PATH  = ../../rtl/memory
VERILATOR_FILES = testbench.sv \
	$(RTL_LIB_PATH)/libcsr.sv $(RTL_LIB_PATH)/libopcode.sv $(RTL_LIB_PATH)/liborv32s.sv \
	$(RTL_LIB_PATH)/libdecode.sv $(RTL_LIB_PATH)/libalu.sv \
	$(RTL_MEM_PATH)/inst_rom.sv $(RTL_MEM_PATH)/data_cache.sv  \
	$(RTL_CORE_PATH)/orv32s_top.sv $(RTL_LIB_PATH)/libdefine.sv \
	$(RTL_CORE_PATH)/if_stage.sv $(RTL_CORE_PATH)/ex_stage.sv $(RTL_CORE_PATH)/decode.sv  \
	$(RTL_CORE_PATH)/load_store_unit.sv $(RTL_CORE_PATH)/im_access.sv \
	$(RTL_CORE_PATH)/inst_buffer.sv  \
	$(RTL_CORE_PATH)/regfile.sv  $(RTL_CORE_PATH)/cs_registers.sv  $(RTL_CORE_PATH)/alu.sv $(RTL_CORE_PATH)/branch_compare.sv \
	$(RTL_CORE_PATH)/multiplier_fast.sv $(RTL_CORE_PATH)/divider_nonrestoring.sv \
	$(RTL_CORE_PATH)/controller.sv      --exe bin2cm.c  sim_main.cpp

LIB_PATH = ../../mine_spike/riscv-isa-sim/build

LIB_FILES = ../$(LIB_PATH)/libspike.a  ../$(LIB_PATH)/libspike_main.a  ../$(LIB_PATH)/libriscv.a ../$(LIB_PATH)/libsoftfloat.a ../$(LIB_PATH)/libfesvr.a  #$(LIB_PATH)/spike.o

SPIKE_FILE_PATH = ./spike_no_pk/benchmarks
TEST_PROCESSOR_PATH = ../../riscv-tests/isa_processor/rv32ui-p-slti
default:

	riscv32-unknown-elf-objcopy -O binary ../benchmarks/dhrystone.riscv dhrystone.bin
	-mkdir obj_dir
	ar rcs $(LIB_PATH)/libspike.a $(LIB_PATH)/spike.o  $(LIB_PATH)/libspike_main.a  \
	$(LIB_PATH)/libriscv.a  $(LIB_PATH)/libsoftfloat.a  $(LIB_PATH)/libfesvr.a

	verilator  -Wno-fatal  --cc --trace  $(VERILATOR_FILES)  $(LIB_FILES) -LDFLAGS "-ldl -lpthread"
	
	make -j$(nproc) -C obj_dir -f Vtestbench.mk Vtestbench
	#cd obj_dir/ && ./Vtestbench ../dhrystone.bin +trace

	
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
	
run:
	cd obj_dir/ && ./Vtestbench ../dhrystone.bin +trace
clean:
	rm -r obj_dir
	rm bin2Mem inst_rom.bin inst_rom.data3 \
	inst_rom.o inst_rom.om *.riscv *.data *.bin
