#include "MyCollection.h"

configuration OneToManyC{
	provides interface OneToMany;
}

implementation{
	components OneToManyP, ActiveMessageC, UserButtonC;
	components new AMSenderC(AM_PAYLOADDATA) as PayloadSender;
	components new AMReceiverC(AM_PAYLOADDATA) as PayloadReceiver;
	components PacketLinkC;
	
	OneToMany = OneToManyP.OneToMany;
	
	OneToManyP.AMPacket -> ActiveMessageC;
	OneToManyP.PayloadSend -> PayloadSender;
	OneToManyP.PayloadReceive -> PayloadReceiver;
	OneToManyP.PacketLink -> PacketLinkC;
}