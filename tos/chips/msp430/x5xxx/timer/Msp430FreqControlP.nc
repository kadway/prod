/*
 * Copyright (c) 2011, João Gonçalves
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the University of California nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdio.h>
#include "freq_control_const.h"

module Msp430FreqControlP @safe() {
  provides {
     interface FreqControl;
  }
  uses{
     interface Leds;
     interface Pmm;
  }
} implementation {

const uint8_t FLLD_val [] = {1, 2, 4, 8, 16};
const uint8_t FLLREFDIV_val [] = {1, 2, 4, 6, 8, 12};

  command uint8_t FreqControl.getFLLD(void){
    uint8_t flld;
      atomic flld = ((UCSCTL2 & FLLD_BITS) >> 12);
      if(flld > 4)
        return 32;
    return FLLD_val[flld];
   }
  
  command uint8_t FreqControl.getFLLN(void){
    atomic return (UCSCTL2 & FLLN_BITS);
  }

  command uint8_t FreqControl.getFLLREFDIV(void){
    uint8_t fllrefdiv;
      atomic fllrefdiv = (UCSCTL3 & FLLREFDIV);
      if (fllrefdiv > 5)
        return 16;
    return FLLREFDIV_val[fllrefdiv]; 
  }

  command uint8_t FreqControl.getMCLKSource(){
    atomic return (UCSCTL4 & 0x0007);  //mclk source bits
  }
  
  command uint32_t FreqControl.getMCLKFreq(uint8_t source){
       /*
        * The purpose is to return the freq value of whatever sources MCLK. 
        * Frequency value in kHz.
        * Only DCOCLK and DCOCLKDIV is implemented.
        */
    switch(source){
      case SELM__XT1CLK:   
      case SELM__VLOCLK:      
      case SELM__REFOCLK:   
      case SELM__DCOCLK:
        return call FreqControl.getDCOFreq(FALSE);       
      case SELM__DCOCLKDIV:{     
        return call FreqControl.getDCOFreq(TRUE);
      }
      case SELM__XT2CLK:       
      default:{
        printf("Something went very wrong. Can't Find MCLK source.\r\n");
        return 0;
      } 
    }
    return 0;
  }
  
  command error_t FreqControl.setMCLKFreq(uint32_t value){
    uint32_t freq;
    uint8_t source;
    /*
     *  Before changing the frequency call setMinRequiredVCore(freq)
     *  and verify if we need to change the core voltage
     */
    source = call FreqControl.getMCLKSource();
    freq = call FreqControl.getMCLKFreq(source);
   
    if(freq == value){
       printf("#error: MCLK frequency is already: %d Hz.\r\n", freq);
       return FAIL;
    }
    
    if(value > freq)
       call Pmm.setMinRequiredVCore(value);
   
    switch (source) {
      case SELM__XT1CLK:
        printf("MCLK is sourced by XT1.\r\n");
        break;    
      case SELM__VLOCLK:
        printf("MCLK is sourced by VLOCLK.\r\n");
        break;    
      case SELM__REFOCLK:
        printf("MCLK is sourced by REFOCLK.\r\n");
        break;    
      case SELM__DCOCLK:
        printf("MCLK is sourced by DCOCLK.\r\n");
        return call FreqControl.setDCOFreq(value, FALSE);       
      case SELM__DCOCLKDIV:
        printf("MCLK is sourced by DCOCLKDIV.\r\n");
        return call FreqControl.setDCOFreq(value, TRUE);       
      case SELM__XT2CLK:
        printf("MCLK is sourced by XT2CLK.\r\n");
        break;    
      default:
       printf("Something went very wrong. Can't Find MCLK source.\r\n");
       return FAIL;
     }

    if(value < freq){
      call Pmm.setMinRequiredVCore(value);
    }
   return SUCCESS;
  }

  command uint32_t FreqControl.getDCOFreq(bool isdcoclkdiv){
     uint16_t flln, fllrefdiv, fllref, flld; 
     uint32_t freq;
       flln = call FreqControl.getFLLN();
       flld = call FreqControl.getFLLD();
       fllrefdiv = call FreqControl.getFLLREFDIV();
   /*
    * I'm assuming the FLL in enabled, so let's find what's it's source.
    * Knowing the FLL reference one can calculate the DCO frequency:
    * fDCOCLK = FLLD*(FLLN+1)*fFLLREF/FLLREFDIV
    * fDCOCLKDIV = (FLLN+1)*fFLLREF/FLLREFDIV
    * Only XT1 is implemented.
    */       
    switch(call FreqControl.getFLLsource()){
      case SELREF_0:
        fllref=XT1_FREQ; // 000 XT1CLK
        break;
      case SELREF_1: //001 Reserved for future use. Defaults to XT1CLK.
      case SELREF_2: //010 REFOCLK
      case SELREF_3: //011 Reserved for future use. Defaults to REFOCLK.
      case SELREF_4: //100 Reserved for future use. Defaults to REFOCLK.
      case SELREF_5: //101 XT2CLK when available, otherwise REFOCLK.
      case SELREF_6: //110 Reserved for future use. XT2CLK when available, otherwise REFOCLK.
      case SELREF_7: //111 No selection. For the 'F543x and 'F541x non-A versions only, this defaults to XT2CLK. 
    }

    if(isdcoclkdiv == TRUE){
      freq = flld*(flln+1)*fllref/fllrefdiv;
      printf("Actual DCO configuration:\nFLLN = %d\nFLLD = %d\nFLLREF frequency = %d Hz\nFLLREFDIV = %d.\r\n", flln, flld, fllref, fllrefdiv);
      printf("Actual DCOCLKDIV frequency is: %d Hz.\r\n", freq);
      return (freq); 
    }
    
    freq = (flln+1)*fllref/fllrefdiv;
    printf("Actual DCO Configuration:\nFLLN = %d\nFLLD = %d\nFLLREF frequency = %d Hz\nFLLREFDIV = %d.\r\n", flln, flld, fllref, fllrefdiv);
    printf("Actual DCOCLK frequency is: %d Hz.\r\n", freq);
    return (freq); 
  }

  command error_t FreqControl.setDCORange(uint32_t value){  
    uint16_t dcorsel, dcorsel_bits=0xF000;   
     /* if((70 <= value) && (value <= 200)){
      dcorsel_bits = 0x0000;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }
 
    if((700 <= value) && (value <= 1700)){
      dcorsel_bits = 0x0000;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }
 
    if((150 <= value) && (value <= 360)){
      dcorsel_bits = 0x0010;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }

    if((1470 <= value) && (value <= 3450)){
      dcorsel_bits = 0x0010;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }

    if((320 <= value) && (value <= 750)){
      dcorsel_bits = 0x0020;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }

    if((3170 <= value) && (value <= 7380)){
      dcorsel_bits = 0x0020;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }

    if((640 <= value) && (value <= 1510)){
      dcorsel_bits = 0x0030;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }

    if((6070 <= value) && (value <= 14000)){
      dcorsel_bits = 0x0030;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }

    if((1300 <= value) && (value <= 3200)){
      dcorsel_bits = 0x0040;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }

    if((12300 <= value) && (value <= 28200)){
      dcorsel_bits = 0x0040;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }

    if((2500 <= value) && (value <= 6000)){
      dcorsel_bits = 0x0050;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }

    if((value >= 23700) && (value <= 54100)){
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
      dcorsel_bits = 0x0050;
      }

    if((4600 <= value) && (value <= 10700)){
      dcorsel_bits = 0x0060;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }

    if((39000 <= value) && (value <= 88000)){
      dcorsel_bits = 0x0060;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
     }

    if((8500 <= value) && (value <= 19600)){
      dcorsel_bits = 0x0070;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }

    if((60000 <= value) && (value <= 135000)){
      dcorsel_bits = 0x0070;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
    }

    if(dcorsel_bits == 0xF000){
       printf("The value of %x (%d kHz) is not accepted. \r\n", value, value);
       return FAIL;
     }*/
  
   // dcorsel = UCSCTL1;
   //dcorsel |= dcorsel_bits;
    
    printf("Actual UCSCTL1 is: %x. \r\n", UCSCTL1);
    UCSCTL1 &= 0xFF8E; //Clean DCORSEL bits and enable modulation
    printf("UCSCTL1 is now: %x . \r\n", UCSCTL1);
    UCSCTL1 |= 0x0040;
    printf("UCSCTL1 DCORSELx bits changed to: %x . \r\n", UCSCTL1);
    printf("For the desired frequency of: %d Hz. \r\n", value);
    return SUCCESS;
  }
 
   command error_t FreqControl.setDCOFreq(uint32_t value, bool isdcoclkdiv){
    uint16_t ucsctl_2;
      /*
       *  Only XT1 as FLL reference is implemented. 
       *  To find DCO config values do: (fFLLREFDIV*fDCO/fFFLLREF) - 1
       *  Make a call to setDCORange to ajust the DCO range to the desired frequency
       *  Just going to find the FLLN value, use fFLLFREFDIV = 1
       */
      switch(call FreqControl.getFLLsource()){
        case SELREF_0:
          atomic{           
            __bis_SR_register(SR_SCG0);  // Disable FLL control
            if(call FreqControl.setDCORange(value) != SUCCESS){
             printf("Could not set new DCO range. \r\n");
             return FAIL;
            }
            /*ucsctl_2 = UCSCTL2;
            ucsctl_2 &= (~FLLN_BITS);
            ucsctl_2 |= ((FLLN_BITS & ((value/XT1_FREQ) - 1)));
            UCSCTL2 = ucsctl_2;
            */
            UCSCTL2 &= (~FLLN_BITS);
            UCSCTL2 |= ((FLLN_BITS & ((value/XT1_FREQ) - 1)));
                      
            __bic_SR_register(SR_SCG0);  // Enable the FLL control loop

            printf("Wait for DCO to settle...\r\n");
            
            // Loop until DCO fault flag is cleared.  Ignore OFIFG, since it
            // incorporates XT1 and XT2 fault detection.
            do {
              UCSCTL7 &= ~(XT2OFFG + XT1LFOFFG + XT1HFOFFG + DCOFFG);
              // Clear XT2,XT1,DCO fault flags
              SFRIFG1 &= ~OFIFG;         // Clear fault flags
            } while (UCSCTL7 & DCOFFG); // Test DCO fault flag
            printf("DCO OK!\r\n");
          }         
          atomic printf("Wrote: %x to UCSCTL2.\r\n", UCSCTL2);
          return SUCCESS;
        default:
          printf("There is a problem in finding FLL source. \r\n");
          return FAIL;
    }
    return SUCCESS;
  }

  command uint8_t FreqControl.getFLLsource(){
    atomic return (UCSCTL3 & FLLREF);  
  }
}
