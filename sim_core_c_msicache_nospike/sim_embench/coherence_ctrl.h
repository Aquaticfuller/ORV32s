/**
 * \file coherence_ctrl.h
 * \author Soumil Krishnanand Heble
 * \date 12/01/2018
 * \brief Header: Coherence Controller and Bus Class
 */

#ifndef __COHERENCE_CTRL_H__
#define __COHERENCE_CTRL_H__

#include "cache.h"

/** Type define unsigned long as ulong */
typedef unsigned long ulong;

/** Type define unsigned char as uchar */
typedef unsigned char uchar;

/** Type define unsigned int as uint */
typedef unsigned int uint;

/** Coherence Bus State Enumeration */
enum bus_state  {
                    INVALID_BUS =   0,  /**< Bus Inactive - Used In All Protocols */
                    VALID_BUS =     1,  /**< Bus Active - Used In All Protocols */
                    BUSRD =         2,  /**< Bus Read Command - Used In All Protocols */
                    BUSRDX =        3,  /**< Bus Read Exclusive (Write) Command - Used In MSI & MESI Protocols */
                    FLUSH =         4,  /**< Flush Command - Used In All Protocols */
                    BUSUPGR =       5,  /**< Bus Upgrade Command - Used In MESI Protocol */
                    FLUSHOPT =      6,  /**< Flush Optimized - Used In MESI Protocol */
                    BUSUPD =        7,  /**< Bus Update Command - Used In Dragon Protocol */
                    CEX =           8,  /**< Copies Exist Signal - Used In MESI & Dragon Protocols */
                    NCEX =          9   /**< Copies Do Not Exist Signal - Used In MESI & Dragon Protocols */
};

/** Coherence Protocol Type Enumeration */
enum coh_protocol   {
                        MSI = 0,    /**< MSI Coherence Protocol */
                        MESI = 1,   /**< MESI Coherence Protocol */
                        DRAGON = 2  /**< Dragon Coherence Protocol */
};

/** Cache Tag Search Outcome Enumeration */
enum searchOutcome  {
                        MISS =  0,      /**< Cache Miss */
                        HIT =   1,      /**< Cache Hit */
                        RST_OUT = 2     /**< Reset State */
};

/** 
 * \class coherenceController
 * \brief Class for a Cache Coherence Controller
 */
class coherenceController
{
protected:
    int num_processors;                     /**< Number of Processors Managed/Simulated by the Coherence Controller */
    enum coh_protocol coherenceProtocol;    /**< Coherence Protocol In Use */
    uchar busControl;                       /**< Processor having Bus Control */
    enum bus_state busValid;                /**< Current Bus State */
    ulong busAddr;                          /**< Address on the Bus */
    ulong busData;                          /**< Data on the Bus - Not Used in the Simulator */
    enum bus_state copiesExist;             /**< Copies Exist Bus Signal */
    enum bus_state busCommand;              /**< Command on the Bus */
    enum searchOutcome hitMiss;             /**< Search Hit or Miss */
    
    Cache **cacheOnbus;                     /**< Pointer to a Pointer to Cache class object */
    
public:
    
    /**
     * \brief coherenceController class Constructor
     * \param[in] s Cache Size
     * \param[in] a Cache Associativity
     * \param[in] b Cache Block Size
     * \param[in] numP Number of Processors
     * \param[in] cohProtocol Coherence Protocol to Use
     */
    coherenceController(int s, int a, int b, int numP, enum coh_protocol cohProtocol);
    
    /**
     * \brief coherenceController class Destructor
     */
    ~coherenceController() 
    {
        delete cacheOnbus; 
    }
    
    /**
     * \brief Process a CPU Access Request
     * \param[in] procNum Processor Requesting the Address
     * \param[in] rdWr Type of Request (R/W)
     * \param[in] reqAddr Address the Processor is Requesting
     */
    void processRequest(ulong procNum, uchar rdWr, ulong reqAddr);
    
    /**
     * \brief Process a CPU Access Request using MSI Protocol
     * \param[in] procNum Processor Requesting the Address
     * \param[in] rdWr Type of Request (R/W)
     * \param[in] reqAddr Address the Processor is Requesting
     */
    void processMSI(ulong procNum, uchar rdWr, ulong reqAddr);
    
    /**
     * \brief Process a CPU Access Request using MESI Protocol
     * \param[in] procNum Processor Requesting the Address
     * \param[in] rdWr Type of Request (R/W)
     * \param[in] reqAddr Address the Processor is Requesting
     */
    void processMESI(ulong procNum, uchar rdWr, ulong reqAddr);
    
    /**
     * \brief Process a CPU Access Request using Dragon Protocol
     * \param[in] procNum Processor Requesting the Address
     * \param[in] rdWr Type of Request (R/W)
     * \param[in] reqAddr Address the Processor is Requesting
     */
    void processDRAGON(ulong procNum, uchar rdWr, ulong reqAddr);
    
    /**
     * \brief Print Coherence Controller Statistics
     */
    void dumpMetrics();
};

#endif
