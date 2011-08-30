#include <Timer.h>
#include "../Radio.h"

module MicaTaskP {
  uses interface Boot;
  uses interface Leds;
  uses interface Timer<TMilli> as Timer0;
  uses interface Timer<TMilli> as Timer1;
  
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface Receive;
  uses interface SplitControl as AMControl;
}
implementation {
  
  message_t pkt;
  bool busy = FALSE;
  uint16_t missedDeadlines = 0;
  uint16_t metDeadlines = 0;
  uint8_t state;
  event void Boot.booted() {
    call AMControl.start(); //start radio
  }
  
  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
     //call Timer0.startPeriodic(DEADLINE);
       call Timer1.startPeriodic(PERIOD);
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
      switch (state){
				case MICA_START: {
					call Timer0.startOneShot(DEADLINE);
				}
				
				
			}
    }
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
    MoteISTMsg* mist_m;
    MicaMsg* micaz_m;
   
    if (len == sizeof(MoteISTMsg)) {
			call Leds.led2Toggle();
      mist_m = (MoteISTMsg*)payload;
      if(mist_m->nodeid == MOTEIST_NODE_ID){
				if (!busy) { //check if radio is busy
          micaz_m = (MicaMsg*)(call Packet.getPayload(&pkt, sizeof(MicaMsg)));
          if (micaz_m == NULL){
						return 0;
          }
          micaz_m->nodeid = MICA_NODE_ID; //assign Micaz ID
          micaz_m->task_i = ITERATIONS;
					micaz_m->deadline = DEADLINE;
					micaz_m->missed = missedDeadlines;
					if((mist_m->task_done)!=0){ // deadline met :)
					  call Timer0.stop(); //stop timer, deadline is met
					}
          else {  // MoteIST is ready to start or it has finished the task
						if(!(call Timer0.isRunning())){ 
							//timer is not running, sending start order
							state = MICA_START;
							micaz_m->task_i = ITERATIONS;
							micaz_m->deadline = DEADLINE;
							micaz_m->missed = missedDeadlines;
							micaz_m->met = metDeadlines;
							}
					  else {
							//moteist has finished the task
							micaz_m->met = ++metDeadlines;
							call Timer0.stop();
						}
							if(call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MicaMsg)) == SUCCESS) {
								busy = TRUE;
							}
					}	
        }//if !busy
			}// if == MICA_NODE_ID
    }// if len = len MicaMsg
    return msg;
  }
  
      
  
  event void Timer0.fired() { //deadline Reached
    MicaMsg* micaz_m;
		if (!busy) { //check if radio is busy
      micaz_m = (MicaMsg*)(call Packet.getPayload(&pkt, sizeof(MicaMsg)));
      if (micaz_m == NULL){
				return;
      }
			micaz_m->nodeid = MICA_NODE_ID;
			micaz_m->task_i = ITERATIONS; // 0 for deadline miss
			micaz_m->deadline = DEADLINE;
			micaz_m->missed = ++missedDeadlines;
			micaz_m->met = metDeadlines;
			micaz_m->state = MICA_DEADLINE_MISS;
			if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MicaMsg)) == SUCCESS) {
				busy = TRUE;
      }
    }
  }
  event void Timer1.fired() { //make new request
    MicaMsg* micaz_m;
		if (!busy) { //check if radio is busy
      micaz_m = (MicaMsg*)(call Packet.getPayload(&pkt, sizeof(MicaMsg)));
      if (micaz_m == NULL){
				return;
      }
      micaz_m->nodeid = MICA_NODE_ID; //assign Micaz ID
			micaz_m->task_i = ITERATIONS;
      micaz_m->deadline = DEADLINE;  // 0 for new request
      micaz_m->missed = missedDeadlines;
      micaz_m->met = metDeadlines;
      micaz_m->state = MICA_REQUEST;
		}
    if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(MicaMsg)) == SUCCESS) {
			call Leds.led0Toggle();
      busy = TRUE;
    }
	}
  
}
