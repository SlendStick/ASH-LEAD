class_name Perks
extends RefCounted
## Every perk's actual numbers, in one place.
##
## A perk is a *modifier*, never a new mechanic: each one changes a value the
## combat/movement/stealth code already reads, so bots, humans and network
## clients all get the same behaviour for free. `Db.PERKS` holds the shop text;
## this file holds the truth. If they ever disagree, this file wins.
##
## Usage inside Actor:
##   Perks.speed_mult(self) * base_speed
##   Perks.footstep_radius(self, radius)

const LIST := [
	"ghost", "iron_lungs", "scavenger", "medic", "technician", "runner",
	"predator", "comms", "battering", "diversion", "sharpshooter", "vigor",
	"mask", "burglar",
]


static func has(a: Actor, perk: String) -> bool:
	return a != null and a.perks.has(perk)


# ---------------------------------------------------------------------------
# MOVEMENT / STAMINA
# ---------------------------------------------------------------------------

## "runner": +12% sprint, and sprinting stays quiet for longer.
static func sprint_mult(a: Actor) -> float:
	return 1.12 if has(a, "runner") else 1.0


static func stamina_drain_mult(a: Actor) -> float:
	return 0.82 if has(a, "runner") else 1.0


## "vigor": +25 HP is applied in setup_stats; here only the bleed bonus.
static func bleed_mult(a: Actor) -> float:
	return 0.7 if has(a, "vigor") else 1.0


# ---------------------------------------------------------------------------
# NOISE / STEALTH
# ---------------------------------------------------------------------------

## "ghost": footsteps are 40% quieter (the AI hears a smaller radius).
static func footstep_noise_mult(a: Actor) -> float:
	return 0.6 if has(a, "ghost") else 1.0


## "mask": witnesses and cameras take 4s longer to identify this actor.
static func witness_delay(a: Actor) -> float:
	return 4.0 if has(a, "mask") else 0.0


## "ghost": concealment fades in faster (the silhouette disappears sooner).
static func concealment_bonus(a: Actor) -> float:
	return 0.12 if has(a, "ghost") else 0.0


# ---------------------------------------------------------------------------
# SHOOTING
# ---------------------------------------------------------------------------

## "iron_lungs": -35% spread and recoil while holding breath.
static func breath_spread_mult(a: Actor) -> float:
	return 0.65 if has(a, "iron_lungs") else 1.0


## "sharpshooter": -25% aiming sway, breath recovers twice as fast.
static func aim_spread_mult(a: Actor) -> float:
	return 0.75 if has(a, "sharpshooter") else 1.0


static func breath_recover_mult(a: Actor) -> float:
	return 2.0 if has(a, "sharpshooter") else 1.0


# ---------------------------------------------------------------------------
# LOOT / ECONOMY
# ---------------------------------------------------------------------------

## "scavenger": +50% reserve ammo from corpses, picked-up guns come full.
static func ammo_pickup_mult(a: Actor) -> float:
	return 1.5 if has(a, "scavenger") else 1.0


static func pickup_comes_loaded(a: Actor) -> bool:
	return has(a, "scavenger")


# ---------------------------------------------------------------------------
# SUPPORT
# ---------------------------------------------------------------------------

## "medic": revives 40% faster, medkits heal 50 more.
static func revive_speed_mult(a: Actor) -> float:
	return 1.4 if has(a, "medic") else 1.0


static func medkit_bonus(a: Actor) -> float:
	return 50.0 if has(a, "medic") else 0.0


## "technician": locks and charges are planted 30% faster.
static func interact_speed_mult(a: Actor) -> float:
	return 1.3 if has(a, "technician") else 1.0


## "burglar": windows and grates open without a kit, and 50% quieter.
static func quiet_breach(a: Actor) -> bool:
	return has(a, "burglar")


## "battering": kicking a door stuns everyone behind it for 1.2s.
static func kick_stun(a: Actor) -> float:
	return 1.2 if has(a, "battering") else 0.0


## "predator": a knife kill from behind restores 20 HP.
static func backstab_heal() -> float:
	return 20.0


## "diversion": thrown objects distract AI within 700 px.
static func diversion_radius(a: Actor) -> float:
	return 700.0 if has(a, "diversion") else 260.0


## "comms": the squad ping keeps enemies marked 3s longer.
static func ping_duration_bonus(a: Actor) -> float:
	return 3.0 if has(a, "comms") else 0.0


# ---------------------------------------------------------------------------
# SHOP HELPERS
# ---------------------------------------------------------------------------

static func price(perk: String) -> int:
	return int(Db.PERKS.get(perk, {}).get("price", 0))


static func name_of(perk: String) -> String:
	return str(Db.PERKS.get(perk, {}).get("name", perk))


static func desc_of(perk: String) -> String:
	return str(Db.PERKS.get(perk, {}).get("desc", ""))


## Short line for the HUD/buy menu: "Тихий шаг — шаги на 40% тише".
static func summary(perk: String) -> String:
	var nm := name_of(perk)
	if nm == perk:
		return perk
	return "%s — %s" % [nm, desc_of(perk)]
