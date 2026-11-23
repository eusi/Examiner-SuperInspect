# Examiner changelog

Changes to sAks/eusi's Examiner (SuperInspect) fork, newest first.

Development lineage: **Aezay's original Examiner → taxidriveer's Classic fork (2019) → sAks/eusi's SoD fork (2024), later expanded across WoW clients**. sAks/eusi occasionally helped before taking over in 2024. The entries below trace the additions in this fork back to its predecessors.

## [1.12.0](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v1.12.0) — 2026-11-23

- Added a zoomable chest and saved inspection time to cached profiles.
- Fixed PvP icons to match the inspected character's faction.
- Fixed surnames appearing as realms on Forever.
- Inspect Target now closes the window when pressed again.
- Added optional gamepad B/Circle support to close the window.

## [1.11.0](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v1.11.0) — 2026-11-21

- Renamed Modern to Flat and added a Dark style with dark grey textures and a greyscale character background.
- Added a live name search to Cached Players.
- Support friend invitations by name without a current target; hide unavailable friend actions.
- Fixed the own guild's member count.
- Kept native fonts in player action tooltips to avoid missing characters in names.
- Fixed a Retail error when opening the Achievements tab.
- Fixed the short mana-regeneration label and removed duplicate Defense rows.

## [1.10.0](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v1.10.0) — 2026-11-18

- Added a button to open a whisper to the inspected player.
- Added a button to invite the inspected player to your group.
- Added a button to add the inspected player to your friends list.
- Cached gear now loads missing item details automatically.
- Small UI fixes.
- Fixed a blocked interaction-distance call when showing item tooltips during combat.

## [1.9.0](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v1.9.0) — 2026-11-15

- Added a dedicated Examiner category in WoW keybinding settings.
- Added an active specialization icon on the Talents tab.
- Fixed stale specialization data and NPC model viewing when player identity data is restricted.

## [1.8.0](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v1.8.0) — 2026-11-12

- The self-inspect keybinding now toggles the window.
- Expanded Gear List to a compact, full-width layout with item-level and GearScore summaries.
- Improved Forever gear stats and stat categories.

## [1.7.0](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v1.7.0) — 2026-11-09

- Added Modern and Forever window styles alongside Classic.
- Added bottom and side icon menus, independent style and menu settings, and a portrait class badge.
- Added the optional Gear List module for equipped items and enhancement details.

## [1.6.0](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v1.6.0) — 2026-11-07

- Added Forever profession progress bars and PvP rank-point caps.
- Updated dual-specialization talent inspection.
- Fixed Forever Wowhead talent links.

## [1.5.0](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v1.5.0) — 2026-11-05

- Added profession inspection and optional profession caching for Forever.
- Expanded the Settings scroll area and improved Stats layout and scrolling.
- Improved menu tooltips and added a right-click hint to Classic talent tooltips.
- Fixed module-tab right-click menus.

## [1.4.0](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v1.4.0) — 2026-11-04

- Added Mists Classic glyph inspection.
- Added a choice between calculated and Blizzard average item levels.
- Added font selection with LibSharedMedia support.
- Localized addon descriptions and fixed Mists Classic issues.

## [1.3.0](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v1.3.0) — 2026-11-01

- Added settings to enable or disable optional modules and tabs.
- Improved module tooltips.

## [1.2.0](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v1.2.0) — 2026-10-29

- Added Italian, Brazilian Portuguese and Latin American Spanish translations, bringing the total to eleven.

## [1.0.1](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v1.01) — 2026-10-26

- Added an inspect-yourself keybinding.
- Improved Forever PvP ranks, window scaling, tooltips and translations.

## [1.0.0](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v1.00) — 2026-10-22

- Updated client compatibility for Retail, Forever, Classic Era, Hardcore, Season of Discovery, TBC Classic and Mists Classic.
- Reworked talent and PvP views, including Forever talent trees and supported build exports.
- Improved equipment inspection, gear-stat comparisons, guild information and cached player profiles.
- Added achievement comparisons for Retail and Mists Classic.
- Improved inspection loading, delayed replies, settings and translations.

## [0.98](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.98) — 2025-06-24

- Fixed GearScore integration with LibFroznFunctions.

## [0.97](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.97) — 2025-06-14

- Fixed the settings dropdown background and mouseover keybinding.
- Improved keybinding names.

## [0.96](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.96) — 2025-06-07

- Added expertise and spell-haste stats.
- Fixed Sanctified equipment counting.

## [0.95](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.95) — 2025-05-24

- Added Sanctified item counts and additional localized stat patterns.
- Fixed SoD critical-strike, hit and haste values.
- Updated LibFroznFunctions to fix GearScore colors and improved stat labels and ordering.

## [0.94](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.94) — 2025-04-24

- Made the window movable by default.
- Fixed rune-tab availability.

## [0.93](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.93) — 2025-04-22

- Added GearScore calculation with LibFroznFunctions and score quality colors.
- Split spell power into spell damage and healing stats.

## [0.91](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.91) — 2025-04-07

- Fixed minor issues following the SoD Phase 7 update.

## [0.9](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.9) — 2025-04-04

- Updated SoD runes and translations and fixed minor issues.

## [0.8](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.8) — 2025-04-03

- Updated SoD Phase 7 runes and dual-specialization support.
- Fixed Phase 7 talent inspection.

## [0.7](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.7) — 2024-02-24

- Fixed minor SoD issues, including incorrect rune and enchant recognition.

## [0.6](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.6) — 2024-02-14

- Added SoD Phase 2 runes and fixed related issues.

## [0.5](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.5) — 2024-02-08

- Added average-item-level calculation.
- Removed rune information from the Stats page.

## [0.4](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.4) — 2024-02-08

- Reworked the Runes page with LibRunes integration and localized Phase 1 rune data.
- Fixed the Talents page.

## [0.3](https://github.com/eusi/Examiner-SuperInspect/releases/tag/v0.3) — 2024-02-01

- Added a dedicated Runes page for Season of Discovery.
- Fixed PvP self-inspection.

## [SoD fork — sAks/eusi](https://github.com/eusi/Examiner-SuperInspect/commit/d3a62b0) — 2024-01-29

- Continued taxidriveer's Classic fork and adapted Examiner for Season of Discovery.

## [Classic Fan Update — taxidriveer](https://github.com/taxidriveer/Examiner/commit/3d969d607bbf52f5cc4999a9103e1f9fe6c61013) — 2019-09-23

- Adapted Aezay's Examiner for WoW Classic.

## [Original Examiner — Aezay](https://www.wowinterface.com/downloads/info7377.html) — 2007-05-31

- Created the original addon for equipment inspection, combined gear stats and player caching.
- This date is the earliest entry in Aezay's published changelog.

[README](README.md) · [GitHub Releases](https://github.com/eusi/Examiner-SuperInspect/releases)
