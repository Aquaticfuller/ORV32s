/**
 * \file coherence_ctrl.cc
 * \author Soumil Krishnanand Heble
 * \date 12/01/2018
 * \brief Source: Coherence Controller and Bus Class
 * Improvements: Make the bus as a class instead of a bunch 
 * of if else and case statements, this will result in cleaner interfaces.
 */

#include "coherence_ctrl.h"
#include <assert.h>
#include <stdio.h>

#define RD_REQ 0
#define WR_REQ 1

coherenceController::coherenceController(int s, int a, int b, int numP, enum coh_protocol cohProtocol)
{
    num_processors = numP;
    coherenceProtocol = cohProtocol;
    busControl = 0xFF;
    busValid = VALID_BUS;
    busAddr = 0;
    busData = 0;
    copiesExist = NCEX;
    busCommand = INVALID_BUS;
    hitMiss = MISS;
    
    cacheOnbus = new Cache*[numP];
    
    uchar loop_i;
    for(loop_i=0;loop_i<numP;loop_i++)
    {
        cacheOnbus[loop_i] = new Cache(s, a, b);
    }
}

void coherenceController::processRequest(ulong procNum, uchar rdWr, ulong reqAddr)
{
    switch(coherenceProtocol)
    {
        case MSI:   processMSI(procNum, rdWr, reqAddr);
                    break;
                    
        case MESI:  processMESI(procNum, rdWr, reqAddr);
                    break;
                    
        case DRAGON:    processDRAGON(procNum, rdWr, reqAddr);
                        break;
    }
}

