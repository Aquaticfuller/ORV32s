    .org 0x0
    .global _start

_start:
li ra,0x0
li sp,0x8000

li  x5,0xdeadbeef
sw  x5,0(ra)

li  x6,0xabcdef
sw  x6,0(sp)


nop
nop
nop

