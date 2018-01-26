#include <Timer.h>
#include "MyCollection.h"
#include <printf.h>

module MyCollectionP {
  provides {
    interface MyCollection;
  }
  uses {
    interface Timer<TMilli> as RefreshTimer;
    interface Timer<TMilli> as NotificationTimer;
    interface Timer<TMilli> as RelayTimer;
    interface Leds;
    interface Boot;
    interface AMPacket;
	interface PacketLink;
    interface AMSend as BeaconSend;
    interface AMSend as DataSend;
    interface Receive as BeaconReceive;
    interface Receive as DataReceive;
    interface CC2420Packet;
	interface SplitControl as AMControl;
    interface Random;
	interface LowPowerListening as LPL;
  }
}

implementation {
	
#define NUM_RETRIES 3
#define RSSI_THRESHOLD (-90)
#define REBUILD_PERIOD (180*1024L) //exactly 120 seconds, 1024 ticks per second in TinyOS 
#define MAX_METRIC 65535U
#define INITIAL_VAL -1

	
message_t beacon_output;
message_t data_output;
bool sending_beacon;
bool sending_data;
bool i_am_sink;
uint16_t current_seq_no;
uint16_t current_parent;
uint16_t current_hops_to_sink = MAX_METRIC; 
uint16_t num_received;
int current_rssi_to_parent;
bool tree_ever_built = FALSE;

/*struct DataItem{
	int node; // key 
	int parent; // value
}*Items[MAX_NODES];*/

int hashCode(int key) {
   return key % MAX_NODES;
}

int search(int key){
	int hashIndex = hashCode(key);
	
	while(Items[hashIndex] != NULL){
		if(Items[hashIndex]->node == key){
			return hashIndex;
		}
		
		++hashIndex;
		hashIndex %= MAX_NODES;
	}
	return -1;
}

/* To insert the nodes and their parents into a hashtable */
void insert(int key, int value){
	int hashIndex;
	int temp;
	
	struct DataItem *item = (struct DataItem*) malloc(sizeof(struct DataItem));
	item->node = key;
	item->parent = value;
	temp = search(key);
	
	if(temp == -1){
		hashIndex = hashCode(key);
		printf("Hashtable:New Entry.\n");
	
		while(Items[hashIndex] != NULL && Items[hashIndex]->node != -1){
			++hashIndex;
			hashIndex %= MAX_NODES;
		}
		Items[hashIndex] = item;
	}else{
		printf("Hashtable:Update Entry.\n");
		Items[temp] = item;
	}
}

/* To delete all the entries in the table after the tree is newly built*/
void deleteEntries(){

	int i = 0;	
	
	for(i = 0; i < MAX_NODES; i++){
		Items[i] = NULL;
	}
	
}

void display() {
   int i = 0;
   for(i = 0; i<MAX_NODES; i++) {
      if(Items[i] != NULL)
         printf(" (%d,%d)",Items[i]->node,Items[i]->parent);
      else
         printf(" ~~ ");
   }
   printf("\n");
}



task void send_beacon();

event void Boot.booted() {
	current_parent = TOS_NODE_ID;
	/* setting up the LPL layer */
	call LPL.setLocalWakeupInterval(LPL_DEF_REMOTE_WAKEUP);
	call AMControl.start();
}

command void MyCollection.buildTree() {
	i_am_sink = TRUE;	
	current_hops_to_sink = 0;
	post send_beacon();
	call RefreshTimer.startPeriodic(REBUILD_PERIOD);
}

task void send_beacon(){
	if (!sending_beacon) {
		error_t err;
		CollectionBeacon* msg = (CollectionBeacon*) (call BeaconSend.getPayload(&beacon_output, sizeof(CollectionBeacon)));
		msg->seq_no = current_seq_no;
		msg->metric = current_hops_to_sink;
		/*     printf("routing:NOT SEQ %u COST %u\n", current_seq_no, current_hops_to_sink); */
		err = call BeaconSend.send(AM_BROADCAST_ADDR, &beacon_output, sizeof(CollectionBeacon));
		if (err == SUCCESS){
			call Leds.led2On();
			sending_beacon = TRUE;
			if(tree_ever_built){ // delete the previous entries of the table of the sink
				deleteEntries();
			}
		} 
		else {
			printf("routing:\n\n\n\nERROR %u\n", err);
			// retry after a random time
			call NotificationTimer.startOneShot(call Random.rand16()%100);
		}
	}
}

event void RefreshTimer.fired() {
	if (!sending_beacon){
		current_seq_no++;
		post send_beacon();
	}
}

event void NotificationTimer.fired() {
	if (!sending_beacon){
		post send_beacon();
	}
}

event void BeaconSend.sendDone(message_t* msg, error_t error) {
	call Leds.led2Off();
	sending_beacon = FALSE;
	tree_ever_built = TRUE;
	if (error != SUCCESS) {
		// retry sending the notification
		call NotificationTimer.startOneShot(call Random.rand16()%100);
	}
}

int getRssi(message_t* msg){
	int rssi = (int8_t)call CC2420Packet.getRssi(msg) - 45; 
	// or CC2420Packet.getLqi(msg);
	return rssi;
}

void updateParent(uint16_t new_parent, uint16_t new_hops_to_sink, int new_rssi_to_parent) {
    current_parent=new_parent;
    current_hops_to_sink=new_hops_to_sink; 
    current_rssi_to_parent=new_rssi_to_parent; 
    printf("routing:NEW PARENT %u COST %u RSSI %d\n", current_parent, current_hops_to_sink, current_rssi_to_parent );
	// try to signal AppP that the parent has been set
	signal MyCollection.notifyParent(current_parent);
    // Inform neighboring nodes after a random time
    call NotificationTimer.startOneShot(call Random.rand16()%100 + LPL_DEF_REMOTE_WAKEUP);
}

// b == a:  0
// b is newer than a:  1
// b is older than a: -1
int compare_seqn(uint8_t a, uint8_t b) {
	// Since the seqnum wraps around zero, and we can receive outdated beacons or lose
	// several beacons, we need to decide what difference of the seqnums should be considered
	// positive and which -- negative.
	//
	// Here we assume that it is more probable to lose 250 beacons than to receive a very old beacon
	// (with a sequence number smaller than the current one by more than 5).
	uint8_t d = b-a;
	if (d == 0)
		return 0;
	else if (d > 250)  // the difference is in range [-5; -1]: considering it as an old beacon
		return -1;
	else
		return 1; 	   // considering the difference positive in range [0; 250]                          
}


event message_t* BeaconReceive.receive(message_t* msg, void* payload, uint8_t len) {
	if (i_am_sink)
		return msg; // ignore all incoming beacons on the sink
	
    if (len == sizeof(CollectionBeacon)) {
      int cmp;
      uint16_t hops_to_sink_through_sender;
      int rssi_to_sender;

	  CollectionBeacon* beacon = (CollectionBeacon*) payload;
	  if (beacon->metric >= MAX_METRIC)
		  return msg; // otherwise it will wrap to zero
	  
      hops_to_sink_through_sender = beacon->metric + 1;
      rssi_to_sender = getRssi(msg);
      num_received++;
      printf("routing:Received beacon from %u seqn %u hops %u RSSI %d\n", call AMPacket.source(msg), beacon->seq_no, hops_to_sink_through_sender, rssi_to_sender); 

	  if (rssi_to_sender < RSSI_THRESHOLD) {
		printf("routing:Ignoring the beacon, too weak signal\n"); 
	  	return msg;
	  }
	  
      cmp = compare_seqn(current_seq_no, beacon->seq_no); 
	  if  (cmp < 0) // old seq_no, ignoring it
        return msg; 
	  else if (cmp > 0){ // newer seq_no, we are rebuilding the tree
        printf("routing:New seqn: rebuilding the tree\n"); 
        current_seq_no = beacon->seq_no;
        updateParent(call AMPacket.source(msg), hops_to_sink_through_sender, rssi_to_sender);
      } else { /* same seq_no */
       if (current_hops_to_sink > hops_to_sink_through_sender){
          printf("routing:Same seqn, found a parent with a better metric\n"); 
          updateParent(call AMPacket.source(msg), hops_to_sink_through_sender, rssi_to_sender);
        }
        else if ((current_hops_to_sink == hops_to_sink_through_sender) && (current_rssi_to_parent < rssi_to_sender)){
          printf("routing:Same seqn, found a parent with the same metric but better RSSI\n"); 
           updateParent(call AMPacket.source (msg), hops_to_sink_through_sender, rssi_to_sender);
        }
      }
    }
    return msg;
}


void send_data() {
	error_t err;

	call PacketLink.setRetries(&data_output, NUM_RETRIES); // important to set it every time
	err = call DataSend.send(current_parent, &data_output, sizeof(CollectionData));
	if (err == SUCCESS)
		sending_data = TRUE;
	else
		sending_data = FALSE;
}

event void DataSend.sendDone(message_t* msg, error_t error) {
	sending_data = FALSE;
}

command void MyCollection.send(MyData * d) {
	CollectionData* payload;
   
	if (sending_data)
		return;
	if (current_parent == TOS_NODE_ID) // we don't have a parent
		return;
	
	payload = call DataSend.getPayload(&data_output, sizeof(CollectionData));

	payload->hops = 0;
	payload->data = *d;
	payload->from = TOS_NODE_ID;
	send_data();
}

event message_t* DataReceive.receive(message_t* msg, void* payload, uint8_t len) {
	MyData *d;
	CollectionData* payload_in = payload;
	
	if (i_am_sink) {
		signal MyCollection.receive(payload_in->from, &payload_in->data);
		d = &payload_in->data;
		insert((int)payload_in->from, (int)d->parent);
		display();
	}
	else {
		CollectionData* payload_out;
		if (sending_data)
			return msg;
		if (current_parent == TOS_NODE_ID) // we don't have a parent
			return msg;

		payload_out = call DataSend.getPayload(&data_output, sizeof(CollectionData));
		
		sending_data = TRUE;
		memcpy(payload_out, payload_in, sizeof(CollectionData));
		payload_out->hops++;
		call RelayTimer.startOneShot(10);
	}
	return msg;
}


event void RelayTimer.fired() {
	send_data();
}

event void AMControl.startDone(error_t err) {
	if (err != SUCCESS) {
		call AMControl.start();   /* trying again */
	}
}


event void AMControl.stopDone(error_t err) {}

}
