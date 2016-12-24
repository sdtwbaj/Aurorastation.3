
#define evolve_nutrition	4000//when a nymph gathers this much nutrition, it can evolve into a gestalt


//Diona time variables, these differ slightly between a gestalt and a nymph. All values are times in seconds
/mob/living/carbon/alien/diona
	var/datum/reagents/vessel
	var/list/internal_organs_by_name = list() // so internal organs have less ickiness too
	max_nutrition = 6000
	language = null
	var/energy_duration = 144//The time in seconds that this diona can exist in total darkness before its energy runs out
	var/dark_consciousness = 144//How long this diona can stay on its feet and keep moving in darkness after energy is gone.
	var/dark_survival = 216//How long this diona can survive in darkness after energy is gone, before it dies
	var/datum/dionastats/DS
	mob_size = 4
	density = 0
	mouth_size = 2//how large of a creature it can swallow at once, and how big of a bite it can take out of larger things
	eat_types = 0//This is a bitfield which must be initialised in New(). The valid values for it are in devour.dm
	composition_reagent = "nutriment"//Dionae are plants, so eating them doesn't give animal protein
	var/mob/living/carbon/gestalt = null//If set, then this nymph is inside a gestalt
	name = "diona nymph"
	voice_name = "diona nymph"
	adult_form = /mob/living/carbon/human
	speak_emote = list("chirrups")
	icon_state = "nymph"
	death_msg = "expires with a pitiful chirrup..."
	universal_understand = 0
	universal_speak = 0
	holder_type = /obj/item/weapon/holder/diona
	var/list/sampled_DNA
	var/list/language_progress
	var/obj/item/clothing/head/hat

/mob/living/carbon/alien/diona/ex_act(severity)
	if (life_tick < 4)
		//If a nymph was just born, then it already took damage from the ex_act on its gestalt
		//So we ignore any farther damage for a couple ticks after its born, to prevent it getting hit twice by the same blast
		return
	else
		..()

/mob/living/carbon/alien/diona/New()
	..()
	//species = all_species[]
	set_species("Diona")
	setup_dionastats()
	eat_types |= TYPE_ORGANIC
	nutrition = 0//We dont start with biomass
	update_verbs()
	sampled_DNA = list()
	language_progress = list()

/mob/living/carbon/alien/diona/verb/check_light()
	set category = "Abilities"
	set name = "Check light level"

	var/light = get_lightlevel_diona(DS)

	if (light <= -0.75)
		usr << span("danger", "It is pitch black here! This is extremely dangerous, we must find light, or death will soon follow!")
	else if (light <= 0)
		usr << span("danger", "This area is too dim to sustain us for long, we should move closer to the light, or we will shortly be in danger!")
	else if (light > 0 && light < 1.5)
		usr << span("warning", "The light here can sustain us, barely. It feels cold and distant.")
	else if (light <= 3)
		usr << span("notice", "This light is comfortable and warm, Quite adequate for our needs.")
	else
		usr << span("notice", "This warm radiance is bliss. Here we are safe and energised! Stay a while..")

/mob/living/carbon/alien/diona/start_pulling(var/atom/movable/AM)
	//TODO: Collapse these checks into one proc (see pai and drone)
	if(istype(AM,/obj/item))
		var/obj/item/O = AM
		if(O.w_class > 2)
			src << "<span class='warning'>You are too small to pull that.</span>"
			return
		else
			..()
	else
		src << "<span class='warning'>You are too small to pull that.</span>"
		return

/mob/living/carbon/alien/diona/put_in_hands(var/obj/item/W) // No hands.
	W.loc = get_turf(src)
	return 1



//Functions duplicated from humans, albeit slightly modified
/mob/living/carbon/alien/diona/proc/set_species(var/new_species)
	if(!dna)
		if(!new_species)
			new_species = "Human"
	else
		if(!new_species)
			new_species = dna.species
		else
			dna.species = new_species

	// No more invisible screaming wheelchairs because of set_species() typos.
	if(!all_species[new_species])
		new_species = "Human"

	if(species)

		if(species.name && species.name == new_species)
			return
		if(species.language)
			remove_language(species.language)
		if(species.default_language)
			remove_language(species.default_language)
		// Clear out their species abilities.
		species.remove_inherent_verbs(src)
		holder_type = null

	species = all_species[new_species]
	if(species.default_language)
		add_language(species.default_language)

	if(species.holder_type)
		holder_type = species.holder_type

	icon_state = lowertext(species.name)

	species.handle_post_spawn(src)

	maxHealth = species.total_health


	spawn(0)
		regenerate_icons()
		make_blood()

	// Rebuild the HUD. If they aren't logged in then login() should reinstantiate it for them.
	if(client && client.screen)
		client.screen.len = null
		if(hud_used)
			qdel(hud_used)
		hud_used = new /datum/hud(src)


	if(species)
		return 1
	else
		return 0


/mob/living/carbon/alien/diona/proc/make_blood()

	if(vessel)
		return

	vessel = new/datum/reagents(600)
	vessel.my_atom = src

	vessel.add_reagent("blood",560)
	spawn(1)
		fixblood()

