/**
 * \file cache.cc
 * \author NCSU ECE 506 TA (2018), Soumil Krishnanand Heble
 * \date 12/01/2018
 * \brief Source: Generic Cache Class
 */

#include "cache.h"
#include <stdlib.h>
#include <assert.h>

using namespace std;

Cache::Cache(int s,int a,int b)
{
    ulong i, j;
    reads = readMisses = writes = 0; 
    writeMisses = writeBacks = currentCycle = 0;

    size       = (ulong)(s);
    lineSize   = (ulong)(b);
    assoc      = (ulong)(a);   
    sets       = (ulong)((s/b)/a);
    numLines   = (ulong)(s/b);
    log2Sets   = (ulong)(log2(sets));   
    log2Blk    = (ulong)(log2(b));   

    /** Initialized Coherence Counters */
    cache2cache_tf = mem_transactions = num_interv = num_inval = num_flush = num_busrd = num_busrdx = num_busupd_upgr = 0;

    tagMask = 0;
    for(i=0;i<log2Sets;i++)
    {
        tagMask <<= 1;
        tagMask |= 1;
    }

    /**create a two dimentional cache, sized as cache[sets][assoc]**/ 
    cache = new cacheLine*[sets];
    for(i=0; i<sets; i++)
    {
        cache[i] = new cacheLine[assoc];
        for(j=0; j<assoc; j++) 
        {
            cache[i][j].invalidate();
        }
    }
}

/** you might add other parameters to Access()
since this function is an entry point 
to the memory hierarchy (i.e. caches) */
void Cache::Access(ulong addr,uchar op)
{
    currentCycle++;/*per cache global counter to maintain LRU order 
                    among cache ways, updated on every cache access*/
            
    if(op == 'w')
    {
        writes++;
    }
    else
    {
        reads++;
    }

    cacheLine * line = findLine(addr);
    if(line == NULL)/*miss*/
    {
        if(op == 'w')
        {
            writeMisses++;
        }
        else
        {
            readMisses++;
        }

        cacheLine *newline = fillLine(addr);
        if(op == 'w')
        {
            newline->setFlags(DIRTY);
        }
    }
    else
    {
        /**since it's a hit, update LRU and update dirty flag**/
        updateLRU(line);
        if(op == 'w') 
        {
            line->setFlags(DIRTY);
        }
    }
}

/*look up line*/
cacheLine * Cache::findLine(ulong addr)
{
    ulong i, j, tag, pos;

    pos = assoc;
    tag = calcTag(addr);
    i   = calcIndex(addr);

    for(j=0; j<assoc; j++)
    {
        if(cache[i][j].isValid())
        {
            if(cache[i][j].getTag() == tag)
            {
                pos = j; 
                break; 
            }
        }
    }
    
    if(pos == assoc)
    {
        return NULL;
    }
    else
    {
        return &(cache[i][pos]); 
    }
}

/*upgrade LRU line to be MRU line*/
void Cache::updateLRU(cacheLine *line)
{
    line->setSeq(currentCycle);  
}

/*return an invalid line as LRU, if any, otherwise return LRU line*/
cacheLine * Cache::getLRU(ulong addr)
{
    ulong i, j, victim, min;

    victim = assoc;
    min    = currentCycle;
    i      = calcIndex(addr);

    for(j=0;j<assoc;j++)
    {
        if(cache[i][j].isValid() == 0) 
        {
            return &(cache[i][j]);
        }
    }   
    for(j=0;j<assoc;j++)
    {
        if(cache[i][j].getSeq() <= min) 
        { 
            victim = j; min = cache[i][j].getSeq();
        }
    } 
    assert(victim != assoc);

    return &(cache[i][victim]);
}

/** Find a victim, move it to MRU position */
cacheLine *Cache::findLineToReplace(ulong addr)
{
    cacheLine * victim = getLRU(addr);
    updateLRU(victim);

    return (victim);
}

/** Allocate a new line */
cacheLine *Cache::fillLine(ulong addr)
{ 
    ulong tag;

    cacheLine *victim = findLineToReplace(addr);
    assert(victim != 0);
    
    if(victim->getFlags() == DIRTY)
    {
        writeBack(addr);
    }
    
    tag = calcTag(addr);   
    victim->setTag(tag);
    victim->setFlags(VALID);    
    /**note that this cache line has been already 
        upgraded to MRU in the previous function (findLineToReplace)**/

    return victim;
}
