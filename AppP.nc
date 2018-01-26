#include <Timer.h>
#include "MyCollection.h"
#include <AM.h>
#include <printf.h>
#include <UserButton.h>
module AppP {
	uses interface MyCollection;
	uses interface OneToMany;
	uses interface Boot;
	uses interface Timer<TMilli> as StartTimer;
	uses interface Timer<TMilli> as PeriodicTimer;
	uses interface Timer<TMilli> as JitterTimer;
	uses interface Random;
	uses interface Notify<button_state_t>;
	uses interface Leds;
}
implementation
{
#define IMI (60*1024L)
#define JITTER (50*1024L) // 50

	MyData data;
	uint16_t current_parent;
	uint8_t counter;
	//bool routing_data_sent = FALSE;
	
	event void Boot.booted() {
		call Notify.enable();
		call StartTimer.startOneShot(10*1024);
	}

	event void StartTimer.fired() {
		if (TOS_NODE_ID == 1) {
			call MyCollection.buildTree();
		}
		else {
			// TODO: uncomment the following to enable sending data
			call PeriodicTimer.startPeriodic(IMI);
		}
	}

	event void PeriodicTimer.fired() {
		/*
		if(!routing_data_sent){
			call JitterTimer.startOneShot(call Random.rand16() % JITTER);
			routing_data_sent = TRUE;
		}*/
		call JitterTimer.startOneShot(call Random.rand16() % JITTER);
	}

	event void JitterTimer.fired() {
		//printf("app:Information sent to sink.\n");
		data.parent = current_parent;
		call MyCollection.send(&data);
	}
	event void MyCollection.receive(am_addr_t from, MyData* d) {
		printf("app:Recv from %d having parent %d\n", from, d->parent);
	}
	
	event void MyCollection.notifyParent(uint16_t parent){
		printf("app:Node %d is being notified about its parent %d\n",TOS_NODE_ID, parent);
		current_parent = parent;
		//routing_data_sent = FALSE;
	}
	
	event void Notify.notify(button_state_t state){
		if(state == BUTTON_PRESSED){
			if(TOS_NODE_ID == 1){
				counter = (counter + 1) % 8;
				call OneToMany.send(2, counter);
				//call Leds.led0Toggle();	
			}
		}
	}
	
	
	event void OneToMany.receive(am_addr_t from, uint16_t payload_counter){
		printf("app:Received payload %d from node %d\n", payload_counter, (int)from);
		call Leds.set(payload_counter);
	}
}
