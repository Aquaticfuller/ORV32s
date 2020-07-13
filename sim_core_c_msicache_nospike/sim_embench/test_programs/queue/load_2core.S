    .org 0x0
    .global _start

_start:
li ra,0x3000
nop
nop

lw  x2,0(ra)
nop
#lw  x2,0(ra)

lw  x3,4(ra)
#lw  x3,4(ra)

lw  x4,8(ra)
#lw  x4,0(ra)

lw  x5,12(ra)
#lw  x5,4(ra)

lw  x6,16(ra)
#lw  x6,0(ra)

lw  x7,20(ra)
#lw  x7,4(ra)

lw  x8,24(ra)
#lw  x8,8(ra)

lw  x9,28(ra)
#lw  x9,12(ra)

lw  x10,32(ra)
#lw  x10,12(ra)

lw  x11,36(ra)
#lw  x11,8(ra)
