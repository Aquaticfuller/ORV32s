default:
	riscv32-unknown-elf-as load_4core_fs.S -o load_4core_fs.o
	riscv32-unknown-elf-ld -T ../load_1core.ld load_4core_fs.o -o load_4core_fs.om
	riscv32-unknown-elf-objcopy -O binary load_4core_fs.om load_4core_fs.bin
	riscv32-unknown-elf-objdump -d load_4core_fs.o -M no-aliases,numeric 

	riscv32-unknown-elf-as load_4core_nfs.S -o load_4core_nfs.o
	riscv32-unknown-elf-ld -T ../load_1core.ld load_4core_nfs.o -o load_4core_nfs.om
	riscv32-unknown-elf-objcopy -O binary load_4core_nfs.om load_4core_nfs.bin
	riscv32-unknown-elf-objdump -d load_4core_nfs.o -M no-aliases,numeric 

clean:
	rm *.o *.om *.bin