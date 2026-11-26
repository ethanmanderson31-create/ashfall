"""Single source of truth for Ashfall's sounds.

Writes the catalog block at the top of scripts/core/audio.gd and the data for
the sound board page (docs/soundboard/). Run after changing SLOTS:
    python3 tools/build_sound_catalog.py
"""
import json
import os

A = "assets/audio/"


def s(*n):
    return [A + "synth/" + x + ".wav" for x in n]


def f(*n):
    return [A + x for x in n]


def rng(fmt, a, b):
    return [A + fmt % i for i in range(a, b + 1)]


# (category, bus, [(slot, name, what it's for, [(key, label, desc, files)]), ...])
SLOTS = [
 ("Weapons", "Effects", [
  ("rifle", "Rifle shot", "Every bullet you fire (real recordings, single shots).", [
    ("A", "AR-15", "Tight, sharp crack.", f("weapons/rifle/ar15_1.wav", "weapons/rifle/ar15_2.wav")),
    ("B", "AK-47", "Heavier, rougher bark.", f("weapons/rifle/ak47_1.wav", "weapons/rifle/ak47_2.wav")),
    ("C", "SKS", "Big, booming rifle with a long tail.", rng("weapons/rifle/sks_%d.wav", 1, 3))]),
  ("reload", "Reload", "Plays through the whole reload animation.", [
    ("A", "Assault rifle", "Mag out, mag in, charging handle.", f("weapons/reload/assault_reload.wav")),
    ("B", "Rifle", "A slightly different rifle reload.", f("weapons/reload/rifle_reload.wav"))]),
  ("swing", "Axe swing", "The whoosh as the axe comes down.", [
    ("A", "Swing 1", "Short, tight whoosh.", f("weapons/swing.wav")),
    ("B", "Swing 2", "Longer, airy whoosh.", f("weapons/swing2.wav")),
    ("C", "Swing 3", "Heavy, low whoosh.", f("weapons/swing3.wav"))]),
  ("axe_hit", "Axe impact", "When the axe connects with a creature.", [
    ("A", "Bone crunch", "Heavy blow, bone crunch, dry crack and a low thud, layered.", rng("composed/axe_crunch_%d.wav", 1, 4)),
    ("B", "Heavy blows", "Recorded heavy punches only.", rng("impacts/punch_heavy_%d.wav", 0, 4))]),
  ("axe_finisher", "Axe finisher", "The third combo hit burying the axe in the ground.", [
    ("A", "Ground-cracking crunch", "Everything heavier, plus falling grit.", f("composed/axe_crunch_heavy.wav"))]),
  ("draw", "Draw the axe", "Scrolling down to the axe.", [
    ("A", "Steel draw", "Bright blade unsheathe.", f("weapons/sword-unsheathe.wav")),
    ("B", "Heavy draw", "Lower, heavier draw.", f("weapons/sword-unsheathe3.wav"))]),
  ("mag_drop", "Magazine hits the ground", "The spent mag landing and bouncing during a reload.", [
    ("A", "Dirt thud", "A dull drop with a little plastic tick.", s("mag_drop_dirt"))]),
  ("bullet_miss", "Bullet hits the ground", "Shots that miss and strike earth or stone.", [
    ("A", "Stone chip", "A crack and a scatter of rock chips.", rng("synth/miss_stone_%d.wav", 1, 3))]),
  ("explosion", "Explosion", "Hot Streak rounds, Ember Rounds, Phoenix, the axe finisher.", [
    ("A", "Crunchy blast", "Explosion with debris crunch.", f("explosions/explosion_crunch_000.wav", "explosions/explosion_crunch_002.wav")),
    ("B", "Deep boom", "Low-frequency thump.", f("explosions/low_frequency_explosion_000.wav", "explosions/low_frequency_explosion_001.wav"))]),
 ]),
 ("Getting hit", "Effects", [
  ("hurt", "Enemy hits you", "When a claw, bite or fist lands on you. Muffled so it reads as your body taking it.", [
    ("A", "Muffled body blow", "A dull thud with a soft crunch underneath.", rng("composed/player_hit_%d.wav", 1, 3))]),
  ("heartbeat", "Low health", "A heartbeat under a third of your health.", [
    ("A", "Heartbeat", "Lub-dub.", s("heartbeat"))]),
 ]),
 ("Your character", "Effects", [
  ("roll", "Combat roll", "The somersault dodge: cloth and armour tumbling, shoulder then feet touching down.", [("A", "Body roll", "", rng("composed/roll_body_%d.wav", 1, 2))]),
  ("jump", "Jump", "A quick creak of leather and light armour.", [("A", "Gear creak", "", rng("composed/jump_gear_%d.wav", 1, 2))]),
  ("land", "Landing", "Boot heel on packed dirt with a soft gear settle.", [("A", "Boot on dirt", "", rng("composed/land_boot_%d.wav", 1, 3))]),
  ("footstep", "Footsteps", "Every step you walk or run on dry ground.", [
    ("A", "Boots + kit", "Heel and toe on packed earth with buckles and mail shifting.", rng("composed/step_gear_%d.wav", 1, 4))]),
  ("air_jump", "Double jump", "Jumping again in mid-air (the ember ring).", [
    ("A", "Spark burst", "A small puff with crackling sparks.", s("air_jump_sparks"))]),
  ("player_death", "You die", "When you fall in battle.", [
    ("A", "Fading heart", "The heartbeat slows while a low choir sinks away.", s("death_fade"))]),
 ]),
 ("Water", "Effects", [
  ("swim_stroke", "Swim stroke", "Each arm stroke of the front crawl.", [
    ("A", "Gentle paddle", "Soft, low slosh with a few bubbles.", s("swim_soft_1", "swim_soft_2"))]),
  ("swim_tread", "Treading water", "Quiet sloshes while you float in place.", [("A", "Soft slosh", "", s("swim_tread_1", "swim_tread_2"))]),
  ("water_splash", "Jumping in", "Entering deep water; louder the harder you hit it.", [
    ("A", "Plunge", "A splash, a body thump and a rush of bubbles.", s("water_plunge"))]),
  ("water_exit", "Climbing out", "Water running off you as you reach the shore.", [
    ("A", "Dripping", "Water pouring off armour, then drips.", s("water_drip"))]),
  ("wade", "Wading steps", "Walking through shallow water.", [
    ("A", "Splashy steps", "Bright kicks of water.", s("wade_splash_1", "wade_splash_2"))]),
 ]),
 ("Rewards", "Effects", [
  ("xp", "XP ember pickup", "Each ember you absorb (rises in pitch in a streak).", [
    ("A", "Coins", "Recorded coin clinks.", f("items/coin.wav", "items/coin2.wav")),
    ("B", "Ember puff", "A soft breath of fire.", s("xp_soft_1", "xp_soft_2", "xp_soft_3"))]),
  ("levelup", "Level up", "When your Ember Level rises.", [("A", "Harp rise", "A rising harp phrase over a soft choir.", s("levelup_fantasy"))]),
  ("codex", "Ember Codex opens", "When you read the book at a cleared site.", [("A", "Arcane choir", "A choir swell, a harp glissando and soft sparkles in a hall.", s("codex_fantasy"))]),
  ("deal", "Cards dealt and flipped", "Each card sliding out, then flipping.", [("A", "Card and harp", "A soft card slide with a faint harp note.", s("deal_fantasy", "card_flip"))]),
  ("hover", "Hovering a card", "As a card lifts under your cursor.", [("A", "Faint harp", "A single quiet harp note with a shimmer.", s("hover_fantasy"))]),
  ("choose", "Claiming a card", "The boon becomes yours.", [("A", "Fairy flourish", "A quick rising harp run, a little flute answer and sparkles.", s("claim_fantasy"))]),
  ("mastery", "Mastery awakened", "Your third boon in a path, and synergies.", [("A", "Bright flourish", "A harp run with a short flute melody and sparkles.", s("mastery_fantasy"))]),
  ("potion_get", "Potion pickup", "Grabbing a flask.", [("A", "Glass bottle", "Bottle clink.", f("items/bottle.wav"))]),
  ("potion_use", "Drinking a potion", "Using keys 1 to 3.", [("A", "Bubble", "Bubbling gulp.", f("items/bubble.wav"))]),
  ("ui", "Menu click", "Buttons in the pause menu.", [("A", "Click", "", f("ui/interface1.wav"))]),
  ("arcana", "Opening the Arcana tree", "Pressing Tab to see your build.", [
    ("A", "Pages and harp", "A page rustle and three soft harp notes.", s("arcana_harp"))]),
 ]),
 ("Creatures", "Creatures", [
  ("ghoul_breath", "Ghoul presence", "Constant rasping breath around every ghoul; louder the closer it is.", [("A", "Rasping breath", "", s("ghoul_breath_loop"))]),
  ("ghoul", "Ghoul growl", "Growls while hunting you.", [
    ("A", "Beast growls", "Recorded deep growls.", rng("creatures/growls/beast_growl_%d.wav", 1, 4)),
    ("B", "Guttural set", "The earlier guttural voices.", rng("creatures/ghoul/mnstr%d.wav", 1, 6))]),
  ("ghoul_attack", "Ghoul attack grunt", "The grunt as a ghoul swings at you.", [
    ("A", "Grunts 1", "Short monster grunts.", rng("creatures/grunts/grunt_%d.wav", 1, 4)),
    ("B", "Grunts 2", "Different grunts.", rng("creatures/grunts/grunt_%d.wav", 5, 8))]),
  ("hound_breath", "Hound presence", "Constant low panting growl around every hound.", [("A", "Low panting growl", "", s("hound_breath_loop"))]),
  ("hound_growl", "Hound growl", "When a hound spots you (replaces the bark).", [
    ("A", "Deep growl", "Made for this game: a low throaty growl.", s("hound_growl_1", "hound_growl_2")),
    ("B", "Demon growl", "Recorded growl, played low.", f("creatures/growls/demon_growl.wav"))]),
  ("snarl", "Hound snarl", "The warning before a bite or pounce.", [
    ("A", "Recorded snarls", "Real monster snarls.", f("creatures/snarls/monster-snarl-5.ogg", "creatures/snarls/monster-snarl-attack.ogg", "creatures/snarls/monster-snarls-2.ogg")),
    ("B", "Rattling snarl", "Synthesized low rattle.", s("hound_snarl_1", "hound_snarl_2"))]),
  ("bite", "Hound bite", "Jaws snapping shut on you.", [
    ("A", "Snap + thud", "Jaw clack with a body thud.", s("hound_snap") + f("impacts/punch_medium_0.wav")),
    ("B", "Body thud", "Recorded medium hits.", rng("impacts/punch_medium_%d.wav", 0, 2))]),
  ("death", "Creature death", "When a ghoul or hound falls.", [("A", "Dying beast", "", f("creatures/growls/dying_beast.wav"))]),
  ("elite", "Elite roar", "When a violet elite erupts.", [
    ("A", "Roar 1", "", f("creatures/elite/roar_01.ogg")), ("B", "Roar 2", "", f("creatures/elite/roar_02.ogg")), ("C", "Roar 3", "", f("creatures/elite/roar_03.ogg"))]),
  ("emerge", "Erupting from the ground", "Under every creature that rises.", [("A", "Earth rumble", "", s("emerge_rumble"))]),
  ("creature_step", "Creature footsteps", "Ghouls and hounds walking (quiet, only up close).", [
    ("A", "Ember crunch", "Heavy thuds with cracking cinder underneath.", rng("synth/cstep_crunch_%d.wav", 1, 3))]),
 ]),
 ("The Colossus", "Creatures", [
  ("boss_breath", "Colossus presence", "Its huge breathing, audible across the arena.", [("A", "Massive breath", "", s("colossus_breath_loop"))]),
  ("boss_voice", "Colossus voice", "Roars when it wakes, charges, summons and enrages.", [
    ("A", "Giant", "Booming bellows.", rng("creatures/boss/giant%d.wav", 1, 5)),
    ("B", "Ogre", "Rougher grunts.", rng("creatures/boss/ogre%d.wav", 1, 5)),
    ("C", "Beast", "Monstrous howls.", f("creatures/boss/monster-1.wav", "creatures/boss/monster-4.wav", "creatures/boss/monster-7.wav"))]),
  ("step", "Colossus footsteps", "Every heavy step.", [("A", "Ground thud", "", s("boss_step"))]),
  ("slam", "Rubble slam", "The ground-burst you have to jump.", [("A", "Earthquake boom", "", s("slam_boom"))]),
 ]),
 ("World", "Ambience", [
  ("wind", "Wind", "Ambient wind across the valley.", [("A", "Valley wind", "", s("wind_loop"))]),
  ("fire", "Braziers", "Fire crackle near the ruin braziers.", [("A", "Crackling fire", "", s("fire_loop"))]),
  ("shore", "Lake shore", "Water at the nearest shoreline, louder as you get close.", [
    ("A", "Trickling water", "A constant brook-like trickle.", s("brook_loop"))]),
  ("wildlife", "Valley wildlife", "Quiet life under the wind across the whole valley.", [
    ("A", "Crickets", "Crickets and a low insect hum.", s("insects_loop"))]),
  ("beacon", "Ember beacon", "The pillar of light marking your next ambush site.", [
    ("A", "Ember drone", "A warm low hum with a little crackle.", s("beacon_drone_loop"))]),
 ]),
]

