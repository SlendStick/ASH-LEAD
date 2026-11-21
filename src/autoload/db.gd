extends Node
## ASH&LEAD -- central content database.
##
## Pure data: weapons, gadgets, armour, perks, operatives (skins), modes, maps,
## civilian archetypes, hostage scenarios, mission intel. Gameplay code only reads
## from here, so balance passes never require touching logic.

const TEAM_CRIMINAL := 0
const TEAM_POLICE := 1
const TEAM_CIVILIAN := 2

const TEAM_NAMES := {0: "НАЁМНИКИ", 1: "ПРАВОПОРЯДОК", 2: "ГРАЖДАНСКИЕ"}
const TEAM_SHORT := {0: "ASH", 1: "LEAD", 2: "CIV"}
const TEAM_COLORS := {
	0: Color("ff2b62"),
	1: Color("35c9ff"),
	2: Color("c8b98a"),
}

## Neon-noir palette. Used by every UI screen and shader so the game reads as one
## art direction: cold blue night, acid green hazard, magenta advertising,
## blood red violence, wet asphalt everywhere.
const PALETTE := {
	"void": Color("07040d"),
	"asphalt": Color("101019"),
	"concrete": Color("1d1c2b"),
	"steel": Color("2b2a3d"),
	"fog": Color("191232"),
	"blue": Color("1d6bff"),
	"cyan": Color("35c9ff"),
	"ice": Color("bfefff"),
	"green": Color("2bff9a"),
	"acid": Color("b6ff2b"),
	"magenta": Color("ff2bd6"),
	"violet": Color("8d2bff"),
	"red": Color("ff1f4b"),
	"blood": Color("7a0016"),
	"amber": Color("ffb02b"),
	"bone": Color("e8e3d5"),
	"grey": Color("7b7890"),
}

