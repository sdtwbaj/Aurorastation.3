/obj/machinery/computer
	name = "computer"
	icon = 'icons/obj/computer.dmi'
	icon_state = "computer"
	density = 1
	anchored = 1.0
	use_power = 1
	idle_power_usage = 300
	active_power_usage = 300
	var/circuit = null //The path to the circuit board type. If circuit==null, the computer can't be disassembled.
	var/processing = 0

	var/icon_screen = "generic"
	var/light_range_on = 2
	var/light_power_on = 1
	var/overlay_layer

/obj/machinery/computer/New()
	overlay_layer = layer
	..()

/obj/machinery/computer/initialize()
	power_change()
	update_icon()

/obj/machinery/computer/process()
	if(stat & (NOPOWER|BROKEN))
		return 0
	return 1

/obj/machinery/computer/emp_act(severity)
	if(prob(20/severity)) set_broken()
	..()


/obj/machinery/computer/ex_act(severity)
	switch(severity)
		if(1.0)
			qdel(src)
			return
		if(2.0)
			if (prob(25))
				qdel(src)
				return
			if (prob(50))
				for(var/x in verbs)
					verbs -= x
				set_broken()
		if(3.0)
			if (prob(25))
				for(var/x in verbs)
					verbs -= x
				set_broken()
		else
	return

/obj/machinery/computer/bullet_act(var/obj/item/projectile/Proj)
	if(prob(Proj.get_structure_damage()))
		set_broken()
	..()

/obj/machinery/computer/update_icon()
	overlays.Cut()
	if(stat & NOPOWER)
		set_light(0)
		return
	else
		set_light(light_range_on, light_power_on)

	if(stat & BROKEN)
		overlays += image(icon,"[icon_state]_broken", overlay_layer)
	else
		overlays += image(icon,icon_screen, overlay_layer)

/obj/machinery/computer/power_change()
	..()
	update_icon()
	if(stat & NOPOWER)
		set_light(0)
	else
		set_light(light_range_on, light_power_on)


/obj/machinery/computer/proc/set_broken()
	stat |= BROKEN
	update_icon()

/obj/machinery/computer/proc/decode(text)
	// Adds line breaks
	text = replacetext(text, "\n", "<BR>")
	return text

/obj/machinery/computer/attackby(I as obj, user as mob)
	if(istype(I, /obj/item/weapon/screwdriver) && circuit)
		playsound(src.loc, 'sound/items/Screwdriver.ogg', 50, 1)
		if(do_after(user, 20))
			var/obj/structure/computerframe/A = new /obj/structure/computerframe( src.loc )
			var/obj/item/weapon/circuitboard/M = new circuit( A )
			A.circuit = M
			A.anchored = 1
			for (var/obj/C in src)
				C.loc = src.loc
			if (src.stat & BROKEN)
				user << "<span class='notice'>The broken glass falls out.</span>"
				new /obj/item/weapon/material/shard( src.loc )
				A.state = 3
				A.icon_state = "3"
			else
				user << "<span class='notice'>You disconnect the monitor.</span>"
				A.state = 4
				A.icon_state = "4"
			M.deconstruct(src)
			qdel(src)
	else
		..()

/obj/machinery/computer/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if(istype(mover,/obj/item/projectile))
		if (prob(80))
//Holoscreens are non solid, and the frames of the computers are thin. So projectiles will usually
//pass through
			return 1
	else if(istype(mover) && mover.checkpass(PASSTABLE))
//Animals can run under them, lots of empty space
		return 1
	return 0