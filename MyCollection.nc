#include <AM.h>
#include "MyCollection.h"

interface MyCollection {
  command void buildTree();
  command void send(MyData* d);
  event void receive(am_addr_t from, MyData* d);
  event void notifyParent(uint16_t parent);
}
