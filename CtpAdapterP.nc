#include "MyCollection.h"
#include "Ctp.h"

module CtpAdapterP {
  uses interface Boot;
  uses interface SplitControl as AMControl;
  uses interface StdControl as RoutingControl;
  uses interface Send;
  uses interface Leds;
  uses interface RootControl;
  uses interface Receive;
  uses interface CollectionPacket;
  uses interface LowPowerListening as LPL;

  provides interface MyCollection;
}
implementation {
  message_t packet;
  bool sendBusy = FALSE;

  event void Boot.booted() {
	/* setting up the LPL layer */
	call LPL.setLocalWakeupInterval(LPL_DEF_REMOTE_WAKEUP);
    call AMControl.start();
  }
  
  event void AMControl.startDone(error_t err) {
    if (err != SUCCESS)
      call AMControl.start();
    else {
      call RoutingControl.start();
    }
  }

command void MyCollection.buildTree() {
	call RootControl.setRoot();
}

command void MyCollection.send(MyData * d) {
    MyData* payload;
	
	if (sendBusy)
		return;
	
    payload = (MyData*)call Send.getPayload(&packet, sizeof(MyData));
	*payload = *d;
	
    if (call Send.send(&packet, sizeof(MyData)) == SUCCESS) 
      sendBusy = TRUE;
  }
  
  event void Send.sendDone(message_t* m, error_t err) {
    sendBusy = FALSE;
  }
  
  event message_t* 
  Receive.receive(message_t* msg, void* payload, uint8_t len) {
	signal MyCollection.receive(call CollectionPacket.getOrigin(msg), payload);
    return msg;
  }

  event void AMControl.stopDone(error_t err) {}
}

