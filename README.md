# Nullgate's Blessings - Forever

> **Status: beta** (1.0.0-beta.8). Looking for paladins to test it, ideally groups with more than one. See [CHANGELOG.md](CHANGELOG.md).

**Nullgate's Blessings** is a paladin addon for **World of Warcraft: Forever** that works out who should give which blessing to whom. It checks the blessings every player already has, skips any another paladin has already given, and moves to that player's next choice. Paladins running the addon reach the same plan automatically, with no chat needed.

---

## How It Works

- **Every player has a wish list** by class and spec: a rogue wants Might, then Kings; a mage wants Wisdom, then Kings; a Feral druid Kings, then Might.
- **Every paladin has leanings** suggested by their talents: Protection leans Might and Kings, Holy leans Wisdom and Kings. You can change your own.
- **The addon reads what's already there.** If another paladin has given the rogue Might, your button for that rogue picks Kings instead. Paladins without the addon are handled from what they actually cast.
- **No two paladins give the same blessing to the same player**, and nobody is given a blessing their paladins don't know.

Example: a Protection and a Holy paladin in a dungeon. The rogue gets Might from the Protection paladin and Kings from the Holy paladin. The mage gets Kings from the Protection paladin and Wisdom from the Holy paladin. Neither of you has to plan it.

---

## Features

- **Smart assignments** from wish lists, leanings and the blessings already on each player.
- **Keeps what you've already given**: a blessing you or another paladin running the addon already has on a player stays as it is, unless it clashes with someone else's or a lock says otherwise.
- **A compact list**: one row per party member with the blessing, their name, a bar for the time left on yours and the timer. Hides while every blessing is fresh.
- **Top Up** row that refreshes every blessing of yours with under 10 minutes left, one per press, before a pull.
- **Smart macro**: one action-bar button that casts the right blessing on your friendly target (your planned one, or the best one they're missing), or tops up your group when you have no friendly target. Made with `/nbless macro` or from the settings, and kept up to date out of combat.
- **Greater Blessings** in raids, one row per class.
- **Lists by spec**: a Feral druid gets Kings and Might, a Balance druid Wisdom and Kings, an Enhancement shaman Might first. The addon learns specs by inspecting nearby group members out of combat and shares them with the other paladins; until a spec is known, the group role is used.
- **Edit the lists**: change the order for any class or spec in the settings. In a group, the leader's lists are used, so every paladin plans the same way.
- **Oath of Light** on the marked tank (or your focus) when you have the talent, with its own row. Top Up refreshes it first when it has under a minute left.
- **Tank detection** from role selection, the raid's Main Tank and Protection talents, with your own marking on top.
- **Locks**: "Bob always gets Kings from me", or leader locks for the whole group.
- **Aura assignments**, an optional announcement to group chat, and a Symbol of Kings warning.
- **Settings** in its own window or inside Nullgate's Addon Config.

Blessings and Greater Blessings both last one hour in Forever. Every duration comes from the Forever client.

---

## Slash Commands

| Command | Action |
| :--- | :--- |
| `/nbless` or `/blessings` | Show or hide the blessing plan. |
| `/nbless tank <name>` | Mark a player as a tank, not a tank, or back to automatic (or target them and leave out the name). |
| `/nbless config` | Open the settings. |
| `/nbless announce` | Post the current assignments to group chat. |
| `/nbless macro` | Make the smart blessing macro and put it on your cursor. |
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

## Development

| Task | Command |
| :--- | :--- |
| Refresh the blessing data after a client patch | `python tools/generate_blessing_data.py` (reads the latest Forever build from wago.tools) |
| Run the tests | `lua tests/run.lua`, `lua tests/smoke.lua` and `lua tests/locales.lua` |
| Build `zips/NullgatesBlessings-Forever-<version>.zip` | `.\package.ps1` (or `.\package.ps1 -Version 1.0.0` to set the version first) |

Publishing a GitHub release uploads that version to CurseForge (`.github/workflows/curseforge.yml`); pushes only run the tests.

---

## License

Source-available, all rights reserved. See [LICENSE.md](LICENSE.md).