# ---------------------------------------------------------------------------
# WEAPONS
# ---------------------------------------------------------------------------
# dmg        : body damage per pellet
# head       : headshot multiplier
# limb       : limb multiplier
# rpm        : rounds per minute
# mag        : magazine size
# reserve    : spare rounds (0 == infinite pickups, arcade modes refill)
# spread     : base cone in degrees
# move_spread: extra degrees at full sprint
# recoil     : vertical kick per shot in degrees
# falloff    : damage multiplier per 100 px beyond `range`
# range      : effective range in px before falloff
# speed      : projectile speed px/s (hitscan if >= 4000)
# pellets    : shots per trigger pull
# loud       : noise radius for AI hearing
# reload     : seconds
# draw       : seconds to raise
# kind       : "pistol" "smg" "rifle" "shotgun" "sniper" "lmg" "special" "melee" "throw"
# class      : "primary" "secondary" "melee" "gadget"
# price      : cost in PAYDAY-style loadout budget
# kick       : camera kick 0..1
# auto       : held trigger
# teams      : which teams may buy it
const WEAPONS := {
	# --- pistols -----------------------------------------------------------
	"pm9": {
		"name": "ПМ-9 «Шёпот»", "short": "ПМ-9", "class": "secondary", "kind": "pistol",
		"dmg": 24.0, "head": 3.2, "limb": 0.75, "rpm": 380.0, "mag": 15, "reserve": 90,
		"spread": 1.1, "move_spread": 2.2, "recoil": 1.5, "range": 620.0, "falloff": 0.72,
		"speed": 4200.0, "pellets": 1, "loud": 780.0, "reload": 1.55, "draw": 0.22,
		"price": 0, "kick": 0.18, "auto": false, "penetration": 0.0, "tracer": "warm",
		"desc": "Штатный пистолет. С глушителем-обманкой: звук глуше, но вспышка видна.",
		"teams": [0, 1],
	},
	"deagle45": {
		"name": "«Клык» .45", "short": "КЛЫК", "class": "secondary", "kind": "pistol",
		"dmg": 62.0, "head": 2.6, "limb": 0.7, "rpm": 210.0, "mag": 7, "reserve": 42,
		"spread": 1.4, "move_spread": 4.4, "recoil": 4.6, "range": 780.0, "falloff": 0.68,
		"speed": 4600.0, "pellets": 1, "loud": 1050.0, "reload": 2.1, "draw": 0.3,
		"price": 450, "kick": 0.48, "auto": false, "penetration": 0.35, "tracer": "white",
		"desc": "Тяжёлый револьверный калибр. Пробивает дерево и лёгкие укрытия.",
		"teams": [0, 1],
	},
	"machine_pistol": {
		"name": "«Осина» АПБ", "short": "ОСИНА", "class": "secondary", "kind": "pistol",
		"dmg": 17.0, "head": 2.4, "limb": 0.8, "rpm": 940.0, "mag": 20, "reserve": 100,
		"spread": 2.6, "move_spread": 4.2, "recoil": 1.9, "range": 460.0, "falloff": 0.6,
		"speed": 4000.0, "pellets": 1, "loud": 820.0, "reload": 1.8, "draw": 0.24,
		"price": 600, "kick": 0.24, "auto": true, "penetration": 0.0, "tracer": "warm",
		"desc": "Автоматический пистолет. Поливает свинцом в упор, бесполезен на дистанции.",
		"teams": [0, 1],
	},
	"flash_pistol": {
		"name": "«Сигнал»", "short": "СИГНАЛ", "class": "secondary", "kind": "special",
		"dmg": 6.0, "head": 1.0, "limb": 1.0, "rpm": 120.0, "mag": 4, "reserve": 8,
		"spread": 1.0, "move_spread": 1.0, "recoil": 1.0, "range": 520.0, "falloff": 1.0,
		"speed": 3600.0, "pellets": 1, "loud": 600.0, "reload": 1.9, "draw": 0.26,
		"price": 900, "kick": 0.2, "auto": false, "penetration": 0.0, "tracer": "flash",
		"flash": 2.4, "desc": "Сигнальный пистолет: ослепляет конусом, поджигает шторы.",
		"teams": [0, 1],
	},
	# --- SMG ---------------------------------------------------------------
	"vk9": {
		"name": "ВК-9 «Стриж»", "short": "СТРИЖ", "class": "primary", "kind": "smg",
		"dmg": 21.0, "head": 2.5, "limb": 0.8, "rpm": 860.0, "mag": 30, "reserve": 150,
		"spread": 1.9, "move_spread": 2.4, "recoil": 1.4, "range": 520.0, "falloff": 0.68,
		"speed": 4400.0, "pellets": 1, "loud": 900.0, "reload": 1.9, "draw": 0.32,
		"price": 1250, "kick": 0.2, "auto": true, "penetration": 0.05, "tracer": "warm",
		"desc": "Компактный ПП. Низкий разброс в движении — оружие раша.",
		"teams": [0, 1],
	},
	"mp5sd": {
		"name": "MP-5SD «Тень»", "short": "ТЕНЬ", "class": "primary", "kind": "smg",
		"dmg": 19.0, "head": 2.4, "limb": 0.8, "rpm": 780.0, "mag": 30, "reserve": 150,
		"spread": 1.4, "move_spread": 1.6, "recoil": 1.0, "range": 480.0, "falloff": 0.62,
		"speed": 4200.0, "pellets": 1, "loud": 210.0, "reload": 2.0, "draw": 0.34,
		"price": 1900, "kick": 0.16, "auto": true, "penetration": 0.05, "tracer": "warm",
		"suppressed": true,
		"desc": "ПП с интегральным глушителем. Почти не поднимает шум — оружие стелса.",
		"teams": [0, 1],
	},
	"pp19": {
		"name": "ПП-19 «Гадюка»", "short": "ГАДЮКА", "class": "primary", "kind": "smg",
		"dmg": 25.0, "head": 2.2, "limb": 0.78, "rpm": 700.0, "mag": 45, "reserve": 180,
		"spread": 2.4, "move_spread": 3.0, "recoil": 1.8, "range": 560.0, "falloff": 0.7,
		"speed": 4300.0, "pellets": 1, "loud": 950.0, "reload": 2.2, "draw": 0.36,
		"price": 1500, "kick": 0.24, "auto": true, "penetration": 0.1, "tracer": "warm",
		"desc": "Большой магазин, тяжёлая пуля. Держит коридоры, но долго перезаряжается.",
		"teams": [0, 1],
	},
	# --- rifles ------------------------------------------------------------
	"ak12": {
		"name": "АК-12 «Гроза»", "short": "ГРОЗА", "class": "primary", "kind": "rifle",
		"dmg": 36.0, "head": 2.6, "limb": 0.72, "rpm": 600.0, "mag": 30, "reserve": 120,
		"spread": 1.6, "move_spread": 5.2, "recoil": 2.9, "range": 900.0, "falloff": 0.8,
		"speed": 5200.0, "pellets": 1, "loud": 1250.0, "reload": 2.3, "draw": 0.4,
		"price": 2700, "kick": 0.36, "auto": true, "penetration": 0.45, "tracer": "warm",
		"desc": "Универсальный автомат. Три попадания в торс, одно в голову.",
		"teams": [0, 1],
	},
	"m4": {
		"name": "M-4 «Хирург»", "short": "ХИРУРГ", "class": "primary", "kind": "rifle",
		"dmg": 31.0, "head": 2.9, "limb": 0.75, "rpm": 700.0, "mag": 30, "reserve": 120,
		"spread": 1.2, "move_spread": 4.6, "recoil": 2.2, "range": 980.0, "falloff": 0.84,
		"speed": 5400.0, "pellets": 1, "loud": 1150.0, "reload": 2.1, "draw": 0.36,
		"price": 3100, "kick": 0.3, "auto": true, "penetration": 0.4, "tracer": "warm",
		"desc": "Точный автомат полиции. Контроль отдачи важнее скорости.",
		"teams": [0, 1],
	},
	"scar": {
		"name": "SCAR-H «Молот»", "short": "МОЛОТ", "class": "primary", "kind": "rifle",
		"dmg": 52.0, "head": 2.4, "limb": 0.7, "rpm": 420.0, "mag": 20, "reserve": 80,
		"spread": 1.5, "move_spread": 6.0, "recoil": 4.2, "range": 1100.0, "falloff": 0.86,
		"speed": 5600.0, "pellets": 1, "loud": 1400.0, "reload": 2.6, "draw": 0.46,
		"price": 3600, "kick": 0.46, "auto": true, "penetration": 0.6, "tracer": "hot",
		"desc": "Тяжёлая винтовка. Пробивает бетонную перегородку и двух врагов.",
		"teams": [0, 1],
	},
	"vintorez": {
		"name": "ВСС «Шёпот-2»", "short": "ШЁПОТ-2", "class": "primary", "kind": "rifle",
		"dmg": 78.0, "head": 2.2, "limb": 0.7, "rpm": 260.0, "mag": 10, "reserve": 50,
		"spread": 0.6, "move_spread": 7.0, "recoil": 4.0, "range": 1300.0, "falloff": 0.9,
		"speed": 5800.0, "pellets": 1, "loud": 180.0, "reload": 2.8, "draw": 0.5,
		"price": 4200, "kick": 0.42, "auto": false, "penetration": 0.55, "tracer": "cold",
		"suppressed": true,
		"desc": "Бесшумная снайперская винтовка. Один выстрел — один тихий труп.",
		"teams": [0, 1],
	},
	# --- sniper / shotgun / lmg --------------------------------------------
	"svd": {
		"name": "СВД «Око»", "short": "ОКО", "class": "primary", "kind": "sniper",
		"dmg": 105.0, "head": 2.4, "limb": 0.65, "rpm": 40.0, "mag": 10, "reserve": 40,
		"spread": 0.2, "move_spread": 9.0, "recoil": 6.5, "range": 1800.0, "falloff": 0.95,
		"speed": 7000.0, "pellets": 1, "loud": 1800.0, "reload": 3.1, "draw": 0.6,
		"price": 4300, "kick": 0.7, "auto": false, "penetration": 0.85, "tracer": "hot",
		"scope": 3.0,
		"desc": "Дальнобойная снайперка. Оптический прицел: колесо мыши меняет кратность.",
		"teams": [0, 1],
	},
	"saiga12": {
		"name": "Сайга-12 «Мясорубка»", "short": "МЯСОРУБКА", "class": "primary", "kind": "shotgun",
		"dmg": 13.0, "head": 2.2, "limb": 0.8, "rpm": 300.0, "mag": 8, "reserve": 32,
		"spread": 6.5, "move_spread": 1.5, "recoil": 4.0, "range": 260.0, "falloff": 0.4,
		"speed": 3400.0, "pellets": 9, "loud": 1400.0, "reload": 2.6, "draw": 0.42,
		"price": 3300, "kick": 0.55, "auto": true, "penetration": 0.0, "tracer": "warm",
		"desc": "Полуавтоматический дробовик. В коридоре квартиры убивает мгновенно.",
		"teams": [0, 1],
	},
	"ksg": {
		"name": "КСГ «Заслон»", "short": "ЗАСЛОН", "class": "primary", "kind": "shotgun",
		"dmg": 16.0, "head": 2.0, "limb": 0.8, "rpm": 85.0, "mag": 6, "reserve": 24,
		"spread": 4.2, "move_spread": 1.0, "recoil": 5.4, "range": 220.0, "falloff": 0.35,
		"speed": 3200.0, "pellets": 12, "loud": 1500.0, "reload": 3.0, "draw": 0.44,
		"price": 2600, "kick": 0.62, "auto": false, "penetration": 0.0, "tracer": "warm",
		"door_breach": true,
		"desc": "Дробовик с дверным патроном. Сносит двери с петель одним выстрелом.",
		"teams": [0, 1],
	},
	"pkm": {
		"name": "ПКМ «Голод»", "short": "ГОЛОД", "class": "primary", "kind": "lmg",
		"dmg": 44.0, "head": 2.0, "limb": 0.7, "rpm": 650.0, "mag": 100, "reserve": 200,
		"spread": 3.2, "move_spread": 8.0, "recoil": 3.4, "range": 1200.0, "falloff": 0.9,
		"speed": 5200.0, "pellets": 1, "loud": 1700.0, "reload": 6.0, "draw": 0.8,
		"price": 5200, "kick": 0.4, "auto": true, "penetration": 0.7, "tracer": "hot",
		"heavy": 0.22,
		"desc": "Пулемёт. Подавляет целые этажи, но с ним не побегаешь.",
		"teams": [0, 1],
	},
	# --- special -----------------------------------------------------------
	"rpg7": {
		"name": "РПГ-7 «Поцелуй»", "short": "ПОЦЕЛУЙ", "class": "primary", "kind": "special",
		"dmg": 140.0, "head": 1.0, "limb": 1.0, "rpm": 20.0, "mag": 1, "reserve": 3,
		"spread": 0.4, "move_spread": 2.0, "recoil": 8.0, "range": 2200.0, "falloff": 1.0,
		"speed": 760.0, "pellets": 1, "loud": 2200.0, "reload": 4.5, "draw": 1.0,
		"price": 9000, "kick": 0.9, "auto": false, "penetration": 1.0, "tracer": "rocket",
		"blast": 190.0, "blast_dmg": 130.0,
		"desc": "Ракетница. Один выстрел ломает стену, отряд и весь этаж.",
		"teams": [0, 1],
	},
	"crossbow": {
		"name": "Арбалет «Тихо»", "short": "ТИХО", "class": "primary", "kind": "special",
		"dmg": 95.0, "head": 2.0, "limb": 0.7, "rpm": 45.0, "mag": 1, "reserve": 8,
		"spread": 0.3, "move_spread": 3.0, "recoil": 1.0, "range": 1000.0, "falloff": 0.9,
		"speed": 2600.0, "pellets": 1, "loud": 60.0, "reload": 2.4, "draw": 0.5,
		"price": 2800, "kick": 0.1, "auto": false, "penetration": 0.3, "tracer": "cold",
		"suppressed": true, "silent_kill": true,
		"desc": "Бесшумное оружие стелса. Труп падает без звука — если никто не видел.",
		"teams": [0, 1],
	},
	# --- melee -------------------------------------------------------------
	"knife": {
		"name": "Тесак «Слово»", "short": "ТЕСАК", "class": "melee", "kind": "melee",
		"dmg": 55.0, "head": 1.0, "limb": 1.0, "rpm": 150.0, "mag": 1, "reserve": 0,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 68.0, "falloff": 1.0,
		"speed": 9000.0, "pellets": 1, "loud": 260.0, "reload": 0.1, "draw": 0.15,
		"price": 0, "kick": 0.05, "auto": false, "penetration": 0.0, "tracer": "none",
		"execute": true,
		"desc": "Нож. Удар со спины — тихое добивание. Удар в лицо — крик и кровь.",
		"teams": [0, 1],
	},
	"pipe": {
		"name": "Труба «Аргумент»", "short": "АРГУМЕНТ", "class": "melee", "kind": "melee",
		"dmg": 72.0, "head": 1.2, "limb": 1.0, "rpm": 95.0, "mag": 1, "reserve": 0,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 76.0, "falloff": 1.0,
		"speed": 9000.0, "pellets": 1, "loud": 420.0, "reload": 0.1, "draw": 0.2,
		"price": 200, "kick": 0.16, "auto": false, "penetration": 0.0, "tracer": "none",
		"stun": 0.9, "execute": true,
		"desc": "Стальная труба. Оглушает, ломает мебель, оставляет синяки и зубы.",
		"teams": [0, 1],
	},
	"baton": {
		"name": "Дубинка «Закон»", "short": "ЗАКОН", "class": "melee", "kind": "melee",
		"dmg": 34.0, "head": 1.0, "limb": 1.0, "rpm": 110.0, "mag": 1, "reserve": 0,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 80.0, "falloff": 1.0,
		"speed": 9000.0, "pellets": 1, "loud": 300.0, "reload": 0.1, "draw": 0.16,
		"price": 0, "kick": 0.1, "auto": false, "penetration": 0.0, "tracer": "none",
		"stun": 1.4, "nonlethal_bonus": true, "execute": true,
		"desc": "Полицейская дубинка. Оглушение вместо смерти: задержание даёт больше денег.",
		"teams": [1],
	},
	"taser": {
		"name": "Тазер «Искра»", "short": "ИСКРА", "class": "melee", "kind": "melee",
		"dmg": 12.0, "head": 1.0, "limb": 1.0, "rpm": 40.0, "mag": 1, "reserve": 4,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 150.0, "falloff": 1.0,
		"speed": 9000.0, "pellets": 1, "loud": 320.0, "reload": 1.6, "draw": 0.2,
		"price": 700, "kick": 0.08, "auto": false, "penetration": 0.0, "tracer": "spark",
		"stun": 2.2, "nonlethal_bonus": true, "execute": false,
		"desc": "Электрошокер. Складывает цель на две секунды — идеально для ареста.",
		"teams": [1],
	},
	# --- thrown ------------------------------------------------------------
	"grenade": {
		"name": "Граната РГД", "short": "РГД", "class": "gadget", "kind": "throw",
		"dmg": 120.0, "head": 1.0, "limb": 1.0, "rpm": 30.0, "mag": 1, "reserve": 2,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 480.0, "falloff": 1.0,
		"speed": 620.0, "pellets": 1, "loud": 900.0, "reload": 3.0, "draw": 0.3,
		"price": 800, "kick": 0.1, "auto": false, "penetration": 0.0, "tracer": "none",
		"blast": 150.0, "blast_dmg": 125.0, "fuse": 2.6,
		"desc": "Осколочная. Рикошетит, шипит, разбрасывает мебель и конечности.",
		"teams": [0, 1],
	},
	"flashbang": {
		"name": "Светошумовая «Хор»", "short": "ХОР", "class": "gadget", "kind": "throw",
		"dmg": 0.0, "head": 1.0, "limb": 1.0, "rpm": 30.0, "mag": 1, "reserve": 3,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 520.0, "falloff": 1.0,
		"speed": 640.0, "pellets": 1, "loud": 900.0, "reload": 3.0, "draw": 0.3,
		"price": 600, "kick": 0.05, "auto": false, "penetration": 0.0, "tracer": "none",
		"blast": 210.0, "flash": 3.6, "fuse": 1.8, "bolt": true,
		"desc": "Ослепляет и глушит всех, кто смотрит в сторону вспышки.",
		"teams": [0, 1],
	},
	"smoke": {
		"name": "Дым «Полог»", "short": "ПОЛОГ", "class": "gadget", "kind": "throw",
		"dmg": 0.0, "head": 1.0, "limb": 1.0, "rpm": 30.0, "mag": 1, "reserve": 3,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 520.0, "falloff": 1.0,
		"speed": 600.0, "pellets": 1, "loud": 120.0, "reload": 3.0, "draw": 0.3,
		"price": 400, "kick": 0.05, "auto": false, "penetration": 0.0, "tracer": "none",
		"blast": 190.0, "smoke": 14.0, "fuse": 1.4,
		"desc": "Режет линию видимости. ИИ и игроки слепнут одинаково.",
		"teams": [0, 1],
	},
	"molotov": {
		"name": "«Коктейль»", "short": "КОКТЕЙЛЬ", "class": "gadget", "kind": "throw",
		"dmg": 45.0, "head": 1.0, "limb": 1.0, "rpm": 30.0, "mag": 1, "reserve": 2,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 460.0, "falloff": 1.0,
		"speed": 640.0, "pellets": 1, "loud": 400.0, "reload": 3.0, "draw": 0.3,
		"price": 500, "kick": 0.05, "auto": false, "penetration": 0.0, "tracer": "none",
		"blast": 130.0, "fire": 8.0, "fuse": 0.0, "impact_fuse": true,
		"desc": "Бутылка с бензином. Поджигает пол, запирает коридор, сжигает улики.",
		"teams": [0, 1],
	},
	"remote_charge": {
		"name": "Растяжка «Слово»", "short": "РАСТЯЖКА", "class": "gadget", "kind": "throw",
		"dmg": 160.0, "head": 1.0, "limb": 1.0, "rpm": 30.0, "mag": 1, "reserve": 3,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 120.0, "falloff": 1.0,
		"speed": 200.0, "pellets": 1, "loud": 40.0, "reload": 2.0, "draw": 0.3,
		"price": 1100, "kick": 0.05, "auto": false, "penetration": 0.0, "tracer": "none",
		"blast": 140.0, "blast_dmg": 150.0, "tripwire": true,
		"desc": "Ставится на стену. Взрывается, когда враг пересекает луч.",
		"teams": [0, 1],
	},
	"c4": {
		"name": "Заряд C-4", "short": "C-4", "class": "gadget", "kind": "throw",
		"dmg": 400.0, "head": 1.0, "limb": 1.0, "rpm": 20.0, "mag": 1, "reserve": 1,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 120.0, "falloff": 1.0,
		"speed": 200.0, "pellets": 1, "loud": 60.0, "reload": 2.0, "draw": 0.3,
		"price": 0, "kick": 0.05, "auto": false, "penetration": 0.0, "tracer": "none",
		"blast": 420.0, "blast_dmg": 300.0, "objective": true,
		"desc": "Заряд для бомбы/сейфа. Один на команду, у одного курьера.",
		"teams": [0],
	},
	"drill": {
		"name": "Дрель «Терпение»", "short": "ДРЕЛЬ", "class": "gadget", "kind": "throw",
		"dmg": 0.0, "head": 1.0, "limb": 1.0, "rpm": 20.0, "mag": 1, "reserve": 1,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 120.0, "falloff": 1.0,
		"speed": 200.0, "pellets": 1, "loud": 1500.0, "reload": 2.0, "draw": 0.3,
		"price": 0, "kick": 0.05, "auto": false, "penetration": 0.0, "tracer": "none",
		"objective": true, "loud_work": true,
		"desc": "Вскрывает сейф или замок за 45 секунд и на весь квартал.",
		"teams": [0],
	},
	"keycard": {
		"name": "Отмычка «Ключ»", "short": "КЛЮЧ", "class": "gadget", "kind": "throw",
		"dmg": 0.0, "head": 1.0, "limb": 1.0, "rpm": 20.0, "mag": 1, "reserve": 1,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 120.0, "falloff": 1.0,
		"speed": 200.0, "pellets": 1, "loud": 20.0, "reload": 2.0, "draw": 0.3,
		"price": 0, "kick": 0.05, "auto": false, "penetration": 0.0, "tracer": "none",
		"objective": true, "silent_work": true,
		"desc": "Тихая отмычка. Медленнее дрели, но не поднимает тревогу.",
		"teams": [0],
	},
	"fortify": {
		"name": "Укрепление", "short": "ЗАСЛОН", "class": "gadget", "kind": "throw",
		"dmg": 0.0, "head": 1.0, "limb": 1.0, "rpm": 20.0, "mag": 1, "reserve": 3,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 120.0, "falloff": 1.0,
		"speed": 200.0, "pellets": 1, "loud": 200.0, "reload": 2.0, "draw": 0.3,
		"price": 500, "kick": 0.05, "auto": false, "penetration": 0.0, "tracer": "none",
		"objective": true,
		"desc": "Ставит баррикаду: 400 HP, двери держат дольше.",
		"teams": [0, 1],
	},
	"drone": {
		"name": "Дрон «Соглядатай»", "short": "СОГЛЯДАТАЙ", "class": "gadget", "kind": "throw",
		"dmg": 0.0, "head": 1.0, "limb": 1.0, "rpm": 20.0, "mag": 1, "reserve": 1,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 120.0, "falloff": 1.0,
		"speed": 200.0, "pellets": 1, "loud": 80.0, "reload": 2.0, "draw": 0.3,
		"price": 1600, "kick": 0.05, "auto": false, "penetration": 0.0, "tracer": "none",
		"objective": true, "recon": true,
		"desc": "Разведывательный дрон. Даёт обзор и отмечает силуэты, но жужжит.",
		"teams": [1],
	},
	"medkit": {
		"name": "Аптечка «Шов»", "short": "ШОВ", "class": "gadget", "kind": "throw",
		"dmg": 0.0, "head": 1.0, "limb": 1.0, "rpm": 20.0, "mag": 1, "reserve": 1,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 120.0, "falloff": 1.0,
		"speed": 200.0, "pellets": 1, "loud": 40.0, "reload": 2.0, "draw": 0.3,
		"price": 700, "kick": 0.05, "auto": false, "penetration": 0.0, "tracer": "none",
		"objective": true, "heal": 100.0,
		"desc": "Лечит 100 HP. Медик ставит её за 3 секунды — под огнём это подвиг.",
		"teams": [0, 1],
	},
	"breach_kit": {
		"name": "Штурмовой набор", "short": "ВЗЛОМ", "class": "gadget", "kind": "throw",
		"dmg": 0.0, "head": 1.0, "limb": 1.0, "rpm": 20.0, "mag": 1, "reserve": 1,
		"spread": 0.0, "move_spread": 0.0, "recoil": 0.0, "range": 120.0, "falloff": 1.0,
		"speed": 200.0, "pellets": 1, "loud": 1200.0, "reload": 2.0, "draw": 0.3,
		"price": 900, "kick": 0.05, "auto": false, "penetration": 0.0, "tracer": "none",
		"objective": true, "breach": true,
		"desc": "Тихий взлом двери, окна, решётки. Ставится 3 секунды, снимает замок и часть стены.",
		"teams": [1],
	},
}

