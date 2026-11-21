class_name GameTypes
extends RefCounted
## Shared enumerations and small constants used across the project.

enum Team {
	CRIMINALS = 0,
	POLICE = 1,
	CIVILIAN = 2,
	NONE = 3,
}

enum Role {
	OBSERVER = 0,
	TECHNICIAN = 1,
	MEDIC = 2,
	SUPPORT = 3,
	NEGOTIATOR = 4,
	GUARDIAN = 5,
}

enum AlertState {
	CALM = 0,
	SUSPICIOUS = 1,
	SEARCH = 2,
	ALARM = 3,
	CRISIS = 4,
}

enum NPCState {
	ROUTINE = 0,
	SUSPICIOUS = 1,
	SEARCH = 2,
	FLEE = 3,
	HIDE = 4,
	HELP = 5,
	PANIC = 6,
	FOLLOW = 7,
	STAY = 8,
	DEAD = 9,
}

enum OrderType {
	FOLLOW = 0,
	HOLD = 1,
	MOVE = 2,
	COVER = 3,
	GATHER = 4,
	INTERACT = 5,
	HELP = 6,
	ESCORT = 7,
	STEALTH = 8,
	FREE = 9,
	CANCEL = 10,
}

enum GamePhase {
	LOBBY = 0,
	BRIEFING = 1,
	LOADOUT = 2,
	PREP = 3,
	ACTIVE = 4,
	POST = 5,
	RESULTS = 6,
}

enum WeaponClass {
	PISTOL = 0,
	SMG = 1,
	CARBINE = 2,
	SHOTGUN = 3,
	MARKSMAN = 4,
	TASER = 5,
	MELEE = 6,
}

enum MatchOutcome {
	WIN = 0,
	LOSS = 1,
	DRAW = 2,
}


static func team_name(team: int) -> String:
	match team:
		GameTypes.Team.CRIMINALS:
			return Localization.t("team_criminals")
		GameTypes.Team.POLICE:
			return Localization.t("team_police")
		GameTypes.Team.CIVILIAN:
			return Localization.t("team_civilians")
	return Localization.t("team_none")


static func role_name(role: int) -> String:
	match role:
		GameTypes.Role.OBSERVER:
			return Localization.t("role_observer")
		GameTypes.Role.TECHNICIAN:
			return Localization.t("role_technician")
		GameTypes.Role.MEDIC:
			return Localization.t("role_medic")
		GameTypes.Role.SUPPORT:
			return Localization.t("role_support")
		GameTypes.Role.NEGOTIATOR:
			return Localization.t("role_negotiator")
		GameTypes.Role.GUARDIAN:
			return Localization.t("role_guardian")
	return ""


static func order_name(order: int) -> String:
	match order:
		GameTypes.OrderType.FOLLOW:
			return Localization.t("order_follow")
		GameTypes.OrderType.HOLD:
			return Localization.t("order_hold")
		GameTypes.OrderType.MOVE:
			return Localization.t("order_move")
		GameTypes.OrderType.COVER:
			return Localization.t("order_cover")
		GameTypes.OrderType.GATHER:
			return Localization.t("order_gather")
		GameTypes.OrderType.INTERACT:
			return Localization.t("order_interact")
		GameTypes.OrderType.HELP:
			return Localization.t("order_help")
		GameTypes.OrderType.ESCORT:
			return Localization.t("order_escort")
		GameTypes.OrderType.STEALTH:
			return Localization.t("order_stealth")
		GameTypes.OrderType.FREE:
			return Localization.t("order_free")
	return Localization.t("order_cancel")
