/*
 * Copyright (c) 2011 João Gonçalves
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
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

/*
 * Simple test application to test ADC
 * Single ADC channel doing repeated conversions
 * @author: João Gonçalves <joao.m.goncalves@ist.utl.pt>
 */

#include "Timer.h"
#include <stdio.h>
#include "Msp430Adc12.h"

#ifdef ADC12_TIMERA_ENABLED
#undef ADC12_TIMERA_ENABLED
#endif

#define SAMPLES 16

module FastADCC{
 provides {
    interface AdcConfigure<const msp430adc12_channel_config_t*> as AdcConfigure;
  }
  uses interface Boot;
  uses interface Leds; 
  uses interface Msp430Adc12Overflow as overflow;
  uses interface Msp430Adc12SingleChannel as adc;
  uses interface Resource;

}

implementation{
      
  uint16_t adb[SAMPLES];
  uint8_t count = 0;
   
  msp430adc12_channel_config_t adcconfig = {

    inch: INPUT_CHANNEL_A1,
    sref: REFERENCE_VREFplus_AVss,
    ref2_5v: REFVOLT_LEVEL_2_5,
    adc12ssel: SHT_SOURCE_ACLK,
    adc12div: SHT_CLOCK_DIV_1,
    sht: SAMPLE_HOLD_4_CYCLES,
    sampcon_ssel: SAMPCON_SOURCE_ACLK,
    sampcon_id: SAMPCON_CLOCK_DIV_1
  };
 
  async command const msp430adc12_channel_config_t* AdcConfigure.getConfiguration(){
    return &adcconfig; // must not be changed
  }

//prototypes
  void printadb();
  void printfFloat(float toBePrinted);
  void showerror();
  error_t configureMultipleRepeat();
    
  event void Boot.booted(){
    call Resource.request();
  }
  
  event void Resource.granted(){
    error_t e = FAIL;
      while(e != SUCCESS){
        e = configureMultipleRepeat();
      }
      printf("Starting the ADC...\n");
	  if(call adc.getData() != SUCCESS)
	    printf("Conversion didn't start!\n");
  } 
  
  
  async event void overflow.conversionTimeOverflow(){ }

  async event void overflow.memOverflow(){ }
 
  async event uint16_t *adc.multipleDataReady(uint16_t *buffer, uint16_t numSamples){
    printadb();
    if(count==9)
      return NULL;
     count++;
    return buffer;
  }
  
  async event error_t adc.singleDataReady(uint16_t data){  
    return FAIL;
  }
//functions
  
  void printadb(){
    uint16_t i;
    float sum = 0;
    uint16_t a;
    float gain = 37.461;
    float mil = 1000;
    float dois_meio = 2.5;
    float quat = 4095;
    float voltage = 0;
    float current = 0;
    float vsense = 0;
      printf("\nPrinting ADC set of samples Nº%d.\n", count);
      for(i = 0; i < SAMPLES; i++){
       sum += (float) adb[i];
       printf("Sample %d =", i);
       printfFloat((float) adb[i]);
       printf("\n");
    }
      sum = sum/SAMPLES;
      
      printf("Sample mean =");
      printfFloat(sum);
      printf("\n");
      
      printf("Vout mean (into ADC) =");
      voltage = sum*dois_meio/quat;
      printfFloat(voltage);
      printf(" V\n");
      
      vsense = (voltage/gain)*mil; //value in mV (Gm.Rout=37.461)
      printf("Vsense =");
      printfFloat(vsense);
      printf(" mV\n");
      
      current = vsense/1.01; //current in mA, Rsense = 1.01 Ohm
      printf("Current =");
      printfFloat(current);
      printf(" mA\n");    
  }

  void printfFloat(float toBePrinted) {
	uint32_t fi, f0, f1, f2;
	char c;
	float f = toBePrinted;

  	  if (f<0){
		c = '-'; f = -f;
		} else {
			c = ' ';
		}
		// integer portion.
		fi = (uint32_t) f;

		// decimal portion...get index for up to 3 decimal places.
		f = f - ((float) fi);
		f0 = f*10;   f0 %= 10;
		f1 = f*100;  f1 %= 10;
		f2 = f*1000; f2 %= 10;
		printf("%c%ld.%d%d%d", c, fi, (uint8_t) f0, (uint8_t) f1,  (uint8_t) f2);
  } 
  
  void showerror(){
    call Leds.led0On();
  }
  
  error_t configureMultipleRepeat(){
    error_t e;
    printf("Configure multipleRepeat\n");
    e = call adc.configureMultipleRepeat(&adcconfig, adb, SAMPLES, 0); 
    if(e != SUCCESS){
		showerror();
        printf("error %d\n", e);
    }
    return e;
  }
  
}