void coherenceController::processMSI(ulong procNum, uchar rdWr, ulong reqAddr)
{
    /** Increment the Cache's Request Count */
    cacheOnbus[procNum]->inccurrentCycle();
    
    /** Pointer to Cache Line to Update Finally */
    cacheLine *line;
    
    /** Check Type of Read and Update Counter */
    if(rdWr==RD_REQ)
    {
        cacheOnbus[procNum]->incReads();
    }
    else
    {
        cacheOnbus[procNum]->incWrites();
    }
    
    /** Look for the Requested Address in the Cache */
    line = cacheOnbus[procNum]->findLine(reqAddr);
    
    /** If Cache Line Not Found */
    if(line==NULL)
    {
        /** Set To Miss */
        hitMiss = MISS;
        
        /** Fetch a Victim Cache Line for the Data */
        cacheLine *victim = cacheOnbus[procNum]->findLineToReplace(reqAddr);
        assert(victim != 0);
        
        /** Store Victim Block to the Cache Line to Update Pointer */
        line = victim;
        
        if(victim->getFlags()==MODIFIED)
        {
            /** Update Writeback Counter */
            cacheOnbus[procNum]->incWB();
            
            /** Update Memory Transaction Counter */
            cacheOnbus[procNum]->incMemtransactions();
        }
        
        /* Bus in Control of Current Processor */
        busControl = procNum;
        
        /* Bus Signals are Valid */
        busValid = VALID_BUS;
        
        /* Place Required Address on the Bus */
        busAddr = reqAddr;
        
        if(rdWr==RD_REQ)
        {
            /** Update Read Miss Counters */
            cacheOnbus[procNum]->incRM();
            
            /** Place BusRd Command on Bus */
            busCommand = BUSRD;
            
            /** Update BusRd Counter */
            cacheOnbus[procNum]->incBusrd();
        }
        else
        {
            /** Update Write Miss Counters */
            cacheOnbus[procNum]->incWM();
            
            /** Place BusRdX Command on Bus */
            busCommand = BUSRDX;
            
            /** Update BusRdX Counter */
            cacheOnbus[procNum]->incBusrdx();
        }
    }
    else
    {
        /** Set To Hit */
        hitMiss = HIT;
        
        /** If Hit Cache Line in Shared State and a Write is Required */
        if((line->getFlags()==SHARED)&&(rdWr==WR_REQ))
        {
            /* Bus in Control of Current Processor */
            busControl = procNum;
            
            /* Bus Signals are Valid */
            busValid = VALID_BUS;
            
            /* Place Required Address on the Bus */
            busAddr = reqAddr;
            
            /** Place BusRdX Command on Bus */
            busCommand = BUSRDX;
            
            /** Update BusRdX Counter */
            cacheOnbus[procNum]->incBusrdx();
        }
    }
    
    /* Perform Bus Snooping Operations */
    if(busValid==VALID_BUS)
    {
        uchar loop_i;
        switch(busCommand)
        {
            case BUSRD: cacheOnbus[procNum]->incMemtransactions();
                        for(loop_i=0; loop_i<num_processors; loop_i++)
                        {
                            /** Look for the Request Address in the Cache */
                            cacheLine *line_procn = cacheOnbus[loop_i]->findLine(busAddr);
                            
                            /** If Found in Cache Other than Cache Serivicing the Request */
                            if((line_procn!=NULL)&&(loop_i!=procNum)&&(line_procn->getFlags()==MODIFIED))
                            {
                                /** Set Cache Line State To Shared */
                                line_procn->setFlags(SHARED);
                                
                                /** Update Intervention Counter */
                                cacheOnbus[loop_i]->incInterv();
                                
                                /** Update Flush Counter */
                                cacheOnbus[loop_i]->incFlush();
                                
                                /** Flush Constitutes as a Memory Transaction */
                                cacheOnbus[loop_i]->incMemtransactions();
                                
                                /** Flush Constitutes as a Writeback */
                                cacheOnbus[loop_i]->incWB();
                                
                                busControl = loop_i;
                                busCommand = FLUSH;
                            }
                        }
                        break;
                        
            case BUSRDX:    cacheOnbus[procNum]->incMemtransactions();
                            for(loop_i=0; loop_i<num_processors; loop_i++)
                            {
                                /** Look for the Request Address in the Cache */
                                cacheLine *line_proc = cacheOnbus[loop_i]->findLine(busAddr);
                                
                                /** If Found in Cache Other than Cache Servicing the Request */
                                if((line_proc!=NULL)&&(loop_i!=procNum))
                                {
                                    /** Update Invalidation Counter */
                                    cacheOnbus[loop_i]->incInval();
                                    
                                    /** If Modified */
                                    if(line_proc->getFlags()==MODIFIED)
                                    {
                                        /** Update Flush Counter */
                                        cacheOnbus[loop_i]->incFlush();
                                        
                                        /** Flush Constitutes as a Memory Transaction */
                                        cacheOnbus[loop_i]->incMemtransactions();
                                        
                                        /** Flush Constitutes as a Writeback */
                                        cacheOnbus[loop_i]->incWB();
                                        
                                        busControl = loop_i;
                                        busCommand = FLUSH;
                                    }
                                    
                                    /** Invalidate Cache Line */
                                    line_proc->invalidate();
                                }
                            }
                            break;
            
            default:    printf("ERROR\n");
                        break;
        }
    }
    
    /** Perform Finishing Actions */
    if(hitMiss==HIT)
    {
        cacheOnbus[procNum]->updateLRU(line);
        
        if(rdWr==WR_REQ)
        {
            line->setFlags(MODIFIED);
        }
    }
    else
    {
        ulong tag;
        tag = cacheOnbus[procNum]->calcTag(reqAddr);
        line->setTag(tag);
        
        cacheOnbus[procNum]->updateLRU(line);
        
        if(rdWr==WR_REQ)
        {
            line->setFlags(MODIFIED);
        }
        else
        {
            line->setFlags(SHARED);
        }
    }
    
    /** Reset Bus */
    busControl = 0xFF;
    busValid = INVALID_BUS;
    busAddr = 0xFFFFFFFF;
    busCommand = INVALID_BUS;
    
    hitMiss = RST_OUT;
}

