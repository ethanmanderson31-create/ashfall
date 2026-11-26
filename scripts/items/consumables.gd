class_name Consumables
extends RefCounted
## Rare potions. Hold up to 3 and drink with keys 1, 2, 3. Rarer potions are
## stronger or last longer.

const RARITY_NAMES := ["Common", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [Color(0.9, 0.88, 0.82), Color(0.35, 0.65, 1.0), Color(0.75, 0.4, 1.0), Color(1.0, 0.78, 0.25)]
const RARITY_WEIGHTS := [50.0, 30.0, 15.0, 5.0]

const ITEMS := {
	"heal_s": {"name": "Ember Draught", "rarity": 0, "tag": "Health", "desc": "Heal 35", "color": Color(0.95, 0.2, 0.15), "heal": 35.0},
	"speed_c": {"name": "Quicksilver", "rarity": 0, "tag": "Speed", "desc": "+35% speed · 15s", "color": Color(0.6, 0.9, 1.0), "buff": "speed", "value": 1.35, "time": 15.0},
	"str_r": {"name": "Brute's Blood", "rarity": 1, "tag": "Strength", "desc": "+50% axe dmg · 15s", "color": Color(1.0, 0.45, 0.1), "buff": "strength", "value": 1.5, "time": 15.0},
	"skin_r": {"name": "Stoneskin Salve", "rarity": 1, "tag": "Toughness", "desc": "-50% dmg taken · 15s", "color": Color(0.6, 0.58, 0.5), "buff": "stoneskin", "value": 0.5, "time": 15.0},
	"heal_l": {"name": "Phoenix Tonic", "rarity": 2, "tag": "Health", "desc": "Heal 80 + regen", "color": Color(1.0, 0.35, 0.2), "heal": 80.0, "buff": "regen", "value": 5.0, "time": 8.0},
	"ammo_e": {"name": "Quiver of Cinders", "rarity": 2, "tag": "Ammo", "desc": "Endless ammo · 15s", "color": Color(1.0, 0.75, 0.25), "buff": "infinite_ammo", "value": 1.0, "time": 15.0},
	"str_l": {"name": "Titan's Wrath", "rarity": 3, "tag": "Strength", "desc": "+120% axe dmg · 30s", "color": Color(1.0, 0.3, 0.05), "buff": "strength", "value": 2.2, "time": 30.0},
	"ammo_l": {"name": "Bottomless Barrel", "rarity": 3, "tag": "Ammo", "desc": "Endless ammo · 30s", "color": Color(1.0, 0.85, 0.3), "buff": "infinite_ammo", "value": 1.0, "time": 30.0},
}


static func roll(min_rarity := 0) -> String:
	var r := 0
	var total := 0.0
	for k in range(min_rarity, 4):
		total += RARITY_WEIGHTS[k]
	var x := randf() * total
	for k in range(min_rarity, 4):
		x -= RARITY_WEIGHTS[k]
		if x <= 0.0:
			r = k
			break
	var pool: Array = []
	for id in ITEMS:
		if ITEMS[id].rarity == r:
			pool.append(id)
	return pool[randi() % pool.size()]


static func info(id: String) -> Dictionary:
	return ITEMS.get(id, {})
