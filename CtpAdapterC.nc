#include "Ctp.h"
configuration CtpAdapterC {
	provides interface MyCollection;
}
implementation {
	components MainC, ActiveMessageC, LedsC;
	components CtpAdapterP;
 	components CollectionC;
  	components new CollectionSenderC(0xee);

	CtpAdapterP.Boot -> MainC;
	CtpAdapterP.AMControl -> ActiveMessageC;
	CtpAdapterP.RoutingControl -> CollectionC;
	CtpAdapterP.Leds -> LedsC;
	CtpAdapterP.Send -> CollectionSenderC;
	CtpAdapterP.RootControl -> CollectionC;
	CtpAdapterP.Receive -> CollectionC.Receive[0xee];
	CtpAdapterP.CollectionPacket -> CollectionC;
  	CtpAdapterP.LPL		  -> ActiveMessageC;
	
	MyCollection = CtpAdapterP.MyCollection;
}