void coherenceController::processMESI(ulong procNum, uchar rdWr, ulong reqAddr)
{
    /** Increment the Cache's Request Count */
    cacheOnbus[procNum]->inccurrentCycle();
    
    /** Pointer to Cache Line to Update Finally */
    cacheLine *line;
    
    /** Check Type of Read and Update Counter */
    if(rdWr==RD_REQ)
    {
        cacheOnbus[procNum]->incReads();
    }
    else
    {
        cacheOnbus[procNum]->incWrites();
    }
    
    /** Look for the Requested Address in the Cache */
    line = cacheOnbus[procNum]->findLine(reqAddr);
    
    /** If Cache Line Not Found */
    if(line==NULL)
    {
        /** Set To Miss */
        hitMiss = MISS;
        
        /** Fetch a Victim Cache Line for the Data */
        cacheLine *victim = cacheOnbus[procNum]->findLineToReplace(reqAddr);
        assert(victim != 0);
        
        /** Store Victim Block to the Cache Line to Update Pointer */
        line = victim;
        
        if(victim->getFlags()==MODIFIED)
        {
            /** Update Writeback Counter */
            cacheOnbus[procNum]->incWB();
            
            /** Update Memory Transaction Counter */
            cacheOnbus[procNum]->incMemtransactions();
        }
        
        /* Bus in Control of Current Processor */
        busControl = procNum;
        
        /* Bus Signals are Valid */
        busValid = VALID_BUS;
        
        /* Place Required Address on the Bus */
        busAddr = reqAddr;
        
        if(rdWr==RD_REQ)
        {
            /** Update Read Miss Counters */
            cacheOnbus[procNum]->incRM();
            
            /** Place BusRd Command on Bus */
            busCommand = BUSRD;
            
            /** Update BusRd Counter */
            cacheOnbus[procNum]->incBusrd();
        }
        else
        {
            /** Update Write Miss Counters */
            cacheOnbus[procNum]->incWM();
            
            /** Place BusRdX Command on Bus */
            busCommand = BUSRDX;
            
            /** Update BusRdX Counter */
            cacheOnbus[procNum]->incBusrdx();
        }
    }
    else
    {
        /** Set To Hit */
        hitMiss = HIT;
        
        /** If Hit Cache Line in Shared State and a Write is Required */
        if((line->getFlags()==SHARED)&&(rdWr==WR_REQ))
        {
            /* Bus in Control of Current Processor */
            busControl = procNum;
            
            /* Bus Signals are Valid */
            busValid = VALID_BUS;
            
            /* Place Required Address on the Bus */
            busAddr = reqAddr;
            
            /** Place BusRdX Command on Bus */
            busCommand = BUSUPGR;
            
            /** Update BusRdX Counter */
            cacheOnbus[procNum]->incBusupdupgr();
        }
    }
    
    /* Perform Bus Snooping Operations */
    if(busValid==VALID_BUS)
    {
        uchar loop_i;
        
        switch(busCommand)
        {
            case BUSRD: for(loop_i=0; loop_i<num_processors; loop_i++)
                        {
                            /** Look for the Request Address in the Cache */
                            cacheLine *line_procn = cacheOnbus[loop_i]->findLine(busAddr);
                            
                            /** If Found in Cache Other than Cache Serivicing the Request */
                            if((line_procn!=NULL)&&(loop_i!=procNum))
                            {
                                /** Copies Exist */
                                copiesExist = CEX;
                                
                                switch(line_procn->getFlags())
                                {
                                    case MODIFIED:  /** Update Flush Counter */
                                                    cacheOnbus[loop_i]->incFlush();
                                                    
                                                    /** Flush Constitutes as a Memory Transaction */
                                                    cacheOnbus[loop_i]->incMemtransactions();
                                                    
                                                    /** Flush Constitutes as a Writeback */
                                                    cacheOnbus[loop_i]->incWB();
                                                    
                                                    /** Update Intervention Counter */
                                                    cacheOnbus[loop_i]->incInterv();
                                                    
                                                    busControl = loop_i;
                                                    busCommand = FLUSH;
                                                    
                                                    break;
                                                    
                                    case EXCLUSIVE: /** Update Intervention Counter */
                                                    cacheOnbus[loop_i]->incInterv();
                                                
                                                    busControl = loop_i;
                                                    busCommand = FLUSHOPT;
                                                
                                                    break;
                                                    
                                    default:    busControl = loop_i;
                                                busCommand = FLUSHOPT;
                                            
                                                break;
                                }
                                
                                /** Set Cache Line State To Shared */
                                line_procn->setFlags(SHARED);
                            }
                        }
                        
                        if(busControl==procNum)
                        {
                            cacheOnbus[procNum]->incMemtransactions();
                            copiesExist = NCEX;
                        }
                        break;
                        
            case BUSRDX:    for(loop_i=0; loop_i<num_processors; loop_i++)
                            {
                                /** Look for the Request Address in the Cache */
                                cacheLine *line_proc = cacheOnbus[loop_i]->findLine(busAddr);
                                
                                /** If Found in Cache Other than Cache Serivicing the Request */
                                if((line_proc!=NULL)&&(loop_i!=procNum))
                                {
                                    /** Update Invalidation Counter */
                                    cacheOnbus[loop_i]->incInval();
                                    
                                    busControl = loop_i;
                                    busCommand = FLUSHOPT;
                                    
                                    /** If Modified */
                                    if(line_proc->getFlags()==MODIFIED)
                                    {
                                        /** Update Flush Counter */
                                        cacheOnbus[loop_i]->incFlush();
                                        
                                        /** Flush Constitutes as a Memory Transaction */
                                        cacheOnbus[loop_i]->incMemtransactions();
                                        
                                        /** Flush Constitutes as a Writeback */
                                        cacheOnbus[loop_i]->incWB();
                                        
                                        busControl = loop_i;
                                        busCommand = FLUSH;
                                    }
                                    
                                    /** Invalidate Cache Line */
                                    line_proc->invalidate();
                                }
                            }
                            
                            if(busControl==procNum)
                            {
                                cacheOnbus[procNum]->incMemtransactions();
                            }
                            break;
                            
            case BUSUPGR:   for(loop_i=0; loop_i<num_processors; loop_i++)
                            {
                                /** Look for the Request Address in the Cache */
                                cacheLine *line_procn = cacheOnbus[loop_i]->findLine(busAddr);
                                
                                /** If Found in Cache Other than Cache Serivicing the Request */
                                if((line_procn!=NULL)&&(loop_i!=procNum)&&(line_procn->getFlags()==SHARED))
                                {
                                    /** Invalidate Cache Line */
                                    line_procn->invalidate();
                                    
                                    /** Update Invalidation Counter */
                                    cacheOnbus[loop_i]->incInval();
                                }
                            }
                            
                            break;
                                    
            
            default:    printf("ERROR\n");
                        break;
        }
    }
    
    /** Perform Finishing Actions */
    if(hitMiss==HIT)
    {
        cacheOnbus[procNum]->updateLRU(line);
        
        if(rdWr==WR_REQ)
        {
            line->setFlags(MODIFIED);
        }
    }
    else
    {
        ulong tag;
        tag = cacheOnbus[procNum]->calcTag(reqAddr);
        line->setTag(tag);
        
        cacheOnbus[procNum]->updateLRU(line);
        
        if(rdWr==WR_REQ)
        {
            line->setFlags(MODIFIED);
        }
        else
        {
            if(copiesExist==NCEX)
            {
                line->setFlags(EXCLUSIVE);
            }
            else
            {
                line->setFlags(SHARED);
            }
        }
    }
    
    if((busCommand==FLUSHOPT)||(busCommand==FLUSH))
    {
        /** Update Flush Counter */
        cacheOnbus[procNum]->incCache2cache();
    }
    
    /** Reset Bus */
    busControl = 0xFF;
    busValid = INVALID_BUS;
    busAddr = 0xFFFFFFFF;
    busCommand = INVALID_BUS;
    copiesExist = NCEX;
    
    hitMiss = RST_OUT;
}

