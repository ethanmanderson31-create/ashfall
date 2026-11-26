class_name SkillTree
extends RefCounted
## Three-branch boon tree. Boons come only from the Ember Codex at each
## cleared site (and the act boss): 3 random choices from what's unlocked,
## so each run builds differently. A branch's 3rd boon awakens its mastery. Deeper tiers unlock as you invest in a branch; tier 4 holds
## build-defining keystones (one per branch).

const BRANCHES := {
	"gun": {"name": "Gunslinger", "color": Color(1.0, 0.64, 0.22), "blurb": "Ranged power, crits and ammo"},
	"blade": {"name": "Blademaster", "color": Color(1.0, 0.32, 0.36), "blurb": "Fast melee, high jumps, aerial slams"},
	"ward": {"name": "Warden", "color": Color(0.36, 0.86, 0.8), "blurb": "Survival, shields and mobility"},
}
const BRANCH_ORDER := ["gun", "blade", "ward"]
const TIER_REQ := [0, 0, 1, 3, 5]   # points needed in the branch to open tier N
const TIER_NAMES := ["", "I", "II", "III", "IV"]

## Your 3rd boon in a branch awakens its mastery: a signature ability.
const MASTERY_AT := 3
const MASTERY := {
	"gun": {"name": "Hot Streak", "desc": "Land 4 shots in a row and your next round explodes"},
	"blade": {"name": "Ember Combo", "desc": "Unlocks the 3-hit axe combo with its ground-cracking finisher"},
	"ward": {"name": "Ember Ward", "desc": "When struck, erupt in a fire pulse that hurls enemies back"},
}

const NODES := [
	# ---------------- Gunslinger
	{"id": "g_dmg", "branch": "gun", "tier": 1, "max": 2, "name": "Tempered Rounds", "desc": "+30% gun damage"},
	{"id": "g_rate", "branch": "gun", "tier": 1, "max": 2, "name": "Hair Trigger", "desc": "+25% fire rate"},
	{"id": "g_mag", "branch": "gun", "tier": 1, "max": 2, "name": "Bandolier", "desc": "+12 magazine, +40 max reserve, and refill 40 rounds now"},
	{"id": "g_crit", "branch": "gun", "tier": 2, "max": 2, "name": "Keen Eye", "desc": "+15% crit chance, crits deal 2.5x", "req": ["g_dmg"]},
	{"id": "g_scav", "branch": "gun", "tier": 2, "max": 2, "name": "Scavenger", "desc": "Ammo drops twice as often and hold more rounds"},
	{"id": "g_reload", "branch": "gun", "tier": 2, "max": 1, "name": "Quick Hands", "desc": "Reload 45% faster"},
	{"id": "g_pierce", "branch": "gun", "tier": 3, "max": 2, "name": "Railshot", "desc": "Bullets pierce +1 enemy", "req": ["g_crit"]},
	{"id": "g_deadeye", "branch": "gun", "tier": 3, "max": 1, "name": "Deadeye", "desc": "Aimed shots deal +60% damage"},
	{"id": "g_explode", "branch": "gun", "tier": 3, "max": 2, "name": "Ember Rounds", "desc": "20% chance per shot to explode"},
	{"id": "g_ks_storm", "branch": "gun", "tier": 4, "max": 1, "keystone": true, "name": "Lead Storm", "desc": "Every 6th shot fires a 5-round volley"},
	{"id": "g_ks_overclock", "branch": "gun", "tier": 4, "max": 1, "keystone": true, "name": "Overclock", "desc": "Gun kills grant 3s of +60% fire rate that uses no ammo"},
	# ---------------- Blademaster
	{"id": "b_dmg", "branch": "blade", "tier": 1, "max": 2, "name": "Honed Edge", "desc": "+40% axe damage"},
	{"id": "b_speed", "branch": "blade", "tier": 1, "max": 2, "name": "Flowing Strikes", "desc": "+25% swing speed"},
	{"id": "b_leap", "branch": "blade", "tier": 1, "max": 1, "name": "Cat's Leap", "desc": "+40% jump height"},
	{"id": "b_double", "branch": "blade", "tier": 2, "max": 1, "name": "Updraft", "desc": "Gain a double jump", "req": ["b_leap"]},
	{"id": "b_leech", "branch": "blade", "tier": 2, "max": 2, "name": "Bloodthirst", "desc": "Axe hits heal 5"},
	{"id": "b_lunge", "branch": "blade", "tier": 2, "max": 1, "name": "Lunge", "desc": "Swings carry you across the gap to the nearest foe"},
	{"id": "b_slam", "branch": "blade", "tier": 3, "max": 1, "name": "Meteor", "desc": "Melee in midair to slam down, damaging everything nearby", "req": ["b_double"]},
	{"id": "b_dash", "branch": "blade", "tier": 3, "max": 1, "name": "Blade Dash", "desc": "Your dodge slices enemies you pass through"},
	{"id": "b_reach", "branch": "blade", "tier": 3, "max": 1, "name": "Wide Arc", "desc": "+50% axe range and arc"},
	{"id": "b_ks_storm", "branch": "blade", "tier": 4, "max": 1, "keystone": true, "name": "Bladestorm", "desc": "Every swing launches a cutting wave"},
	{"id": "b_ks_frenzy", "branch": "blade", "tier": 4, "max": 1, "keystone": true, "name": "Frenzy", "desc": "Melee kills stack +10% attack and move speed (max 5)"},
	# ---------------- Warden
	{"id": "s_hp", "branch": "ward", "tier": 1, "max": 2, "name": "Iron Heart", "desc": "+40 max health and heal fully"},
	{"id": "s_speed", "branch": "ward", "tier": 1, "max": 2, "name": "Fleet Foot", "desc": "+15% move speed"},
	{"id": "s_dodge", "branch": "ward", "tier": 1, "max": 1, "name": "Phase Step", "desc": "Dodge cooldown halved"},
	{"id": "s_regen", "branch": "ward", "tier": 2, "max": 2, "name": "Second Wind", "desc": "Regenerate 3 health/s after 3s unhurt"},
	{"id": "s_magnet", "branch": "ward", "tier": 2, "max": 1, "name": "Ember Pull", "desc": "Double pickup range"},
	{"id": "s_armor", "branch": "ward", "tier": 2, "max": 2, "name": "Plating", "desc": "-20% damage taken"},
	{"id": "s_aegis", "branch": "ward", "tier": 3, "max": 1, "name": "Aegis", "desc": "Dodging grants a 40 shield for 3s", "req": ["s_dodge"]},
	{"id": "s_thorns", "branch": "ward", "tier": 3, "max": 1, "name": "Ashen Skin", "desc": "Attackers take 30 damage"},
	{"id": "s_ks_phoenix", "branch": "ward", "tier": 4, "max": 1, "keystone": true, "name": "Phoenix", "desc": "Once per run, rise from death with half health in a blast of fire"},
	{"id": "s_ks_jugg", "branch": "ward", "tier": 4, "max": 1, "keystone": true, "name": "Juggernaut", "desc": "+100 max health, -10% move speed"},
]


