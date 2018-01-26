#include "MyCollection.h"

configuration MyCollectionC
{
  provides interface MyCollection;
}
implementation
{
  components MainC, MyCollectionP, ActiveMessageC, LedsC;
  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;
  components new AMSenderC(AM_COLLECTIONBEACON) as BeaconSender;
  components new AMReceiverC(AM_COLLECTIONBEACON) as BeaconReceiver;
  components new AMSenderC(AM_COLLECTIONDATA) as DataSender;
  components new AMReceiverC(AM_COLLECTIONDATA) as DataReceiver;
  components RandomC;
  components CC2420PacketC;
  MyCollectionP.CC2420Packet -> CC2420PacketC;
  components PacketLinkC;

  MyCollection = MyCollectionP.MyCollection;
  
  MyCollectionP -> MainC.Boot;
  MyCollectionP.NotificationTimer -> Timer0;
  MyCollectionP.RefreshTimer -> Timer1;
  MyCollectionP.RelayTimer -> Timer2;
  MyCollectionP.Leds -> LedsC;
  MyCollectionP.AMPacket -> ActiveMessageC;
  MyCollectionP.BeaconSend -> BeaconSender;
  MyCollectionP.BeaconReceive -> BeaconReceiver;
  MyCollectionP.DataSend -> DataSender;
  MyCollectionP.DataReceive -> DataReceiver;
  MyCollectionP.Random -> RandomC;
  MyCollectionP.AMControl -> ActiveMessageC;
  
  MyCollectionP.PacketLink -> PacketLinkC;
  MyCollectionP.LPL		  -> ActiveMessageC;
}

