# Skada for WoTLK (_Revisited - v1.8.78_)

![Discord](https://img.shields.io/discord/795698054371868743?label=discord)
![GitHub last commit](https://img.shields.io/github/last-commit/bkader/Skada-WoTLK)
![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/bkader/Skada-WoTLK?label=version)

_This version is a total **Rewrite** of Skada `r301` for `3.3.5` and not a **Backport** like some believe._

Skada is a modular damage meter with various viewing modes, segmented fights and customizable windows. It aims to be highly efficient with memory and CPU.

_**Also available for [Cataclysm](https://github.com/bkader/Skada-Cata/)**_

<p align="center"><img src="https://user-images.githubusercontent.com/4732702/170839578-72a9a952-c999-457a-8f57-7d151e3b76a8.png" alt="Skada WotLK"></p>

## IMPORTANT: How to install

1. If you used the default on **Skada** before, please make sure to delete all its files from `Interface\AddOns` folder as well as all its _SavedVariables_ from `WTF` folder (_just delete all `Skada.lua` and `Skada.lua.bak` for this folder. Use the search box for quick delete_). If you are new, skip this step.
2. [Download the package](https://github.com/bkader/Skada-WoTLK/archive/refs/heads/main.zip).
3. Open the Zip package inside which you will find a single folder named `Skada-WoTLK-main`.
4. Extract or drag and drop the unique folder `Skada` into your `Interface\AddOns` folder.
5. If you want to use `SkadaImprovement` module, drop it there as well.

## Show Love & Support

Though it's not required, **PayPal** donations are most welcome at **bkader[at]mail.com**, or via Discord [Donate Bot](https://donatebot.io/checkout/795698054371868743).

## Table of content

* [What's the difference?](#whats-the-difference)
* [How to install](#how-to-install)
* [Modules](#modules)
  * [Absorbs](#absorbs)
  * [Activity](#activity)
  * [Buffs and Debuffs](#buffs-and-debuffs)
  * [Crowd Control (_Done, Taken and Breakers_)](#crowd-control)
  * [Damage](#damage)
  * [Damage taken](#damage-taken)
  * [Deaths](#deaths)
  * [Dispels, Interrupts and Resurrects](#dispels-interrupts-and-resurrects)
  * [Enemies](#enemies)
  * [Failbot](#failbot)
  * [Friendly Fire](#friendly-fire)
  * [Healing](#healing)
  * [Improvement](#improvement)
  * [Nickname](#nickname)
  * [Parry-haste](#parry-haste)
  * [Potions](#potions)
  * [Power gains](#power-gains)
  * [Threat](#threat)
  * [My Spells](#my-spells)
  * [Scroll](#scroll)
  * [Sunder Counter (_Sunder Armor_)](#sunder-counter)
  * [Themes](#themes)
  * [Tweaks](#tweaks)
  * [PvP](#pvp)
  * [Project Ascension](#project-ascension)

## What's the difference?

This version of Skada is a mix between the old default version available for **WotLK** and the **latest retail** version. Everything was fully rewritten to provide more detailed spell breakdowns and more. Here is why it is better than the old default version:

- An **All-In-One** addon instead of having modules seperated into addons. Most of the modules can be enable or disabled on the options panel.
- Lots of new modules were added, some found on the internet and others were requested by the community.
- Windows are resizable using the resize grips/handles found at both bottom corners. Holding **SHIFT** when resizing changes widths while holding **ALT** changes heights.
- Bars are more fancy, colored by not only class but also spell school colors.
- Bars can display players/enemies classes, roles or specializations unlike the default old version. Spells also had their icons changed to display info tooltips (_spells tooltips_).
- The **most (*if not the only*) accurate** combat log parser for WotLK, whether it is for damage, healing or absorbs. Since absorbs aren't really available in this expansion, this Skada is best at estimating amounts with lots of calculations and logics implemented after months and gigabytes of combat log parsing.
- Profiles importation/exportation as well as dual-spec profiles.
- Under consistent, free and solo development thanks to WotLK community and their feedbacks (_helps and pull requests are most welcome_).
- An annoying number of options available for more advanced players.

## Modules

The modules are the same you are used to see on default **Skada** but completely rewritten from the ground up to really give justice the the _combatlog_, by recording and showing everything related to it (_almost everything_).

### Absorbs

Because _WoTLK_ has no event to record the absorbs, auras priority system was used to give the best and most accurate numbers possible. It gives you access to _Absorbs_, _Absorb spells_ and _Absorb targets_.
This module has a sub-module called `Absorbs and healing` that requires both Absorbs and healing to be enabled because it collects data from both.

### Activity

Shows players activity in the raid, or what's called _Active Time_.

### Buffs and Debuffs

This module shows players buffs and their uptime, debuffs and their uptime and targets.

### Crowd Control

1. **CC Done** & **CC Taken**: unlike default ones, they now provided details info about spells used to CC and targets/sources.
2. **CC Breakers** : this was rewritten a bit, it is almost like the old one but optimized and provided like other CC modules, spell and target details.

### Damage

This module shows detailed data about damage done, giving you access to _Damage spell list_ and _Damage target list_ and has three sub-modules:

1. **DPS**: obviously, shows the dps of raid members depending on the time measurement you choose (_active or effective_) and it gives you access to the same data as its parent.
2. **Damage done by spell**: this module shows a list of all spells used in your raid with their damage and the percentage of damage to the total. Clicking on a spell gives you access to the _Damage source list_, aka list of players that used that spell.
3. **Useful damage**: a useful damage is the damage required for the target to die, anything above it is called _Overkill_, this module shows the damage done in your raid without the overkill, it means all the damage that was required for all your raid targets to reach 0 health.
4. **Overkill**: this module does the reverse of what _Useful damage_ does, it only lists players overkill with the list of their overkill spells.
5. **Absorbed Damage**: simply shows the damage that was absorbed because some players consider it part of the damage anyways.

### Damage taken

Shows the damage taken by players of your raid with details about damage spells and damage sources. It provides three sub-modules:

1. **Damage taken by spell**: the same as the _Damage done by spell_ but for damage your raid took, clicking a spell bar shows the list of players with the damage they took from it.
2. **Avoidance & Mitigation**: a pure tank module that gives you info about damage avoidance and mitigation (absorb, dodge, misses, blocks ... etc).
3. **Damage mitigated**: shows data about the damage that was aborbed, blocked or resisted, giving you access to _Damage spell list_ which gives you access to _Damage spell details_, all in the concept of mitigated damage.
4. **DTPS** (_Damage taken per second_): the data is already shown as a column in _Damage taken_ module, but this module can be handy for some.

### Deaths

This module was completely rewritter and unlike the default one, it keeps all player deaths and not only one and the deathlog provided spell details (absorb, resist, block, overkill ... etc).

### Dispels, Interrupts and Resurrects

These module do what they are named after, and unlike before, they provide more data: spells dispelled/interrupted, spells used to dispel/interrupt, targets dispelled/interrupted, spells user to resurrect, targets resurrected and resurrect spells used on the select player (_too many boring details right?_).

### Enemies

1. **Enemy Damage Done**: shows the list of targets that damage players during the combat with the damage they've done. Clicking on an enemy bar gives you access to the list of players that were damaged by the enemy, and clicking on a players shows you the spells used on the selected player by the selected enemy. One level deeper and you will see details about the select spell that was used on the selected player by the selected enemy.
2. **Enemy Damage Taken**: shows the list of enemies your party/raid members damaged during the combat with the total damage they took. Clicking on an enemy gives you access to the list of players that damage the selected enemy and clicking on a player shows you the spells that the selected player used on the selected enemy.
3. **Enemy Healing Done**: a simple module that keeps track of enemies healing done, showing their spells and targets.


### Failbot

Unlike the default Failbot module, it displays proper spell names and clicking on a players shows their fails, then clicking on a fail will show you the list of players that fail the selected even. If you are a tank don't you worry, events that are not considered fails for the tank won't be counted for you.

### Friendly Fire

As its name states, it shows the damage players do to each other (_it doesn't count damage you do to youself_). It gives you access to _Damage spell list_ and _Damage target list_.

### Healing
This module shows the _effective healing_ which means it substructs the _overhealing_ as his one is a sub-module of it. It gives you access to _Healing spell list_ and _Healing spell targets_ and it comes with four (4) sub-modules:

1. **Overhealing**: the _Healing_ module keeps the effective healing and all overheals are shown when using this module, giving you access to _Overhealing spell list_ and _Overhealed player list_.
2. **Total healing**: this module shows the data of _Healing_ and _Overhealing_ combined, giving you access to _Healing spell list_ and _Healing player list_.
3. **Healing and Overhealing**: so you don't get confused, this module is made for pure comparison between players healing and overhealing, showing on its bars these data as well as the percentage of overhealing. It gives you access as well to _Healing spell list_ and _Healing player list_.
4. **Healing received**: shows the list of players by their received healing and gives you access to the list of players that healed them.
5. **Healing done by spell**: it lists the healing spells used during the selected segment. Clicking on a spell shows the list of players who used it with the amount.
6. **HOS** (_healing per second_): even if it is already shown in Absorbs and healing, some people want to see it just like **DPS**, so it's available as a module as well.

### Improvement

Use to track your character improvement. It records your boss data in raids only and allows you to compare compare your performance on the same target on different dates.

### Nickname

This module allows you to set a nickname for your character (_for example: the name of the main character if you are playing on an alt_), this name will be displayed on main bars instead of your character's name. All other Skada users and have nicknames enabled will see that name as well.

You can access this module's settings on Tweaks panel > Advanced.

### Parry-haste

Tracks all parry-hastes caused by players in your raid with access to the targets that parried them. Note that this module only records data for bosses that actionly parry-haste.

### Potions

Tracks potions usage during an encounter. It even tracks and prints out to you **pre-potions**.

### Power gains

It records mana, range, energy and runic power gained by players (_happiness of hunter's pet is treated as energy_). Clicking a bar shows you the spells responsible for the gain.

### Threat

I think you already know what this module is used for, so no need to talk more about it. Oh and yes! You can use it instead of Omen or use both, it's up to you and it's a matter of personal preferences.

### My Spells

This mode shows the list of your damage spells, healing spells and absorbs spells, all in a single window with their amounts. The tooltip shows some info if available: hits, normal and critical hits, average, mininum hit, maximum hit and average hit

### Scroll
It provides additional options for scrolling the bar displays. its main features are:

* Allows the middle-button to act as a scroll wheel for people missing wheel hardware (many laptops).
* Provides keybinds for scrolling the bar displays.

### Sunder Counter
Counts and shows the _Sunder Armor_ usage by warriors.

### Themes
It allows you to create themes that you can use if you want to change windows look. Themes can be created, applied and deleted (_probably Shared as well in the future if I don't forget to add it_).

### Tweaks
This module was created in order to add some tweaks to Skada, hence its name. It comes with few options that you may or may not find handy.

***General*** > **First Hit**
This is not a **who pulled** feature, it simply prints out what was the first hit and who was the first boss' target. When it comes to determining who pulled, this is only reliable in certain situations and requires a bit of understanding. The first hit can be from player to boss or boss to player. _Only works on boss fights_.

***General*** > **Module Icons**
Simply shows module icons when you are on the modes list.

***General*** > **Filter DPS messages**
Previously known as _Spamage_, catches damage meters report and shows them in a single line link with tooltip of details.

***General*** > **Ignore Fury of Frostmourne**
If you don't want this spell to be included in anything, enable this option.

***General*** > **Absorbed Damage**
Some people (_Details! users >cough<_) consider that absorbed damage should be included in the overall damage, and because Skada doesn't include it but rather shows it as an extra info, this option was added to satisfy them and so we won't hear/read `Oh! They are not showing the same numbers...`.

***Advanced*** > **Smart Stop**
This feature relies on DBM/BigWigs to stop collecting data after the amount of seconds you choose. It is useful in case of being in combat bug (_not combatlog bug, but stuck in combat_) or if you want to stop collecting data right after the boss has died.

***Advanced*** > **Combat Log**
Unlike the macro people use, this feature ONLY fixes the combat log is detected broken. If it still doesn't fix your combatlog, you can always use `/skada clear`.
If you want to mimic **CL_Fix**, enabled aggressive mode and your combatlog will be cleared every **2 seconds**.

***Advanced*** > **Notifications**
Skada provides visual/toaster notifications for few actions only. These settings allow you to disable this behavior so only use printed messages to the chat window; change the location of notifications as well as changing their on-screen duration and opacity.

### PvP

This module was added as of `r340` and brings extra small features for PvPers:

**Enemies spec detection**
Enemies specs and roles are guessed from their buffs or certain spells they can. Only few auras/spells are added to the detection table but if you know of any more ones that can be used, please let me know on [Discord](https://discord.gg/a8z5CyS3eW) or open an [issue](https://github.com/bkader/Skada-WoTLK/issues) with the `enhancement` label.

**Arena Features**
- It shows both group members and enemies on the same damage and healing windows.
- Players are colored by their team (_flag_) color: Gold for Yellow/Gold Team and Green for the Green Team. If the in-game color blind mode is enabled, the Green team appears Purple.

### Project Ascension

After requests from players to make the addon work properly on [Project Ascension](https://ascension.gg/) and after their staff's help, I could access their [Conquest of Azeroth](https://ascension.gg/news/conquest-of-azeroth-alpha/332) and work on the addon. Thus, as of `v1.8.73`, CoA classes are available on Skada.

Project Ascension is also a **Classless** game that allows you to imagine and build the character of your dreams. Your custom character has any ability or talent within their reach. For this reason and as of `v1.8.73.330`, a special tweaks module was added to Skada to give freedom to players to choose their icons and colors. This module is only available if you play there and you can find in `Tweaks` panel, `Advanced` tab.

Icons and colors are saved per character and cached ones (_from other players_) are saved per account. Your hero is unique, your build is unique, so why not make your character on Skada unique!

### API

This concept was added as of version **1.8.72** and allows the player to access and use data provided by Skada externally. It can be used for example by **WeakAuras** to display things you want.

#### Segments/Sets functions

```lua
-- to retrieve a segment (current for example):
local set = Skada:GetSet("current")

-- After the segment is found, you have access to the following functions
-- called like so: set:Func(...)
set:GetTime() -- returns the segment time

set:GetActor(name, guid) -- attempts to retrieve a player or an enemy.
set:GetPlayer(guid, name) -- attempts to retrieve a player.
set:GetEnemy(name, guid) -- attempts to retrieve an enemy.
set:GetActorTime(guid, name, active) -- returns the actor's time if found or 0.

set:GetDamage(useful) -- returns the segment damage amount, exlucing overkill if "useful" is true
set:GetDPS(useful) -- returns the dps and damage amount, excluding overkill if "useful" is true

set:GetDamageTaken() -- returns the damage taken by players.
set:GetDTPS() -- returns the damage taken by players per second and damage amount.

set:GetActorDamage(guid, name, useful) -- returns the damage done by the given actor.
set:GetActorDPS(guid, name, useful, active) -- returns the dps and damage for the given actor.
set:GetActorDamageTargets(guid, name, tbl) -- returns the table of damage targets.
set:GetActorDamageSpells(guid, name) -- returns the table of damage spells.
set:GetActorDamageOnTarget(guid, name, targetname) -- returns the damage, overkill [and useful for enemies]

set:GetActorDamageTaken(guid, name) -- returns the damage taken by the actor.
set:GetActorDTPS(guid, name, active) -- returns the damage taken by the actor per second and damage amount.
set:GetActorDamageSources(guid, name, tbl) -- returns the table of damage taken sources.
set:GetActorDamageTakenSpells(guid, name) -- returns the table of damage taken spells.
set:GetActorDamageFromSource(guid, name, targetname) -- returns the damage, overkill [and useful for enemies].

set:GetOverkill() -- returns the amount of overkill

set:GetHeal() -- returns the amount of heal.
set:GetHPS() -- returns the amount of heal per second and the heal amount.

set:GetOverheal() -- returns the amount of overheal.
set:GetOHPS() -- returns the amount of overheal per second and the overheal amount.

set:GetTotalHeal() -- returns the amount of heal, including the overheal
set:GetTHPS() -- returns the amount of heal+overheal per second

set:GetAbsorb() -- returns the amount of absorbs.
set:GetAPS() -- returns the amount of absorbs per second and the absorb amount.

set:GetAbsorbHeal() -- returns the amount of heals and absorbs combined.
set:GetAHPS() -- returns the amount of heals and absorbs combined per second.
set:GetAbsorbHealSpells(tbl) -- returns the table of heal spells and absorbs spells combined.

--
-- below are functions available only if certain modules are enabled.
--

-- requires Healing Taken module
set:GetAbsorbHealTaken(tbl) -- returns the amount of heal taken.

-- requires either Buffs or Debuffs modules.
set:GetAuraPlayers(spellid) -- returns the list of players that had the aura.

-- requires Enemies modules
set:GetEnemyDamage() -- returns the damage done by enemeies.
set:GetEnemyDPS() -- returns enemies DPS and damage amount.
set:GetEnemyDamageTaken() -- returns the damage taken by enemeies.
set:GetEnemyDTPS() -- returns enemies DTPS and damage taken amount.
set:GetEnemyOverkill() -- returns enemies overkill amount.
set:GetEnemyHeal(absorb) -- returns enemies heal amount [including absorbs]
set:GetEnemyHPS(absorb, active) -- returns enemies HPS and heal amount.

-- requires Absorbed Damage module
set:GetAbsorbedDamage() -- returns the amount of absorbed damage.

-- requires Fails module
set:GetFailCount(spellid) -- returns the number of fails for the given spell.

-- requires Potions module
set:GetPotion(potionid, class) -- returns the list of players for the given potion id (optional class filter)
```

#### Actors functions (_Common to both players and enemies_)

First, you would want to get the segment, then the actor. After, you will have access to a set of predefined functions:

```lua
-- After retrieving and actor like so:
local set = Skada:GetSet("current")
local actor = set:GetActor(name, guid)

-- here is the list of common functions.
actor:GetTime(active) -- returns actor's active/effective time.

actor:GetDamage(useful) -- returns actor's damage, excluding overkill if "useful" is true
actor:GetDPS(useful, active) -- returns the actor's active/effective DPS and damage amount
actor:GetDamageTargets(tbl) -- returns the actor's damage targets table.
actor:GetDamageOnTarget(name) -- returns the damage, overkill [and userful] on the given target

actor:GetOverkill() -- returns the amount of overkill

actor:GetDamageTaken() -- returns the amount of damage taken
actor:GetDTPS(active) -- returns the DTPS and the amount of damage taken
actor:GetDamageSources(tbl) -- returns the table of damage taken sources.
actor:GetDamageFromSource(name) -- returns the damage, overkill [and useful for enemies]

actor:GetHeal() -- returns the actor's heal amount.
actor:GetHPS(active) -- returns the actor's HPS and heal amount.
actor:GetHealTargets(tbl) -- returns the actor's heal targets table.
actor:GetHealOnTarget(name) -- returns the actor's heal and overheal amount on the target.

actor:GetOverheal() -- returns the actor's overheal amount.
actor:GetOHPS(active) -- returns the actor's overheal per second and overheal amount.
actor:GetOverhealTargets(tbl) -- returns the table of actor's overheal targets.
actor:GetOverhealOnTarget(name) -- returns the amount of overheal on the given target.

actor:GetTotalHeal() -- returns the actor's heal amount including overheal.
actor:GetTHPS(active) -- returns the actor's total heal per second and total heal amount.
actor:GetTotalHealTargets(tbl) -- returns the table of actor's total heal targets.
actor:GetTotalHealOnTarget(name) -- returns the total heal amount on the given target.

actor:GetAbsorb() -- returns the amount of absorbs.
actor:GetAPS(active) -- returns the absorbs per second and absorbs amount.
actor:GetAbsorbTargets(tbl) -- returns the table of actor's absorbed targets.

actor:GetAbsorbHeal() -- returns the amounts of heal and absorb combined.
actor:GetAHPS(active) -- returns the heal and absorb combined, per second and their combined amount.
actor:GetAbsorbHealTargets(tbl) -- returns the table of actor's healed and absorbed targets.
actor:GetAbsorbHealOnTarget(name) -- returns the actor's heal (including absorbs) and overheal on the target.
```

#### Players functions

First, you would want to get the segment, then the player. After, you will have access to a set of predefined functions that only work if **their modules are enabled**:

```lua
local set = Skada:GetSet("current")
local player = set:GetPlayer(UnitGUID("player"), UnitName("player")) -- get my own table

-- require Debuffs module
player:GetDebuffsTargets() -- returns the table of actor's debuffs targets.
player:GetDebuffTargets(spellid) -- returns the table of actor's given debuff targets.
player:GetDebuffsOnTarget(name) -- returns the list of actor's debuffs on the given target.

-- require CC Done, CC Taken or CC Break modules.
player:GetCCDoneTargets() -- returns the table of CC Done targets.
player:GetCCTakenSources() -- returns the table of CC Taken sources.
player:GetCCBreakTargets() -- returns the table of CC Break targets.

-- require Dispel module
player:GetDispelledSpells() -- returns the table of actor's dispelled spells.
player:GetDispelledTargets() -- returns the table of actor's dispelled targets.

-- requires Friendly Fire module
player:GetFriendlyFireTargets(tbl) -- returns the table of actor's friendly fire targets.

-- requires Healing Taken module
player:GetAbsorbHealSources(tbl) -- returns the table of actor's heal and absorb sources.

-- require Interrupts module
player:GetInterruptedSpells() -- returns the table of actor's interrupted spells.
player:GetInterruptTargets() -- returns the table of actor's interrupted targets.

-- requires Resurrects module
player:GetRessTargets() -- returns the table of actor's resurrected targets.

-- required Sunder Counter
player:GetSunderTargets() -- returns the table of actor's Sunder Armor targets.
```

#### Enemies functions

The same deal, you want first to get the segment then the enemy, after that you have access to a set of functions:

```lua
local set = Skada:GetSet("current")
local enemy = set:GetEnemy("The Lich King") -- example

-- requires: Enemy Damage Taken module
enemy:GetDamageTakenBreakdown() -- returns damage, total and useful

-- require Enemy Damage Done module
enemy:GetDamageTargetSpells(name) -- returns the table of enemy's damage spells on the target.
enemy:GetDamageSpellTargets(spellid) -- returns the targets of the enemy's given damage spell.
```

#### Extending the API

You can easily extend the API if you know the table structure of course, which will be added and explained another time:

```lua
-- To extend segments functions:
local setPrototype = Skada.setPrototype -- use the prototype
function setPrototype:MyOwnSetFunction()
  -- do your thing
end

-- to extend common functions to both players and enemies
local actorPrototype = Skada.actorPrototype
function actorPrototype:MyOwnActorFunction()
  -- do your thing
end

-- To extend players functions
local playerPrototype = Skada.playerPrototype
function playerPrototype:MyOwnPlayerFunction()
  -- do your thing
end

-- To extend enemies functions:
local enemyPrototype = Skada.enemyPrototype
function enemyPrototype:MyOwnEnemyFunction()
  -- do your thing
end
```