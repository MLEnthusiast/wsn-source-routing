#include <Timer.h>
#include "MyCollection.h"
#include <printf.h>

module OneToManyP {
	provides {
		interface OneToMany;
	}
	
	uses{
		interface AMPacket;
		interface PacketLink;
		interface AMSend as PayloadSend;
		interface Receive as PayloadReceive;
	}
}

implementation{
	//#define MAX_PATH_LENGTH 10
	#define NUM_RETRIES 3
	
	typedef struct PayLoads{
		int Route[MAX_PATH_LENGTH + 1];
	}PayLoad;
	
	int source_route[MAX_PATH_LENGTH + 1];
	

	message_t payload_output;
	bool sending_payload;
	bool isSink;
	
	int hashCode(int key) {
		return key % MAX_NODES;
	}
	
	/* Find the address of the parent for a given node */
	int search(int key){
		int parent = -1;
		int hashIndex = hashCode(key);
		
		while(Items[hashIndex] != NULL){
			if(Items[hashIndex]->node == key){
				return Items[hashIndex]->parent;
			}
			
			++hashIndex;
			hashIndex %= MAX_NODES;
		}
		return parent;
	}
	
	/* To form the payload for source routing */
	void preparePayload(int destination, uint16_t counter){
		
		int i;
		//int ar[MAX_PATH_LENGTH + 1];
		int node = destination;
		int parent = -1;
		//PayLoad *payload;
		//payload = (struct PayLoad*) malloc(sizeof(PayLoad));
		
		//ar[MAX_PATH_LENGTH] = counter; // initialize with the payload
		//ar[MAX_PATH_LENGTH - 1] = node;
		//payload->Route[MAX_PATH_LENGTH] = counter;
		//payload->Route[MAX_PATH_LENGTH - 1] = node;
		source_route[MAX_PATH_LENGTH] = counter;
		source_route[MAX_PATH_LENGTH - 1] = node;
		
		for(i = MAX_PATH_LENGTH - 2; i >= 0; i--){
			parent = search(node);
			if((parent != -1) && (parent != TOS_NODE_ID)){
				//ar[i] = parent;
				//payload->Route[i] = parent;
				source_route[i] = parent;
				node = parent;
			}else{
				//ar[i] = -1;
				//payload->Route[i] = -1;
				source_route[i] = -1;
			}
		}
		//memcpy(payload->Route, ar, sizeof(ar));
	}
	
	
	void displayPayload(PayLoad *p){
		int i;
		for(i = 0; i <= MAX_PATH_LENGTH; i++){
			if(p->Route[i] != -1){
				printf(" (%d) ", p->Route[i]);
			}else{
				printf(" ~~ ");
			}
		}
		printf("\n");
	}
	
	/* It finds the next node where the payload must be delivered */
	int get_next_node(PayLoad *p){
		int j = 0;
		while(p->Route[j] == -1){
			++j;
		}
		return p->Route[j];
	}
	
	void send_payload(PayLoad *pl){
		error_t err;
		int next_node;
		call PacketLink.setRetries(&payload_output, NUM_RETRIES); // important to set it every time
		next_node = get_next_node(pl);
		displayPayload(pl);
		printf("sourceRoute:The next node is %d\n", next_node);
		err = call PayloadSend.send(next_node, &payload_output, sizeof(PayLoad));
		if(err == SUCCESS)
			sending_payload = TRUE;
		else
			sending_payload = FALSE;
	}
	
	command void OneToMany.send(am_addr_t destination, uint16_t counter){
		PayLoad *payload;
		preparePayload((int)destination, counter);		
		if(sending_payload)
			return;
		if(TOS_NODE_ID != 1){
			printf("Nodes other than sink can not initiate a P2P transfer.\n");
			return;
		}
		if(destination == 1){
			printf("The sink is trying to send payload to itself. Please stop!\n");
			return;
		}
		payload = call PayloadSend.getPayload(&payload_output, sizeof(PayLoad));
		memcpy(payload->Route, source_route, sizeof(source_route));
		send_payload(payload);
	}
	

	event void PayloadSend.sendDone(message_t* msg, error_t error){
		sending_payload = FALSE;
	}
	
	
	event message_t* PayloadReceive.receive(message_t* msg, void* payload, uint8_t len) {
		PayLoad* payload_in = payload;
		int i = 0;
		am_addr_t from;
		from = call AMPacket.source(msg);
		
		if(payload_in->Route[MAX_PATH_LENGTH - 1] == TOS_NODE_ID){ // deliver payload if the receiving node is the destination node
			signal OneToMany.receive(from, payload_in->Route[MAX_PATH_LENGTH]);
		}else{ // forward the payload to the next node in line
			PayLoad* payload_out;
			if(sending_payload)
				return msg;
			payload_out = call PayloadSend.getPayload(&payload_output, sizeof(PayLoad));
			
			/* To strip off the address of a node where the payload has just been delivered */
			while(payload_in->Route[i] == -1){
				++i;
			}
			payload_in->Route[i] = -1;
			
			memcpy(payload_out, payload_in, sizeof(PayLoad));
			send_payload(payload_out);
			
		}
		return msg;
	}
}