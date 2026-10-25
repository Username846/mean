#!/usr/bin/env python3
"""Synthesized voice lines (espeak-ng) -> assets/voice/*.ogg + scripts/lines.gd

Speakers:
  bro  - the big brother (whiny, higher pitch)
  you  - the narrator / announcer (deep game-show voice)
  mom  - Mom, heard from off-screen
"""
import os
import subprocess
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "voice")

VOICES = {
    "bro": ["-v", "en-us+m3", "-p", "78", "-s", "165", "-a", "180"],
    "you": ["-v", "en-us+m1", "-p", "28", "-s", "140", "-a", "180"],
    "mom": ["-v", "en-us+f2", "-p", "60", "-s", "150", "-a", "180"],
    "doc": ["-v", "en-us+m4", "-p", "40", "-s", "150", "-a", "180"],
}

# id: (speaker, spoken text, subtitle shown on screen)
LINES = {
    # --- generic brother reactions
    "hey": ("bro", "Hey! Cut it out!", "Hey! Cut it out!"),
    "mom": ("bro", "Mooooom!", "MOOOOM!"),
    "telling": ("bro", "I'm telling Mom!", "I'm telling Mom!"),
    "notfunny": ("bro", "That's not funny!", "That's NOT funny!"),
    "ow": ("bro", "Ow!", "Ow!"),
    "ouch": ("bro", "Ouch! Hey!", "Ouch! Hey!"),
    "oof": ("bro", "Oof!", "Oof!"),
    "whyyou": ("bro", "Why are you like this?", "Why are you like this?!"),
    "stop": ("bro", "Stop it!", "Stop it!"),
    "quit": ("bro", "Quit it! Seriously!", "Quit it! Seriously!"),
    "ugh": ("bro", "Ugh. Really?", "Ugh. Really?"),
    "revenge": ("bro", "I'll get you for this!", "I'll get you for this!"),
    "missed": ("bro", "Ha ha! You missed!", "Ha ha! You missed!"),
    "nyah": ("bro", "Nyah nyah! Can't get me!", "Nyah nyah! Can't get me!"),
    "tooslow": ("bro", "Too slow!", "Too slow!"),
    "notagain": ("bro", "Oh no. Not again.", "Oh no. Not again."),
    "whatdoing": ("bro", "What are you doing?", "What are you doing?"),
    "leavemealone": ("bro", "Leave me alone!", "Leave me alone!"),
    "fine": ("bro", "Fine! You win this time!", "Fine! You win this time!"),
    "ohcomeon": ("bro", "Oh, come on!", "Oh, come ON!"),
    "grr": ("bro", "Grrrrr!", "Grrrrr!"),
    "aaah": ("bro", "Aaaaaaah!", "AAAAAAAH!"),
    # --- living room
    "putmedown": ("bro", "Put me down!", "Put me down!"),
    "whoa": ("bro", "Whoa oh oh oh!", "Whoa-oa-oa!"),
    "dizzy": ("bro", "Whoa. I'm so dizzy.", "Whoa... I'm so dizzy..."),
    "tickle": ("bro", "Ha ha ha! Stop! That tickles!", "Ha ha ha! Stop! That tickles!"),
    "wasntme": ("bro", "That wasn't me! I swear!", "That wasn't me! I swear!"),
    "tvtime": ("bro", "I'm trying to watch TV!", "I'm trying to watch TV!"),
    # --- kitchen
    "pieface": ("bro", "My face! It's all pie!", "My face! It's all pie!"),
    "mmpie": ("bro", "Mmm. Actually, that's pretty good.", "Mmm... actually that's pretty good."),
    "kitchen_hi": ("bro", "Don't you dare throw that pie!", "Don't you DARE throw that pie!"),
    # --- backyard
    "soaked": ("bro", "Aaah! I'm soaked!", "AAAH! I'm soaked!"),
    "cold": ("bro", "Brrr! That's freezing!", "Brrr! That's freezing!"),
    "umbrella": ("bro", "Ha! Umbrella shield!", "Ha! Umbrella shield!"),
    # --- bedroom
    "sleeptalk": ("bro", "Mmm. Five more minutes.", "Mmm... five more minutes..."),
    "mumble": ("bro", "Mmm. Pancakes.", "Mmm... pancakes..."),
    "whosthere": ("bro", "Huh? Who's there?", "Huh? Who's there?!"),
    "myface": ("bro", "What did you do to my face?", "WHAT did you do to my FACE?!"),
    "getout": ("bro", "Get out of my room!", "Get out of my room!"),
    # --- game room
    "almost": ("bro", "Yes! Yes! I'm about to beat the boss!", "Yes! YES! I'm about to beat the boss!"),
    "nooo": ("bro", "Nooooo! I was so close!", "NOOOOO! I was SO close!"),
    "won": ("bro", "Ha! I beat it! Champion!", "Ha! I beat it! CHAMPION!"),
    "gaming": ("bro", "Shh! I'm gaming.", "Shh! I'm gaming."),
    # --- cafeteria
    "yum": ("bro", "Mmm, my favorite sandwich!", "Mmm, my favorite sandwich!"),
    "gross": ("bro", "Eww! Gross!", "EWW! GROSS!"),
    "hot": ("bro", "Hot! Hot! Hot! Water!", "HOT! HOT! HOT! WATER!"),
    "worm": ("bro", "Is that a worm?", "Is that... a WORM?!"),
    "notbad": ("bro", "Huh. Not bad, actually.", "Huh. Not bad, actually."),
    # --- snow park
    "snowfight": ("bro", "Snowball fight! You're going down!", "Snowball fight! You're going down!"),
    "brrr": ("bro", "It went down my shirt!", "It went down my SHIRT!"),
    "gotcha": ("bro", "Gotcha!", "Gotcha!"),
    # --- beach
    "letmeout": ("bro", "Hey! Let me out!", "Hey! Let me out of here!"),
    "crab": ("bro", "Ow ow ow! Crab! Crab!", "OW OW OW! CRAB! CRAB!"),
    "relax": ("bro", "Ahh. Finally some peace and quiet.", "Ahh... finally some peace and quiet."),
    "splashed": ("bro", "Ack! Salty!", "Ack! SALTY!"),
    # --- treehouse
    "treehouse": ("bro", "This is my treehouse! No little siblings allowed!", "This is MY treehouse! No little siblings allowed!"),
    "stranded": ("bro", "Hey! How am I supposed to get down now?", "HEY! How am I supposed to get down now?!"),
    "squirrel": ("bro", "Aaah! Squirrel! Get it off me!", "AAAH! SQUIRREL! Get it OFF me!"),
    "snack": ("bro", "Snack time!", "Snack time!"),
    "comics": ("bro", "Hey! My comics!", "Hey! My COMICS!"),
    "scream": ("bro", "Aaaaaaaaaaah!", "AAAAAAAAAAAAH!!!"),
    # --- carnival
    "taunt": ("bro", "Come on! You throw like a baby!", "Come on! You throw like a baby!"),
    "taunt2": ("bro", "Missed me! Missed me!", "Missed me! Missed me!"),
    "dunked": ("bro", "Glub glub glub!", "GLUB GLUB GLUB!"),
    # --- ending
    "truce": ("bro", "Okay okay! I'm sorry I was mean to you. Truce?",
              "Okay, okay! I'm sorry I was mean to you. Truce?"),
    # --- emergencies
    "myeyes": ("bro", "Aaaah! My eyes! My eyes!", "AAAAH! MY EYES! MY EYES!"),
    "cantbreathe": ("bro", "Can't. Breathe.", "Can't... breathe..."),
    "help": ("bro", "Help! Help! Glub!", "HELP! HELP! GLUB!"),
    "zapped": ("bro", "Aaaaaaaaah!", "AAAAAAAZZZZZT!!!"),
    "water": ("bro", "Water! Water! I need water!", "WATER! WATER! I NEED WATER!"),
    "choking": ("bro", "Ack! Cough! Cough! Ack!", "*COUGH* *COUGH* ACK!"),
    "medic_crash": ("doc", "Whoa! The tire blew! Hold on!", "PARAMEDIC: WHOA! The tire blew! Hold on!"),
    "pilot": ("doc", "Air rescue! We'll fly him to another hospital!", "PILOT: Air rescue! We'll fly him to ANOTHER hospital!"),
    "doctor_twice": ("doc", "An ambulance crash on the way here too? This kid needs a helmet!", "DOCTOR: An ambulance crash on the way here too?! This kid needs a helmet!"),
    "mom_ambulance": ("mom", "Oh no! Somebody call an ambulance!", "MOM: Oh no! Somebody call an AMBULANCE!"),
    "medic": ("doc", "Hang in there, kid! We've got you!", "PARAMEDIC: Hang in there, kid! We've got you!"),
    "doctor_ok": ("doc", "He's going to be okay. But no more pranks!", "DOCTOR: He's going to be okay. But NO more pranks!"),
    "hosp_bro": ("bro", "Ow. I am so telling Mom about this one.", "Ow... I am SO telling Mom about this one."),
    "emergency": ("you", "Emergency!", "EMERGENCY!"),
    # --- mom
    "mom_stop": ("mom", "Kids! Play nice!", "MOM: Kids! Play nice!"),
    "mom_dinner": ("mom", "Dinner's ready!", "MOM: Dinner's ready!"),
    # --- announcer
    "title": ("you", "Bug my brother!", "BUG MY BROTHER!"),
    "choose": ("you", "Choose a place to bug your brother!", "Choose a place to bug your brother!"),
    "s_living_room": ("you", "The living room!", "The Living Room!"),
    "s_kitchen": ("you", "Kitchen pie fight!", "Kitchen Pie Fight!"),
    "s_backyard": ("you", "Backyard water balloons!", "Backyard Water Balloons!"),
    "s_bedroom": ("you", "Bedroom marker mayhem!", "Bedroom Marker Mayhem!"),
    "s_game_room": ("you", "Game room sabotage!", "Game Room Sabotage!"),
    "s_cafeteria": ("you", "Cafeteria sandwich surprise!", "Cafeteria Sandwich Surprise!"),
    "s_snow_park": ("you", "Snowball showdown!", "Snowball Showdown!"),
    "s_beach": ("you", "Beach burial!", "Beach Burial!"),
    "s_treehouse": ("you", "Treehouse trouble!", "Treehouse Trouble!"),
    "s_carnival": ("you", "Carnival dunk tank!", "Carnival Dunk Tank!"),
    "maxrage": ("you", "Maximum brother rage!", "MAXIMUM BROTHER RAGE!"),
    "supermean": ("you", "Super mean!", "SUPER MEAN!"),
    "combo": ("you", "Combo!", "COMBO!"),
    "nice": ("you", "Nice shot!", "Nice shot!"),
    "perfect": ("you", "Perfect!", "PERFECT!"),
    "ending": ("you", "You are the ultimate little sibling!", "You are the ULTIMATE little sibling!"),
}


def gen(id_, speaker, text):
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        tmp = f.name
    subprocess.run(["espeak-ng", *VOICES[speaker], "-w", tmp, text], check=True)
    dst = os.path.join(OUT, id_ + ".ogg")
    # light compression + small room reverb so the voices sit nicely over music
    flt = "acompressor=threshold=0.2:ratio=3,aecho=0.8:0.5:30:0.15,loudnorm=I=-16"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-af", flt,
                    "-ar", "22050", "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", dst],
                   check=True)
    os.unlink(tmp)


def write_gd():
    path = os.path.join(ROOT, "scripts", "lines.gd")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("# Generated by tools/gen_voices.py - do not edit by hand.\n")
        f.write("extends RefCounted\n\nconst LINES := {\n")
        for k, (spk, _, sub) in LINES.items():
            sub = sub.replace('"', '\\"')
            f.write(f'\t"{k}": ["{spk}", "{sub}"],\n')
        f.write("}\n")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for k, (spk, text, _) in LINES.items():
        gen(k, spk, text)
    write_gd()
    print(len(LINES), "lines")
