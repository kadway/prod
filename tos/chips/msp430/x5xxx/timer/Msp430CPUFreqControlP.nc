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

module Msp430CPUFreqControlP @safe() {
  provides {
     interface Msp430FreqControl;
  }
  uses{
     interface Leds;
  }
} implementation {

#define FLLD_BITS 0x7000
#define FLLN_BITS 0x03FF
#define XT1_FREQ 32
#define FLLREFDIV 0x0007
#define FLLREF 0x0070

 void uwait(uint16_t u) {
    uint16_t t0 = TA0R;
    while((TA0R - t0) <= u);
  }

  command uint16_t Msp430FreqControl.getFLLD(uint8_t flld){
  
   switch(flld){
     case 0: 
       return 1;
     case 1:
       return 2;
     case 2:
       return 4;
     case 3:
       return 8;
     case 4:
       return 16;
     case 5:
       return 32;
     case 6:
       return 32;
     case 7:
       return 32;
     default:     
       return 32;
   }
   return 32; 
  }
  
  command uint16_t Msp430FreqControl.getMCLKSource(){
    atomic return (UCSCTL4 & 0x0007);  //mclk source bits
  } 

 command uint16_t Msp430FreqControl.getMCLKFreq(uint16_t source){
   uint16_t value; 
  /*
   * The purpose is to return the freq value of whatever sources MCLK. 
   * Frequency value in kHz.
   * Only DCOCLK and DCOCLKDIV is implemented.
   */
  
  switch(source){

    case SELM__XT1CLK:
      break;    
    case SELM__VLOCLK:
      break;        
    case SELM__REFOCLK:   
      break;
    case SELM__DCOCLK:
      value = call Msp430FreqControl.getDCOFreq(FALSE);       
      break;
    case SELM__DCOCLKDIV:{     
      value = call Msp430FreqControl.getDCOFreq(TRUE);
      break;
    }
    case SELM__XT2CLK:       
      break;
    default:{
       printf("Something went very wrong. Can't Find MCLK source.\r\n");
       return 0;
      } 
  }
 return value;
 }
  command error_t Msp430FreqControl.setMCLKFreq(uint16_t value){
    uint16_t freq, source;
    /*
     *  Before changing the frequency call setPMMCoreVoltage 
     *  and verify if we need to change the core voltage
     */
    source = call Msp430FreqControl.getMCLKSource();
  
    freq = call Msp430FreqControl.getMCLKFreq(source);
    printf("# Actual MCLK frequency is : %d kHz.\r\n", freq);
   
    if(freq == value){
       return FAIL;
    }

    if(freq >  value){
       //call setPmmCoreVoltage(freq);  // NOT implemented yet
    }
    switch(source){
      case SELM__XT1CLK:{
        printf("MCLK is sourced by XT1.\r\n");
        break;    
      }
      case SELM__VLOCLK:{
        printf("MCLK is sourced by VLOCLK.\r\n");
        break;    
      }
      case SELM__REFOCLK:{
        printf("MCLK is sourced by REFOCLK.\r\n");
        break;    
      }
      case SELM__DCOCLK:{
        printf("MCLK is sourced by DCOCLK.\r\n");
        return call Msp430FreqControl.setDCOFreq(value);       
        break;
      }
      case SELM__DCOCLKDIV:{
        printf("MCLK is sourced by DCOCLKDIV.\r\n");
        return call Msp430FreqControl.setDCOFreq(value);       
        break;    
      }
      case SELM__XT2CLK:{
        printf("MCLK is sourced by XT2CLK.\r\n");
        break;    
      }
      default:{
       printf("Something went very wrong. Can't Find MCLK source.\r\n");
       return FAIL;
      }
     }
    if(freq <  value){
      //call setPmmCoreVoltage(freq);  // NOT DEFINED yet
    }
   return SUCCESS;
  }

  command uint16_t Msp430FreqControl.getDCOFreq(bool isdcoclkdiv){
     uint16_t flln, flldiv, fllref, flld;

     atomic{
       flln = (UCSCTL2 & FLLN_BITS);
       flldiv = (UCSCTL3 & FLLREFDIV);
       }

   switch(flldiv){
     case 0: 
       flldiv = 1;
       break;
     case 1:
       flldiv = 2;
       break;
     case 2:
       flldiv = 4;
       break;
     case 3:
       flldiv = 6;
       break;
     case 4:
       flldiv = 8;
       break;
     case 5:
       flldiv = 12;
       break;     
     case 6:
       flldiv = 16;
       break;
     default:     
       flldiv = 16;
   }

  /*
    *I'm assuming the FLL in enabled, so let's find what's it's source.
    *Knowing the FLL reference one can calculate the DCO frequency with fDCO = (N+1)*fFLLREF/n
    *Only XT1 is implemented.
    */       

    switch(call Msp430FreqControl.getFLLsource()){
      case SELREF_0:{ // 000 XT1CLK
        fllref=XT1_FREQ;
        break;
      }
      case SELREF_1: //001 Reserved for future use. Defaults to XT1CLK.
        break;
      case SELREF_2: //010 REFOCLK
        break;
      case SELREF_3: //011 Reserved for future use. Defaults to REFOCLK.
        break;
      case SELREF_4: //100 Reserved for future use. Defaults to REFOCLK.
        break;
      case SELREF_5: //101 XT2CLK when available, otherwise REFOCLK.
        break;
      case SELREF_6: //110 Reserved for future use. XT2CLK when available, otherwise REFOCLK.
        break;
      case SELREF_7: //111 No selection. For the 'F543x and 'F541x non-A versions only, this defaults to XT2CLK. 
        break;
    }

    if(isdcoclkdiv == TRUE){
      atomic flld = ((UCSCTL2&FLLD_BITS)>>12);
      flld = call Msp430FreqControl.getFLLD(flld);
      printf("In getDCOFreq: N is %d, D is %d, FLLRef is %d and FLLDiv is %d. \r\n", flln, flld, fllref, flldiv);
      return (((flln+1)*fllref/flldiv)/flld); 
    }

    printf("In getDCOFreq: N is %d, FLLRef is %d and FLLDiv is %d. \r\n", flln, fllref, flldiv);
    return ((flln+1)*fllref/flldiv); 
  }

  command error_t Msp430FreqControl.setDCORange(uint16_t value){  
  // value has to be in kHz
  // This is form the msp430f548A datasheet
    uint16_t dcorsel, dcorsel_bits;
    bool ok = FALSE;   
  
    if((70 <= value) && (value <= 200)){
      dcorsel_bits = 0x0000;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
      ok = TRUE;
    }
 
    if((700 <= value) && (value <= (1024+700))){
      dcorsel_bits = 0x0000;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
      ok = TRUE;
    }
 
    if((150 <= value) && (value <= 360)){
      dcorsel_bits = 0x0010;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
      ok = TRUE;
    }

    if(((1024+470) <= value) && (value <= ((3*1024)+450))){
      dcorsel_bits = 0x0010;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
      ok = TRUE;
    }

    if((320 <= value) && (value <= 750)){
      dcorsel_bits = 0x0010;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
      ok = TRUE;
    }

    if((((3*1024)+170) <= value) && (value <= ((7*1024)+380))){
      dcorsel_bits = 0x0020;
      printf("set DCORSEL bits to %x. \r\n", dcorsel_bits);
      ok = TRUE;
    }

   if(!ok){
       printf("The value of %x (%d kHz) is not accepted. \r\n", value, value);
       return FAIL;
     }
  
      dcorsel = UCSCTL1;
      dcorsel &= 0xFF8F; //Clean DCORSEL bits
      dcorsel |= dcorsel_bits;
      UCSCTL1 = dcorsel;
    

    printf("For the frequency of: %d kHz. \r\n", value);
    printf("Change the DCO range bits to: %x. \r\n", dcorsel_bits);

    return SUCCESS;
  }

  command error_t Msp430FreqControl.setDCOFreq(uint16_t value){
    uint16_t ucsctl_2;
      /*
       *  Only XT1 as FLL reference is implemented. 
       *  To find DCO config values do: (fFLLREFDIV*fDCO/fFFLLREF) - 1
       *  Make a call to setDCORange to ajust the DCO range to the desired frequency
       *  Just going to find the FLLN value, use fFLLFREFDIV = 1
       */

    switch(call Msp430FreqControl.getFLLsource()){
  
      case SELREF_0:{
        atomic{
          /* Disable FLL control */
          __bis_SR_register(SR_SCG0);

          if(call Msp430FreqControl.setDCORange(value) != SUCCESS){
             printf("Could not set new DCO range. \r\n");
             return FAIL;
          }

          ucsctl_2 = UCSCTL2;
          ucsctl_2 &= (~FLLN_BITS);
          ucsctl_2 |= ((FLLN_BITS & ((value/XT1_FREQ) - 1)));
          UCSCTL2 = ucsctl_2;
          
          __bic_SR_register(SR_SCG0);               // Enable the FLL control loop

          // Loop until DCO fault flag is cleared.  Ignore OFIFG, since it
          // incorporates XT1 and XT2 fault detection.
          do {
            UCSCTL7 &= ~(XT2OFFG + XT1LFOFFG + XT1HFOFFG + DCOFFG);
            // Clear XT2,XT1,DCO fault flags
            SFRIFG1 &= ~OFIFG;         // Clear fault flags
            printf("Wait for DCO to settle.\r\n");
          } while (UCSCTL7 & DCOFFG); // Test DCO fault flag

        } 
        
       printf("Wrote: %x to UCSCTL2.\r\n", ucsctl_2);
       break;
      }
      default:{
        printf("There is a problem in finding FLL source. \r\n");
        return FAIL;
      }
    }
    return SUCCESS;
  }

 command uint16_t Msp430FreqControl.getFLLsource(){
      atomic return (UCSCTL3 & FLLREF);  
  }
}
