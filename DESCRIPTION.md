**Nullgate's Blessings** is a paladin addon for **World of Warcraft: Forever** that works out who should give which blessing to whom. It checks the blessings every player already has, skips any that another paladin has already given, and moves on to that player's next choice.

When two or more paladins run the addon, they all reach the same plan automatically. No more "I'll do Might on the rogues, you do Kings" before every pull.

> **Beta:** this is an early test version and we're looking for paladins to try it, ideally in groups with more than one paladin. If something doesn't work, run `/nbless check`, then send us the results with a short description.

---

## Features

- **Smart assignments**: every player has a recommended list of blessings for their class and spec, best first, every paladin has leanings based on their talents, and the addon picks the best combination so nobody gets the same blessing twice.
- **Reads what's already there**: if another paladin has given the rogue Might, your button for that rogue picks Kings instead. This works even when the other paladin doesn't use the addon.
- **Keeps what you've already given**: a blessing you or another paladin running the addon already has on a player stays as it is, unless it clashes with someone else's or a lock says otherwise.
- **A compact list**: one row per party member with the blessing it will cast, their name, a bar for the time left on yours and the timer. Click a row to cast. The list hides while every blessing is fresh.
- **Top Up**: refreshes every blessing of yours with less than 10 minutes left, one per press, so nothing drops in the middle of a fight.
- **Smart macro**: one action-bar button that casts the right blessing on your friendly target (your planned one, or the best one they're missing), or tops up your group when you have no friendly target. Made with `/nbless macro` or from the settings, and kept up to date out of combat.
- **Greater Blessings in raids**: one row per class.
- **Lists by spec**: a Feral druid gets Kings and Might, a Balance druid Wisdom and Kings, an Enhancement shaman Might first. The addon learns specs by inspecting nearby group members out of combat and shares them with the other paladins; until a spec is known, the group role is used.
- **Edit the lists**: change the order for any class or spec in the settings. In a group, the leader's lists are used, so every paladin plans the same way.
- **Tank detection** from role selection, the raid's Main Tank and Protection talents, with your own marking on top. Tanks never get Salvation.
- **Locks**: "Bob always gets Salvation from me", or leader locks for the whole group. Everyone else plans around them.
- **Aura assignments**, an optional announcement to group chat, and a warning when your Symbol of Kings run low.
- **Key bindings** under Key Bindings > AddOns.
- **Simple settings**: wish lists, your leanings, warnings, layout and the language.

---

## How It Works

Example: a Protection paladin tanking and a Holy paladin healing, with a rogue, a mage and a hunter.

| Player | Protection gives | Holy gives |
| :--- | :--- | :--- |
| Rogue | Might | Kings |
| Mage | Kings | Wisdom |
| Hunter | Kings | Wisdom |
| Protection paladin | Kings | Wisdom |
| Holy paladin | Kings | Wisdom |

Neither paladin has to plan anything. If one of them doesn't know Kings, or a third paladin joins, the plan adjusts by itself.

Blessings and Greater Blessings last one hour in Forever, and the addon uses the real durations from the game.

The game doesn't allow buttons to change during combat. If the plan changes mid-fight, the list updates as soon as combat ends.

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
| `/nbless check` | Test what the addon needs in your game client and save the results (for bug reports). |

---

## Installation

1. Download the latest file.
2. Extract the `NullgatesBlessings-Forever` folder into the `Interface\AddOns` folder of your World of Warcraft: Forever installation.
3. Log in on a paladin and join a group. Type `/nbless` to see the plan.

---

## Good to Know

- The addon only runs for paladins.
- Paladins share their plan through hidden addon messages, not chat.
- Available in 10 languages: English, Deutsch, Español, Français, Italiano, Português (Brasil), Русский, 한국어, 简体中文 and 繁體中文 (every language the game client runs in). The game's language is used automatically, and you can pick another in the settings. The translations were made with machine assistance; corrections are welcome.
