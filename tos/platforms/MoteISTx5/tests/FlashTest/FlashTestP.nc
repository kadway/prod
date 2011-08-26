
/**
 * 
 **/

#include "Timer.h"
#include <stdio.h>

module FlashTestP @safe()
{
  //uses interface Timer<TMilli> as Timer0;
  uses interface Leds;
  uses interface Boot;
  uses interface Settings;
  uses interface Init;

 }
implementation
{
   
  void uwait(uint16_t u) {
    uint16_t t0 = TA0R;
    while((TA0R - t0) <= u);
  }

  uint8_t data[] = {1,2,3,4,5,6,7,8};
  event void Boot.booted(){
   printf("Booted.\n");
   call Init.init();
  }
  
  event void Settings.requestLogin(){
    error_t status;
    uint8_t i;
  /**
   * @param data Pointer to the buffer that contains the local
   *     component's configuration data in global memory.
   * @param size Size of the buffer that contains local config data.
   * @return 
   *     SUCCESS if the client got registered and the data loaded with CRC OK
   *     EINVAL if the client got registered and the data didn't load (i.e.
   *         the very first time you power up the device perhaps).
   *     ESIZE if there is not enough memory
   *     FAIL if the client cannot login at this time because you
   *         weren't paying attention to the instructions. :)
   */
    printf("Request login.\n");
   
    status = call Settings.login((void*) data, sizeof(data)*sizeof(uint8_t));
    switch (status){
	  case EINVAL:{
        printf("This is the first boot, nothing in flash memory.\n");
        
        printf("Storing ");
        for(i=0; i<sizeof(data); i++)
          printf("%d ", data[i]);
          
        if(call Settings.store() == SUCCESS)
          printf("\nDone!\n");
        break;
      }
      case SUCCESS:{
	    printf("Data is now loaded from flash.\n");
	    
	    printf("Data is: ");
	    for(i=0; i<sizeof(data); i++)
          printf("%d ", data[i]);

	    break;
      }
      case FAIL:{
		printf("The client cannot login at this time because you weren't paying attention to the instructions. :).\n");
	    break;
      }
      default:
       //error
    }
  }
}
