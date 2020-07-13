/*
��������ת��������
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

  		//��ȡ�ļ��Ĵ�С 
		size = GetBinSize(srcbin); 
		printf("%s, size: %d\n", srcbin, size); 
		//�������ڴ�Ÿ��ļ������� 
		buf = (unsigned char *)malloc(sizeof(unsigned char)*(size+4));
		memset(buf, 0, sizeof(unsigned char)*(size+4));
		//��ȡ�ļ� 
		read_bin(srcbin, buf, size);  	  
		//�������ڴ�Ÿ��ļ������� 
		//mem = (unsigned long *)malloc(sizeof(unsigned long)*(size/sizeof(unsigned long)));
		//memset(mem, 0, sizeof(unsigned long)*(size/sizeof(unsigned long)));
		//����ͷ�ļ�����ͷ�ļ��º����������飬һ���������ݵģ�����һ����ȫ0����
		//ȫ0��Ҫ���ã��Ժ�Ҫ��տ��Ե���������� 
		OutPut_handle(mem, buf, size); 
		
		free(buf); 
		//free(mem); 


    return 0;  
}  
 