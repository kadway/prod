
/**
 * Output MCLK and SMCLK on Boot.
 * Toggle One Led to know the OS is alive
 **/

#include "Timer.h"
#include <stdio.h>
#include "../../../../chips/msp430/x5xxx/usci/msp430usci.h"

module ClockTestP @safe()
{
  uses interface Timer<TMilli> as Timer0;
  uses interface Leds;
  uses interface Boot;
  uses interface FreqControl;
  uses interface UartByte;
 }
implementation
{
 uint32_t value = 3000000;

  void uwait(uint16_t u) {
    uint16_t t0 = TA0R;
    while((TA0R - t0) <= u);
  }

  event void Boot.booted(){
   
    P1DIR |= 0x40;                       // P1.6 to output direction
    P2DIR |= 0x01;                       // P2.0 to output direction
    P1SEL |= 0x40;                       // P1.6 Output SMCLK
    P2SEL |= 0x01;                       // 2.0 Output MCLK
   printf("#\n\n STARTING: Input frequency value is %d MHz:\r\n", (int)value);
   printf("#\n\n STARTING: Input frequency value is %d MHz:\r\n", (int)(value>>24));
   printf("#\n\n STARTING: Input frequency value is %d MHz:\r\n", (int)(value>>48));
   printf("#\n\n STARTING: Input frequency value is %d MHz:\r\n", (uint8_t)value);
   printf("#\n\n STARTING: Input frequency value is %d MHz:\r\n", (uint8_t)(value>>24));
   printf("#\n\n STARTING: Input frequency value is %d MHz:\r\n", (uint8_t)(value>>48));
   printf("#\n\n STARTING: Input frequency value is %d MHz:\r\n", value);
   if(call FreqControl.setMCLKFreq(value) == FAIL ){
     printf("Could not change the frequency to: %d Hz. \r\n", (uint8_t)value);
   }
    else{
     printf("MCLK frequency is now %d Hz. \r\n", (uint8_t)value);
     call Leds.led2Off();
     call Leds.led1Off();
    }

  // call Timer0.startPeriodic( 250 );
  }

  event void Timer0.fired(){
    call Leds.led0Toggle();
  }
  
}

