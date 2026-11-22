# Changelog

All notable changes to Nullgate's Blessings - Forever.

## [1.0.0-beta.3] - 2026-11-21

### Fixed

- No more "Auras cannot be accessed when secret" error. While the game hides a player's buffs from addons, usually in combat, the addon keeps using what it last saw on them, with the timers counting down.

## [1.0.0-beta.2] - 2026-11-21

### Fixed

- No more error when the game hides a group member's range from addons ("attempt to perform boolean test on local 'checked'"). That player is treated as in range.
- Blessings the game hides from addons, usually in combat, are skipped instead of causing an error.

## [1.0.0-beta.1] - 2026-11-20

First test version, looking for paladins to try it, ideally in groups with more than one paladin.

### New

- **Smart assignments**: every player has a wish list by class and role, every paladin has leanings from their talents (you can change yours), and the addon picks the best combination so no player gets the same blessing twice and nobody is given a blessing their paladin doesn't know.
- **Reads what's already there**: a blessing on a player from a paladin without the addon is left alone, and that player's next wish is planned instead.
- **Paladins running the addon agree automatically**: they share their blessings, leanings, tank marks and locks through hidden addon messages, and every copy computes the same plan.
- **Party buttons**: one per party member, casting the blessing you're assigned at the highest rank they can receive, with the time left on yours. Red when it's missing or under 5 minutes.
- **Top Up**: casts on whoever's blessing from you is missing, then whoever's is lowest under 10 minutes.
- **Raids**: Greater Blessings planned per class, with a button per class and a Symbol of Kings warning.
- **Tank detection** from role selection and the raid's Main Tank, plus a Protection talent guess for yourself, with `/nbless tank <name>` to mark a tank or not-a-tank. Tanks never get Salvation.
- **Plan window**: every paladin's blessings at a glance. Click a cell in your row to lock it; the group leader or an assistant can lock any cell.
- **Auras**: each paladin gets a different aura, with a button for yours.
- **Announce** the plan to group chat.
- Blessings and Greater Blessings last one hour in Forever; every rank and duration is read from the client data.
- **Settings** in its own window or inside Nullgate's Addon Config, and **`/nbless check`** for bug reports.
- Available in English, Deutsch, Español, Français, Italiano, Português (Brasil), Русский, 한국어, 简体中文 and 繁體中文.

### Good to know

- Buttons can't change during combat. If the plan changes mid-fight, the buttons update as soon as combat ends.
- In raids, Mass Salvation also reaches tanks of that class; they can cancel it.
