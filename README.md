# Nullgate's Blessings - Forever

> **Status: planning.** No code yet. See [PLAN.md](PLAN.md).

**Nullgate's Blessings** is a paladin addon for **World of Warcraft: Forever** that works out who should give which blessing to whom. It checks the blessings every player already has, skips any another paladin has already given, and moves to that player's next choice. Paladins running the addon reach the same plan automatically, with no chat needed.

---

## How It Works

- **Every player has a wish list** by class and role: a rogue wants Might, then Kings, then Salvation; a mage wants Wisdom, then Kings.
- **Every paladin has leanings** suggested by their talents: Protection leans Might and Kings, Holy leans Wisdom and Kings. You can change your own.
- **The addon reads what's already there.** If another paladin has given the rogue Might, your button for that rogue picks Kings instead. Paladins without the addon are handled from what they actually cast.
- **No two paladins give the same blessing to the same player**, and nobody is given a blessing their paladins don't know.

Example: a Protection and a Holy paladin in a dungeon. The rogue gets Might from the Protection paladin and Kings from the Holy paladin. The mage gets Kings from the Protection paladin and Wisdom from the Holy paladin. Neither of you has to plan it.

---

## Features

- **Smart assignments** from wish lists, leanings and the blessings already on each player.
- **Party buttons**: one per party member, showing the blessing it will cast and the time left on yours.
- **Top Up** button that refreshes every blessing of yours with under 10 minutes left, one per press, before a pull.
- **Greater Blessing buttons** per class in raids.
- **Tank detection** from role selection and the raid's Main Tank, with your own marking on top. Tanks never get Salvation.
- **Locks**: "Bob always gets Salvation from me", or leader locks for the whole group.
- **Aura assignments**, an optional announcement to group chat, and a Symbol of Kings warning.
- **Settings** in its own window or inside Nullgate's Addon Config.

Blessings and Greater Blessings both last one hour in Forever. Every duration comes from the Forever client.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/nbless` or `/blessings` | Open the assignments and settings. |
| `/nbless announce` | Post the current assignments to group chat. |
| `/nbless lock` / `/nbless unlock` | Lock or unlock the bar. |
| `/nbless reset` | Reset the bar's position. |
| `/nbless check` | Test what the addon needs in your game client and save the results. |

---

## Installation

Not released yet. Once it is:

1. Download the latest release from CurseForge or the GitHub releases page.
2. Extract the `NullgatesBlessings-Forever` folder into the `Interface\AddOns` folder of your World of Warcraft: Forever installation.
3. Log in on a paladin and type `/nbless`.

---

## Part of the Nullgate Addon Suite

- **Nullgate's Addon Config**: one settings hub and profile manager for the whole suite.
- **Nullgate's Raid Buffs**, **Cooldowns**, **Restock**, **Quest Tracker** and more.

---

## License

Source-available, all rights reserved. See [LICENSE.md](LICENSE.md).
