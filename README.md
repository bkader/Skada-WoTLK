# Skada for WoTLK (_Revisited - v1.8.67_)

![Discord](https://img.shields.io/discord/795698054371868743?label=discord)
![GitHub last commit](https://img.shields.io/github/last-commit/bkader/Skada-WoTLK)
![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/bkader/Skada-WoTLK?label=version)

I am simply a huge fan of **Skada**, I prefer it to other damage meters for several reasons. No need to judge me, it's after all a personal preference.

## How to install

1. If you used the default on **Skada** before, please make sure to delete all its files from `Interface\AddOns` folder as well as all its _SavedVariables_ from `WTF` folder (_just delete all `Skada.lua` and `Skada.lua.bak` for this folder. Use the search box for quick delete). If you are new, skip this step.
2. [Download the package](https://github.com/bkader/Skada-WoTLK/archive/refs/heads/main.zip).
3. Open the Zip package inside which you will find a single folder named `Skada-WoTLK-main`.
4. Extract or drag and drop the unique folder `Skada` into your `Interface\AddOns` folder.
5. If you want to use `SkadaImprovement` module, drop it there as well.

## Show Love & Support

Though it's not required, if you want to show some love and support, PayPal donations are most welcome at **bkader[at]mail.com** or @[Buy Me a Coffee](https://www.buymeacoffee.com/bkader).

## Table of content

* [What's the difference?](#whats-the-difference)
* [How to install](#how-to-install)
* [Modules](#modules)
  * [Absorbs](#absorbs)
  * [Activity](#activity)
  * [Buffs and Debuffs](#buffs-and-debuffs)
  * [CC Tracker (_Done, Taken and Breakers_)](#cc-tracker)
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
  * [Player Score](#player-score)
  * [Potions](#potions)
  * [Power gains](#power-gains)
  * [Scroll](#scroll)
  * [Spamage](#spamage)
  * [Sunder Counter (_Sunder Armor_)](#sunder-counter)
  * [Themes](#themes)
  * [Threat](#threat)

## What's the difference?

Almost everything was changed, starting from the default version that was available for **v3.3.5** of the game up to what you can see on the addon.

- It is now an **all-in-one** addon as opposed to what it was, modules can de enabled or disabled easily on the config panel.
- Data collection was simplified and reduced teremendously and modules reply on each other to function (_more explained later_).
- Several accessibility found here and there on the net and judged useful were added to the addon as modules (_window buttons, mouse & keyboard scroll, themes...etc_).
- Unlike before, windows are resizable using the resize handles found at both bottom corners.
- Bars are more fancy, colored by not only class but also spell school colors.
- Bars display icons for both players and spells (_spell tooltips as well for the latter_).

## Modules

The modules are the same you are used to see on default **Skada** but completely rewritten from the ground up to really give justice the the _combatlog_, by recording and showing everything related to it (_almost everything_).

### Absorbs

Because _WoTLK_ has no event to record the absorbs, auras priority system was used to give the best and most accurate numbers possible. It gives you access to _Absorbs_, _Absorb spells_ and _Absorb targets_.
This module has a sub-module called `Absorbs and healing` that requires both Absorbs and healing to be enabled because it collects data from both.

### Activity

Shows players activity in the raid, or what's called _Active Time_.

### Buffs and Debuffs

This module shows players buffs and their uptime, debuffs and their uptime and targets.

### CC Tracker

1. **CC Done** & **CC Taken**: unlike default ones, they now provided details info about spells used to CC and targets/sources.
2. **CC Breakers** : this was rewritten a bit, it is almost like the old one but optimized and provided like other CC modules, spell and target details.

### Damage

This module shows detailed data about damage done, giving you access to _Damage spell list_ and _Damage target list_ and has three sub-modules:

1. **DPS**: obviously, shows the dps of raid members depending on the time measurement you choose (_active or effective_) and it gives you access to the same data as its parent.
2. **Damage done by spell**: this module shows a list of all spells used in your raid with their damage and the percentage of damage to the total. Clicking on a spell gives you access to the _Damage source list_, aka list of players that used that spell.
3. **Useful damage**: a useful damage is the damage required for the target to die, anything above it is called _Overkill_, this module shows the damage done in your raid without the overkill, it means all the damage that was required for all your raid targets to reach 0 health.
4. **Overkill**: this module does the reverse of what _Useful damage_ does, it only lists players overkill with the list of their overkill spells.

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

The following modules require _Damage_ or _Damage taken_ modules to be enabled in order to work, because as said before, **Skada** no longer records duplicates and unnecessary data that can be found on other modules.

1. **Enemy damage done**: shows the list of targets that damage players during the combat with the damage they've done. Clicking on an enemy bar gives you access to the list of players that were damaged by the enemy, and clicking on a players shows you the spells used on the selected player by the selected enemy. One level deeper and you will see details about the select spell that was used on the selected player by the selected enemy.
2. **Enemy damage taken**: shows the list of enemies your party/raid members damaged during the combat with the total damage they took. Clicking on an enemy gives you access to the list of players that damage the selected enemy and clicking on a player shows you the spells that the selected player used on the selected enemy.

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

### Parry-haste

Tracks all parry-hastes caused by players in your raid with access to the targets that parried them. Note that this module only records data for bosses that actionly parry-haste.

### Player Score

A simple module that evaluates and scores the player performance in the raid, using a simple formula:
`(damagedone x fact1 + healingdone x fact2 + mitigation x fact3) / damagetaken)`. fact1-3 are mutipliers that depend on the player's role (_damager, healer or tank_).

### Potions

Tracks potions usage during an encounter. It even tracks and prints out to you **pre-potions**.

### Power gains

It records mana, range, energy and runic power gained by players (_happiness of hunter's pet is treated as energy_). Clicking a bar shows you the spells responsible for the gain.

### Scroll

It provides additional options for scrolling the bar displays. its main features are:

* Allows the middle-button to act as a scroll wheel for people missing wheel hardware (many laptops).
* Provides keybinds for scrolling the bar displays.

### Spamage

Suppresses chat messages from damage meters and provides single chat-link damage statistics in a popup. Useful if you don't spam on your chat window.

### Sunder Counter

Counts and shows the _Sunder Armor_ usage by warriors.

### Themes

It allows you to create themes that you can use if you want to change windows look. Themes can be created, applied and deleted (_probably Shared as well in the future if I don't forget to add it_).

### Threat

I think you already know what this module is used for, so no need to talk more about it. Oh and yes! You can use it instead of Omen or use both, it's up to you and it's a matter of personal preferences.