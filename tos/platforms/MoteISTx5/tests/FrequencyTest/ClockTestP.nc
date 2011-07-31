
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
  uses interface Msp430FreqControl;
  uses interface UartByte;
 }
implementation
{
 uint16_t value = (1024*3);

  void uwait(uint16_t u) {
    uint16_t t0 = TA0R;
    while((TA0R - t0) <= u);
  }

  event void Boot.booted(){
   
    P1DIR |= 0x40;                       // P1.6 to output direction
    P2DIR |= 0x01;                       // P2.0 to output direction
    P1SEL |= 0x40;                       // P1.6 Output SMCLK
    P2SEL |= 0x01;                       // 2.0 Output MCLK

   printf("#\n\n STARTING: Input frequency value is %d kHz:\r\n", value);
  
   if(call Msp430FreqControl.setMCLKFreq(value) == FAIL ){
     printf("Could not change the frequency to: %d kHz. \r\n", value);
   }
    else{
     printf("MCLK frequency is now %d kHz. \r\n", value);
     call Leds.led2Off();
     call Leds.led1Off();
    }
 while(1);
 //   call Timer0.startPeriodic( 250 );
  }

  event void Timer0.fired(){
    call Leds.led0Toggle();
  }
  
}

