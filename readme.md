# Examiner

With Examiner, you can check other players' gear, gear stats, talents, runes, achievements, guild information, honor, and arena details in one convenient window. Mouseover shortcuts, gear comparisons, a searchable inspection cache, and customizable settings make inspecting players quick and easy. Available features depend on your WoW version.

## Installation

- **Automatic:** Install via [CurseForge](https://www.curseforge.com/wow/addons/examiner-classic-sod)
- **Manual:** Download the addon ZIP from [GitHub Releases](https://github.com/eusi/Examiner-SoD-/releases), extract the `Examiner` folder into your WoW client's `Interface/AddOns`. Then restart WoW and enable Examiner in **AddOns**.

## Features

- **Gear overview:** Equipped items, individual and average item levels, GearScore, and combined gear stats.
- **Inspect keybindings:** Mouseover (without selecting the player), target, and yourself; toggle Examiner.
- **3D model:** Rotate, move, zoom, and customize the background.
- **Talents:** Interactive trees and spell tooltips; Retail/Forever build exports and Wowhead links.
- **PvP:** Honor, kills, ranks, and arena/rated records; Forever rank progress.
- **Player cache:** Keep inspected gear and optional talent, PvP, and guild snapshots for later; search, filter, and sort saved players.
- **Guilds:** Guild details and crests where available.
- **SoD runes:** Equipped runes across all Season of Discovery phases.
- **Achievements:** Completion dates, points, and rewards (Retail/Mists).
- **Auto-inspect:** Follow target changes while Examiner is open.
- **Gear comparison:** Stat differences between players or individual items.
- **Customization:** Movable, scalable window; item-level, tooltip, and caching options.
- **11 translations:** enUS, deDE, frFR, esES, esMX, itIT, ptBR, koKR, ruRU, zhCN, zhTW.

Features depend on the client and available inspect data. Gear stats exclude base stats, talents, and buffs; some conditional bonuses are incomplete. Enable caching and choose which data to save in **Settings**; caching is off by default.

![Examiner screenshots](https://github.com/user-attachments/assets/8a99a3ae-c1f7-417a-a7d4-f01b86ce9cf9)

**Supported versions:** Retail, Forever, Classic Era, Hardcore, Season of Discovery, TBC Classic, and Mists of Pandaria Classic.

## Quick start

- Inspect through the player's unit menu or `/ex inspect target`.
- Assign shortcuts under **Key Bindings > Examiner**.

## Controls

- **Gear comparison:** Shift-left-click **Stats** to mark a reference; Shift-right-click to clear it.
- **Cache filters:** Shift-click **Cache**. Examples: `1-79`, `class:deathknight`, `class:hunter guild:awesome`.
- **Model:** Left-drag to rotate, right-drag to move, scroll to zoom. Ctrl-left-click changes the background; Ctrl-right-click toggles it; Shift-left-click resets the model.

## Commands

`/ex` or `/examiner` lists commands. Both prefixes work with the following:

| Command | Action |
| --- | --- |
| `/ex inspect [unit]` | Inspect `target`, `player`, `focus`, `party3`, etc. Defaults to your target, or yourself without a target. |
| `/ex si <itemLink>` | Print an item's gear stats. |
| `/ex compare <itemLink1> <itemLink2>` | Print item stat differences. |
| `/ex scale <value>` | Window scale: `0.75`–`1.50`; default `1.00`. |
| `/ex reset` | Center the window when **Make Examiner Movable** is enabled in Settings. |
| `/ex clearcache` | Delete all cached inspection data. |

## History & Credits

I took over and rebuilt Aezay's original Examiner in 2024, followed by another major overhaul in 2026, while keeping the original idea.

- Aezay, the original author of Examiner.
- Chester, the original author of SuperInspect, who gave me the idea to make this mod.
- Haldamir of Gorgonnash, for the German translation.
- Qcat0214, who made the Chinese translation for the 1.13.2 patch.
- omosiro, who made the Korean translation.
- chkid, for Korean translation update for the 1.13.2 patch.
- g3gg0, changes to the German translation & author to one of the SuperInspect versions.
- Pettigrow of Sinstralis, for the translation to French.
- Siphony of EU-Onyxia, updated German translation.
- Dridzt, for some of the required changes in the WotLK to make it function properly again.
- quicksylver, for updating the English patterns to WotLK.
- Darigaaz of SoulFlayer(RU) for the Russian translation.
- Hoofik of AshenVale for the 3.0 patch update of the Russian translation.
- Maxfunkey (aka Carambha of EU-Lordearon), patch 3.0.2 update of the German and Frensh translation.
- Thorakon (aka Pulgrim of EU-Alexstrasza), for the patch 3.0.3 update of the German translation.
- ericyen, for the Taiwan translation for the 3.1 release.
- eusi, for the updated talent module in Mists of Pandaria.
- ywfn, for making the PvP module work with all pvp and battleground changes.
- fallendos, for an update to the Korean patterns.
- Netrox, for the help in updaing the talents module for WoD.
- Cidrei, updates to the GetUpgradedItemLevel lib to fix itemLevels for Timewarped items.
- Valmere for ZG enchants and more.
- vanillalad for Details talents implementation and AQ enchant (enUS).
- All the people using Examiner!

Cheers,
sAks/eusi
