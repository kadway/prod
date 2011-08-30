#define NODE_ID 1 //for MoteIST

enum {
  AM_BLINKTORADIO = 6,
  TIMER_PERIOD_MILLI = 1000
};

typedef nx_struct MicaMsg {
  nx_uint16_t nodeid; //node id
  nx_uint16_t deadline; // deadline for the task done
  nx_uint16_t missed; // number of missed deadlines
} MicaMsg;

typedef nx_struct MoteISTMsg {
  nx_uint16_t nodeid; //node id
  nx_bool task_done; //task done: 1 means done
                     //0 means ok to start task
} MoteISTMsg;