const WEAPON_ORDER := [
	"vk9", "mp5sd", "pp19", "ak12", "m4", "scar", "vintorez", "svd",
	"saiga12", "ksg", "pkm", "rpg7", "crossbow",
	"pm9", "deagle45", "machine_pistol", "flash_pistol",
	"knife", "pipe", "baton", "taser",
	"grenade", "flashbang", "smoke", "molotov", "remote_charge",
	"medkit", "breach_kit", "fortify",
]

const ARMOR := {
	"none": {"name": "Без брони", "hp": 0.0, "speed": 1.0, "price": 0, "desc": "Быстро и смертельно."},
	"kevlar": {"name": "Кевлар", "hp": 100.0, "speed": 0.97, "price": 650, "desc": "Держит пистолетный калибр."},
	"heavy": {"name": "Штурмовая плита", "hp": 180.0, "speed": 0.9, "price": 1400, "desc": "Тяжело, зато держит винтовку."},
	"riot": {"name": "Риот-щит", "hp": 260.0, "speed": 0.84, "price": 2000, "desc": "Фронтальная броня, уязвимый фланг."},
}

const PERKS := {
	"ghost": {"name": "Тихий шаг", "price": 1200, "desc": "Шаги слышны на 40% тише, силуэт гаснет в тени на 0.4 с раньше."},
	"iron_lungs": {"name": "Дыхание", "price": 800, "desc": "-35% к разбросу и отдаче на 4 секунды после задержки дыхания."},
	"scavenger": {"name": "Мародёр", "price": 700, "desc": "Патроны с трупов +50%, оружие врагов подбирается полным магазином."},
	"medic": {"name": "Санитар", "price": 900, "desc": "Поднимает союзников на 40% быстрее, аптечка лечит на 50 больше."},
	"technician": {"name": "Техник", "price": 1000, "desc": "Вскрывает замки и ставит заряд на 30% быстрее."},
	"runner": {"name": "Бегун", "price": 600, "desc": "+12% к спринту, дольше не шумит при беге."},
	"predator": {"name": "Хищник", "price": 1400, "desc": "Убийство со спины ножом восстанавливает 20 HP."},
	"comms": {"name": "Связист", "price": 1100, "desc": "Пинг отмечает врагов для всей команды на 3 секунды дольше."},
	"battering": {"name": "Таран", "price": 1200, "desc": "Двери с ноги, оглушая врагов за ней на 1.2 с."},
	"diversion": {"name": "Отвлечение", "price": 900, "desc": "Бросок предмета отвлекает ИИ в радиусе 700 px."},
	"sharpshooter": {"name": "Стрелок", "price": 1500, "desc": "-25% к покачиванию в прицеле, задержка дыхания восстанавливается вдвое быстрее."},
	"vigor": {"name": "Живучесть", "price": 1300, "desc": "+25 HP, кровотечение останавливается на 3 секунды раньше."},
	"mask": {"name": "Маска", "price": 800, "desc": "Камеры и свидетели узнают вас на 4 секунды позже."},
	"burglar": {"name": "Взломщик", "price": 1000, "desc": "Окна и решётки открывает без набора. Тише на 50%."},
}