void coherenceController::processDRAGON(ulong procNum, uchar rdWr, ulong reqAddr)
{
    /** Increment the Cache's Request Count */
    cacheOnbus[procNum]->inccurrentCycle();
    
    /** Pointer to Cache Line to Update Finally */
    cacheLine *line;
    
    /** Check Type of Read and Update Counter */
    if(rdWr==RD_REQ)
    {
        cacheOnbus[procNum]->incReads();
    }
    else
    {
        cacheOnbus[procNum]->incWrites();
    }
    
    /** Look for the Requested Address in the Cache */
    line = cacheOnbus[procNum]->findLine(reqAddr);
    
    /** If Cache Line Not Found */
    if(line==NULL)
    {
        /** Set To Miss */
        hitMiss = MISS;
        
        /** Fetch a Victim Cache Line for the Data */
        cacheLine *victim = cacheOnbus[procNum]->findLineToReplace(reqAddr);
        assert(victim != 0);
        
        /** Store Victim Block to the Cache Line to Update Pointer */
        line = victim;
        
        if((victim->getFlags()==MODIFIED)||(victim->getFlags()==SMODIFIED))
        {
            /** Update Writeback Counter */
            cacheOnbus[procNum]->incWB();
            
            /** Update Memory Transaction Counter */
            cacheOnbus[procNum]->incMemtransactions();
        }
        
        /* Bus in Control of Current Processor */
        busControl = procNum;
        
        /* Bus Signals are Valid */
        busValid = VALID_BUS;
        
        /* Place Required Address on the Bus */
        busAddr = reqAddr;
        
        if(rdWr==RD_REQ)
        {
            /** Update Read Miss Counters */
            cacheOnbus[procNum]->incRM();
            
            /** Place BusRd Command on Bus */
            busCommand = BUSRD;
            
            /** Update BusRd Counter */
            cacheOnbus[procNum]->incBusrd();
        }
        else
        {
            /** Update Write Miss Counters */
            cacheOnbus[procNum]->incWM();
            
            /** Place BusRdX Command on Bus */
            busCommand = BUSUPD;
            
            /** Update BusRd Counter */
            cacheOnbus[procNum]->incBusrd();
            
            /** Update BusRdX Counter */
            cacheOnbus[procNum]->incBusupdupgr();
        }
    }
    else
    {
        /** Set To Hit */
        hitMiss = HIT;
        
        /** If Hit Cache Line in Shared State and a Write is Required */
        if(((line->getFlags()==SMODIFIED)||(line->getFlags()==SCLEAN))&&(rdWr==WR_REQ))
        {
            /* Bus in Control of Current Processor */
            busControl = procNum;
            
            /* Bus Signals are Valid */
            busValid = VALID_BUS;
            
            /* Place Required Address on the Bus */
            busAddr = reqAddr;
            
            /** Place BusRdX Command on Bus */
            busCommand = BUSUPD;
            
            /** Update BusRdX Counter */
            cacheOnbus[procNum]->incBusupdupgr();
        }
    }
    
    /* Perform Bus Snooping Operations */
    if(busValid==VALID_BUS)
    {
        uchar loop_i;
        
        switch(busCommand)
        {
            case BUSRD: if(hitMiss==MISS)
			{
				cacheOnbus[procNum]->incMemtransactions();
			}
			for(loop_i=0; loop_i<num_processors; loop_i++)
                        {
                            /** Look for the Request Address in the Cache */
                            cacheLine *line_procn = cacheOnbus[loop_i]->findLine(busAddr);
                            
                            /** If Found in Cache Other than Cache Serivicing the Request */
                            if((line_procn!=NULL)&&(loop_i!=procNum))
                            {
                                /** Copies Exist */
                                copiesExist = CEX;
                                
                                switch(line_procn->getFlags())
                                {
                                    case MODIFIED:  /** Update Flush Counter */
                                                    cacheOnbus[loop_i]->incFlush();
                                                    
                                                    /** Update Intervention Counter */
                                                    cacheOnbus[loop_i]->incInterv();
                                                    
                                                    //cacheOnbus[loop_i]->incMemtransactions();
                                                    
                                                    /** Set Cache Line State To Shared */
                                                    line_procn->setFlags(SMODIFIED);
                                                    
                                                    busControl = loop_i;
                                                    busCommand = FLUSH;
                                                    
                                                    break;
                                                    
                                    case EXCLUSIVE: /** Update Intervention Counter - Unsure */
                                                    cacheOnbus[loop_i]->incInterv();
                                                    
                                                    /** Set Cache Line State To Shared */
                                                    line_procn->setFlags(SCLEAN);
                                                    
                                                    busControl = loop_i;
                                                    
                                                    break;
                                                    
                                    case SMODIFIED: /** Update Flush Counter */
                                                    cacheOnbus[loop_i]->incFlush();
                                                    
                                                    /** Set Cache Line State To Shared */
                                                    line_procn->setFlags(SMODIFIED);
                                                    
                                                    //cacheOnbus[loop_i]->incMemtransactions();
                                                    
                                                    busControl = loop_i;
                                                    busCommand = FLUSH;
                                                    break;
                                                    
                                    case SCLEAN:    busControl = loop_i;
                                                    break;
                                                    
                                    default:    printf("ERROR\n");
                                }
                            }
                        }
                        
                        if(busControl==procNum)
                        {
                            //cacheOnbus[procNum]->incMemtransactions();
                            //copiesExist = NCEX; //Redundant
                        }
                        else
                        if(busCommand!=FLUSH)
                        {
                            //cacheOnbus[procNum]->incMemtransactions();
                        }
                        break;
                        
            case BUSUPD:    if(hitMiss==MISS)
			    {
				cacheOnbus[procNum]->incMemtransactions();
			    }
			    for(loop_i=0; loop_i<num_processors; loop_i++)
                            {
                                /** Look for the Request Address in the Cache */
                                cacheLine *line_proc = cacheOnbus[loop_i]->findLine(busAddr);
                                
                                /** If Found in Cache Other than Cache Serivicing the Request */
                                if((line_proc!=NULL)&&(loop_i!=procNum))
                                {
                                    /** Copies Exist */
                                    copiesExist = CEX;
                                    
                                    switch(line_proc->getFlags())
                                    {
                                        case MODIFIED:  /** Update Flush Counter */
                                                        cacheOnbus[loop_i]->incFlush();
                                                        
                                                        /** Update Intervention Counter */
                                                        cacheOnbus[loop_i]->incInterv();
                                                        
                                                        //cacheOnbus[loop_i]->incMemtransactions();
                                                        
                                                        /** Set Cache Line State To Shared */
                                                        line_proc->setFlags(SCLEAN);
                                                        
                                                        busControl = loop_i;
                                                        busCommand = FLUSH;
                                                        
                                                        break;
                                                        
                                        case EXCLUSIVE: /** Update Intervention Counter - Unsure */
                                                        cacheOnbus[loop_i]->incInterv();
                                                        
                                                        busControl = loop_i;
                                                        
                                                        /** Set Cache Line State To Shared */
                                                        line_proc->setFlags(SCLEAN);
                                                        
                                                        break;
                                                        
                                        case SMODIFIED: if(hitMiss==MISS)
                                                        {
                                                            /** Update Flush Counter */
                                                            cacheOnbus[loop_i]->incFlush();
                                                            //cacheOnbus[loop_i]->incMemtransactions();
                                                        }
                                                        
                                                        busControl = loop_i;
                                                        busCommand = FLUSH;
                                                        
                                                        /** Set Cache Line State To Shared */
                                                        line_proc->setFlags(SCLEAN);
                                                        
                                                        break;
                                                    
                                        case SCLEAN:    busControl = loop_i;
                                                        break;
                                                        
                                        default:    printf("ERROR\n");
                                    }
                                }
                            }
                            
                            if(busControl==procNum)
                            {
                                if(hitMiss==MISS)
                                {
                                    //cacheOnbus[procNum]->incMemtransactions();
                                }
                                //copiesExist = NCEX;   //Redundant
                            }
                            else
                            if((busCommand!=FLUSH)&&(hitMiss==MISS))
                            {
                                //cacheOnbus[procNum]->incMemtransactions();
                            }
                            break;
                            
            default:    printf("ERROR\n");
        }
    }
    
    /** Perform Finishing Actions */
    if(hitMiss==HIT)
    {
        cacheOnbus[procNum]->updateLRU(line);
        
        if(rdWr==WR_REQ)
        {
            switch(line->getFlags())
            {
                case EXCLUSIVE: line->setFlags(MODIFIED);
                                break;
                                
                default:    if(copiesExist==NCEX)
                            {
                                line->setFlags(MODIFIED);
                            }
                            else
                            {
                                line->setFlags(SMODIFIED);
                            }
            }
        }
    }
    else
    {
        ulong tag;
        tag = cacheOnbus[procNum]->calcTag(reqAddr);
        line->setTag(tag);
        
        cacheOnbus[procNum]->updateLRU(line);
        
        if(rdWr==WR_REQ)
        {
            if(copiesExist==NCEX)
            {
                line->setFlags(MODIFIED);
            }
            else
            {
                line->setFlags(SMODIFIED);
            }
        }
        else
        {
            if(copiesExist==NCEX)
            {
                line->setFlags(EXCLUSIVE);
            }
            else
            {
                line->setFlags(SCLEAN);
            }
        }
    }
    
    /** Reset Bus */
    busControl = 0xFF;
    busValid = INVALID_BUS;
    busAddr = 0xFFFFFFFF;
    busCommand = INVALID_BUS;
    copiesExist = NCEX;
    
    hitMiss = RST_OUT;
}

