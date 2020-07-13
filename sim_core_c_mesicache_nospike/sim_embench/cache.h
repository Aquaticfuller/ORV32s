/**
 * \file cache.h
 * \author NCSU ECE 506 TA (2018), Soumil Krishnanand Heble
 * \date 12/01/2018
 * \brief Header: Generic Cache Class
 */

#ifndef __CACHE_H__
#define __CACHE_H__

#include <cmath>        /** Header for Standard Math Function Library */
#include <iostream>     /** Header for I/O Stream Function Library */

/** Type define unsigned long as ulong */
typedef unsigned long ulong;

/** Type define unsigned char as uchar */
typedef unsigned char uchar;

/** Type define unsigned int as uint */
typedef unsigned int uint;

/** Cache Block State Enumeration */
enum cacheFlag  {
                    INVALID =   0,  /**< Invalid State - Used by All Protocols */
                    VALID =     1,  /**< Valid State - Used by All Protocols */
                    DIRTY =     2,  /**< Dirty State - Used by Generic Cache */
                    MODIFIED =  3,  /**< Modified State - Used by All Protocols */
                    SHARED =    4,  /**< Shared State - Used by MSI & MESI Protocols */
                    EXCLUSIVE = 5,  /**< Exclusive State - Used by MESI & Dragon Protocols */
                    SMODIFIED = 6,  /**< Shared Modified State - Used by Dragon Protocol */
                    SCLEAN =    7   /**< Shared Clean State - Used by Dragon Protocol */
};

/** 
 * \class cacheLine
 * \brief Class of a cache line 
 */
class cacheLine 
{
protected:
    ulong tag;                  /**< Cache Line Tag */
    enum cacheFlag Flags;       /**< Cache Line State Variable */
    ulong seq;                  /**< Cache LRU Rank */

public:
    
    /**
     * \brief cacheLine Class Constructor
     */
    cacheLine()                         
    { 
        tag = 0; Flags = INVALID; 
    }
    
    /**
     * \brief Get Cache Line Tag
     * \return Tag of the Cache Line
     */
    ulong getTag()                      
    { 
        return tag; 
    }
    
    /**
     * \brief Get Cache Line Flag
     * \return Flag of the Cache Line
     */
    cacheFlag getFlags()                
    { 
        return Flags; 
    }
    
    /**
     * \brief Get Cache Line LRU Rank
     * \return LRU Rank of the Cache Line
     */
    ulong getSeq()                      
    { 
        return seq;
    }
    
    /**
     * \brief Set Cache Line LRU Rank
     * \param[in] Seq LRU Rank to Set
     */
    void setSeq(ulong Seq)              
    { 
        seq = Seq;
    }
    
    
    /**
     * \brief Set Cache Line Flag
     * \param[in] flags Flag to Set
     */
    void setFlags(cacheFlag flags)	
    { 
        Flags = flags; 
    }
    
    /**
     * \brief Set Cache Tag
     * \param[in] a Tag to Set
     */
    void setTag(ulong a)                
    { 
        tag = a; 
    }
    
    /**
     * \brief Invalidate a Cache Line
     */
    void invalidate()                   
    { 
        tag = 0; 
        Flags = INVALID; 
    }
    
    /**
     * \brief Cache Line Invalid Flag Check
     * \return Whether Line is Invalid or Not
     */
    bool isValid()                      
    { 
        return ((Flags) != INVALID);
    }
};

/** 
 * \class Cache
 * \brief Class of a General Cache 
 */
class Cache
{
protected:
    ulong size;         /**< Cache Size */
    ulong lineSize;     /**< Cache Block Size */
    ulong assoc;        /**< Associativity of Cache */
    ulong sets;         /**< Number of Sets in Cache */
    ulong log2Sets;     /**< Number of Bits Required to Describe Number of Sets */
    ulong log2Blk;      /**< Number of Bits Required to Describe Number of Block in the Cache */
    ulong tagMask;      /**< Tag Mask for Address */
    ulong numLines;     /**< Number of Lines (Blocks) in Cache */
    ulong currentCycle; /**< Current Instruction Count */
    