# ---------------------------------------------------------------------------
# OPERATIVES / SKINS
# ---------------------------------------------------------------------------
# outfits are keyed by mode family so each mission has its own look.
const CRIMINAL_OUTFITS := {
	"assault": {
		"name": "Ночной таран", "desc": "Бронежилет поверх капюшона, разгрузка на липучках, маска-балаклава с прорезями для глаз.",
		"colors": ["#161320", "#2a2138", "#ff2b62"], "head": "#0d0b14", "visor": "#ff2b62",
		"gear": ["plate_carrier", "balaclava", "radio_pouch", "knee_pads"],
	},
	"heist": {
		"name": "Костюм и гнев", "desc": "Дешёвый чёрный костюм, белая рубашка под ним, латексная маска президента и перчатки.",
		"colors": ["#0f0f17", "#e8e3d5", "#8d2bff"], "head": "#e8e3d5", "visor": "#8d2bff",
		"gear": ["suit", "president_mask", "duffel_strap", "gloves"],
	},
	"stealth": {
		"name": "Тень рынка", "desc": "Мягкая куртка без блеска, обмотки на ботинках, прибор ночного видения на лбу, нож на бедре.",
		"colors": ["#101019", "#1d1c2b", "#2bff9a"], "head": "#101019", "visor": "#2bff9a",
		"gear": ["hoodie", "nv_goggles", "knife_sheath", "soft_soles"],
	},
	"siege": {
		"name": "Осада", "desc": "Сварной шлем с решёткой, тяжёлый фартук, кувалда на спине, руки в бинтах.",
		"colors": ["#1d1c2b", "#2b2a3d", "#ffb02b"], "head": "#2b2a3d", "visor": "#ffb02b",
		"gear": ["welded_helmet", "apron", "sledge", "wraps"],
	},
	"hostage": {
		"name": "Торг", "desc": "Пальто поверх бронежилета, шарф, маска-череп, в кармане детонатор.",
		"colors": ["#141126", "#2b2a3d", "#ff2bd6"], "head": "#e8e3d5", "visor": "#ff2bd6",
		"gear": ["long_coat", "skull_mask", "detonator", "gloves"],
	},
	"arcade": {
		"name": "Неоновый псих", "desc": "Куртка с кислотными нашивками, маска кролика, окровавленные перчатки, кроссы 80-х.",
		"colors": ["#1b1230", "#ff2bd6", "#b6ff2b"], "head": "#2b1b3d", "visor": "#b6ff2b",
		"gear": ["varsity", "rabbit_mask", "sneakers", "bloody_gloves"],
	},
}