static func find(id: String) -> Dictionary:
	for n in NODES:
		if n.id == id:
			return n
	return {}


static func branch_points(ranks: Dictionary, b: String) -> int:
	var total := 0
	for n in NODES:
		if n.branch == b:
			total += int(ranks.get(n.id, 0))
	return total


static func main_branch(ranks: Dictionary) -> String:
	var best := 0
	var main := ""
	for b in BRANCH_ORDER:
		var p := branch_points(ranks, b)
		if p > best:
			best = p
			main = b
	return main


static func tier_open(ranks: Dictionary, n: Dictionary) -> bool:
	return branch_points(ranks, n.branch) >= TIER_REQ[n.tier]


static func is_available(ranks: Dictionary, n: Dictionary) -> bool:
	if int(ranks.get(n.id, 0)) >= n.max:
		return false
	if not tier_open(ranks, n):
		return false
	for r in n.get("req", []):
		if int(ranks.get(r, 0)) == 0:
			return false
	if n.get("keystone", false):
		for o in NODES:
			if o.branch == n.branch and o.get("keystone", false) and int(ranks.get(o.id, 0)) > 0:
				return false
	return true


## Weighted random offer: favours your main branch and deeper tiers, but
## always tries to show more than one branch so pivots stay possible.
static func roll(ranks: Dictionary, count: int) -> Array:
	var pool: Array = NODES.filter(func(n): return is_available(ranks, n))
	var main := main_branch(ranks)
	var picks: Array = []
	while picks.size() < count and not pool.is_empty():
		var weights: Array[float] = []
		var total := 0.0
		for n in pool:
			var w: float = [0.0, 6.0, 5.0, 4.5, 4.0][n.tier]
			if n.branch == main:
				w *= 1.5
			if n.get("keystone", false):
				w *= 1.6
			for p in picks:
				if p.branch == n.branch:
					w *= 0.55
			weights.append(w)
			total += w
		var r := randf() * total
		var idx := 0
		for i in weights.size():
			r -= weights[i]
			if r <= 0.0:
				idx = i
				break
		picks.append(pool[idx])
		pool.remove_at(idx)
	return picks


static func has_mastery(ranks: Dictionary, b: String) -> bool:
	return branch_points(ranks, b) >= MASTERY_AT


## Cross-path synergies: owning both halves unlocks a bonus effect.
## A need is a boon id, or "m:<branch>" for that path's mastery.
const SYNERGIES := [
	{"id": "molten_edge", "name": "Molten Edge", "needs": ["b_dmg", "g_explode"], "desc": "Axe hits set creatures ablaze"},
	{"id": "gunblade", "name": "Gunblade", "needs": ["m:gun", "m:blade"], "desc": "Every axe hit primes an explosive round"},
	{"id": "ironclad", "name": "Ironclad Fury", "needs": ["s_armor", "b_speed"], "desc": "Axe hits grant 8 shield (up to 40)"},
	{"id": "hunters_mark", "name": "Hunter's Mark", "needs": ["g_deadeye", "b_lunge"], "desc": "Lunging hits mark prey: +50% gun damage to it for 4s"},
	{"id": "ember_dancer", "name": "Ember Dancer", "needs": ["s_dodge", "g_rate"], "desc": "Rolling grants +40% fire rate for 2s"},
]


static func _has(ranks: Dictionary, need: String) -> bool:
	if need.begins_with("m:"):
		return has_mastery(ranks, need.substr(2))
	return int(ranks.get(need, 0)) > 0


static func active_synergies(ranks: Dictionary) -> Array:
	var out := []
	for sy in SYNERGIES:
		var ok := true
		for n in sy.needs:
			if not _has(ranks, n):
				ok = false
		if ok:
			out.append(sy)
	return out


## Synergies this pick would complete.
static func completes(ranks: Dictionary, id: String) -> Array:
	var after := ranks.duplicate()
	after[id] = int(after.get(id, 0)) + 1
	var before_ids := active_synergies(ranks).map(func(s): return s.id)
	return active_synergies(after).filter(func(s): return not before_ids.has(s.id))