    /** Cache Performance Counters */
    ulong reads;        /**< Number of Read Accesses to Cache */
    ulong readMisses;   /**< Number of Read Accesses to Cache that Miss */
    ulong writes;       /**< Number of Write Accesses to Cache */
    ulong writeMisses;  /**< Number of Write Accesses to Cache that Miss */
    ulong writeBacks;   /**< Number of Writebacks by the Cache to Lower Level in the Hierarchy */

    /** Coherence Controller Performance Counters */
    ulong cache2cache_tf;       /**< Number of Cache to Cache Transfers */
    ulong mem_transactions;     /**< Number of Transactions (R/W) with Memory */
    ulong num_interv;           /**< Number of Interventions in the Cache */
    ulong num_inval;            /**< Number of Invalidations in the Cache */
    ulong num_flush;            /**< Number of Flush Commands Placed on the Bus */
    ulong num_busrd;            /**< Number of BusRd Commands Placed on the Bus */
    ulong num_busrdx;           /**< Number of BusRdX Commands Placed on the Bus */
    ulong num_busupd_upgr;      /**< Number of BusUpgr or BusUpd Commands Placed on the Bus */

    cacheLine **cache;          /**< Pointer to a Pointer of cacheLine class object */
    
    /**
     * \brief Calculate Index from the CPU Access Address
     * \param[in] addr Access Address from CPU
     * \return Index of the Access Address according to Cache Organization
     */
    ulong calcIndex(ulong addr)     
    { 
        return ((addr >> log2Blk) & tagMask); 
    }
    
    /**
     * \brief Calculate Full Block Aligned Address from Tag
     * \param[in] addr Tag
     * \return Full Block Aligned Address
     */
    ulong calcAddr4Tag(ulong tag)   
    { 
        return (tag << (log2Blk));
    }
   
public:
    
    /**
     * \brief Cache Class Constructor
     * \param[in] s Cache Size
     * \param[in] a Cache Line/Block Size
     * \param[in] b Cache Associativity
     */
    Cache(int s,int a,int b);
    
    /**
     * \brief Cache Class Destructor
     */
    ~Cache() 
    { 
        delete cache; 
    }

    /**
     * \brief Find a Line to Fill Based on the CPU Access Address
     * \param[in] addr CPU Access Address
     * \return Pointer to the Replacement Line as a cacheLine Class Object
     */
    cacheLine *findLineToReplace(ulong addr);
    
    /**
     * \brief Fill a Line to Based on the CPU Access Address
     * \param[in] addr CPU Access Address
     * \return Pointer to the Filled Line as a cacheLine Class Object
     */
    cacheLine *fillLine(ulong addr);
    
    /**
     * \brief Find whether a Cache Line Exists Based on the CPU Access Address
     * \param[in] addr CPU Access Address
     * \return Pointer to the Line as a cacheLine Class Object
     */
    cacheLine *findLine(ulong addr);
    
    /**
     * \brief Get Cache Line to be Evicted in a Particular Set
     * \param[in] addr CPU Access Address
     * \return Pointer to the Line to be Replace as a cacheLine Class Object
     */
    cacheLine *getLRU(ulong addr);

    /** Get Functions */
    
    /**
     * \brief Get currentCycle
     * \return Current Cycle Counter Value
     */
    ulong getcurrentCycle()            
    { 
        return currentCycle;
    }
    
    /**
     * \brief Get Reads Counter
     * \return Cache Read Counter Value
     */
    ulong getReads()            
    { 
        return reads;
    }
    
    /**
     * \brief Get Read Miss Counter
     * \return Cache Read Miss Counter Value
     */
    ulong getRM()               
    { 
        return readMisses; 
    } 
    /**
     * \brief Get Writes Counter
     * \return Cache Write Counter Value
     */
    ulong getWrites()           
    { 
        return writes; 
    }
    
    /**
     * \brief Get Write Miss Counter
     * \return Cache Write Miss Counter Value
     */
    ulong getWM()               
    { 
        return writeMisses; 
    } 
    
    /**
     * \brief Get Write Back Counter
     * \return Cache Write Back Counter Value
     */
    ulong getWB()               
    { 
        return writeBacks;
    }
    