const POLICE_OUTFITS := {
	"patrol": {
		"name": "Патруль", "desc": "Тёмно-синяя форма, светоотражающие полосы, кепка, рация, дубинка на поясе.",
		"colors": ["#101b2e", "#1d6bff", "#bfefff"], "head": "#101b2e", "visor": "#35c9ff",
		"gear": ["patrol_cap", "radio", "baton_holster", "hi_vis_stripes"],
	},
	"swat": {
		"name": "SWAT «Свинец»", "desc": "Чёрный тактический костюм, шлем с визором, баллистический щит на груди, подсумки.",
		"colors": ["#0d1018", "#1d6bff", "#35c9ff"], "head": "#0d1018", "visor": "#35c9ff",
		"gear": ["helmet", "visor", "chest_rig", "flashlight_mount"],
	},
	"detective": {
		"name": "Детектив", "desc": "Плащ, шляпа, значок, сигарета, кобура под плечом. Всё это под дождём.",
		"colors": ["#161320", "#7b7890", "#bfefff"], "head": "#161320", "visor": "#bfefff",
		"gear": ["trenchcoat", "fedora", "badge", "cigarette"],
	},
	"riot": {
		"name": "РИОТ", "desc": "Тяжёлый противоударный комплект, шлем с забралом, огромный щит, дымовые патроны.",
		"colors": ["#12131f", "#2b2a3d", "#ffb02b"], "head": "#12131f", "visor": "#ffb02b",
		"gear": ["riot_helmet", "riot_shield", "gas_mask", "flashbang_pouch"],
	},
	"negotiator": {
		"name": "Переговорщик", "desc": "Бронежилет под рубашкой, наушники, планшет, громкоговоритель.",
		"colors": ["#141126", "#bfefff", "#35c9ff"], "head": "#141126", "visor": "#bfefff",
		"gear": ["headset", "tablet", "megaphone", "kevlar_vest"],
	},
	"heavy": {
		"name": "Тяжёлый", "desc": "Комплект сапёра: забрало, фартук, дробовик, ранцевый дымогенератор.",
		"colors": ["#1d1c2b", "#35c9ff", "#b6ff2b"], "head": "#1d1c2b", "visor": "#b6ff2b",
		"gear": ["blast_visor", "heavy_apron", "shotgun", "smoke_backpack"],
	},
	"ci": {
		"name": "Отдел «Кобра»", "desc": "Городская тактическая форма, скрытая броня, маска-бафф, компактный ПП.",
		"colors": ["#0f1520", "#1d6bff", "#8d2bff"], "head": "#0f1520", "visor": "#8d2bff",
		"gear": ["buff_mask", "covert_vest", "smg_holster", "gloves"],
	},
}

