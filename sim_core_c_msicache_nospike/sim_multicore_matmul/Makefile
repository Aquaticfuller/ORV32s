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

#INCLUDE_PATH = ./include

#INCLUDE = -I$(INCLUDE_PATH)  #-I$(INCLUDE_PATH)/fesvr  -I$(INCLUDE_PATH)/riscv

#LIB_PATH = /mnt/f/2-stage-pipeline/ORV32s/rtl/lib
#LIB_PATH = /mnt/d/IDE/Eclipse/eclipse-workspace-cpp/mine_spike/riscv-isa-sim/build
LIB_PATH = ../../mine_spike/riscv-isa-sim/build

LIB_FILES = ../$(LIB_PATH)/libspike.a  ../$(LIB_PATH)/libspike_main.a  ../$(LIB_PATH)/libriscv.a ../$(LIB_PATH)/libsoftfloat.a ../$(LIB_PATH)/libfesvr.a  #$(LIB_PATH)/spike.o

SPIKE_FILE_PATH = ./spike_no_pk/benchmarks
#spike.o  libspike_main.a  libriscv.a  libsoftfloat.a  libfesvr.a
TEST_PROCESSOR_PATH = ../../riscv-tests/isa_processor/rv32ui-p-slti
default:
	#riscv32-unknown-elf-as inst_rom.S -o inst_rom.o
	#riscv32-unknown-elf-ld -T ram.ld inst_rom.o -o inst_rom.om
	#riscv32-unknown-elf-gcc inst_rom.c -std=gnu99 -O2  -o inst_rom.o
	#riscv32-unknown-elf-objcopy -O binary inst_rom.om inst_rom.bin
	
	
	#riscv32-unknown-elf-objcopy -O binary ../benchmarks/dhrystone.riscv ./test_programs/dhrystone.bin
	#riscv32-unknown-elf-objcopy -O binary ../../riscv-coremark/coremark.bare.riscv ./test_programs/coremark.bare.bin
	
	#riscv32-unknown-elf-objdump -d inst_rom.o -M no-aliases,numeric 
	
	#-mkdir binoutput
	#riscv32-unknown-elf-objcopy -O binary $(TEST_PROCESSOR_PATH) binoutput/inst_rom.bin
	#riscv32-unknown-elf-objdump -d $(TEST_PROCESSOR_PATH) -M no-aliases,numeric 
	#riscv32-unknown-elf-objdump -d $(TEST_PROCESSOR_PATH) -M no-aliases,numeric >binoutput/dump

	#cp ./spike_no_pk/benchmarks/dhrystone.riscv ./
	#cp ./spike_no_pk/benchmarks_proc/dhrystone.riscv ./inst_rom.bin
	#riscv32-unknown-elf-objdump -d inst_rom.bin -M no-aliases,numeric
	
	#gcc bin2Mem.c -o bin2Mem
	#./bin2Mem
	-mkdir obj_dir
	#gcc bin2c.c -o bin2c
	#./bin2c ../isa_processor/ ./obj_dir/ 
	
#	od -Ax -tx1 inst_rom.data3
#	od -An -tx1 inst_rom.data3
    
#	riscv32-unknown-elf-gcc -I$(SPIKE_FILE_PATH)/../env -I$(SPIKE_FILE_PATH)/common -I$(SPIKE_FILE_PATH)/mine \
#	-DPREALLOCATE=1 -mcmodel=medany -static -std=gnu99 -O2 \
#	-ffast-math -fno-common -fno-builtin-printf -o mine.riscv \
#	$(SPIKE_FILE_PATH)/mine/mine.c  $(SPIKE_FILE_PATH)/common/syscalls.c $(SPIKE_FILE_PATH)/common/crt.S \
#	-static -nostdlib -nostartfiles -lm -lgcc -T $(SPIKE_FILE_PATH)/common/test.ld
	

	ar rcs $(LIB_PATH)/libspike.a $(LIB_PATH)/spike.o  $(LIB_PATH)/libspike_main.a  \
	$(LIB_PATH)/libriscv.a  $(LIB_PATH)/libsoftfloat.a  $(LIB_PATH)/libfesvr.a
	#ranlib $(LIB_PATH)/libspike.a
	#cp -r ../include/.         ./obj_dir/
	#cp    ../include/*.h       ./obj_dir/
	#verilator $(INCLUDE)  -Wno-fatal  --cc --trace  $(VERILATOR_FILES)  $(LIB_FILES) -LDFLAGS "-ldl -lpthread"
	verilator  -Wno-fatal  --cc --trace  $(VERILATOR_FILES)  $(LIB_FILES) -LDFLAGS "-ldl -lpthread"
	
	#cp Vtestbench.mk obj_dir/
	make -j$(nproc) -C obj_dir -f Vtestbench.mk Vtestbench
	#cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32uc-p-rvc.bin +trace
	#cd obj_dir/ && ./Vtestbench ../test_programs/load_1core.bin +trace

	
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
#rv32ui
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-add.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-addi.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-and.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-andi.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-auipc.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-beq.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-bge.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-bgeu.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-blt.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-bltu.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-bne.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-fence_i.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-jal.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-jalr.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-lb.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-lbu.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-lh.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-lhu.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-lw.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-lui.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-or.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-ori.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-sb.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-sh.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-sw.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-sll.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-slli.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-slt.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-slti.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-sltiu.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-sltu.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-sra.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-srai.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-srl.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-srli.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-sub.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-xor.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32ui-p-xori.bin +trace 
#rv32um
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32um-p-mul.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32um-p-mulh.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32um-p-mulhsu.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32um-p-mulhu.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32um-p-div.bin +trace
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32um-p-divu.bin +trace
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32um-p-rem.bin +trace
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32um-p-remu.bin +trace
#rv32uc
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32uc-p-rvc.bin +trace
#rv32mi
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32mi-p-breakpoint.bin +trace 
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32mi-p-csr.bin +trace
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32mi-p-illegal.bin +trace
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32mi-p-ma_addr.bin +trace
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32mi-p-ma_fetch.bin +trace
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32mi-p-mcsr.bin +trace
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32mi-p-sbreak.bin +trace
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32mi-p-scall.bin +trace
	cd obj_dir/ && ./Vtestbench ../../isa_processor/rv32mi-p-shamt.bin +trace
	
clean:
	rm -r obj_dir
	rm bin2Mem inst_rom.bin inst_rom.data3 \
	inst_rom.o inst_rom.om *.riscv *.data
