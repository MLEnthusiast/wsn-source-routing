#include <AM.h>
#include "MyCollection.h"

interface OneToMany{
	command void send(am_addr_t destination, uint16_t counter);
	event void receive(am_addr_t from, uint16_t payload_counter);
}