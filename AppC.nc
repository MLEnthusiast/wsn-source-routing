configuration AppC {
}
implementation {
	components MyCollectionC as CollectionC;
	//components CtpAdapterC as CollectionC;
	components OneToManyC as OtoMC;
	components AppP, UserButtonC;
	components SerialPrintfC, SerialStartC;
	components new TimerMilliC() as StartTimer;
	components new TimerMilliC() as PeriodicTimer;
	components new TimerMilliC() as JitterTimer;
	components MainC, RandomC, LedsC;

	AppP.Boot -> MainC;
	AppP.MyCollection -> CollectionC;
	AppP.Random -> RandomC;
	AppP.StartTimer -> StartTimer;
	AppP.PeriodicTimer -> PeriodicTimer;
	AppP.JitterTimer -> JitterTimer;
	AppP.Notify -> UserButtonC;
	AppP.Leds -> LedsC;
	AppP.OneToMany -> OtoMC;
}
