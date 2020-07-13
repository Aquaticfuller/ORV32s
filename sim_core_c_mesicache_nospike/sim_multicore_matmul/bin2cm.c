/*
将二进制转化成数组
*/

//#include <stdio.h>  
//#include <stdlib.h>  
//#include <string.h>
//#include <fcntl.h>
//#include <unistd.h>
//#include <math.h>
//#define DIVIDE_SIZE 8 //8 byte per line
//typedef unsigned char u8;
//typedef unsigned int  u32;
#include "func.h"

void read_bin(char *path, u8 *buf, u32 size)  
{  
    FILE *infile;  
      
    if((infile=fopen(path,"rb"))==NULL)  
    {  
        printf( "\nCan not open the path: %s \n", path);  
        exit(-1);  
    }  
    fseek(infile,0L,SEEK_SET);
    int recive=fread(buf, sizeof(u8), size, infile);
    fclose(infile);  
//    int i=0;
//    for(i=0;i<10;i++)
//    printf("%d,%d,%d : %x\n",size,recive, 5363+i, buf[5363+i]);
} 
u32 GetBinSize(char *filename)  
{     
    u32  siz = 0;     
    FILE  *fp = fopen(filename, "rb");     
    if (fp)   
    {        
        fseek(fp, 0, SEEK_END);        
        siz = ftell(fp);        
        fclose(fp);     
    }     
    return siz;  
} 
void OutPut_handle(unsigned long *mem, u8 *buf, u32 size)  
{  
    int i,j,n;
    int k = 0; 
    int fd ;
    char pbuf[10]={0};  
         
    for(i = 0; i < size/sizeof(unsigned long); i++)  
    {  
    	      //int reverse;
    	      //reverse = (i/8+1)*8-1-i+(i/8)*8;
            for(k = 0; k < DIVIDE_SIZE; k++)
            {
              //long iData;
              //sscanf( buf+i*DIVIDE_SIZE+k, "%lx", &iData );
             // printf("%x ",*(buf+i*DIVIDE_SIZE+k));
             // printf("%lx \n",iData);
             unsigned long tmp = 1;
             for (n=0;n<2*k;n++)
             {
             	tmp *= 16;
             }
            	mem[i]+= *(buf+i*DIVIDE_SIZE+k) * tmp;

            }
            //printf("line%4x: 0x%16lx\n", i, mem[i]);
            //getchar();
    }  
}   
 
int bin2cm(char source[], unsigned long *mem)  
{ 
	u8 *buf = NULL;  
	//unsigned long* mem =NULL;
	u32 size;  

  int i = 0;
  
  	char srcbin[200];	
  	strcpy(srcbin,source);

  		//获取文件的大小 
		size = GetBinSize(srcbin); 
		printf("%s, size: %d\n", srcbin, size); 
		//申请用于存放该文件的数组 
		buf = (unsigned char *)malloc(sizeof(unsigned char)*(size+4));
		memset(buf, 0, sizeof(unsigned char)*(size+4));
		//读取文件 
		read_bin(srcbin, buf, size);  	  
		//申请用于存放该文件的数组 
		//mem = (unsigned long *)malloc(sizeof(unsigned long)*(size/sizeof(unsigned long)));
		//memset(mem, 0, sizeof(unsigned long)*(size/sizeof(unsigned long)));
		//制作头文件，该头文件下含有两个数组，一个是有数据的，另外一个是全0数组
		//全0主要备用，以后要清空可以调用这个数组 
		OutPut_handle(mem, buf, size); 
		
		free(buf); 
		//free(mem); 


    return 0;  
}  
 