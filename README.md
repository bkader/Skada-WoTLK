# Skada Revisited

I am simply a huge fan of **Skada**, I prefer it to other damage meters for several reasons. No need to judge me, it's after all a perfonal preference.

## What's new?

Lots of things were changed, the version for **3.3.5** that you all know is no longer the same. Everything works the same but with much more details and way better performance.

## Core Modifications

* No more several addons aka modules to enable or disable, everything is within a single addon.
* Data collection was tweaked in a way to save memory and to avoid double writting but instead single time writting and each module manipulates the data the way it needs to present it.
* Added windows buttons just like recount: Reset, Segments, Modes and Report.
* Added the possibility to scroll holding the mouse wheel or by key binding up and down scrolling.
* The tooltip is now smart and positions itself depending on the window position.
* No more Bar display background, no struggle with the window height and width. Resize it on-the-go.
* Added class icons, role icons, clicthrough and bar smoothing (aka animating).
* Lots of other settings were added, explore it and compare it to the default one you were using.

## Modules Modifications

* The Absorbs and healing was slightly tweaked to show details log.
* Debuff uptime was completely changed and now it tracks both buffs (or procs) and debuffs, with much more details!
* Added a CC Tracker module containig: the old CC Breakers (untouched), CC Done and CC Taken.
* All damage module were completely rewritten for more fexibility and details but names kept the same to not confuse Skada users.
* Added a Damage done by spell module, useful to see which spell did the most damage for the selected segment or total.
* Added a Friendly Fire module, its name says what it does.
* Added a Avoidance & Mitigation, useful for tanks and shows how many hits were dodged, blocked, parried...etc
* The Deaths module was completely rewritten and now it keeps track of all deaths and keeps all death logs. Skada's default behavior is to wipe the log after the player is resurrected.
* The Dispels module was completely rewritten and now shows what was dispelled, what was used to dispel, targets and sources.
* The Failbot was changed too and now stores proper data and presents proper fail event names.
* Added an Improvement module that stores all your bosses fights with overall details, useful to compare yourself to yourself instead of comparing to others. The data is stored per character for this one.
* The Interrupts module was changed as well and just like the Dispels one, shows who interrupted, what was interrupted and what spells was used to interrupt.
* Added a new module called Power, it keeps track of power gain per encounter: mana, rage, energy and runic power.
* Added a Resurrects module to track battle resurrects during encouters. Same, who res'd who, what spell was used, on who and how many times.

## Themes Module

It is now possible to use default provided themes or simply make your own.
All you have to do is to style the window and bars the way the want it, save the theme and voilà!

## IMPORTANT: How to install

It is important to know that for most addons to properly function without issues, if to have a clean installation. If you don't proceed to a clean installation, there is a huge change that you will run into issues and errors that people who installed it the first time won't encouter ever. So, please, if you want to use it and you were at certain point using default Skada, follow the steps below:

1. Delete old Skada addon and modules: All folders which the name starts with Skada within the `InterFace\AddOns` folder must be deleted.
2. Navigate to `WTF\Account` folder, use the search box on top right and search for "Skada". Select all files and delete them.
3. Download the repository package and extract to `Interface\AddOns`. Please keep everything with the default folder inside the package.
4. Rename the folder to **Skada**.
5. Start the game, enable the addon, change the settings the way you want them to be and enjoy!
