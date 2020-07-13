/*************************************************************************
	> File Name: mine.c
	> Author: Fu zexin
	> Mail: fuzexinxin@qq.com 
	> Created Time: Thu Feb 20 23:50:48 2020
 ************************************************************************/

volatile int main()
{
  asm volatile (
           "li  x1, 0\n\t"
           "li  x2, 0\n\t"
           "li  x3, 0\n\t"
           "li  x4, 0\n\t"
           "li  x5, 0\n\t"
           "li  x6, 0\n\t"
           "li  x7, 0\n\t"
           "li  x8, 0\n\t"
           "li  x9, 0\n\t"
           "li  x10,0\n\t"
           "li  x11,0\n\t"
           "li  x12,0\n\t"
           "li  x13,0\n\t"
           "li  x14,0\n\t"
           "li  x15,0\n\t"
           "li  x16,0\n\t"
           "li  x17,0\n\t"
           "li  x18,0\n\t"
           "li  x19,0\n\t"
           "li  x20,0\n\t"
           "li  x21,0\n\t"
           "li  x22,0\n\t"
           "li  x23,0\n\t"
           "li  x24,0\n\t"
           "li  x25,0\n\t"
           "li  x26,0\n\t"
           "li  x27,0\n\t"
           "li  x28,0\n\t"
           "li  x29,0\n\t"
           "li  x30,0\n\t"
           "li  x31,0\n\t"
           "addi sp,sp,-8\n\t"
  //////change the instructions below for custom simulation////////
          "li s1,0xfedcba98\n\t"
          "li s2,0x02345678\n\t"
		  "slli s2,s2,0x4\n\t"
          "sw s1,0(sp)\n\t"
          "sw s2,4(sp)\n\t"
          "lw s3,0(sp)\n\t"
          "lw s4,4(sp)\n\t"
		  "addi s3,x0,0x7ff\n\t"
		  "c.slli s3,4\n\t"
		  "addi s3,x0,0x6\n\t"
		  "sra s2,s2,s3\n\t"
		  "bge s2,s3,a\n\t"
		  "mul s5,s1,s2\n\t"
		  "a: mulhu s6,s1,s2\n\t"
		  "mulh s7,s1,s2\n\t"
		  "mulhsu s8,s1,s2\n\t"
		  "divu s9,s1,s2\n\t"
		  "remu s9,s1,s2\n\t"
 ///////////////////////////////////////////////////////
		  "nop\n\t"
		  "nop\n\t"
		  "nop\n\t"
  );
	//asm volatile ("");
//  volatile int a =1;
//  volatile int b =2;
//  volatile int c;
//  c =b/a;
//
//  return c;
}
