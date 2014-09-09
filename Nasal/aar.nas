# Properties under /consumables/fuel/tank[n]:
# + level-gal_us    - Current fuel load.  Can be set by user code.
# + level-lbs       - OUTPUT ONLY property, do not try to set
# + selected        - boolean indicating tank selection.
# + density-ppg     - Fuel density, in lbs/gallon.
# + capacity-gal_us - Tank capacity 
#
# Properties under /engines/engine[n]:
# + fuel-consumed-lbs - Output from the FDM, zeroed by this script
# + out-of-fuel       - boolean, set by this code.


# set constants
UPDATE_PERIOD = 0.3;
AAR_FUEL_GAL_PER_MIN = 1000;

#variables
initialized = 0;
enabled = 0;

print ("running E3B aar");
# print (" enabled " , enabled,  " initialized ", initialized);

updateTanker = func {
	# print ("tanker update running ");
	#if (!initialized ) {
	#	print("calling initialize");
	#	initialize();
	#}

        Refueling = props.globals.getNode("/systems/refuel/contact");
        AllAircraft = props.globals.getNode("ai/models").getChildren("aircraft");
	AllMultiplayer = props.globals.getNode("ai/models").getChildren("multiplayer");
        Aircraft = props.globals.getNode("ai/models/aircraft");

	#   select all tankers which are in contact. For now we assume that it must be in 
	#		contact	with us.

        selectedTankers = [];
	
	if ( enabled ) { # check that AI Models are enabled, otherwise don't bother
            foreach(a; AllAircraft) {
                contact_node = a.getNode("refuel/contact");
                id_node = a.getNode("id");
                tanker_node = a.getNode("tanker");

                contact = contact_node.getValue();
                id = id_node.getValue();
                tanker = tanker_node.getValue();

		#print ("contact ", contact , " tanker " , tanker );

                if (tanker and contact) {
                    append(selectedTankers, a);
                }
            }
	    foreach(m; AllMultiplayer) {
                contact_node = m.getNode("refuel/contact");
                id_node = m.getNode("id");
                tanker_node = m.getNode("tanker");

                contact = contact_node.getValue();
                id = id_node.getValue();
                tanker = tanker_node.getValue();

		#print (" mp contact ", contact , " tanker " , tanker );

                if (tanker and contact) {
                    append(selectedTankers, m);
                }
            }
        }

	#print ("tankers ", size(selectedTankers) );
	addFuel = func {
		fuelAmount = AAR_FUEL_GAL_PER_MIN / 60 * UPDATE_PERIOD;
		numDuds = 0;
		tanks = props.globals.getNode("consumables/fuel").getChildren("tank");
		foreach (w;tanks) {
			currentFuel = w.getNode("level-gal_us").getValue();
			capacity = w.getNode("capacity-gal_us").getValue();
			if (capacity < 2 or (currentFuel+fuelAmount)>capacity) {
				numDuds+=1;
			}
		}
		#print(size(tanks)-numDuds);
		addedFuel= fuelAmount / (size(tanks)-numDuds);
		foreach (w;tanks) {
			string="consumables/fuel/"~w.getName()~"["~w.getIndex()~"]/";
			currentFuel = w.getNode("level-gal_us").getValue();
			capacity = w.getNode("capacity-gal_us").getValue();
			if ((currentFuel + addedFuel)  < capacity) {
				setprop(string,"level-gal_us",currentFuel + addedFuel);
			}
		}
	}

	#hasAARBoom = getprop("systems/equipment/AARBoom");
        if ( size(selectedTankers) >= 1 ){
            Refueling.setBoolValue(1);
            #addFuel();
        } else {
            Refueling.setBoolValue(0);
        }

	settimer(updateTanker,UPDATE_PERIOD);
}




# Initalize: Make sure all needed properties are present and accounted
# for, and that they have sane default values.

initialize = func {

    AI_Enabled = props.globals.getNode("sim/ai/enabled");
    Refueling = props.globals.getNode("/systems/refuel/contact",1);

    Refueling.setBoolValue(0);
    enabled = AI_Enabled.getValue();

    initialized = 1;
}

registerTimer = func {
    settimer(arg[0],UPDATE_PERIOD);
} 

# Fire it up
if (!initialized) {initialize();}
settimer(updateTanker,10);

#=================
# strobe stuff
beacon = func() {
	#turn off tail beacon
	base = "sim/model/e3b/material/tailBeacon/";
	setprop(base ~ "diffuse/red", 0.4);
	setprop(base ~ "ambient/red", 0.4);
	setprop(base ~ "emission/red", 0);

	settimer(bellyBeacon,0.5);
	settimer(tailBeacon,1);	
}

bellyBeacon = func() {
	base = "sim/model/e3b/material/bellyBeacon/";
	setprop(base ~ "diffuse/red", 1);
	setprop(base ~ "ambient/red", 1);
	setprop(base ~ "emission/red", 1);
}

tailBeacon = func() {
	base = "sim/model/e3b/material/bellyBeacon/";
	setprop(base ~ "diffuse/red", 0.4);
	setprop(base ~ "ambient/red", 0.4);
	setprop(base ~ "emission/red", 0);

	base = "sim/model/e3b/material/tailBeacon/";
	setprop(base ~ "diffuse/red", 1);
	setprop(base ~ "ambient/red", 1);
	setprop(base ~ "emission/red", 1);
}

sec15cron = func {
   beacon();
   settimer(sec15cron,1.5);
}

# EXPORT : functions ending by export are called from xml
# CRON : functions ending by cron are called from timer
# SCHEDULE : functions ending by schedule are called from cron



# ==============
# DME Selector
# ==============

# DME

dmeschedule = func{
   brgmode=getprop("/instrumentation/navcomputer/brg-switch-position");
   inrange="false";
   distance=999.9;
   bearing=0;
   heading=0;
   if(brgmode == 1){
       inrange=getprop("/instrumentation/dme/in-range");
       if(inrange){distance=getprop("/instrumentation/dme/indicated-distance-nm");};
       bearing=getprop("/instrumentation/nav/radials/reciprocal-radial-deg");
   }
   if(brgmode == 2){
       inrange=getprop("/instrumentation/tacan/in-range");
       if(inrange){distance=getprop("/instrumentation/tacan/indicated-distance-nm");};
       bearing=getprop("/instrumentation/tacan/indicated-bearing-true-deg")-getprop("/environment/magnetic-variation-deg");
   }
   if(brgmode == 3){
       inrange=getprop("/instrumentation/tacan/in-range");
       if(inrange){distance=getprop("/instrumentation/tacan/indicated-distance-nm");};
       bearing=getprop("/instrumentation/adf/indicated-bearing-deg");
       heading=getprop("/orientation/heading-magnetic-deg[0]");
       bearing=bearing+heading;
   }
   if(brgmode == 4){
       inrange=getprop("/instrumentation/tacan/in-range");
       if(inrange){distance=getprop("/instrumentation/tacan/indicated-distance-nm");};
       bearing=getprop("/instrumentation/nav/radials/reciprocal-radial-deg");
   }
   setprop("/instrumentation/navcomputer/in-range", inrange);
   setprop("/instrumentation/navcomputer/indicated-bearing", bearing);
   setprop("/instrumentation/navcomputer/indicated-distance-nm", distance);

}

sec1cron = func {
   dmeschedule();
   settimer(sec1cron,1);
}

init = func {
   settimer(sec1cron,1);
   settimer(sec15cron,1.5);
}

init();


