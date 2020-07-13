/*
��������ת��������ͷ�ļ� 
*/
//Version:2016.12.16
//author:Y.X.YANG
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
void OutPut_handle(char *outpath, u8 *buf, u32 size)  
{  
    FILE *infile; 
    int i,j,k,n;  
    int fd ;
    char pbuf[10]={0};  
    char mfgimage[4096*2];
    char *array = "static const unsigned long SPIflashimage[SPIIMAGESIZE] = {\n";
    //char *array1 = "static const unsigned long mfgimage[MFGIMAGESIZE] = {\n";
    char *Handle = "#ifndef SPI_FLASH_H_ \n";
    char *Handle1 = "#define SPI_FLASH_H_ \n";
    char *SPI_SPIflash = "#define SPI_SPIflash 0 \n";
    char *SPIIMAGESIZE = "#define SPIIMAGESIZE   411652 \n";
    //char *MFGIMAGESIZE = "#define MFGIMAGESIZE   411652 \n";
    char *SIZE_4K      = "#define SIZE_4K   4096*2 \n";
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
    //fwrite(SPI_SPIflash,strlen(SPI_SPIflash),1,infile);
    fwrite(SPIIMAGESIZE,strlen(SPIIMAGESIZE),1,infile);
    //fwrite(MFGIMAGESIZE,strlen(MFGIMAGESIZE),1,infile);
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
    //��infile�ļ��кͻ��� 
    fwrite(line_T,strlen(line_T),1,infile);
//    //����һ���ļ����ڱ��������� 
//    fd = creat("nufile.bin",0777);
//	if(-1 == fd)
//	{
//		perror("creat fair!");
//		return ;
// 	}	 
// 	//ƫ��д�� 
//	int offset = lseek(fd,4096*2,SEEK_END);
//	write(fd,"",1);
//	/**************************************************/
//	//������ 
//	for(i = 0 ; i < 10 ; i++)
//	   pbuf[i] = 0 ;
//	for(i = 0 ; i < 4096*2 ; i++)
//	   mfgimage[i] = 0 ;
//	//д�ڶ������� 
//    fwrite(array1,strlen(array1),1,infile);
//    //�ӿ��ļ�������ݶ���mfgimage���� 
//	read(fd,mfgimage,4096*2);
//	//�ر��ļ���� 
//	close(fd);
//	//���ļ��������д���� 
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
//    //ɾ����ǰĿ¼�µ�һ���ն��ļ� 
//    if(remove("nufile.bin") == 0)
//    	printf("del file success!\n");
//    else
//        printf("del file fair!\n");
    fclose(infile);  
}   
 
int main()  
{ 
	u8 *buf = NULL;  
	u32 size;  
	char srcbin[100]="inst_rom.bin";  
	char dstfile[100]="inst_rom.h";
	//��ȡĿ��.bin�ļ� 
	//printf("please input src file path\n");  
	//scanf("%s",srcbin);
	
	//����һ��.hͷ�ļ����ڱ���binתC������ļ� 
	//printf("please input output path\n");
	//scanf("%s",dstfile);

	//��ȡ�ļ��Ĵ�С 
	size = GetBinSize(srcbin); 
	printf("size: %d\n", size); 
	//�������ڴ�Ÿ��ļ������� 
	buf = (unsigned char *)malloc(sizeof(unsigned char)*(size+4));
	memset(buf, 0, sizeof(unsigned char)*(size+4));
	//��ȡ�ļ� 
	read_bin(srcbin, buf, size);  	  
	//����ͷ�ļ�����ͷ�ļ��º����������飬һ���������ݵģ�����һ����ȫ0����
	//ȫ0��Ҫ���ã��Ժ�Ҫ��տ��Ե���������� 
	OutPut_handle(dstfile, buf, size);  
    return 0;  
}  
 