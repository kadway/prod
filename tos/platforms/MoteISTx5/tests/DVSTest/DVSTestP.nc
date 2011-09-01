#include <Timer.h>
#include <stdio.h>
#include "Radio.h"

#define ADC_SAMPLE_TIME 10 //miliseconds

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
  norace bool busy = FALSE;
  norace uint16_t state;
  event void Boot.booted() {
    //call Timer0.startPeriodic(ADC_SAMPLE_TIME);
    printf("Booted\n");
    call Leds.led0Off();
    call Leds.led1Off();
    call Leds.led2Off();
    call AMControl.start(); //start radio
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
      //printf("clear busy-> state: %d\n", state);
    }
    else
      printf("some's worng in the sending\n");
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
    MoteISTMsg* mist_m;
    MicaMsg* micaz_m;
    uint8_t dummy;
    if (len == sizeof(MicaMsg)) {
      micaz_m = (MicaMsg*)payload;
      /*
       * Check if message comes from Mica1 and if it is a request to start the processing (task != 0)
       */
      if(micaz_m->nodeid == MICA_NODE_ID){
				//printf("Incoming msg from mica\n");
				if (!busy) { //check if radio is busy
          mist_m = (MoteISTMsg*)(call Packet.getPayload(&pkt, sizeof(MoteISTMsg)));
          if (mist_m == NULL){
	        return 0;
          }
          mist_m->nodeid = MOTEIST_NODE_ID; //assign MoteIST ID
          state = micaz_m->state;
          switch(micaz_m->state){
            
            case MICA_REQUEST:
          //  printf("Mica: REQUEST\n\n");
              mist_m->state = MICA_REQUEST;
              state = MICA_REQUEST;
              break;
            case MICA_START:
            //printf("Mica: START. \niterations=%d\ndeadline=%d\nmissed=%d\nmet=%d\n\n", micaz_m->task_i, micaz_m->deadline, micaz_m->missed, micaz_m->met);
              mist_m->state = MICA_START;
              call Tasks.getFibonacci(micaz_m->task_i, micaz_m->deadline);
              state = MICA_START;
              break;
            case MICA_DEADLINE_MET:
              call Leds.led2Toggle();
            //printf("Mica DEADLINE_MET:\nmissed=%d\nmet=%d\n\n", micaz_m->missed, micaz_m->met);
              return msg;
              break;
            case MICA_DEADLINE_MISS:
              call Leds.led1Toggle();
            //printf("Mica: DEADLINE_MISS\nmissed=%d\nmet=%d\n\n", micaz_m->missed, micaz_m->met);
              return msg;
              break;
            default:
              break;
					}
          if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MoteISTMsg)) == SUCCESS) {
           // situation where the event fibonacci one see's the busy flag at false if there 
           //  is a printf here, the dummy for() does not work either
           // for(dummy = 0; dummy++; dummy<14000){dummy++;}
             printf("dummy\n");
            busy = TRUE;
          }
        }//if !busy
			}// if == MICA_NODE_ID
    }// if len = len MicaMsg
    return msg;
  }
  
  event void Tasks.FibonacciDone(uint16_t iterations, uint32_t elapsedTime, error_t status){
	  MoteISTMsg* mist_m;
    //printf("App: fib dne\n");
	  if(status!= SUCCESS){
	    //printf("App: Deadline Missed!\n Iterations left:%d\nelapsed time: %lu\n\n", iterations, elapsedTime);
		}
		else{
	    
	    if (!busy) { //check if radio is busy
        /*build the packet*/
        //printf("App: Deadline met!\nFinished at %lu\n\n", elapsedTime);
        mist_m = (MoteISTMsg*)(call Packet.getPayload(&pkt, sizeof(MoteISTMsg)));
        if (mist_m == NULL){
          printf("App: null pointer\n");
	        return;
        }
        mist_m->nodeid = MOTEIST_NODE_ID; //assign MoteIST ID
        mist_m->state = MICA_DEADLINE_MET; // task done in time
        state = MICA_DEADLINE_MET;
        /*send the packet*/
        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MoteISTMsg)) == SUCCESS) {
            //printf("set busy-> state: %d \n", mist_m->state);
            busy = TRUE;
        }
			} //if(!busy)
		}//else
  }
  event void Tasks.FibonacciIterationDone(){ }
  
  event void Timer0.fired() {}
  
  event void Timer1.fired() {}
  
}