const CIVILIAN_ARCHETYPES := {
	"office": {
		"name": "Офисный планктон", "colors": ["#2b2a3d", "#7b7890", "#bfefff"],
		"behaviours": ["panic", "hide", "surrender", "call", "flee"], "speed": 0.9,
	},
	"bystander": {
		"name": "Прохожий", "colors": ["#3d2b3a", "#ffb02b", "#e8e3d5"],
		"behaviours": ["record", "flee", "panic", "bump", "surrender"], "speed": 1.0,
	},
	"worker": {
		"name": "Рабочий", "colors": ["#2b2a1d", "#ffb02b", "#e8e3d5"],
		"behaviours": ["hide", "resist", "flee", "panic"], "speed": 0.85,
	},
	"nurse": {
		"name": "Медсестра", "colors": ["#bfefff", "#2bff9a", "#e8e3d5"],
		"behaviours": ["protect", "hide", "panic", "flee"], "speed": 0.95,
	},
	"student": {
		"name": "Студент", "colors": ["#1d2b4a", "#ff2bd6", "#e8e3d5"],
		"behaviours": ["record", "huddle", "flee", "panic", "surrender"], "speed": 1.05,
	},
	"security": {
		"name": "Охранник", "colors": ["#0d1018", "#7b7890", "#ffb02b"],
		"behaviours": ["challenge", "report", "draw", "patrol"], "speed": 0.95,
	},
	"cop": {
		"name": "Участковый", "colors": ["#101b2e", "#1d6bff", "#bfefff"],
		"behaviours": ["investigate", "radio", "draw", "chase"], "speed": 1.0,
	},
	"drunk": {
		"name": "Пьяный", "colors": ["#3d1d17", "#ffb02b", "#e8e3d5"],
		"behaviours": ["wander", "bump", "resist", "panic"], "speed": 0.55,
	},
	"courier": {
		"name": "Курьер", "colors": ["#b6ff2b", "#101019", "#e8e3d5"],
		"behaviours": ["deliver", "flee", "panic", "record"], "speed": 1.1,
	},
}

# ---------------------------------------------------------------------------
# MODES
# ---------------------------------------------------------------------------
# family: "arcade" (respawn, loops, replay) or "heist" (rounds, economy, police
# arrival timer, one life per round, longer stealth phase).
const MODES := {
	"deathmatch": {
		"name": "БОЙ НАСМЕРТЬ", "tagline": "Ни целей, ни свидетелей.",
		"family": "arcade", "max_minutes": 10, "score_limit": 50, "respawn": 3.0,
		"players": "5v5", "civilians": 0, "police_delay": 0.0, "brief": "Командный deathmatch с силовой броней и респауном.",
		"rules": ["Первый до 50 фрагов", "Респаун 3 секунды", "Все стволы в арсенале доступны сразу"],
	},
	"arms_race": {
		"name": "ГОНКА ВООРУЖЕНИЙ", "tagline": "Каждый фраг — апгрейд.",
		"family": "arcade", "max_minutes": 12, "score_limit": 0, "respawn": 1.5,
		"players": "6v6", "civilians": 0, "police_delay": 0.0, "brief": "Убийство выдаёт следующий ствол. Последний ствол — золотой нож.",
		"rules": ["15 ступеней", "Убийство с ножа — переход через ступень", "Смерть откатывает на ступень назад"],
	},
	"domination": {
		"name": "ЗАХВАТ ТОЧЕК", "tagline": "Кто держит свет — держит город.",
		"family": "arcade", "max_minutes": 15, "score_limit": 300, "respawn": 4.0,
		"players": "6v6", "civilians": 3, "police_delay": 0.0, "brief": "Три точки (A/B/C) на процедурной карте, тикеты и венты.",
		"rules": ["Точка даёт 1 тикет/с", "Все точки — двойной тикет", "Гражданские помехи у точек"],
	},
	"sabotage": {
		"name": "ЗАКЛАДКА БОМБЫ", "tagline": "Двадцать секунд, чтобы стать новостью.",
		"family": "heist", "max_minutes": 0, "score_limit": 0, "respawn": 0.0,
		"players": "5v5", "civilians": 4, "police_delay": 180.0, "brief": "Наёмники ставят заряд на «тамбур» полиции, полиция разминирует.",
		"rules": ["Один штурм — одна жизнь", "Бомба ставится за 3 с, тикает 40 с", "Разминирование 7 с, тик 0.5"],
	},
	"heist": {
		"name": "ОГРАБЛЕНИЕ", "tagline": "Деньги не пахнут. Кровь тоже.",
		"family": "heist", "max_minutes": 0, "score_limit": 0, "respawn": 0.0,
		"players": "4v4", "civilians": 8, "police_delay": 150.0, "brief": "Вскрыть 2-3 сейфа/кассы, донести сумки до фургона, уйти до прихода копов.",
		"rules": ["Тихая фаза до тревоги", "Дрель или отмычка на выбор", "Сумки замедляют носителя", "Фургон уходит через 60 с после тревоги"],
	},
	"hostage": {
		"name": "ЗАЛОЖНИКИ", "tagline": "Они верят, что договоримся.",
		"family": "heist", "max_minutes": 0, "score_limit": 0, "respawn": 0.0,
		"players": "5v5", "civilians": 10, "police_delay": 120.0, "brief": "Наёмники держат 3 заложников в банке, полиция обязана войти.",
		"rules": ["Заложники поднимаются по одному", "Казнь заложника = немедленный штурм", "Полиция обязана крикнуть «ПОЛИЦИЯ!» перед входом"],
	},
	"siege": {
		"name": "ЗАХВАТ ЗДАНИЯ", "tagline": "Двенадцать комнат. Двенадцать секунд.",
		"family": "heist", "max_minutes": 0, "score_limit": 0, "respawn": 0.0,
		"players": "6v6", "civilians": 12, "police_delay": 90.0,
		"brief": "Наёмники берут здание (госпиталь, склад, школа, кинотеатр, ТЦ), полиция отбивает этаж за этажом.",
		"rules": ["2 этапа на этаж: зачистка и удержание 30 с", "Полиция входит от главного входа и сервисных лестниц", "На карте остаются гражданские, их счётчик в HUD"],
	},
	"bomb_defuse": {
		"name": "РАЗМИНИРОВАНИЕ", "tagline": "Красный провод. Или тот, что краснее.",
		"family": "heist", "max_minutes": 0, "score_limit": 0, "respawn": 0.0,
		"players": "5v5", "civilians": 5, "police_delay": 240.0, "police_on_start": true,
		"brief": "Наёмники минируют три места в здании, полиция снимает заряды и выводит людей.",
		"rules": ["3 точки, 2 заряда нужны для победы", "Обезвреживание 6 с", "Полиция на карте с первой секунды"],
	},
	"extraction": {
		"name": "ЭВАКУАЦИЯ", "tagline": "Пока не закроется дверь.",
		"family": "heist", "max_minutes": 0, "score_limit": 0, "respawn": 0.0,
		"players": "5v5", "civilians": 8, "police_delay": 120.0,
		"brief": "Наёмники выводят VIP-свидетеля с карты к фургону, полиция его перехватывает.",
		"rules": ["VIP-бот идёт сам, но пугается выстрелов", "VIP можно переносить (медленно)", "Полиция может вывести VIP в участок"],
	},
	"vip": {
		"name": "ОХРАНА ЛИЦА", "tagline": "Он даже не знает, что мы здесь.",
		"family": "heist", "max_minutes": 0, "score_limit": 0, "respawn": 0.0,
		"players": "4v4", "civilians": 6, "police_delay": 90.0,
		"brief": "Полиция охраняет мэра/судью от ликвидации. Наёмники охотятся.",
		"rules": ["VIP-бот следует за охраной", "Наёмники получают фото и фото-след", "Убийство VIP — мгновенная победа"],
	},
}

