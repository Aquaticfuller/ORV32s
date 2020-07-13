//gcc bin2Mem.c -o bin2Mem
#include<stdio.h>
#include<stdlib.h>
#include<malloc.h>
int main()
{
	FILE *fp_r;
	FILE *fp_w;
	FILE *fp_v;
	int length;
	unsigned char* buffer;
	char  in;
	int i;
	int j;
	char a1;
	char a0;
	char temp;

	if( (fp_r=fopen("inst_rom.bin","rb"))==NULL )
		{
			printf("file inst_rom.bin open error\n");
			exit(1);
		}
			
	if( (fp_w=fopen("inst_rom.data","wb"))==NULL )
		{
			printf("file inst_rom.data open error\n");
			exit(1);
		}

	if( (fp_v=fopen("inst_rom.data3","wb"))==NULL )
		{
			printf("file inst_rom.data3 open error\n");
			exit(1);
		}
			
			fseek(fp_r,0L,SEEK_END);
			length = ftell(fp_r);
			printf("length=%d\n",length);
			fseek(fp_r,0L,SEEK_SET);
			fseek(fp_w,0L,SEEK_SET);
			
			if( (buffer=(unsigned char *)malloc(length*sizeof(char)))==NULL  )
				{
					printf("melloc error\n");
					exit(1);
				}
				//memset(buffer,0,length);
				for(i=0;i<length;i++)
				{
					fscanf(fp_r,"%c",buffer+i);
				}
				
				//printf("size of char=%d\n",buffer[0]);
				for(i=0;i<length;i+=8)
				{
					if(i!=0) fprintf(fp_w,"\n");
					for(j=7;j>=0;j--)
					{
						temp = buffer[i+j] >> 4;
						a1 = temp<10 ? temp+48 : temp +55;

						temp = (buffer[i+j] % 16);
						a0 = temp<10 ? temp+48 : temp +55;

						fprintf(fp_w,"%c",a1);
						fprintf(fp_w,"%c",a0);
						fprintf(fp_v,"%c",buffer[i+j]);

						//fwrite(buffer+i+j,sizeof(char),1,fp_w);
						//printf(" %d,%d%d ",buffer[i+j],a1,a0);
					}
				}
				
				fclose(fp_r);
				fclose(fp_w);
				fclose(fp_v);
				fp_r = NULL;
				fp_w = NULL;
				fp_v = NULL;
	return 0;
	}
