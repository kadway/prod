
/**
 * Output MCLK and SMCLK on Boot.
 * Toggle One Led to know the OS is alive
 **/

#include "Timer.h"
#include <stdio.h>
#include "../../../../chips/msp430/x5xxx/usci/msp430usci.h"


module ClockTestP @safe()
{
  //uses interface Timer<TMilli> as Timer0;
  uses interface Leds;
  uses interface Boot;
  uses interface FreqControl;
  //uses interface UartByte;
 }
implementation
{
   
  void uwait(uint16_t u) {
    uint16_t t0 = TA0R;
    while((TA0R - t0) <= u);
  }

	void frequency_swype(uint32_t start_freq, uint32_t end_freq, uint32_t step){
		while(start_freq <= end_freq){
			printf("Setting MCLK frequency to %d MHz.\n", (uint8_t) (start_freq/1000000));
			if(call FreqControl.setMCLKFreq(start_freq) == FAIL )
				printf("Could not change the frequency to: %d MHz. \r\n", (uint8_t) (start_freq/1000000));
			else
				printf("MCLK frequency is now %d MHz. \r\n\n", (uint8_t)(start_freq/1000000));
		start_freq = start_freq + step;
		}
    }
    
  event void Boot.booted(){
    uint32_t start_freq = 10000000;
    uint32_t end_freq = 25000000; 
    uint32_t step = 100000;
    
    P1DIR |= 0x40;                       // P1.6 to output direction
    P2DIR |= 0x01;                       // P2.0 to output direction
    P1SEL |= 0x40;                       // P1.6 Output SMCLK
    P2SEL |= 0x01;                       // 2.0 Output MCLK
    /* Override default: Use REFOCLK for ACLK, and DCOCLKDIV for SMCLK and DCOCLK SMCLK */
    
    printf("#\n\n|************* Starting frequency swype *************|\n\n");
    
    atomic UCSCTL4 = SELA__REFOCLK | SELS__DCOCLKDIV | SELM__DCOCLK;
    printf("#MCLK is sourced by DCOCLK.\n\n");
    printf("#VCore will be ajusted to the frequency of MCLK.\n");
    printf("#Start swype at %d MHz and end at %d MHz. Use %d MHz of step.\n", (uint8_t)(start_freq/1000000), (uint8_t)(end_freq/1000000), (uint8_t)(step/1000000));
    
    frequency_swype(start_freq, end_freq, step);
    
    atomic UCSCTL4 = SELA__REFOCLK | SELS__DCOCLKDIV | SELM__DCOCLKDIV;
    printf("\n\n#MCLK is now sourced by DCOCLKDIV which is half the DCOCLK rate.\n");
    printf("#VCore will be ajusted to the frequency of MCLK.\n");
    printf("#Start swype at %d MHz and end at %d MHz. Use %d MHz of step.\n", (uint8_t)(start_freq/1000000), (uint8_t)(end_freq/1000000), (uint8_t)(step/1000000));
    
    frequency_swype(start_freq, end_freq, step);
    printf("#\n\n|************* Frequency swype finished *************|\n\n");
  }
}

