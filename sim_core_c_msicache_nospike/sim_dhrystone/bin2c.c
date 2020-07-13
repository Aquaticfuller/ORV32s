/*
将二进制转化成数组头文件 
*/

#include <stdio.h>  
#include <stdlib.h>  
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#define DIVIDE_SIZE 8 //8 byte per line
typedef unsigned char u8;
typedef unsigned int  u32;

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
void OutPut_handle(char *outpath, u8 *buf, u32 size, u8 number)  
{  
    FILE *infile; 
    int i,j,k,n;  
    int fd ;
    char pbuf[10]={0};  
    char mfgimage[4096*2];
    
    char array[200] = "static unsigned long ROMimage";
    char s[20];
    sprintf(s,"%d",number);
    strcat(array,s);
    strcat(array,"[IMAGESIZE] = {\n");
   // char *array = "static const unsigned long ROMimage[SPIIMAGESIZE] = {\n";
    
    
    //char *array1 = "static const unsigned long mfgimage[MFGIMAGESIZE] = {\n";
    char s0[100];
    strcpy(s0,"#ifndef SPI_FLASH_H_");
    strcat(s0,s);
    strcat(s0," \n");
    char *Handle = s0;
    
    char s1[100];
    strcpy(s1,"#define SPI_FLASH_H_");
    strcat(s1,s);
    strcat(s1," \n");
    char *Handle1 = s1;
    //char *Handle1 = "#define SPI_FLASH_H_ \n";
    //char *Statement = "#include \"../rv32ui-p.h\"\n";
   // char *SPIIMAGESIZE = "#define SPIIMAGESIZE   411652 \n";
    //char *Statement2 = "extern unsigned long ROMimage[38][IMAGESIZE]; \n";
   // char *SIZE_4K      = "#define SIZE_4K   4096*2 \n";
    char *line_T       = "\n";
    char *EndIF        = "\n#endif \n";
 
    if((infile=fopen(outpath,"wa+"))==NULL)  
    {  
        printf( "\nCan not open the path: %s \n", outpath);  
        exit(-1);  
    }  
    k=0; 
    fwrite(Handle,strlen(Handle),1,infile);
    fwrite(Handle1,strlen(Handle1),1,infile);
   // fwrite(Statement,strlen(Statement),1,infile);
   // fwrite(SPIIMAGESIZE,strlen(SPIIMAGESIZE),1,infile);
    //fwrite(Statement2,strlen(Statement2),1,infile);
    //fwrite(SIZE_4K,strlen(SIZE_4K),1,infile);
    
    
    fwrite(array,strlen(array),1,infile);  
    for(i = 0; i < size+4; i++)  
    {  
    	      int reverse;
    	      reverse = (i/8+1)*8-1-i+(i/8)*8;
            ++k;  
            
            if( k % DIVIDE_SIZE == 1)
            {
           		sprintf(pbuf,"0x%02x",buf[reverse]); 
           	}
            else
          	{
              sprintf(pbuf,"%02x",buf[reverse]);
            }
            //printf("%d: %02x\n",reverse, buf[reverse]);
 
            fwrite(pbuf,strlen(pbuf),1,infile);  
            
            if(k % DIVIDE_SIZE == 0 && i < size+4-1) 
            {
            	fwrite(", ",strlen(", "),1,infile);
            }
      
            if(k==DIVIDE_SIZE)  
            {  
                k=0;  
                fwrite("\n",strlen("\n"),1,infile);  
            }  
    }  
    fseek(infile,0,SEEK_END);  
    if(k == 0)  
        fwrite("};",strlen("};"),1,infile);  
    else  
        fwrite("\n};",strlen("\n};"),1,infile);         
    //在infile文件中和换行 
    fwrite(line_T,strlen(line_T),1,infile);
//    //创建一个文件用于保存零数组 
//    fd = creat("nufile.bin",0777);
//	if(-1 == fd)
//	{
//		perror("creat fair!");
//		return ;
// 	}	 
// 	//偏移写空 
//	int offset = lseek(fd,4096*2,SEEK_END);
//	write(fd,"",1);
//	/**************************************************/
//	//清数组 
//	for(i = 0 ; i < 10 ; i++)
//	   pbuf[i] = 0 ;
//	for(i = 0 ; i < 4096*2 ; i++)
//	   mfgimage[i] = 0 ;
//	//写第二个数组 
//    fwrite(array1,strlen(array1),1,infile);
//    //从空文件里读数据读到mfgimage数组 
//	read(fd,mfgimage,4096*2);
//	//关闭文件句柄 
//	close(fd);
//	//往文件后面继续写数据 
//	k = 0 ;
//	for(i = 0; i < 4096*2; i++)  
//    {  
//           k++;  
//		   sprintf(pbuf,"0x%02x",mfgimage[i]);  
//           fwrite(pbuf,strlen(pbuf),1,infile);  
//           if(k != 16)  
//               fwrite(", ",strlen(", "),1,infile);  
//           else  
//               fwrite(",",strlen(","),1,infile);     
//           if(k==16)  
//           {  
//              k=0;  
//              fwrite("\n",strlen("\n"),1,infile);  
//           }  
//    }  
//    fseek(infile,0,SEEK_END);  
//    if(k == 0)  
//        fwrite("};",strlen("};"),1,infile);  
//    else  
//        fwrite("\n};",strlen("\n};"),1,infile);
//	
//	fwrite(line_T,strlen(line_T),1,infile);
    fwrite(EndIF,strlen(EndIF),1,infile);  
//    //删除当前目录下的一个空洞文件 
//    if(remove("nufile.bin") == 0)
//    	printf("del file success!\n");
//    else
//        printf("del file fair!\n");
    fclose(infile);  
}   
 
