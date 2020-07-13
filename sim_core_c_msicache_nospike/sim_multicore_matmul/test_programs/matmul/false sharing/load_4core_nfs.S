    .org 0x0
    .option rvc
    .global _start

_start:
    li s0,0x100000 # load data memory start at 1 MB memory #x8
    li s1,0x300000 # store data memory start at 3MB memory #x9
	li s2,0x8000   # hart 1 store offset
	li s3,0x10000  # hart 2 store offset
	li s4,0x18000  # hart 3 store offset

    li t0,0  # i = 0;
    csrr s5, mhartid # get mhartid
    j judgloop
mainloop:
hart0:
    li x15, 0
 	bne	s5,x15,hart1  #mhartid == 0?

 	mv   x15,t0
   	slli x15,x15,0x5  # offset 16 bytes for 2 2*2 matrix
   	add	 x15,x15,s0

 	lw	 x14, 0(x15) # x14 = A[i][0]

 	mv   x15,t0      # x15 =i
   	slli x15,x15,0x5 # backet offset
 #   li   x12,1
 #   slli x12,x12,0x4 # inside backet offset
 #   add  x15,x15,x12 # total offset
   	add	 x15,x15,s0  # addr = offset + base

 	lw	x15, 16(x15)  # x15 = B[i][0]

 	mul	x14,x14,x15   # x14 = A[i][0]*B[i][0]

 	mv   x15,t0
   	slli x15,x15,0x5  # offset 16 bytes for 2 2*2 matrix
   	add	 x15,x15,s0

 	lw	x13, 4(x15)  # x13 = A[i][1]

 	mv   x15,t0
   	slli x15,x15,0x5  # offset 16 bytes for 2 2*2 matrix
   	add	 x15,x15,s0

 	lw	x15, 24(x15)  # x15 = B[i][2]

 	mul	x15,x13,x15   # x15 = A[i][1]*B[i][2]

   	add	x14,x14,x15   # x14 = A[i][0]*B[i][0] + A[i][1]*B[i][2]

    mv   x15,t0
   	slli x15,x15,0x2  # offset 4 bytes for 1 byte
   	add	 x15,x15,s1

 	sw	x14, 0(x15) # store  output[i][0] = A[i][0]*B[i][0] + A[i][1]*B[i][2]
   	j  plusi

hart1:
    li x15, 1
 	bne	s5,x15,hart2  #mhartid == 1?

 	mv   x15,t0
   	slli x15,x15,0x5  # offset 16 bytes for 2 2*2 matrix
   	add	 x15,x15,s0

 	lw	 x14, 0(x15) # x14 = A[i][0]

 	mv   x15,t0      # x15 =i
   	slli x15,x15,0x5 # backet offset
   	add	 x15,x15,s0  # addr = offset + base

 	lw	x15, 20(x15)  # x15 = B[i][1]

 	mul	x14,x14,x15   # x14 = A[i][0]*B[i][1]

 	mv   x15,t0
   	slli x15,x15,0x5  # offset 16 bytes for 2 2*2 matrix
   	add	 x15,x15,s0

 	lw	x13, 4(x15)  # x13 = A[i][1]

 	mv   x15,t0
   	slli x15,x15,0x5  # offset 16 bytes for 2 2*2 matrix
   	add	 x15,x15,s0

 	lw	x15, 28(x15)  # x15 = B[i][3]

 	mul	x15,x13,x15   # x15 = A[i][1]*B[i][3]

   	add	x14,x14,x15   # x14 = A[i][0]*B[i][1] + A[i][1]*B[i][3]

    mv   x15,t0
   	slli x15,x15,0x2  # offset 4 bytes for 1 byte
   	add	 x15,x15,s1
	add  x15,x15,s2

 	sw	x14, 0(x15) # store  output[i][1] = A[i][0]*B[i][1] + A[i][1]*B[i][3]
   	j  plusi

hart2:
    li x15, 2
 	bne	s5,x15,hart3  #mhartid == 2?

 	mv   x15,t0
   	slli x15,x15,0x5  # offset 16 bytes for 2 2*2 matrix
   	add	 x15,x15,s0

 	lw	 x14, 8(x15) # x14 = A[i][2]

 	mv   x15,t0      # x15 =i
   	slli x15,x15,0x5 # backet offset
   	add	 x15,x15,s0  # addr = offset + base

 	lw	x15, 16(x15)  # x15 = B[i][0]

 	mul	x14,x14,x15   # x14 = A[i][2]*B[i][0]

 	mv   x15,t0
   	slli x15,x15,0x5  # offset 16 bytes for 2 2*2 matrix
   	add	 x15,x15,s0

 	lw	x13, 12(x15)  # x13 = A[i][3]

 	mv   x15,t0
   	slli x15,x15,0x5  # offset 16 bytes for 2 2*2 matrix
   	add	 x15,x15,s0

 	lw	x15, 24(x15)  # x15 = B[i][2]

 	mul	x15,x13,x15   # x15 = A[i][3]*B[i][2]

   	add	x14,x14,x15   # x14 = A[i][2]*B[i][0] + A[i][3]*B[i][2]

    mv   x15,t0
   	slli x15,x15,0x2  # offset 4 bytes for 1 byte
   	add	 x15,x15,s1
	add  x15,x15,s3

 	sw	x14, 0(x15) # store  output[i][2] = A[i][2]*B[i][0] + A[i][3]*B[i][2]
   	j  plusi

hart3:
    li x15, 3
 	bne	s5,x15,plusi  #mhartid == 3?

 	mv   x15,t0
   	slli x15,x15,0x5  # offset 16 bytes for 2 2*2 matrix
   	add	 x15,x15,s0

 	lw	 x14, 8(x15) # x14 = A[i][2]

 	mv   x15,t0      # x15 =i
   	slli x15,x15,0x5 # backet offset
   	add	 x15,x15,s0  # addr = offset + base

 	lw	x15, 20(x15)  # x15 = B[i][1]

 	mul	x14,x14,x15   # x14 = A[i][2]*B[i][1]

 	mv   x15,t0
   	slli x15,x15,0x5  # offset 16 bytes for 2 2*2 matrix
   	add	 x15,x15,s0

 	lw	x13, 12(x15)  # x13 = A[i][3]

 	mv   x15,t0
   	slli x15,x15,0x5  # offset 16 bytes for 2 2*2 matrix
   	add	 x15,x15,s0

 	lw	x15, 28(x15)  # x15 = B[i][3]

 	mul	x15,x13,x15   # x15 = A[i][3]*B[i][3]

   	add	x14,x14,x15   # x14 = A[i][2]*B[i][1] + A[i][3]*B[i][3]

    mv   x15,t0
   	slli x15,x15,0x2  # offset 4 bytes for 1 byte
   	add	 x15,x15,s1
	add  x15,x15,s4

 	sw	x14, 0(x15) # store  output[i][3] = A[i][2]*B[i][1] + A[i][3]*B[i][3]
#   	j  plusi

plusi:         
	addi  t0,t0,1        # -20(s0)++; # i++    # replace it by t0/x5 
judgloop: 
	li  x15,8191            # loop pow(2,15) times 32767 4095 # 64KB
    bge	  x15,t0,mainloop # 1 >= x14, continue loop


end:
    li  t1,100              # tell simulator exe finished
    li  t1,0
    nop
    nop
    nop
	nop

