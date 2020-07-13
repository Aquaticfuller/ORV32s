ORV32
=====

About
-----

2-stage pipeline version ORV32 for embedded and low-power controllers, 
with modified RISC-V simulator from spike

Directory Structure
-------------------
```
     .
     ├── rtl                                      ORV32s RTL description using SystemVerilog code
     │   ├── core
     │   ├── lib
     │   └── memory
     ├── sim_core_asm_nocache_withspike           Single core ORV32s with referring to RISC-V golden model
     ├── sim_core_c_mesicache_nospike             Multicore ORV32s with Cache Coherency Simulator(MESI protocol)
     ├── sim_core_c_msicache_nospike              Multicore ORV32s with Cache Coherency Simulator(MSI protocol)
     │   ├── sim_coremark                         Coremark benchmark
     │   ├── sim_dhrystone                        Dhrystone benchmark
     │   ├── sim_embench                          Embench benchmark
     │   └── sim_multicore_matmul                 Matrix multiplication simulation
     └── sim_core_rvunittest_nocache_nospike      ORV32s unit-test
```

Prerequisites
-------------
1.[Verilator: SystemVerilog Translator and simulator](https://www.veripool.org/projects/verilator/wiki/Installing)
    
   Please use the 3rd method(Git) to install to make sure your verilator is up-to-date.
   The project is developed under the Verilator with version 4.022.
	
2.[Gtkwave: Wave viewer](http://gtkwave.sourceforge.net/)

3.[RISC-V GNU Compiler Toolchain](https://github.com/riscv/riscv-gnu-toolchain).
   
   Please make sure you have at least installed with 32-bit RV toolchain, and the 64-bit version is also recommended.
 * Choose Newlib for installation.
 * For 32-bit toolchain compiling, the configuration should be: ```./configure --prefix=/opt/riscv --with-arch=rv32gc --with-abi=ilp32d```
 * To add ```$PATH```into PATH,  If you choose, say, ```/opt/riscv``` as prefix:

        $ vim ~/.bashrc
      append ```export PATH=$PATH:/opt/riscv/bin``` into .bashrc, then save & exit
        
        $ source ~/.bashrc

4.Set ORV32s PATH ```ORV32S```

 * If you place the project at, say, ```/opt/ORV32s```

        $ vim ~/.bashrc
      append ```export ORV32S=/opt/ORV32s``` into .bashrc, then save & exit
        $ source ~/.bashrc
   
Related Tools
-------------
[riscv-tools](https://github.com/riscv/riscv-tools)
   Riscv tools recommended to install.
 * If you want to compile rv32 pk, and you have set ```RISCV``` to your riscv path, say ```/opt/riscv```
   get into folder ```$RISCV/riscv-tools/riscv-pk/build``` and use the following configuration:
   ```
    ../configure --prefix=/opt/riscv --host=riscv32-unknown-elf --with-arch=rv32gc --with-abi=ilp32d
    make
    make install
   ```

Build Steps for RISC-V Simulator
--------------------------------
The simulator is modified from [Spike](https://github.com/riscv/riscv-isa-sim). 
We assume that the ```$RISCV``` environment variable is set to the RISC-V tools installation path, 
for example ```/opt/riscv```

     $ cd $ORV32S/mine_spike/riscv-isa-sim/
     $ mkdir build
     $ cd build
     $ ../configure
     $ make
	
Build & Run ORV32s unit-test
----------------------------
We provide user with rv32 unit tests based on standard unit-test in [riscv-tools](https://github.com/riscv/riscv-tools). 
As the ORV32s supports IMC extensions, this unit test suite is modified from rv32ui, rv32um, rv32uc unit-test.


 * Firstly, you should build the unit test binary files:
    
        $ cd $ORV32S/sim_core_rvunittest_nocache_nospike/isa_processor/
        $ make

 * Then, you can compile the rtl and simulation file to run rv32 unit-test, 
   and check the instructions supported by ORV32s

        $ cd $ORV32S/sim_core_rvunittest_nocache_nospike/unit_test_sim
        $ make
        $ make run

Run ORV32s Multicore with Coherent Cache Simulator
--------------------------------------------------

### Coherent Cache Simulator system overview

The program uses SystemVerilog to build rtl for each core L1 data cache and cache controller, 
uses C++ program to simulate the snooping control unit (SCU) and Interconnect Bus, 
and links the C++ part with SystemVerilog part through the direct programming interface (DPI). 

### Coherent Cache design

Now the simulator support snoopy based MSI cache coherent protocol, which can handle up to 8 cores, 
and will add MESI protocol version based on TileLink 5-channel recently.

The parameter of L1 data cache is as follows:

| L1 data cache capacity | Cache line numbers | Cache line capacity | Mapping method |
| :--------------------: | :----------------: | :-----------------: | :------------: |
| 32 KBytes              | 1024               | 32 Bytes            | direct map     |

### Build & Run the Simulator

We provide user with a matrix multiplication program, which illustrate the traffic and 
performance of coherent cache

 * Build the test program

        $ cd $ORV32S/sim_core_c_msicache_nospike/sim_multicore_matmul/test_programs/matmul/
        $ make

 * Build the simulator

        $ cd $ORV32S/sim_core_c_msicache_nospike/sim_multicore_matmul/
        $ make
    
 * Run the test program
    
        $ cd $ORV32S/sim_core_c_msicache_nospike/sim_multicore_matmul/obj_dir/
        $ ./Vtestbench +trace

Run ORV32s Benchmarks
---------------------
So far we have provided usr with 3 benchmarks, namely dhrystone, coremark and embench(matmult)

 * Dhrystone
 
   Build Dhrystone program
   
        $ cd $ORV32S/sim_core_c_msicache_nospike/benchmarks
        $ make

   Build the simulator
   
        $ cd $ORV32S/sim_core_c_msicache_nospike/sim_dhrystone
        $ make

   Run Dhrystone
      
        $ cd $ORV32S/sim_core_c_msicache_nospike/sim_dhrystone/obj_dir/
        $ ./Vtestbench ../dhrystone.bin +trace

 * Coremark
    
   Build Coremark program
   
        $ cd $ORV32S/riscv-coremark/
        $ ./build-coremark.sh
   
   Build the simulator
   
        $ cd $ORV32S/sim_core_c_msicache_nospike/sim_coremark
        $ make

   Run Coremark
      
        $ cd $ORV32S/sim_core_c_msicache_nospike/sim_coremark/obj_dir/
        $ ./Vtestbench ../../../riscv-coremark/coremark.bare.bin +trace
  
 * Embench
    
   Build Embench program
   
        $ cd $ORV32S/embench-iot/
        $ ./build_all.py --arch native  --chip default --board default
   
   Build the simulator
   
        $ cd $ORV32S/sim_core_c_msicache_nospike/sim_embench
        $ make

   Run Embench matmult-int
      
        $ cd $ORV32S/sim_core_c_msicache_nospike/sim_embench/obj_dir/
        $ ./Vtestbench ../embench.matmult-int.bin  +trace
    
   

Run ORV32s with referring to RISC-V golden model
------------------------------------------------

To make sure user's customed modification on ORV32s rtl is correct, 
we provide user with a test program referring to RISC-V golden instruction-by-instruction, 
the program can verify the correction of the output by ORV32s by checking 
the result of general purpose registers in both ORV32s and RISC-V golden model.

The RISC-V golden model is modified from [Spike](https://github.com/riscv/riscv-isa-sim)

 * Build & Run asm program with referring to RISC-V golden model

        $ cd $ORV32S/sim_core_asm_nocache_withspike/
        $ make
   
   And the then you will see a view of GPRs, CSRs, PC, current privilege mode etc. internal parameters 
   of ORV32s, and the value of 32 GPRs are compared with RV golden model to ensure the instruction
   implementations in ORV32s have right outputs.

 * To change the instructions running in the ORV32s, edit the file: 
``` $ORV32S/sim_core_asm_nocache_withspike/code_run_by_proc/inst_rom.S```

 * To change the instructions running in the RV golden model, edit the file: 
``` $ORV32S/sim_core_asm_nocache_withspike/code_run_by_sim/mine/mine.c```
	
Plase make sure the Processor and the Simulator are running 
the same set of instructions, as it would turn out error when 
the value inconsistence happens in general registers between 
the ORV32s Processor and the RV golden model simulator.

Check the Waveform file
-----------------------

With the argument ```+trace``` after ```./Vtestbench```, 
the program will produce a waveform file with suffix ```.vcd``` in the folder ```logs``` 
under its corresponding folder prefixed with ```sim_```.
	
To check the waveform file, we use [Gtkwave](http://gtkwave.sourceforge.net/), 
say the ```.vcd``` file named ```vlt_dump.vcd```:

     $ gtkwave vlt_dump.vcd
