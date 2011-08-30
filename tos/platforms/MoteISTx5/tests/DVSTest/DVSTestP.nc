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
  bool busy = FALSE;
  
  event void Boot.booted() {
    //call Timer0.startPeriodic(ADC_SAMPLE_TIME);
    printf("Booted\n");
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
    }
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
    MoteISTMsg* mist_m;
    MicaMsg* micaz_m;
   
    if (len == sizeof(MicaMsg)) {
      micaz_m = (MicaMsg*)payload;
      /*
       * Check if message comes from Mica1 and if it is a request to start the processing (task != 0)
       */
      if(micaz_m->nodeid == MICA_NODE_ID){
				printf("Incoming msg from mica\n");
				if (!busy) { //check if radio is busy
          mist_m = (MoteISTMsg*)(call Packet.getPayload(&pkt, sizeof(MoteISTMsg)));
          if (mist_m == NULL){
	        return 0;
          }
          mist_m->nodeid = MOTEIST_NODE_ID; //assign MoteIST ID
          if(!(micaz_m->task_i && micaz_m->deadline))
            printf("Mica says deadline met.\n missed so far: %d\nmet so far%d\n", micaz_m->missed, micaz_m->met);
            return msg;
					if((micaz_m->deadline)==0){
					/*
					* Message is a request
					* task has the number of iterations to perform for fibonacci sequence
					*/
					printf("Mica requests...\n");
					}
		      /*
					 * 
           * Send task_done = 0 to receive further requests from micaz
           */
					if(micaz_m->task_i == 0){
            printf("Mica Says: Deadline Miss\n");
            return msg;
					}
				  if(micaz_m->task_i && micaz_m -> deadline){
						printf("Mica says: start. \niterations: %d\ndeadline: %d\nmissed: %d\nmet:%d\n", micaz_m->task_i, micaz_m->deadline, micaz_m->missed, micaz_m->met);
						call Tasks.getFibonacci(micaz_m->task_i, micaz_m->deadline);
						return msg;
					}
					printf("Send OK to start\n");
					mist_m->task_done = 0;
          if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MoteISTMsg)) == SUCCESS) {
            busy = TRUE;
          }
        }//if !busy
			}// if == MICA_NODE_ID
    }// if len = len MicaMsg
    return msg;
  }
  
  event void Tasks.FibonacciDone(uint16_t iterations, uint32_t elapsedTime, error_t status){
	  MoteISTMsg* mist_m;
	  if(status!= SUCCESS){
	    printf("App: Deadline Missed!\n Iterations left:%d\nelapsed time: %lu\n", iterations, elapsedTime);
		}
		else{
	    printf("App: Deadline met!\nFinished at %lu\n", elapsedTime);
	    if (!busy) { //check if radio is busy
        /*build the packet*/
        mist_m = (MoteISTMsg*)(call Packet.getPayload(&pkt, sizeof(MoteISTMsg)));
        if (mist_m == NULL){
	        return;
        }
        mist_m->nodeid = MOTEIST_NODE_ID; //assign MoteIST ID
        mist_m->task_done = 1; // task done in time
        /*send the packet*/
        if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MoteISTMsg)) == SUCCESS) {
            busy = TRUE;
        }
			} //if(!busy)
		}//else
  }
  event void Tasks.FibonacciIterationDone(){ }
  
  event void Timer0.fired() {}
  
  event void Timer1.fired() {}
  
}