int main(int argc,char* argv[])  
{ 
	u8 *buf = NULL;  
	u32 size;  
char  binsource[47+9][50]= {
	                            //rv32ui-p-
															"add",
															"addi",
															"and",
															"andi",
															"auipc",
															"beq",
															"bge",
															"bgeu",
															"blt",
															"bltu",
															"bne",
															"fence_i",
															"jal",
															"jalr",
															"lb",
															"lbu",
															"lh",
															"lhu",
															"lw",
															"lui",
															"or",
															"ori",
															"sb",
															"sh",
															"sw",
															"sll",
															"slli",
															"slt",
															"slti",
															"sltiu",
															"sltu",
															"sra",
															"srai",
															"srl",
															"srli",
															"sub",
															"xor",
															"xori",
															
															//rv32um-p-
															"mul",
                              "mulh",
                              "mulhsu",
                              "mulhu",
															"div",
                              "divu",
                              "rem",
                              "remu",
                              
                              //rv32uc-p-
                              "rvc",
                              
                              //rv32mi-p-
                              "breakpoint",
                              "csr",
                              "illegal",
                              "ma_addr",
                              "ma_fetch",
                              "mcsr",
                              "sbreak",
                              "scall",
                              "shamt"
	};
	//char* srcbin  = argv[1];//"inst_rom.bin";  
	//char* dstfile = argv[2];//"inst_rom.h";
	//读取目标.bin文件 
	//printf("please input src file path\n");  
	//scanf("%s",srcbin);
	
	//创建一个.h头文件用于保存bin转C数组的文件 
	//printf("please input output path\n");
	//scanf("%s",dstfile);
  int i = 0;
  for(i=0;i<47+9;i++)
  {
  	char srcbin[200];
  	char dstfile[200];
  	char prefix[30];
  	
  	if(i<38)
  		strcpy(prefix,"rv32ui-p-");
  	else if(i<46)
  		strcpy(prefix,"rv32um-p-");
  	else if(i<47)
  		strcpy(prefix,"rv32uc-p-");
  	else
  		strcpy(prefix,"rv32mi-p-");
  			
  	char suffix1[30] = ".bin";
  	char suffix2[30] = ".h";
  	
  	strcpy(srcbin,argv[1]);
  	strcat(srcbin,prefix);
  	strcat(srcbin,binsource[i]);
  	strcat(srcbin,suffix1);
  	
  	strcpy(dstfile,argv[2]);
  	strcat(dstfile,prefix);
  	strcat(dstfile,binsource[i]);
  	strcat(dstfile,suffix2);
  	
  	//char* srcbin  = strcatargv[1];//"inst_rom.bin";  
	  //char* dstfile = argv[2];//"inst_rom.h";
  		//获取文件的大小 
		size = GetBinSize(srcbin); 
		printf("%s, size: %d\n", srcbin, size); 
		//申请用于存放该文件的数组 
		buf = (unsigned char *)malloc(sizeof(unsigned char)*(size+4));
		memset(buf, 0, sizeof(unsigned char)*(size+4));
		//读取文件 
		read_bin(srcbin, buf, size);  	  
		//制作头文件，该头文件下含有两个数组，一个是有数据的，另外一个是全0数组
		//全0主要备用，以后要清空可以调用这个数组 
		OutPut_handle(dstfile, buf, size, i); 
		free(buf); 
  }

    return 0;  
}  
 