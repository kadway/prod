#include <Timer.h>
#include <stdio.h>

#define ADC_SAMPLE_TIME 10 //miliseconds
#define ITERATIONS 200
#define DEADLINE 1000

module DVSTestP {
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as Timer0;
  uses interface Timer<TMilli> as Timer1;
  uses interface Tasks;
  
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface Receive;
  uses interface SplitControl as AMControl;
}
implementation {
  
  message_t pkt;
  bool busy = FALSE;
  
  event void Boot.booted() {
    //call Timer0.startPeriodic(ADC_SAMPLE_TIME);
    call AMControl.start(); //start radio
    printf("Booted, call getFibonacci\n");
    call Tasks.getFibonacci(ITERATIONS, DEADLINE);
  }
  
  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
     // call Timer0.startPeriodic(TIMER_PERIOD_MILLI);
    }
    else {
      call AMControl.start();
    }
  }
  
    event void AMControl.stopDone(error_t err) {
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
    if (&pkt == msg) {
      busy = FALSE;
    }
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
    
    if (len == sizeof(BlinkToRadioMsg)) {
      BlinkToRadioMsg* btrpkt = (BlinkToRadioMsg*)payload;
      setLeds(btrpkt->counter);
      printf("Received \nnodeid: %d\ncounter:%d\ntest:%d\n", btrpkt->nodeid, btrpkt->counter, btrpkt->test);
    }
    return msg;
  }
  
  event void Tasks.FibonacciDone(uint16_t iterations, uint32_t elapsedTime, error_t status){
	  if(status!= SUCCESS)
	 
	  printf("App: Deadline Missed!\n Iterations left:%d\nelapsed time: %lu\n", iterations, elapsedTime);
	  
	  
	  else
	    if (!busy) {
          BlinkToRadioMsg* btrpkt = 
	(BlinkToRadioMsg*)(call Packet.getPayload(&pkt, sizeof(BlinkToRadioMsg)));
      if (btrpkt == NULL) {
	return;
      }
      btrpkt->nodeid = TOS_NODE_ID;
      btrpkt->counter = counter;
      btrpkt->test = 23;
      if (call AMSend.send(AM_BROADCAST_ADDR, 
          &pkt, sizeof(BlinkToRadioMsg)) == SUCCESS) {
        busy = TRUE;
        printf("Sent a packt\n");
      }
    }
	  printf("App: Deadline met!\nFinished at %lu\n", elapsedTime);  
  }
      
  event void Tasks.FibonacciIterationDone(){ }
  
  event void Timer0.fired() {
  }
  
  event void Timer1.fired() {
  }
  
}
