# Changelog

## 0.9.12
- The Hall of Fame is now one ranking of the living and the fallen. Who died keeps a place at the level of the first death, with a cross and a grey name. The living keep climbing and can pass them
- From level 30, every level without dying gets a short line in your own chat: "Kestrel reached level 38 deathless (#7 in the Hall of Fame)". Not in guild chat
- Pass a guildie on the Hall of Fame and everyone with the addon sees it: "Kestrel passed Ashveil (#6 in the Hall of Fame)"
- New Duels tab: a duel ranking with one Omen belt. Beat someone above you to take their place, the champion holds the belt until beaten. One duel per pair per day counts. See who is online and whisper a challenge with one click

## 0.9.11
- New Hall of Fame tab: everyone who never died, ranked by level. Level 60 on top, stay alive and level up to climb
- Deathless achievements: reach level 10, 20, 30, 40, 50 or 60 without ever dying and the guild hears it. Each step is bigger, level 60 gets the biggest popup. Battleground deaths do not count
- Your very first death gets its own line, bigger after a longer deathless run
- The death line now shows the level of the killer, as the game shows it: "Hogger (lvl 12)", "(lvl ??)" for a skull
- Smaller tabs, so they all fit next to the window
- Tabs that are not finished yet (Duels, Custom Messages, Raids) are hidden. Type /omen beta to see them
- Behind the scenes, nothing changes in your game: in dungeons and raids the addon checks what raid tools the game allows, to build the Raids tab

## 0.9.10
- New setting Guild repairs (off by default): choose if auto repair may pay from the guild bank. Off means you pay yourself
- The Repairs board now only counts what players paid themselves
- With Guild repairs on, the addon also checks if the guild bank holds enough gold

## 0.9.9
- Dungeons: everyone now posts their own funny line, also in a boss fight. Raids keep one summary per fight

## 0.9.8
- Killers get a face: NPCs in the top 3 show their portrait, and falls, lava, fire, drowning, fatigue and slime each have their own icon. Killers from before this update get theirs as soon as a guildie with this version comes across them
- A brand new window in the game's own style, with icon tabs on the side and the top 3 on real gravestones. Prefer the old one? Type /omen newui
- The Awards tab now shows last week's winners and who is on course this week
- New tabs, still under construction: Duels and Custom Messages
- Fixes: long text no longer runs off a gravestone, and duel results missed while offline now arrive

## 0.9.7
- Behind the scenes, nothing changes in your game: the result of a duel between two guildies is now shared with the guild, to test a future Omen duel ranking

## 0.9.6
- The popup for a guildie's death now shows the same line as guild chat. Both of you need this version; if the killer is not known right away, the popup waits for the line
- Many more lines per class, new lines for class and role together, and role lines in raids and the open world too
- Streaks stand out: [3x STREAK] up front in guild chat, an orange popup, and louder lines at 4, 5 and 10 in a row
- All Time rank-ups: a short [Rank 33 > 32] at the end of your line, and a line of its own when you pass someone in the top 3
- Taking the Spirit Healer's deal now gets you publicly shamed in guild chat
- Fixes a double boss summary: addons now take turns
- A popup can no longer get lost when the message with the line does not arrive

## 0.9.5
- Fixes game stutter when a guildie logs in: the addon no longer re-sends every death it knows each time someone logs in or reloads. Update helps you and your guild most when everyone has it
- Behind the scenes only, nothing changes in your game: the addon keeps a short log of the lines it posts in guild chat (so a flood of lines can be explained), and measures what the game's damage meter and duels give, for future features (boss fights, duels)

## 0.9.4
- Battlegrounds and arenas no longer spam guild chat: those deaths are never posted, and a guildie's death there gives no popup, sound or chat line. They still count on the board under Battlegrounds
- The Guild chat button is now simply On / Off (the "On, battlegrounds too" setting is gone)

## 0.9.3
- Death sound is much louder: it now plays on your Master volume, three times at once
- A popup tells you when a newer version is out (the chat line was easy to miss)

## 0.9.2
- Every place on the board now has its own title, from "Spirit Healer's Favourite" for the most deaths to "Immortal (So Far)" for the fewest (100 titles)

## 0.9.1
- Repairs board: amounts now show with coin icons like the game does ("14s" looked like "148" gold)
- Fixed a measurement on your own PC that counted logging in as coming back from your last death

## 0.9.0
- **New lines for special deaths:** your 10th, 25th, 50th, 100th death and every 100 after that; dying together with a guildie in the same fight; a mob that already killed another guildie today; your first death in more than 3 days; dying right after a level-up; being one-shot from full health
- **Class lines:** every class gets its own jokes ("Kwatta's bubble was on cooldown vs Hogger")
- **Last week's awards** in guild chat after the weekly reset: Death of the week, Floor Inspector (most falls) and Deadliest foe
- **Auto repair:** your gear is repaired when you open a merchant who can repair (on by default, switch it off in the Repairs view or with `/omen repair`), and a new **Repairs** board shows who pays the biggest repair bills
- **Sound button:** hear the human death scream (male or female, like who died) when a guildie dies (off by default)
- Now on CurseForge: install it in the CurseForge app (World of Warcraft → Forever) and it updates itself
- Less work for the addon at every death (old measuring code removed)

## 0.8.9
- Dying the same way again and again gets its own lines ("Hogger 3, Benny 0. Someone call for backup.")
- Dungeon lines fit your role: tanks, healers and damage dealers each get their own
- The update message says when a game restart is needed

## 0.8.8
- The Omen guild logo on the minimap button

## 0.8.7
- New lines for a mob way above your level (red or skull) and for gray mobs
- Leaderboard per raid boss
- A short message in guild chat when a new version is out
- Fixed: a death could give two lines in guild chat

## 0.8.6
- The update message explains how to load the new version

## 0.8.5
- Fixed: a guild chat line could go missing

## 0.8.4
- Old battleground deaths move to the Battlegrounds board
- Only players who are in the guild now are shown

## 0.8.2 and 0.8.3
- Guild chat button with three settings: No BG (default), Off and On
- Fixed: the X did not close the window

## 0.8.0 and 0.8.1
- Health page: which version every guildie runs and whether their addon works
- A message when a guildie runs a newer version, with where to get it

## Before 0.8.0
- Leaderboard for Today, This Week, This Month and All Time, per place
- Killers board, funny lines in guild chat, one summary per boss fight, popup, minimap button