/mob/living/carbon/alien/diona/proc/fixblood()
	for(var/datum/reagent/blood/B in vessel.reagent_list)
		if(B.id == "blood")
			B.data = list(	"donor"=src,"viruses"=null,"species"=species.name,"blood_DNA"=name,"blood_colour"= species.blood_color,"blood_type"=null,	\
							"resistances"=null,"trace_chem"=null, "virus2" = null, "antibodies" = list())
			var/color = B.data["blood_colour"]
			B.color = color


/mob/living/carbon/alien/diona/proc/setup_dionastats()
	var/MLS = (1.5 / 2.1)//Maximum energy lost per second, in total darkness
	DS = new/datum/dionastats()
	DS.max_energy = energy_duration * MLS
	DS.stored_energy = (DS.max_energy / 2)
	DS.max_health = maxHealth
	DS.pain_factor = (50 / dark_consciousness) / MLS
	DS.trauma_factor = (DS.max_health / dark_survival) / MLS
	DS.dionatype = 1//Nymph

//This is called periodically to register or remove this nymph's status as a bad organ of the gestalt
//This is used to notify the gestalt when it needs repaired
/mob/living/carbon/alien/diona/proc/check_status_as_organ()
	if (istype(gestalt, /mob/living/carbon/human))
		var/mob/living/carbon/human/H = gestalt

		if (health < maxHealth)
			if (!(src in H.bad_internal_organs))
				H.bad_internal_organs.Add(src)
		else
			H.bad_internal_organs.Remove(src)


//This function makes sure the nymph has the correct split/merge verbs, depending on whether or not its part of a gestalt
/mob/living/carbon/alien/diona/proc/update_verbs()
	if (gestalt)
		if (!(/mob/living/carbon/alien/diona/proc/split in verbs))
			verbs.Add(/mob/living/carbon/alien/diona/proc/split)

		verbs.Remove(/mob/living/proc/ventcrawl)
		verbs.Remove(/mob/living/proc/hide)
		verbs.Remove(/mob/living/carbon/alien/diona/proc/grow)
		verbs.Remove(/mob/living/carbon/alien/diona/proc/merge)
		verbs.Remove(/mob/living/carbon/proc/absorb_nymph)
		verbs.Remove(/mob/living/proc/devour)
		verbs.Remove(/mob/living/carbon/alien/diona/proc/sample)
	else
		if (!(/mob/living/carbon/alien/diona/proc/merge in verbs))
			verbs.Add(/mob/living/carbon/alien/diona/proc/merge)

		if (!(/mob/living/carbon/proc/absorb_nymph in verbs))
			verbs.Add(/mob/living/carbon/proc/absorb_nymph)

		if (!(/mob/living/carbon/alien/diona/proc/grow in verbs))
			verbs.Add(/mob/living/carbon/alien/diona/proc/grow)

		if (!(/mob/living/proc/devour in verbs))
			verbs.Add(/mob/living/proc/devour)

		if (!(/mob/living/proc/ventcrawl in verbs))
			verbs.Add(/mob/living/proc/ventcrawl)

		if (!(/mob/living/proc/hide in verbs))
			verbs.Add(/mob/living/proc/hide)

		if (!(/mob/living/carbon/alien/diona/proc/sample in verbs))
			verbs.Add(/mob/living/carbon/alien/diona/proc/sample)

		verbs.Remove(/mob/living/carbon/alien/diona/proc/split)

	verbs.Remove(/mob/living/carbon/alien/verb/evolve)//We don't want the old alien evolve verb


/mob/living/carbon/alien/diona/Stat()
	..()
	if (statpanel("Status"))
		stat(null, text("Biomass: [nutrition]/[evolve_nutrition]"))
		if (nutrition > evolve_nutrition)
			stat(null, text("You have enough biomass to grow!"))

//Overriding this function from /mob/living/carbon/alien/life.dm
/mob/living/carbon/alien/diona/handle_regular_status_updates()

	if(status_flags & GODMODE)	return 0

	if(stat == DEAD)
		blinded = 1
		silent = 0
	else
		updatehealth()
		handle_stunned()
		handle_weakened()
		if(health <= 0)
			death()
			blinded = 1
			silent = 0
			return 1

		if (halloss > 50)
			paralysis = 8


		if(paralysis && paralysis > 0)
			handle_paralysed()
			blinded = 1
			stat = UNCONSCIOUS

		if(sleeping)
			if (mind)
				if(mind.active && client != null)
					sleeping = max(sleeping-1, 0)
			blinded = 1
			stat = UNCONSCIOUS
		else if(resting)

		else
			stat = CONSCIOUS

		// Eyes and blindness.
		if(!has_eyes())
			eye_blind =  1
			blinded =    1
			eye_blurry = 1
		else if(eye_blind)
			eye_blind =  max(eye_blind-1,0)
			blinded =    1
		else if(eye_blurry)
			eye_blurry = max(eye_blurry-1, 0)

		//Ears
		if(sdisabilities & DEAF)	//disabled-deaf, doesn't get better on its own
			ear_deaf = max(ear_deaf, 1)
		else if(ear_deaf)			//deafness, heals slowly over time
			ear_deaf = max(ear_deaf-1, 0)
			ear_damage = max(ear_damage-0.05, 0)

		update_icons()

	return 1


/mob/living/carbon/alien/diona/proc/wear_hat(var/obj/item/new_hat)
	if(hat)
		return
	hat = new_hat
	new_hat.forceMove(src)
	update_icons()