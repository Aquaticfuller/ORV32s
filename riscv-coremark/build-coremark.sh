#!/bin/bash

set -e

BASEDIR=$PWD
CM_FOLDER=coremark

cd $BASEDIR/$CM_FOLDER

# run the compile
echo "Start compilation"
make PORT_DIR=../riscv32 compile
mv coremark.riscv ../

make PORT_DIR=../riscv32-baremetal compile
mv coremark.bare.riscv ../

cd ..
riscv64-unknown-elf-objdump --disassemble-all --disassemble-zeroes -M numeric coremark.riscv > coremark.riscv.dump
riscv64-unknown-elf-objdump --disassemble-all --disassemble-zeroes -M no-aliases,numeric coremark.bare.riscv > coremark.bare.riscv.dump
riscv32-unknown-elf-objcopy -O binary  coremark.bare.riscv  coremark.bare.bin
