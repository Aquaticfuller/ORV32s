default:
	riscv32-unknown-elf-as load_4core_fair_loop.S -o load_4core.o
	riscv32-unknown-elf-ld -T load_1core.ld load_4core.o -o load_4core.om
	riscv32-unknown-elf-objcopy -O binary load_4core.om load_4core.bin
	riscv32-unknown-elf-objdump -d load_4core.o -M no-aliases,numeric 

	riscv32-unknown-elf-as load_2core_fair_loop.S -o load_2core.o
	riscv32-unknown-elf-ld -T load_1core.ld load_2core.o -o load_2core.om
	riscv32-unknown-elf-objcopy -O binary load_2core.om load_2core.bin
	riscv32-unknown-elf-objdump -d load_2core.o -M no-aliases,numeric

	riscv32-unknown-elf-as load_1core.S -o load_1core.o
	riscv32-unknown-elf-ld -T load_1core.ld load_1core.o -o load_1core.om
	riscv32-unknown-elf-objcopy -O binary load_1core.om load_1core.bin
	riscv32-unknown-elf-objdump -d load_1core.o -M no-aliases,numeric

	riscv32-unknown-elf-as load_8core.S -o load_8core.o
	riscv32-unknown-elf-ld -T load_1core.ld load_8core.o -o load_8core.om
	riscv32-unknown-elf-objcopy -O binary load_8core.om load_8core.bin
	riscv32-unknown-elf-objdump -d load_8core.o -M no-aliases,numeric 

clean:
	rm *.o *.om *.bin