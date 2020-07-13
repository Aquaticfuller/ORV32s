 .org 0x0
 .option rvc
 .section ".text"
 .global _start
_start:
# don't change below:##################
    li sp,0x0
    addi sp,sp,-8
# ######################################



# change the instructions below for custom test:####

    li s1,0xfedcba98
    li s2,0x02345678
    slli s2,s2,0x4
    sw s1,0(sp)
    sw s2,4(sp)
    lw s3,0(sp)
    lw s4,4(sp)
    addi s3,x0,0x7ff
    c.slli s3,4
    addi s3,x0,0x6
    sra s2,s2,s3
    bge s2,s3,a
    mul s5,s1,s2
a:  mulhu s6,s1,s2
    mulh s7,s1,s2
    mulhsu s8,s1,s2
    divu s9,s1,s2
    remu s9,s1,s2
    li  a0,0

# ######################################

# don't change below:##################
    nop
    nop
    nop
# ######################################