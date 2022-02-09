# Skada for WoTLK (_Revisited - v1.8.73.357_)

![Discord](https://img.shields.io/discord/795698054371868743?label=discord)
![GitHub last commit](https://img.shields.io/github/last-commit/bkader/Skada-WoTLK)
![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/bkader/Skada-WoTLK?label=version)

Skada is a modular damage meter with various viewing modes, segmented fights and customizable windows. It aims to be highly efficient with memory and CPU.

<p align="center"><img src="https://repository-images.githubusercontent.com/306277951/dcdd501d-57be-43cb-81d5-c791c0b255a3" alt="Skada WotLK"></p>

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
local set = Skada:GetSet("current") -- gets the current segment table.
-- then you have access to the following functions:
set:GetLabel() -- returns the formatted set name
set:GetTime() -- returns the segment time or combat time
set:GetFormatedTime() -- returns the formatted segment time in HH:MM:SS

set:GetPlayer(guid, name) -- retrieves a player's table
set:GetEnemy(name, guid) -- retrieves an enemy table
set:GetActor(name, guid) -- retrieves a player or an enemy

set:GetAPS() -- returns the amount of Absorbs per second APS
set:GetHeal() -- returns the amount of heal
set:GetAbsorbHeal() -- returns the amount of absorbs?
set:GetAHPS() -- returns the amounts of absorbs and heals combined.
set:GetHPS() -- returns the amount of heal per second
set:GetDPS(useful) -- returns the group DPS amount. useful: exclude the overkill
set:GetOHPS() -- returns the amount of overheal
set:GetTHPS() -- returns the total healing, including the overheal
set:GetDTPS() -- returns the amount of damage taken per second by the whole group.

set:GetActorTime(id, name, active) -- return the actor's time.
set:GetAbsorbHealSpells() -- returns the table of both absorb heals spells.
set:GetAuraPlayers(spellid) -- returns the list of players by the given buff id.
set:GetActorDamage(id, name) -- returns the actor's damage.
set:GetActorDamageSpells(id, name) -- returns the actor's spell table if found.
set:GetActorDamageTargets(id, name, tbl) -- returns the actor's damage targets table with options cache table.
set:GetDamage(useful) -- returns the damage amount. if "useful" is true, it excludes the overkill.
set:GetDamageTaken() -- returns the amount of damage taken by the whole group.
set:GetFailCount(spellid) -- returns the number of fails per give spell id
set:GetAbsorbHealTaken() -- returns the table of players their healing taken amounts.
set:GetPotion(potionid) -- returns the list of players and total usage of the give potion id

set:GetEnemyDamageTaken() -- returns the amount of damage enemies took.
set:GetEnemyDamage() -- returns the amount of damage enemies dealt to your group.
set:GetEnemyDPS() -- returns total dps and damage amount of all enemies.
set:GetEnemyHeal() -- returns the amount of heal enemies did.
set:GetEnemyHPS() -- returns the total hps and heal amount of all enemies.
```

#### Players functions

First, you would want to get the segment, then the player. After, you will have access to a set of predefined functions that only work if their modules are enabled:

```lua
local set = Skada:GetSet("current")
local player = set:GetPlayer(UnitGUID("player"), UnitName("player")) -- get my own table

-- now to functions:
player:GetTime(active) -- returns the player time if active is set to true, otherwise the combat time.
player:GetAPS(active) -- returns the amount of absorbs the player did per second
player:GetAbsorbTargets() -- returns the list of players the player shieled and absorbed.
player:GetAbsorbHeal() -- returns the amount of absorbs and heals the player did.
player:GetAHPS() -- returns the amount of absorb+heal per second.
player:GetAbsorbHealTargets() -- returns the list of absorb and heal targets.
player:GetAbsorbHealOnTarget(name) -- returns the amount of absorb and heal the player did on the given target.
player:GetDebuffsTargets() -- returns the list of the player's debuffs targets.
player:GetDebuffTargets(spellid) -- returns the list of the given debuff targets.
player:GetDebuffsOnTarget(name) -- returns the list of debuffs applied on the given target.
player:GetCCDoneTargets() -- returns the list of targets the player CC'd.
player:GetCCTakenSources() -- returns the list of sources the player got CC'd from.
player:GetCCBreakTargets() -- returns the list of CC break targets.
player:GetDamage(useful) -- returns the amount of damage the player did. usef: excludes the overkill.
player:GetDPS(useful, active) -- returns the dps and amount of damage the player did.
player:GetDamageTargets() -- returns the list of the player's damage targets and their amounts table.
player:GetDamageTaken() -- returns the amount of the damage taken by the player
player:GetDTPS(active) -- returns the damage taken per second as well as the total amount
player:GetDamageSources() -- returns the list of sources the player took damage from with their amounts table.
player:GetDispelledSpells() -- returns the list of spells the player dispelled.
player:GetDispelledTargets() -- returns the list of targets the player dispelled.
player:GetFriendlyFireTargets() -- returns the list of players the player caused friendly fire to.
player:GetHPS(active) -- returns the amount of healing per second.
player:GetOHPS(active) -- returns the amount of overhaling per second.
player:GetHealTargets() -- returns the list of targets the player healed.
player:GetHealOnTarget(name) -- returns the amount of healing the player did on the given target.
player:GetOverhealTargets() -- returns the list of targets the player overhealed.
player:GetOverhealOnTarget(name) -- returns the amount of overhealing the player did on the given target.
player:GetTHPS(active) -- returns the amount of healing+overhealing per second.
player:GetTotalHealTargets() -- returns the list of targets the player healed and overhealed.
player:GetTotalHealOnTarget(name) -- returns the amount of healing and overhealing combined on the given target.
player:GetAbsorbHealSources() -- returns the list of players the player was healed by.
player:GetInterruptedSpells() -- returns the list of spells the player interrupted.
player:GetInterruptTargets() -- returns the list of targets the player interrupted.
player:GetRessTargets() -- returns the list of targets the player resurrected.
player:GetSunderTargets() -- returns the list of targets the player applied Sunder Armor to.
```

#### Enemies functions

The same deal, you want first to get the segment then the enemy, after that you have access to a set of functions:

```lua
local set = Skada:GetSet("current")
local enemy = set:GetEnemy("The Lich King") -- example

-- functions:
enemy:GetTime() -- simply returns the combat time
enemy:GetDamageTaken() -- returns the amount of damage the enemy took
enemy:GetDamageTakenBreakdown() -- returns the amount, total and useful damage taken by the enemy.
enemy:GetDTPS() -- returns the amount of damage the enemy took per second.
enemy:GetDamageSources() -- returns the list of players who damaged the enemy and their amounts table.
enemy:GetDamageFromSource(name) -- returns the amount, total and useful damage the given name did on the enemy.
enemy:GetDamage() -- returns the amount of damage the enemy did.
enemy:GetDPS() -- returns the enemy DPS.
enemy:GetDamageTargets() -- returns the list of players the enemy did damage to.
enemy:GetDamageOnTarget(name) -- returns the amount of damage the enemy did to the given player.
enemy:GetHPS() -- returns the amount healing per second the enemy did.
enemy:GetHealTargets() -- returns the list of targets the enemy healed.
enemy:GetHealOnTarget() -- returns the amount of heal on the give target.
```

#### Extending the API

You can easily extend the API if you know the table structure of course, which will be added and explain another time:

```lua
-- To extend segments functions:
local setPrototype = Skada.setPrototype -- use the prototype
function setPrototype:MyOwnSetFunction()
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