const MODE_ORDER := [
	"deathmatch", "arms_race", "domination", "sabotage", "heist",
	"hostage", "siege", "bomb_defuse", "extraction", "vip",
]

# ---------------------------------------------------------------------------
# MAPS
# ---------------------------------------------------------------------------
# Procedural buildings. Each map is a theme with tile palette, props, civilian
# archetypes, security profile and mode hooks.
const MAPS := {
	"asphalt_night": {
		"name": "МОКРЫЙ АСФАЛЬТ", "type": "street", "size": [5, 4],
		"palette": ["#0d0d16", "#1b1a2b", "#221d33"], "accent": "#ff2b62", "accent2": "#35c9ff",
		"fog": ["#121024", "#1b1533"], "lights": ["street", "headlight", "neon_sign"],
		"civilians": ["bystander", "drunk", "courier", "student"],
		"props": ["car", "dumpster", "cone", "puddle", "neon_sign", "vending_machine", "phone_booth"],
		"security": 0.2, "brief": "Перекрёсток у закрытого рынка: мокрый асфальт, фары, вывеска «24/7» и пятна крови, которые никто не убирал.",
	},
	"corner_store": {
		"name": "МАГАЗИН УГЛА", "type": "shop", "size": [3, 3],
		"palette": ["#1a1410", "#2a1d16", "#3a2a1d"], "accent": "#b6ff2b", "accent2": "#ffb02b",
		"fog": ["#1a120e", "#241a10"], "lights": ["fluorescent", "fridge_glow", "sign"],
		"civilians": ["bystander", "student", "worker"],
		"props": ["shelf", "fridge", "counter", "register", "crate"],
		"security": 0.35, "brief": "Круглосуточный магазин: морозильники гудят, камера смотрит в пустоту, касса открыта.",
	},
	"hospital": {
		"name": "ГОРОДСКАЯ БОЛЬНИЦА", "type": "hospital", "size": [6, 5],
		"palette": ["#0b1418", "#16242b", "#1f323b"], "accent": "#2bff9a", "accent2": "#bfefff",
		"fog": ["#0b1620", "#102430"], "lights": ["ceiling", "surgical", "exit_sign"],
		"civilians": ["nurse", "office", "worker"],
		"props": ["gurney", "iv_stand", "wheelchair", "vending_machine", "desk", "xray"],
		"security": 0.5, "brief": "Госпиталь: зелёные лампы операционных, кафель в крови, лифты с музыкой.",
	},
	"warehouse": {
		"name": "СКЛАД №7", "type": "warehouse", "size": [7, 4],
		"palette": ["#141414", "#1f1f1f", "#2b2519"], "accent": "#ffb02b", "accent2": "#b6ff2b",
		"fog": ["#151313", "#221d16"], "lights": ["sodium", "forklift", "hanging_bulb"],
		"civilians": ["worker", "security", "courier"],
		"props": ["pallet", "forklift", "crate", "barrel", "catwalk", "container"],
		"security": 0.4, "brief": "Склад: стеллажи до потолка, натриевые лампы, погрузчик с ключами в замке.",
	},
	"school": {
		"name": "ШКОЛА №9", "type": "school", "size": [6, 4],
		"palette": ["#101820", "#1b2630", "#243442"], "accent": "#35c9ff", "accent2": "#ff2bd6",
		"fog": ["#0d141c", "#16202c"], "lights": ["fluorescent", "emergency", "projector"],
		"civilians": ["student", "office", "security"],
		"props": ["desk", "locker", "chalkboard", "backpack", "basketball_hoop"],
		"security": 0.45, "brief": "Школа: длинные коридоры, шкафчики, спортивный зал с одной лампой.",
	},
	"cinema": {
		"name": "КИНОТЕАТР «ЗАРЯ»", "type": "cinema", "size": [5, 5],
		"palette": ["#1a0f18", "#281a24", "#3a2133"], "accent": "#ff2bd6", "accent2": "#8d2bff",
		"fog": ["#1a0d1a", "#2a1028"], "lights": ["marquee", "projector", "seat_glow"],
		"civilians": ["bystander", "student"],
		"props": ["seat_row", "popcorn", "poster", "curtain", "projector"],
		"security": 0.3, "brief": "Кинотеатр: красный бархат, мерцающий экран, пустые кресла и чей-то телефон.",
	},
	"mall": {
		"name": "ТОРГОВЫЙ ЦЕНТР «ЭДЕМ»", "type": "mall", "size": [8, 6],
		"palette": ["#111118", "#1d1c2b", "#2b2a3d"], "accent": "#8d2bff", "accent2": "#ff2b62",
		"fog": ["#101020", "#1a1430"], "lights": ["atrium", "shop_window", "led_billboard"],
		"civilians": ["bystander", "student", "office", "security"],
		"props": ["mannequin", "escalator", "bench", "kiosk", "fountain"],
		"security": 0.55, "brief": "Торговый центр: атриум с эскалаторами, закрытые магазины, реклама на весь этаж.",
	},
	"bank": {
		"name": "БАНК «ЛИДЕР»", "type": "bank", "size": [5, 4],
		"palette": ["#0d1117", "#161c26", "#232a33"], "accent": "#ffb02b", "accent2": "#bfefff",
		"fog": ["#0c1018", "#161c26"], "lights": ["chandelier", "vault_light", "desk_lamp"],
		"civilians": ["office", "security", "bystander"],
		"props": ["desk", "vault_door", "teller_window", "chandelier", "cash_rack"],
		"security": 0.7, "brief": "Банк: мрамор, золото на стойках, стальные сейфы и очень много камер.",
	},
	"precinct": {
		"name": "ОТДЕЛЕНИЕ «ЛИДЕР»", "type": "precinct", "size": [6, 4],
		"palette": ["#0a0f1a", "#131c2b", "#1d2b3d"], "accent": "#1d6bff", "accent2": "#35c9ff",
		"fog": ["#080d16", "#101a26"], "lights": ["fluorescent", "siren", "monitor_glow"],
		"civilians": ["cop", "office"],
		"props": ["desk", "cell", "evidence_board", "copier", "locker"],
		"security": 0.85, "brief": "Отделение полиции: синие огни, запертые камеры, доска с вашими фотографиями.",
	},
	"subway": {
		"name": "СТАНЦИЯ «ГЛУБИНА»", "type": "subway", "size": [8, 3],
		"palette": ["#0b0d14", "#151821", "#1f222e"], "accent": "#2bff9a", "accent2": "#ff2b62",
		"fog": ["#0a0c12", "#141824"], "lights": ["tunnel", "warning_strip", "train_headlight"],
		"civilians": ["bystander", "drunk", "courier"],
		"props": ["bench", "pillar", "train_car", "ticket_machine", "glass_barrier"],
		"security": 0.3, "brief": "Станция метро: кафель, гул поездов, ветер, рельсы и платформа для перестрелки.",
	},
	"penthouse": {
		"name": "ПЕНТХАУС", "type": "penthouse", "size": [4, 3],
		"palette": ["#0d0b16", "#171426", "#231d33"], "accent": "#8d2bff", "accent2": "#35c9ff",
		"fog": ["#0b0a14", "#161228"], "lights": ["led_strip", "chandelier", "city_window"],
		"civilians": ["office", "bystander"],
		"props": ["couch", "bar", "piano", "glass_wall", "safe"],
		"security": 0.65, "brief": "Пентхаус: стеклянная стена, город внизу, дорогой ковёр и дешёвые люди.",
	},
	"mall_roof": {
		"name": "КРЫША ТЦ", "type": "roof", "size": [6, 3],
		"palette": ["#0d1018", "#171c26", "#222a36"], "accent": "#35c9ff", "accent2": "#ff2b62",
		"fog": ["#0b0f18", "#121828"], "lights": ["beacon", "helipad", "billboard"],
		"civilians": ["worker", "security"],
		"props": ["ac_unit", "helipad", "vent", "dish", "water_tank"],
		"security": 0.25, "brief": "Крыша: ветер, красные маяки, железяки, город внизу и вертолёт, который не прилетит.",
	},
}

