-- Omen Deaths: a funny line that fits how someone died.
-- {name} = who died, {killer} = what killed them, {n} = how many times in a row (streak lines).
-- {NAME}, {KILLER} = the same in capitals (the loudest streak lines).
-- Lines with {killer} are only used when it is known.
local _, ns = ...
local Lines = {}
ns.Lines = Lines

Lines.SETS = {
    fall = {
        plain = { "{name} tested gravity. Gravity won.", "{name} forgot their parachute",
            "{name} took the express route down", "{name} asked the floor for a hug",
            -- 0.9.14: more of every kind (287 lines in guild chat in one week, 21-27 Nov 2026)
            "{name} took the stairs. All of them. At once.", "{name} misjudged the distance to the ground",
            "{name} was introduced to the floor at high speed" },
    },
    drown = {
        plain = { "{name} forgot to come up for air", "{name} is sleeping with the fishes",
            "{name} tried to breathe underwater", "{name} held their breath a little too long",
            "{name} went looking for Atlantis and found the graveyard" },
    },
    lava = {
        plain = { "{name} went for a swim in the lava", "{name} found out the floor is lava",
            "{name} is now extra crispy", "{name} took a dip and came out well done",
            "{name} mistook the lava for a hot tub", "{name} is now part of the volcano" },
    },
    fatigue = {
        plain = { "{name} swam a bit too far from shore", "{name} tried to swim to the next continent",
            "{name} went for a long swim and forgot the way back" },
    },
    slime = {
        plain = { "{name} got slimed", "{name} lost a fight with a puddle of slime", "{name} got stuck in the goo for good" },
    },
    pvp = {
        killer = { "{name} met {killer} up close", "{killer} collected an honorable kill: {name}" },
        plain = { "{name} gave the enemy an honorable kill", "{name} paid the toll for that flag" },
    },
    raid = {
        killer = { "{killer} says hi to {name}", "{name} became a raid statistic, courtesy of {killer}",
            "{name} stood in the wrong spot vs {killer}", "{killer} put {name} on the wipe list",
            "{name} learned the tactics of {killer} the hard way" },
        plain = { "{name} became a raid statistic", "{name} stood in something purple",
            "{name} missed the one mechanic that mattered", "{name} will watch the rest of this fight from the floor" },
        -- 0.9.6: role lines outside dungeons too (wish of the user, 21-11-2026)
        roles = {
            tank = {
                killer = { "{killer} went through {name} and is now looking at the rest of the raid",
                    "{name} took {killer} to the face. All of it." },
                plain = { "Main tank down! {name} has delegated aggro to whoever is closest", "{name} was the wall. The wall has fallen." },
            },
            healer = {
                killer = { "{killer} found the healer. {name}'s raid frames send their condolences",
                    "{killer} cut the heals short: {name} is down" },
                plain = { "{name} stopped healing. Raid frames are turning a worrying shade of red",
                    "{name} ran out of mana and the raid ran out of a healer" },
            },
            dps = {
                killer = { "{name} was busy parsing and did not notice {killer}", "{name} stood right in front of {killer} for a better parse" },
                plain = { "{name} was top DPS right up until the floor turned purple",
                    "{name} kept pressing buttons until there was nothing left to press" },
            },
        },
    },
    -- Dungeon lines per role (09-11-2026: a tank got "found out why the tank goes first"). killer/plain fit
    -- every role; roles[r] adds lines for a known role (rec.r). Unknown role: only the ones for every role.
    dungeon = {
        killer = { "{killer} cleared {name} from the dungeon", "{name} took one hit too many from {killer}",
            "{killer} sent {name} back to the entrance", "{name} was the warm-up for {killer}",
            "{killer} made the group one player lighter: {name}", "{name} looked away from {killer} for one second" },
        plain = { "{name} did not survive this pull", "{name} is waiting for a res at the entrance",
            "{name} has started a corpse run. The clock is ticking.", "{name} is lying on the floor in a very tactical position",
            "{name} has decided to watch the rest of the run from the floor", "{name} will be needing a res. And a moment." },
        roles = {
            tank = {
                killer = { "{killer} chewed through {name}'s shield", "{name} held aggro on {killer} a little too well",
                    "{name} pulled {killer} a little too early", "{killer} saw {name} as the snack before the meal",
                    "{name} taunted {killer}. {killer} accepted." },
                plain = { "{name} pulled one mob too many", "The tank is down! {name} leads the corpse run now",
                    "{name} ran ahead and the group stayed behind. Smart group.", "{name} was the tank. Was." },
            },
            healer = {
                killer = { "{killer} went for the healer. {name} did not like that",
                    "{name} healed everyone but themselves vs {killer}", "{killer} skipped the tank and went straight for {name}",
                    "{name} had one heal left and {killer} had one hit left" },
                plain = { "{name} healed everyone but themselves", "The healer is down. Good luck, everyone.",
                    "{name} was too busy keeping everyone alive to stay alive", "The healer is down. Everyone, please stop standing in things." },
            },
            dps = {
                killer = { "{name} found out why the tank goes first ({killer})", "{name} pulled aggro from {killer} and regretted it",
                    "{name} pulled threat off the tank and {killer} said thank you", "{name} hit {killer} before the tank did. Bold move." },
                plain = { "{name} found out why the tank goes first", "{name} pulled aggro. Bad idea.",
                    "{name} was top damage for a very short time", "{name} tested if the tank was really needed. They were." },
            },
        },
    },
    -- 0.9.14: a few lines per dungeon, mixed into the dungeon lines (deaths per dungeon in the
    -- guild up to 27-11-2026: Blackrock Depths 53, The Drowned City 42, Scarlet Monastery 29, ...).
    -- The dungeons new in Forever get a line from their name only; Krol'dok Stronghold, Blackmaw Hold
    -- and The Shaper's Terrace none yet (nothing known about them). Keyed by the zone name the game gives.
    dungeons = {
        ["Blackrock Depths"] = { killer = { "{killer} made sure {name} never reached the bar in Blackrock Depths" },
            plain = { "{name} never made it to the Grim Guzzler" } },
        ["The Drowned City"] = { killer = { "{killer} pulled {name} under in the Drowned City" },
            plain = { "{name} took the name of the Drowned City a bit too literally" } },
        ["Scarlet Monastery"] = { killer = { "{killer} declared {name} unclean and acted on it" },
            plain = { "The Scarlet Crusade crosses one more name off the list: {name}" } },
        ["Shadowfang Keep"] = { killer = { "{killer} added {name} to the ghosts of Shadowfang Keep" },
            plain = { "{name} is now haunting Shadowfang Keep" } },
        ["Excavation Site: Wetlands"] = { killer = { "{killer} dug a hole for {name} at the excavation site" },
            plain = { "{name} dug a little too deep" } },
        ["Blackrock Spire"] = { killer = { "{name} will not reach the top of Blackrock Spire. {killer} made sure." },
            plain = { "{name} will not be climbing Blackrock Spire any further today" } },
        ["City of Dalaran"] = { killer = { "{killer} showed {name} some magic in the City of Dalaran. The deadly kind." },
            plain = { "{name} came to the City of Dalaran to learn magic and learned about dying instead" } },
        ["Gnomeregan"] = { killer = { "{killer} broke {name} into spare parts in Gnomeregan" },
            plain = { "{name} has been recycled by Gnomeregan" } },
        ["Alcaz Prison"] = { killer = { "{killer} gave {name} a life sentence in Alcaz Prison. A short one." },
            plain = { "{name} will be leaving Alcaz Prison as a ghost" } },
        ["Zul'Farrak"] = { killer = { "{killer} left {name} in the sand of Zul'Farrak" },
            plain = { "{name} found out Zul'Farrak is hot, dry and deadly" } },
        ["Uldaman"] = { killer = { "{killer} turned {name} into one more relic of Uldaman" },
            plain = { "{name} has been added to the Uldaman collection" } },
        ["Stratholme"] = { killer = { "{killer} added {name} to the dead of Stratholme" },
            plain = { "{name} has joined the population of Stratholme" } },
        ["Dire Maul"] = { killer = { "{killer} made {name}'s stay in Dire Maul a short one" },
            plain = { "{name} found the dire part of Dire Maul" } },
        ["Wailing Caverns"] = { killer = { "{killer} gave {name} something to wail about" },
            plain = { "{name} is doing the wailing in the Wailing Caverns now" } },
        ["Ragefire Chasm"] = { killer = { "{killer} put out {name}'s fire in Ragefire Chasm" },
            plain = { "{name} found the fire in Ragefire Chasm" } },
        ["Ruins of Lordaeron"] = { killer = { "{killer} buried {name} in the Ruins of Lordaeron" },
            plain = { "{name} is one more ruin in the Ruins of Lordaeron" } },
        ["Blackfathom Deeps"] = { killer = { "{killer} dragged {name} to the bottom of Blackfathom Deeps" },
            plain = { "{name} went a bit too deep in Blackfathom Deeps" } },
        ["Scholomance"] = { killer = { "{killer} taught {name} a lesson in Scholomance. The final one." },
            plain = { "{name} failed the exam in Scholomance" } },
        ["Maraudon"] = { killer = { "{killer} ended {name}'s trip through Maraudon" },
            plain = { "{name} got lost in Maraudon. Maybe forever." } },
        ["Razorfen Kraul"] = { killer = { "{killer} ran {name} through the thorns of Razorfen Kraul" },
            plain = { "{name} got stuck in the thorns of Razorfen Kraul" } },
        ["Razorfen Downs"] = { killer = { "{killer} put {name} down in Razorfen Downs" },
            plain = { "{name} went down in Razorfen Downs" } },
        ["Sunken Temple"] = { killer = { "{killer} sank {name} along with the temple" },
            plain = { "{name} went down with the Sunken Temple" } },
        ["The Deadmines"] = { killer = { "{killer} showed {name} why they are called the Deadmines" },
            plain = { "{name} found out why they are called the Deadmines" } },
        ["The Stockade"] = { killer = { "{killer} broke out of the Stockade and broke {name}" },
            plain = { "{name} got locked up in the Stockade. For good." } },
    },
    -- "lost a fair fight" was read literally by a guildie who died to a skull mob (08-11-2026)
    world = {
        killer = { "{name} picked the wrong fight with {killer}", "{killer} added {name} to their trophy wall",
            "{name} underestimated {killer}", "{name} was humbled by {killer}",
            "{name} met {killer} and it went badly", "{killer} had a great day. {name} did not.",
            "{name} walked up to {killer} full of confidence and left as a ghost", "{name} lost the argument with {killer}" },
        roles = {
            tank = { killer = { "{name} tried to tank {killer} with nobody watching. Nobody healed either.",
                "{name} had the full attention of {killer}. That was the problem." } },
            healer = { killer = { "{name} tried to heal through {killer}. Solo. With a mace.",
                "{name} healed and healed, but {killer} hit harder" } },
            dps = { killer = { "{name} looked around for a tank. {killer} did not wait.",
                "{name} brought the damage but forgot the plan vs {killer}" } },
        },
    },
    -- open world, killer far above my level: red or skull, as the game colours its level
    above = {
        killer = { "{name} picked a fight way above their pay grade: {killer}",
            "{name} saw the level of {killer} and went for it anyway", "{killer} was a few levels out of {name}'s league",
            "{name} took on {killer} without checking the level first", "{killer} was in a different weight class than {name}" },
    },
    -- open world, killer gray: gives no experience, still got me
    gray = {
        killer = { "{name} lost to {killer}. Yes, the gray one.", "{killer} gives no XP, but it did get {name}",
            "{name} was taken out by {killer}, a gray mob", "{name} got beaten by {killer}. The gray one. Everyone saw.",
            "{killer} has not given anyone XP in ages, but it still got {name}" },
    },
    -- The same killer or cause as the death before, on the same day (09-11-2026, wish of the user):
    -- "in a row", replaces the line. Steps: 2nd time, 3rd and 4th, 5th and more (chosen by the user).
    streak = {
        killer = {
            [2] = { "{name} lost to {killer}. Again. {killer} is starting to recognise them.",
                "{name} vs {killer}, round two. Same result.", "{killer} got {name} twice. Some lessons take longer." },
            [3] = { "{killer} {n}, {name} 0. Someone call for backup.", "{name} died to {killer} {n} times in a row. Rematch?",
                "{name} keeps visiting {killer}. {killer} keeps winning." },
            [4] = { "{name} keeps going back to {killer}. This is no longer a fight, it's a relationship.",
                "{killer} has started waiting for {name} at the graveyard", "{name} vs {killer}, round {n}. The crowd has gone home." },
            [5] = { "{KILLER} OWNS {NAME} NOW. Somebody stop this.",
                "{name} has died to {killer} {n} times in a row. At this point {killer} should get a guild invite.",
                "{killer} has claimed {name} {n} times in a row. Somebody stop this." },
            [10] = { "{name} has died to {killer} {n} times in a row. {killer} has been promoted to Guild Master.",
                "{killer} has killed {name} {n} times in a row. Somebody frame this streak." },
        },
        fall = {
            [2] = { "{name} fell to their death. Again. The stairs are right there.", "{name} fell again. Same spot, same result." },
            [3] = { "{name} fell to their death {n} times in a row. Gravity: undefeated.",
                "{name} has fallen {n} times in a row. Somebody build a railing." },
            [4] = { "{name} fell again. The ground has started saving them a spot." },
            [5] = { "{name} has fallen to their death {n} times in a row. Wings are not included." },
            [10] = { "{name} has fallen to their death {n} times in a row. GRAVITY HAS BEEN PROMOTED TO GUILD MASTER." },
        },
        lava = {
            [2] = { "{name} went for another lava bath. They clearly like it warm.",
                "{name} went back into the lava. Just checking it was still hot." },
            [3] = { "{name} took lava bath number {n} in a row. Somebody hide the lava.",
                "{name} has burned in lava {n} times in a row. The lava sends its regards." },
            [4] = { "{name} is back in the lava. They have a favourite spot now." },
            [5] = { "{name} has gone for a lava bath {n} times in a row. It's a lifestyle now." },
            [10] = { "{name} has gone for a lava bath {n} times in a row. THE LAVA NOW PAYS RENT TO {NAME}." },
        },
        drown = {
            [2] = { "{name} forgot to breathe. Again. Gills not included.", "{name} drowned again. The water won the rematch." },
            [3] = { "{name} drowned {n} times in a row. Swimming lessons, anyone?",
                "{name} has drowned {n} times in a row. Water {n}, {name} 0." },
            [4] = { "{name} drowned again. The fish know them by name now." },
            [5] = { "{name} has drowned {n} times in a row. The fish are starting to worry." },
            [10] = { "{name} has drowned {n} times in a row. THE FISH HAVE ELECTED {NAME} AS THEIR KING." },
        },
        other = {
            [2] = { "{name} died the same way. Again.", "{name} died the same way twice. Consistency!" },
            [3] = { "{name} died the same way {n} times in a row. A pattern is forming.",
                "{name} died the same way {n} times in a row. Somebody write this down." },
            [4] = { "{name} died the same way again. Scientists are taking notes." },
            [5] = { "{name} has died the same way {n} times in a row. That's a tradition now." },
            [10] = { "{name} has died the same way {n} times in a row. THIS IS NOW A GUILD HOLIDAY." },
        },
    },
    -- 0.9.0 (10-11-2026, all ten ideas chosen by the user). {nth} = 200th, {other} = a guildie.
    -- All Time reaches 10, 25, 50, 100, 200, ... (steps chosen by the user)
    milestone = {
        plain = { "{name} just died for the {nth} time! Achievement unlocked: Professional Corpse",
            "Death number {n} for {name}! The Spirit Healer is baking a cake",
            "{name} reached {n} deaths. Somebody frame this one.",
            "{name} hit death number {n}. The graveyard put up a plaque.",
            "{nth} death for {name}! The Spirit Healer has them on speed dial." },
    },
    -- a guildie died in the same fight and place just before
    together = {
        killer = { "{name} joined {other} in the afterlife, courtesy of {killer}. Together forever.",
            "{killer} took out {other} and {name}. Buy one, get one free.", "{killer} got {other} and {name} in one go. Teamwork!" },
        plain = { "{name} joined {other} in the afterlife. Together forever.", "{other} and {name} died side by side. How romantic.",
            "{other} went first, {name} followed. Loyal to the end." },
    },
    -- this killer got another guildie today as well ({n} of us)
    plague = {
        killer = { "{killer} claims another Omen soul: {name}. That's {n} of us today.",
            "{killer} has now killed {n} Omen members today. {name} is the latest.",
            "{killer} is farming Omen today. {name} makes {n}." },
    },
    -- the first death in more than 3 days ({n} days, chosen by the user)
    clean = {
        plain = { "{name} died for the first time in {n} days. It was nice while it lasted.",
            "{name}'s {n}-day survival streak is over.", "{name} had not died in {n} days. Had." },
    },
    -- the first death after a level-up this session ({n} = the new level)
    levelup = {
        plain = { "{name} dinged {n} and celebrated by dying", "{name} hit level {n} and immediately tested it. It failed.",
            "{name} reached level {n} and spent the first minutes of it as a ghost", "Ding {n}! Then dead. Congrats, {name}." },
    },
    -- from full health to dead in one hit (own death recap)
    oneshot = {
        killer = { "{killer} took {name} from full health to dead in one hit", "{name} was one-shot by {killer}. Didn't even see it coming.",
            "{killer} needed one hit for {name}. Just one.", "{name} went from full health to the graveyard in one hit from {killer}" },
    },
    -- 0.9.6: came back at the Spirit Healer (asked + Resurrection Sickness, measured 2 of 20 returns)
    spirit = {
        plain = { "{name} paid the Spirit Healer rather than walk. Shameful.",
            "{name} looked at the corpse run and chose Resurrection Sickness instead",
            "{name} took the Spirit Healer's deal. Their gear will remember this.",
            "{name} chose the Spirit Healer. The corpse run was too much effort.",
            "{name} took Resurrection Sickness over a short walk. Brave." },
    },
    -- 0.9.6: passing someone in the All Time top 3, a second line in guild chat
    rank = {
        top3 = { "[ALL TIME TOP 3] {name} passes {other} with death number {n}. This one goes in the guild archives." },
        [2] = { "[ALL TIME #2] {name} overtakes {other} with {n} deaths. Only {leader} stands between them and eternal shame." },
        [1] = { "[ALL TIME #1] ALL HAIL {NAME}! {n} deaths, {other} has been dethroned. Omen has a new Lord of the Graveyard." },
    },
    -- mixed into the usual lines, for the class of who died
    class = {
        WARRIOR = { killer = { "{name} charged {killer}. {killer} charged back.", "{name} saved Shield Wall for later. There was no later vs {killer}",
                "{name} hit {killer} with everything except a heal", "{name} forgot that rage does not heal vs {killer}" },
            plain = { "{name} raged all the way to the graveyard", "{name} ran out of rage and then out of health",
                "{name} charged in and stayed there", "{name} had all the rage and none of the health" } },
        PALADIN = { killer = { "{name}'s bubble was on cooldown vs {killer}", "{name} tried to judge {killer}. {killer} judged back.",
                "{killer} broke through every blessing {name} had", "{name} laid hands on {killer}. Wrong target." },
            plain = { "{name} forgot Divine Shield exists", "Even the Light could not save {name}",
                "{name} has been blessed with a corpse run", "{name} pressed the bubble a second too late" } },
        HUNTER = { killer = { "{name}'s Feign Death did not fool {killer}", "{name}'s pet watched {killer} do it", "{name} kited {killer} straight into a wall",
                "{name} ran out of arrows and out of luck vs {killer}", "{name} sent the pet in. {killer} came for {name} instead." },
            plain = { "{name}'s pet is looking for a new owner", "{name}'s pet held aggro for a full two seconds",
                "{name}'s pet will have to find its own way home", "{name} trapped everything except the thing that killed them" } },
        ROGUE = { killer = { "{name} vanished. Just not from {killer}", "{name} used Evasion. {killer} used hitting them anyway.",
                "{name} went for the backstab. {killer} turned around.", "{name} tried to sneak past {killer}. {killer} saw." },
            plain = { "{name} went into stealth. Permanently.", "{name} backstabbed the air and the air won",
                "{name} cheated death. Death checked the cards.", "{name} ran out of energy and out of tricks" } },
        PRIEST = { killer = { "{name} forgot to shield themselves vs {killer}", "{killer} walked right through {name}'s Power Word: Shield",
                "{name} tried Psychic Scream on {killer}. {killer} was not scared.", "{name} healed through it, until {killer} hit harder" },
            plain = { "{name} ran out of mana and out of life", "{name} prayed. Nobody picked up.",
                "{name} has gone to meet the Light in person", "{name} forgot to heal the most important person: themselves" } },
        SHAMAN = { killer = { "{name}'s totems did nothing against {killer}", "{name} dropped every totem they had and {killer} stepped over them",
                "{name} dropped totems. {killer} dropped {name}.", "{name} shocked {killer}. {killer} was not shocked." },
            plain = { "{name}'s totems are still standing. {name} is not.", "{name}'s Reincarnation is on cooldown. So is {name}.",
                "{name} called on the spirits. The spirits sent a ghost.", "{name}'s Ankh was in the bank" } },
        MAGE = { killer = { "Blink did not take {name} far enough from {killer}", "{name} tried to polymorph {killer}. {killer} declined.",
                "{name}'s Frost Nova did not freeze {killer} for long enough", "{killer} got through all of {name}'s ice" },
            plain = { "{name} blinked straight into the afterlife", "{name} had Ice Block ready. {name} also had other plans, apparently.",
                "{name} conjured water, food and no plan", "{name} ran out of mana and out of spells" } },
        WARLOCK = { killer = { "{name}'s demon survived {killer}. {name} did not.", "{name} tried to fear {killer}. {killer} was not afraid.",
                "{name} drained {killer}. {killer} drained {name} faster.", "{name}'s Voidwalker watched {killer} do it" },
            plain = { "{name} paid for that Life Tap with a life", "{name}'s Soulstone was in the other bag",
                "{name} made a deal with a demon. The demon won.", "{name} used Life Tap one time too many" } },
        DRUID = { killer = { "{name} shapeshifted into a corpse vs {killer}", "{name} went bear, then cat, then corpse vs {killer}",
                "{name} tried every form vs {killer}. None of them worked.", "{killer} was not impressed by {name}'s shapeshifting" },
            plain = { "{name} turned into a tree. A dead one.", "{name} had nine forms to choose from and picked corpse",
                "{name} went into hibernation. A long one.", "{name} put down roots. Six feet under." } },
    },
    -- 0.9.6: class and role together, only in dungeons and raids (they talk about a group)
    classRole = {
        WARRIOR = {
            tank = { killer = { "{killer} got through {name}'s shield and the armor behind it" }, plain = { "{name}'s Shield Wall lasted longer than {name} did" } },
            dps = { killer = { "{name} hit {killer} really hard for about four seconds" }, plain = { "{name} brought two weapons and zero survival" } },
        },
        PALADIN = {
            tank = { killer = { "{name}'s Divine Shield worked perfectly. {killer} just went for the healer, then came back." }, plain = { "{name} consecrated the floor they are now lying on" } },
            healer = { killer = { "{name} was busy flashing everyone else when {killer} showed up" }, plain = { "{name} had Lay on Hands ready and gave it to the wrong person: everyone else" } },
            dps = { killer = { "{name} went in swinging at {killer} and forgot to bubble" }, plain = { "{name} brought a two-hander and no plan" } },
        },
        DRUID = {
            tank = { killer = { "{name} went bear. {killer} went hunting." }, plain = { "{name}'s bear form has gone into hibernation" } },
            healer = { killer = { "{killer} walked through {name}'s HoTs like they were not there" }, plain = { "{name} kept everyone's HoTs rolling, except their own" } },
            dps = { killer = { "{name} was mid-rotation when {killer} ended it" }, plain = { "{name} ran out of energy and out of options" } },
        },
        PRIEST = {
            healer = { killer = { "{name} had a Renew on everyone but themselves vs {killer}" }, plain = { "{name} healed the whole group. The group did not return the favour." } },
            dps = { killer = { "{name} tried to mind flay {killer}. {killer} flayed back." }, plain = { "{name} went Shadow and took the darkness a bit too literally" } },
        },
        SHAMAN = {
            healer = { killer = { "{killer} kicked over {name}'s Mana Spring and kept going" }, plain = { "{name} chain healed everyone but the last link: themselves" } },
            dps = { killer = { "{name} threw lightning at {killer}. {killer} threw {name}." }, plain = { "{name} grounded themselves. Six feet deep." } },
        },
    },
    -- Deathless (0.9.11, wish of the user): every 10 levels without ever dying, each step bigger.
    -- {n} = the level. No pronouns (the user's choice: none, else "their").
    deathless = {
        [10] = { "Achievement: {name} reached level 10 without dying. A careful start.",
            "Achievement: {name} reached level 10 without a single death. The Spirit Healer is still waiting for a first visit." },
        [20] = { "Achievement: {name} reached level 20 deathless. Twenty levels, zero corpse runs.",
            "Achievement: {name} reached level 20 without dying. The graveyard has started asking questions." },
        [30] = { "Achievement: {name} reached level 30 without dying! Halfway there, and not a scratch.",
            "Achievement: {name} hit level 30 deathless! Even the murlocs have given up." },
        [40] = { "ACHIEVEMENT: {name} reached level 40 WITHOUT DYING! Mounted, armed and still never seen a graveyard.",
            "ACHIEVEMENT: {name} reached level 40 deathless! The Spirit Healer has filed a missing person report." },
        [50] = { "ACHIEVEMENT: {name} reached level 50 WITHOUT A SINGLE DEATH! Ten more levels. The whole guild is watching. No pressure.",
            "ACHIEVEMENT: {name} reached level 50 deathless! Legends are whispered in Orgrimmar and Stormwind alike." },
        [60] = { "LEGEND: {name} reached level 60 WITHOUT DYING ONCE!" },
    },
    deathless60 = { "60 levels. Zero deaths. Bow down, mortals. {name} enters the Hall of the Deathless." },
    -- The very first death of a character (0.9.11): always its own line, bigger after a longer run.
    -- {n} = the level, {levels} = the levels it stayed alive.
    first = {
        low = { killer = { "First blood: {name} died for the first time at level {n}, to {killer}. Welcome to the club.",
                "First blood: {name} died for the first time at level {n}, to {killer}. Every hero starts somewhere." },
            plain = { "First blood: {name} died for the first time at level {n}. Welcome to the club.",
                "First blood: {name} died for the first time at level {n}. Every hero starts somewhere." } },
        high = { killer = { "The deathless run is over: {name} died for the first time at level {n}, to {killer}. {levels} levels of perfection, gone.",
                "The deathless run is over: {killer} ended {name}'s run at level {n}. {levels} levels without a death. It was a good run." },
            plain = { "The deathless run is over: {name} died for the first time at level {n}. {levels} levels of perfection, gone.",
                "The deathless run is over: {name} died for the first time at level {n}. {levels} levels without a death. It was a good run." } },
        close = { killer = { "SO CLOSE: {name} died for the first time at level {n}, to {killer}, one level before Deathless 60. The guild will never forget." },
            plain = { "SO CLOSE: {name} died for the first time at level {n}, one level before Deathless 60. The guild will never forget." } },
        -- already Deathless 60: the fall of a legend
        top = { killer = { "A LEGEND FALLS: {name}, Deathless 60, died for the first time, to {killer}. The Hall of Fame carves a cross before the name." },
            plain = { "A LEGEND FALLS: {name}, Deathless 60, died for the first time. The Hall of Fame carves a cross before the name." } },
    },
    generic = {
        plain = { "{name} bit the dust", "{name} is taking a dirt nap", "{name} joined the Spirit Healer fan club",
            "{name} is now a ghost. Spooky.", "Pour one out for {name}", "{name} took a shortcut to the graveyard",
            "{name} has left the land of the living (temporarily)", "{name} is visiting the Spirit Healer again",
            "The graveyard welcomes {name} back", "{name} ran out of health. It happens.",
            "{name} is lying down for a while", "{name} has stopped moving. For now." },
    },
}

-- The German client names a dungeon in German (seen once: Scharlachrotes Kloster, 27-11-2026)
Lines.DUNGEON_ALIAS = { ["Scharlachrotes Kloster"] = "Scarlet Monastery" }

-- 0.9.14: the template used last time, per player, so the same line does not come twice in a row
Lines.recent = {}

-- Kinds of damage from the death recap (environmentalType, shown as "Falling", "Lava", ...).
local ENV = { Falling = "fall", Drowning = "drown", Lava = "lava", Fire = "lava", Fatigue = "fatigue", Slime = "slime" }

-- Which set fits this death.
function Lines.Situation(rec)
    if not rec.k and rec.s and ENV[rec.s] then return ENV[rec.s] end
    local it = rec.it or "none"
    if it == "pvp" or it == "arena" then return "pvp" end
    if it == "raid" then return "raid" end
    if it == "party" then return "dungeon" end
    if rec.k then
        -- kt = how the game coloured the killer's level at the death (only known to who died)
        if rec.kt == "skull" or rec.kt == "red" then return "above" end
        if rec.kt == "gray" then return "gray" end
        return "world"
    end
    return "generic"
end

-- "1st", "2nd", "3rd", "4th", "11th", "200th"
function Lines.Nth(n)
    local last, two = n % 10, n % 100
    local suffix = (two >= 11 and two <= 13) and "th" or last == 1 and "st" or last == 2 and "nd" or last == 3 and "rd" or "th"
    return n .. suffix
end

-- vars: a number ({n}, as before 0.9.0) or { n = ..., other = ... }.
function Lines.Render(template, name, killer, vars)
    if type(vars) ~= "table" then vars = { n = vars } end
    local n = vars.n
    return (template:gsub("{name}", function() return name end):gsub("{killer}", function() return killer or "" end)
        :gsub("{nth}", function() return type(n) == "number" and Lines.Nth(n) or "" end)
        :gsub("{n}", function() return tostring(n or "") end)
        :gsub("{other}", function() return vars.other or "" end)
        :gsub("{leader}", function() return vars.leader or "" end)
        :gsub("{levels}", function() return tostring(vars.levels or "") end)
        :gsub("{NAME}", function() return Lines.Loud(name) end)
        :gsub("{KILLER}", function() return Lines.Loud(killer or "") end))
end

-- In capitals, leaving a colour code around the text intact (the popup's chat line colours the name).
function Lines.Loud(s)
    local open, body, close = s:match("^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
    if open then return open .. body:upper() .. close end
    return s:upper()
end

-- What the streak looks at: the killer, else a kind of damage from the recap (Falling, Lava...).
local function StreakKey(r)
    if r.k then return "k:" .. r.k end
    if r.s and ENV[r.s] then return "s:" .. r.s end
end

-- How many deaths in a row (this one included) had the same killer or cause, on the same day.
function Lines.Streak(rec, owner, book)
    local key = StreakKey(rec)
    if not key or not owner or type(rec.t) ~= "number" then return 1 end
    book = book or (ns.Book and ns.Book())
    local p = book and book.players[owner]
    if not p then return 1 end
    local from = ns.Data.PeriodStart("day", rec.t)
    local before = {}
    for t, r in pairs(p.deaths) do
        if t < rec.t and t >= from then before[#before + 1] = r end
    end
    table.sort(before, function(a, b) return a.t > b.t end)
    local n = 1
    for _, r in ipairs(before) do
        if StreakKey(r) ~= key then break end
        n = n + 1
    end
    return n
end

-- The streak list for n deaths in a row, nil below 2.
function Lines.StreakList(rec, n)
    if n < 2 then return nil end
    local set = Lines.SETS.streak[rec.k and "killer" or ENV[rec.s]] or Lines.SETS.streak.other
    local step = n >= 10 and 10 or n >= 5 and 5 or n
    -- 0.9.6: the count up front, so a streak stands out in guild chat (no colours there)
    local tag = "[{n}x STREAK" .. (n >= 10 and "!!!" or n >= 5 and "!" or "") .. "] "
    local list = {}
    for i, template in ipairs(set[step]) do list[i] = tag .. template end
    return list
end

-- All Time of the owner up to and including this death: the game's statistic (without battlegrounds)
-- plus the deaths after it was read, or the deaths the addon saw if that is more (as the leaderboard).
function Lines.AllTime(rec, owner, book)
    local p = book and owner and book.players[owner]
    if not p or type(rec.t) ~= "number" or not ns.Data.InScope(rec, nil) then return nil end
    local seen, after = 0, 0
    local st = p.stat
    for t, r in pairs(p.deaths) do
        if t <= rec.t and ns.Data.InScope(r, nil) then
            seen = seen + 1
            if st and t > st.at then after = after + 1 end
        end
    end
    local fromStat = st and (st.total - (st.bg or 0) + after) or 0
    return math.max(seen, fromStat)
end

-- Did this death move me up the All Time board? Returns { from, to, n, other, leader } or nil.
-- Only really passing counts: someone with as many deaths as me stays ahead of me, in both the
-- rank before and after (the board itself orders equal counts by name). Not on my first death.
function Lines.RankUp(rec, owner, book)
    if not book or not owner then return nil end
    local mine = Lines.AllTime(rec, owner, book)
    if not mine or mine < 2 then return nil end
    local ahead, passed = {}, {}
    for name in pairs(book.players) do
        if name ~= owner and ns.Data.Shown(name) then
            local n = Lines.AllTime({ t = rec.t, it = "none" }, name, book) or 0
            if n >= mine then ahead[#ahead + 1] = { name = name, n = n }
            elseif n == mine - 1 then passed[#passed + 1] = name end
        end
    end
    if #passed == 0 then return nil end
    table.sort(passed)
    table.sort(ahead, function(a, b)
        if a.n ~= b.n then return a.n > b.n end
        return a.name < b.name
    end)
    local to = #ahead + 1
    return { from = to + #passed, to = to, n = mine, other = passed[1], leader = ahead[1] and ahead[1].name }
end

Lines.MILESTONES = { [10] = true, [25] = true, [50] = true } -- then every 100 (chosen by the user)
function Lines.IsMilestone(n)
    return type(n) == "number" and (Lines.MILESTONES[n] or (n >= 100 and n % 100 == 0)) or false
end

-- A guildie who died in the same fight (since rec.fs, when my fight began; own deaths only) and
-- the same place, before me: their name.
function Lines.Together(rec, owner, book)
    if type(rec.fs) ~= "number" or not book then return nil end
    local best, bestT
    for name, p in pairs(book.players) do
        if name ~= owner and ns.Data.Shown(name) then
            for t, r in pairs(p.deaths) do
                local here = rec.id and r.id == rec.id or (not rec.id and not r.id and r.z == rec.z)
                if t >= rec.fs and t <= rec.t and here and (not bestT or t > bestT) then best, bestT = name, t end
            end
        end
    end
    return best
end

-- How many of us this killer got today, this death included (only when someone else is among them).
function Lines.Plague(rec, owner, book)
    if not rec.k or type(rec.t) ~= "number" or not book then return 0 end
    local from, who, others = ns.Data.PeriodStart("day", rec.t), {}, 0
    for name, p in pairs(book.players) do
        if ns.Data.Shown(name) or name == owner then
            for t, r in pairs(p.deaths) do
                if t >= from and t <= rec.t and r.k == rec.k and not who[name] then
                    who[name] = true
                    if name ~= owner then others = others + 1 end
                end
            end
        end
    end
    return others > 0 and (others + 1) or 0
end

-- Days since the death before this one, when that is more than CLEAN_DAYS (else nil).
Lines.CLEAN_DAYS = 3 -- chosen by the user (10-11-2026)
function Lines.CleanDays(rec, owner, book)
    local p = book and owner and book.players[owner]
    if not p or type(rec.t) ~= "number" then return nil end
    local prev
    for t in pairs(p.deaths) do
        if t < rec.t and (not prev or t > prev) then prev = t end
    end
    if not prev then return nil end
    local days = math.floor((rec.t - prev) / 86400)
    return (rec.t - prev > Lines.CLEAN_DAYS * 86400) and days or nil
end

-- The first death (0.9.11): low under 30, high from 30, close at 59 (one level before Deathless 60).
-- 30 is where the deathless popups start; the user approved these steps (25-11-2026).
-- At 60 (already Deathless 60): "top".
Lines.FIRST_HIGH, Lines.FIRST_CLOSE, Lines.FIRST_TOP = 30, 59, 60
function Lines.FirstTier(level)
    if level >= Lines.FIRST_TOP then return "top" end
    if level >= Lines.FIRST_CLOSE then return "close" end
    if level >= Lines.FIRST_HIGH then return "high" end
    return "low"
end

-- Is this (not yet stored) death the character's very first? Only when the game's own statistic
-- is known: without it, someone who got the addon late would get a false "first death".
-- AllTime = the statistic without battlegrounds plus the deaths seen after it was read.
function Lines.IsFirst(rec, owner, book)
    local p = book and owner and book.players[owner]
    if not p or not p.stat then return false end
    return Lines.AllTime(rec, owner, book) == 0
end

-- The special line that fits, first in this order (one line per death): milestone, together,
-- streak, plague, clean, level-up, one-shot. Returns list, named, vars; nil when none fits.
function Lines.Special(rec, name, book)
    local S = Lines.SETS
    local function pick(set, vars)
        if rec.k and set.killer then return set.killer, true, vars end
        if set.plain then return set.plain, false, vars end
    end
    -- the very first death goes before everything (0.9.11)
    if rec.fd then
        local lv = type(rec.l) == "number" and rec.l or 1
        local set = S.first[Lines.FirstTier(lv)]
        local list, named = pick(set, nil)
        return list, named, { n = lv, levels = math.max(0, lv - 1) }
    end
    local all = Lines.AllTime(rec, name, book)
    if Lines.IsMilestone(all) then return S.milestone.plain, false, { n = all } end
    local other = Lines.Together(rec, name, book)
    if other then return pick(S.together, { other = other }) end
    local n = Lines.Streak(rec, name, book)
    local streak = Lines.StreakList(rec, n)
    if streak then return streak, rec.k ~= nil, { n = n } end
    local plague = Lines.Plague(rec, name, book)
    if plague >= 2 then return S.plague.killer, true, { n = plague } end
    local days = Lines.CleanDays(rec, name, book)
    if days then return S.clean.plain, false, { n = days } end
    if type(rec.lu) == "number" then return S.levelup.plain, false, { n = rec.lu } end
    if rec.os and rec.k then return S.oneshot.killer, true, {} end
end

-- A line for this death, whether it already names the killer, the template it came from, and its
-- values ({n}, {other}) for Render.
function Lines.For(rec, name, book)
    book = book or (ns.Book and ns.Book())
    local list, named, vars = Lines.Special(rec, name, book)
    if not list then
        vars = {}
        local situation = Lines.Situation(rec)
        local set = Lines.SETS[situation]
        local role = set.roles and rec.r and set.roles[rec.r]
        -- class lines mix in, not for falls, lava and other kinds of damage
        local envKind = not rec.k and rec.s and ENV[rec.s]
        local class = not envKind and Lines.SETS.class[rec.c or ""] or nil
        local inGroup = rec.it == "party" or rec.it == "raid"
        local combo = inGroup and not envKind and rec.r and (Lines.SETS.classRole[rec.c or ""] or {})[rec.r] or nil
        local here = situation == "dungeon" and rec.z and Lines.SETS.dungeons[Lines.DUNGEON_ALIAS[rec.z] or rec.z] or nil
        list, named = Lines.SETS.generic.plain, false
        if rec.k and set.killer then
            list, named = set.killer, true
            if role and role.killer then list = Lines.Merge(list, role.killer) end
            if class and class.killer then list = Lines.Merge(list, class.killer) end
            if combo and combo.killer then list = Lines.Merge(list, combo.killer) end
            if here and here.killer then list = Lines.Merge(list, here.killer) end
        elseif set.plain then
            list = set.plain
            if role and role.plain then list = Lines.Merge(list, role.plain) end
            if class and class.plain then list = Lines.Merge(list, class.plain) end
            if combo and combo.plain then list = Lines.Merge(list, combo.plain) end
            if here and here.plain then list = Lines.Merge(list, here.plain) end
        elseif class and class.plain then
            list = Lines.Merge(list, class.plain)
        end
    end
    local template = Lines.Pick(list, name)
    return Lines.Render(Lines.WithLevel(template, rec), name, rec.k, vars), named, template, vars
end

-- A random template, not the same one as this player's line before (when there is a choice).
function Lines.Pick(list, name)
    local i = math.random(#list)
    local key = name or "?"
    if #list > 1 and list[i] == Lines.recent[key] then i = i % #list + 1 end
    Lines.recent[key] = list[i]
    return list[i]
end

-- The killer's level as the game shows it: -1 = "??" (a skull mob).
function Lines.Level(kl)
    if type(kl) ~= "number" then return nil end
    return kl == -1 and "??" or tostring(kl)
end

-- The level goes right after the first time the line names the killer (0.9.11, asked by the guild):
-- "Hogger (lvl 12) says hi to Bob". Lines without the killer get it in Lines.Detail.
function Lines.WithLevel(template, rec)
    local lvl = rec.k and Lines.Level(rec.kl)
    if not lvl then return template end
    local a = template:find("{killer}", 1, true)
    local b = template:find("{KILLER}", 1, true)
    local at = a and b and math.min(a, b) or a or b
    if not at then return template end
    return template:sub(1, at + 7) .. " (lvl " .. lvl .. ")" .. template:sub(at + 8)
end

function Lines.Merge(a, b)
    local out = {}
    for _, v in ipairs(a) do out[#out + 1] = v end
    for _, v in ipairs(b) do out[#out + 1] = v end
    return out
end

-- What follows the line: " - to Hogger (Rend) in Elwynn Forest", without the killer if the line has it,
-- and without the place when the line (text) already names it (0.9.14, the dungeon lines).
function Lines.Detail(rec, namedKiller, text)
    local cause
    if rec.k and not namedKiller then
        local lvl = Lines.Level(rec.kl)
        local inside = lvl and ("lvl " .. lvl .. (rec.s and (", " .. rec.s) or "")) or rec.s
        cause = "to " .. rec.k .. (inside and (" (" .. inside .. ")") or "")
    elseif rec.k and rec.s then
        cause = "by " .. rec.s
    elseif not rec.k and rec.s and not ENV[rec.s] then
        cause = "to " .. rec.s
    end
    local parts = {}
    if cause then parts[#parts + 1] = cause end
    local named = rec.z and type(text) == "string" and text:lower():find((rec.z:lower():gsub("^the ", "")), 1, true)
    if rec.z and not named then parts[#parts + 1] = "in " .. rec.z end
    return table.concat(parts, " ")
end