void coherenceController::dumpMetrics()
{
    uchar loop_i;
    for(loop_i=0; loop_i<num_processors; loop_i++)
    {
        
        printf("============ Simulation results (Cache %u) ============\n",(uint)loop_i);
        printf("01. number of reads:    \t\t\t%lu\n", cacheOnbus[loop_i]->getReads());
        printf("02. number of read misses:      \t\t%lu\n", cacheOnbus[loop_i]->getRM());
        printf("03. number of writes:   \t\t\t%lu\n", cacheOnbus[loop_i]->getWrites());
        printf("04. number of write misses:     \t\t%lu\n", cacheOnbus[loop_i]->getWM());
        printf("05. total miss rate:    \t\t\t%.2f%%\n", ((float)(cacheOnbus[loop_i]->getRM()+cacheOnbus[loop_i]->getWM()))*100.0/((float)(cacheOnbus[loop_i]->getReads()+cacheOnbus[loop_i]->getWrites())));
        printf("06. number of writebacks:\t\t\t%lu\n", cacheOnbus[loop_i]->getWB());
        printf("07. number of cache-to-cache transfers: \t%lu\n", cacheOnbus[loop_i]->getCache2cache());
        printf("08. number of memory transactions:      \t%lu\n", cacheOnbus[loop_i]->getMemtransactions());
        printf("09. number of interventions:    \t\t%lu\n", cacheOnbus[loop_i]->getInterv());
        printf("10. number of invalidations:    \t\t%lu\n", cacheOnbus[loop_i]->getInval());
        printf("11. number of flushes:  \t\t\t%lu\n", cacheOnbus[loop_i]->getFlush());
        printf("12. number of BusRdX:   \t\t\t%lu\n", cacheOnbus[loop_i]->getBusrdx());
    }
}