const MAP_ORDER := [
	"asphalt_night", "corner_store", "hospital", "warehouse", "school",
	"cinema", "mall", "bank", "precinct", "subway", "penthouse", "mall_roof",
]

# ---------------------------------------------------------------------------
# CIVILIAN DIALOGUE / AI BARK  (short, cynical, unhinged)
# ---------------------------------------------------------------------------
const CIV_BARKS := {
	"panic": [
		"Нет-нет-нет, я просто шёл мимо!",
		"У меня дома кот!",
		"Я не полицейский, клянусь!",
		"Только не в лицо, только не в лицо...",
		"Вы же понимаете, что это всё записывается?",
	],
	"surrender": [
		"Я сдаюсь, я тут ни при чём!",
		"Руки видите? Я в домике.",
		"Можно я просто уйду? Я заплачу.",
	],
	"record": [
		"Это будет в новостях.",
		"Смотрите, снимаю!",
		"Вот это контент...",
		"Пожалуйста, повернитесь к камере.",
	],
	"call": [
		"Полиция? Я в магазине на углу...",
		"Они вооружены! Приезжайте!",
		"Алло, мам, я потом объясню...",
	],
	"resist": [
		"Мы так не договаривались!",
		"Скинь шлем, поговорим.",
		"Ещё шаг — и я крикну!",
	],
	"challenge": [
		"Чем могу помочь? Вы не должны здесь находиться.",
		"Медленно. Достаньте руки из-за спины.",
		"Это частная территория.",
	],
	"cop_radio": [
		"Есть подтверждение — это те, что взяли банк.",
		"Запросите поддержку, у них автоматика.",
		"Код 3, всем постам.",
	],
	"protect": [
		"Закройте дверь, пожалуйста.",
		"Я прикрою, только не выходите!",
		"Держитесь за мной.",
	],
	"dead": ["...", "Я...", "...", "Больно."],
	"yield": ["Хорошо, хорошо, я молчу.", "Только не стреляйте, я всё понял."],
}

const COP_BARKS := {
	"shout": ["ПОЛИЦИЯ! ОРУЖИЕ НА ЗЕМЛЮ!", "ВСЕМ ЛЕЖАТЬ! ОРУЖИЕ ВПЕРЁД!", "ОПЕРГРУППА! СВОБОДНЫЕ РУКИ!"],
	"hostage": ["ЗАЛОЖНИКИ, НА ПОЛ! МЫ СВОИ!", "ЛИЦОМ В ПОЛ, РУКИ НА ВИДУ!"],
	"breach": ["ЩИТ ВПЕРЁД, ВХОДИМ!", "Смена, вперёд! Тихо!", "ВЗРЫВАЙМ! ТРИ, ДВА, ОДИН!"],
	"downed": ["Офицер упал, прикройте!", "Медика сюда! Медика!", "Мужики, их больше!"],
	"clear": ["Сектор чист.", "Комната чиста, двигаемся.", "Тишина. Слишком тихо."],
}

const CRIM_BARKS := {
	"shout": ["ЭТО ОГРАБЛЕНИЕ! НА ПОЛ!", "СУМКИ НА ПОЛ! БЫСТРО!", "КТО ДЁРНЕТСЯ — ПОЛУЧИТ!"],
	"taunt": ["Они будут говорить, что мы злодеи.", "Я просто платил кредит.", "Город уже сожрал меня, я только отвечаю."],
	"downed": ["Я ранен! Прикрой!", "Не оставляй меня здесь!", "Мне не так плохо, как выглядит..."],
	"order": ["Держим вход.", "Стволы проверили? Тогда работаем.", "Тишина. Кто шумит — тот и умирает."],
}

const CIV_NAMES := [
	"Вера", "Максим", "Оля", "Серый", "Костя", "Аня", "Дед Ильич", "Лиза",
	"Тимур", "Настя", "Гоша", "Марина", "Вадим", "Соня", "Костя-курьер",
	"Богдан", "Инна", "Пашка", "Дина", "Артём",
]

const BOT_NAMES := [
	"Штырь", "Клещ", "Седой", "Молот", "Тихон", "Дым", "Кастет", "Ноль",
	"Вектор", "Скала", "Пепел", "Сом", "Ржавый", "Кобра", "Шрам", "Дизель",
	"Клинок", "Псы", "Гром", "Легат", "Пиксель", "Фантом", "Кэш", "Барс",
]

# ---------------------------------------------------------------------------
# MISSION INTEL (procedural brief, used by briefing screens & AI dialogs)
# ---------------------------------------------------------------------------
const INTEL_TAGS := [
	"Охрана недосчиталась смены", "Кто-то слил расписание камер",
	"Сейф под сигнализацией давления", "В здании дети — это только усложняет",
	"Управляющий хочет инсценировку", "Камеры писали последние 40 минут",
	"Код от чёрного хода известен только уборщице", "Тихая фаза до первой крови",
	"Полиция уже получила анонимный звонок", "На крыше вертолётная площадка",
	"Есть заложники в комнате отдыха", "Стайки гражданских у выхода",
	"Пожарная лестница заварена", "Сирена включится через 90 секунд",
]