SEQ = {"deal"}
## Slots where the game uses an option other than A (picked on the sound board).
PICKS = {"swing": "C", "draw": "B", "explosion": "B", "xp": "B"}
## Added in session 2 (sound audit): flagged NEW on the sound board.
NEW = {"footstep", "air_jump", "player_death", "swim_stroke", "swim_tread", "water_splash", "water_exit", "wade", "mag_drop",
       "bullet_miss", "creature_step", "arcana", "shore", "wildlife", "beacon"}


def main():
    files, data, cat_lines, bus_lines, pick_lines = [], [], [], [], []
    for cat, bus, slots in SLOTS:
        cs = []
        for sid, name, use, opts in slots:
            os_ = []
            for key, label, desc, fl in opts:
                for x in fl:
                    assert os.path.exists(x), x
                    if x not in files:
                        files.append(x)
                os_.append({"key": key, "label": label, "desc": desc, "files": fl, "seq": sid in SEQ})
            cs.append({"id": sid, "name": name, "use": use, "options": os_, "isnew": sid in NEW, "pick": PICKS.get(sid, "A")})
            cat_lines.append('\t"%s": {%s},' % (sid, ", ".join('"%s": %s' % (o["key"], json.dumps(["res://" + x for x in o["files"]])) for o in os_)))
            bus_lines.append('\t"%s": "%s",' % (sid, bus))
            pick_lines.append('\t"%s": "%s",' % (sid, PICKS.get(sid, "A")))
        data.append({"cat": cat, "slots": cs})
    path = "scripts/core/audio.gd"
    src = open(path).read()
    body = src[src.index("var _cache"):]
    head = ["extends Node", "## Sound catalog + playback. Generated by tools/build_sound_catalog.py.",
            "## Every slot lists its options (A/B/C) as on the Ashfall Sound Board;",
            "## PICKS chooses which option the game uses.", "", "const SOUNDS := {"] + cat_lines + ["}", "", "const BUS := {"] + bus_lines + ["}", "",
            "## Which option each slot uses.", "var PICKS := {"] + pick_lines + ["}", "", ""]
    open(path, "w").write("\n".join(head) + body)
    json.dump({"data": data, "files": files}, open("build/sound_board.json", "w"))
    print(len(files), "files,", sum(len(s[2]) for s in SLOTS), "slots")


if __name__ == "__main__":
    main()