    /**
     * \brief Get Cache To Cache Transfer Counter
     * \return Cache Cache To Cache Transfer Counter Value
     */
    ulong getCache2cache()      
    { 
        return cache2cache_tf; 
    }
    
    /**
     * \brief Get Memory Transaction Counter
     * \return Cache Memory Transaction Counter Value
     */
    ulong getMemtransactions()  
    { 
        return mem_transactions; 
    }
    
    /**
     * \brief Get Intervention Counter
     * \return Cache Intervention Counter Value
     */
    ulong getInterv()           
    { 
        return num_interv;
    }
    
    /**
     * \brief Get Invalidation Counter
     * \return Cache Intervention Counter Value
     */
    ulong getInval()            
    { 
        return num_inval;
    }
    
    /**
     * \brief Get Flush Counter
     * \return Cache Flush Counter Value
     */
    ulong getFlush()            
    { 
        return num_flush;
    }
    
    /**
     * \brief Get BusRd Counter
     * \return Cache BusRd Counter Value
     */
    ulong getBusrd()           
    { 
        return num_busrd; 
    }
    
    /**
     * \brief Get BusRdX Counter
     * \return Cache BusRdX Counter Value
     */
    ulong getBusrdx()           
    { 
        return num_busrdx; 
    }
    
    /**
     * \brief Get BusUpgr/BusUpd Counter
     * \return Cache BusUpgr/BusUpd Counter Value
     */
    ulong getBusupdupgr()       
    { 
        return num_busupd_upgr;
    }
    
    /** Update Functions */
    
    /**
     * \brief Increment Current Cycle
     */
    void inccurrentCycle()            
    { 
        currentCycle++; 
    }
    
    /**
     * \brief Increment Reads Counter
     */
    void incReads()            
    { 
        reads++; 
    }
    
    /**
     * \brief Increment Read Miss Counter
     */
    void incRM()               
    { 
        readMisses++;
    } 
    
    /**
     * \brief Increment Writes Counter
     */
    void incWrites()           
    { 
        writes++;
    }
    
    /**
     * \brief Increment Write Miss Counter
     */
    void incWM()               
    { 
        writeMisses++;
    } 
    
    /**
     * \brief Increment Write Back Counter
     */
    void incWB()               
    { 
        writeBacks++; 
    }
    
    /**
     * \brief Write Back Dirty Cache Block
     * \param[in] addr Address of Cache Block Which is Dirty
     */
    void writeBack(ulong addr)       
    { 
        writeBacks++; 
    }
    
    /**
     * \brief Increment Cache To Cache Transfer Counter
     */
    void incCache2cache()      
    { 
        cache2cache_tf++; 
    }
    
    /**
     * \brief Increment Memory Transaction Counter
     */
    void incMemtransactions()  
    { 
        mem_transactions++;
    }
    
    /**
     * \brief Increment Intervention Counter
     */
    void incInterv()           
    { 
        num_interv++; 
    }
    
    /**
     * \brief Increment Invalidation Counter
     */
    void incInval()            
    { 
        num_inval++; 
    }
    
    /**
     * \brief Increment Flush Counter
     */
    void incFlush()            
    { 
        num_flush++;
    }
    
    /**
     * \brief Increment BusRd Counter
     */
    void incBusrd()           
    { 
        num_busrd++; 
    }
    
    /**
     * \brief Increment BusRdX Counter
     */
    void incBusrdx()           
    { 
        num_busrdx++; 
    }
    
    /**
     * \brief Increment BusUpgr/BusUpd Counter
     */
    void incBusupdupgr()       
    { 
        num_busupd_upgr++;
    }
    
    /**
     * \brief Update LRU of a Cache Line
     * \param[in] line Pointer to a Cache Line
     */
    void updateLRU(cacheLine *line);
    
    /**
     * \brief Cache Access Routine
     * \param[in] addr CPU Access Address
     * \param[in] op CPU Access Type (Read/Write)
     */
    void Access(ulong addr,uchar op);
    
    /**
     * \brief Calculate Tag from the CPU Access Address
     * \param[in] addr Access Address from CPU
     * \return Tag of the Access Address according to Cache Organization
     */
    ulong calcTag(ulong addr)       
    { 
        return (addr >> (log2Blk));
    }
};

#endif
