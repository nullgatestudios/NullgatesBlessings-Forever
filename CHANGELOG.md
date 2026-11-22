# Changelog

All notable changes to Nullgate's Blessings - Forever.

## [1.0.0-beta.9] - 2026-11-21

### New

- **Oath of Light on the tank.** If you have the Oath of Light talent, the bar gets a row for it on the marked tank, with the time left. Top Up casts the Oath first when it's missing or has under a minute left, then goes back to blessings. The smart macro does the same, both on your target and for Top Up. If your Oath is already on one of the tanks, it stays there.

### Changed

- **Blessing of Light and Salvation are gone from Forever** (client 1.60.1.71037), so the addon no longer plans them or offers them in the settings and the plan window. Might, Wisdom and Kings work as before.

### Good to know

- The tank is whoever is marked tank: by role, the raid's Main Tank, Protection talents or your own marking. You never get your own Oath.

## [1.0.0-beta.8] - 2026-11-21

### New

- **Smart macro.** Type `/nbless macro` (or use the button in the settings) to make a character macro called NGBless and put it on your cursor; drop it on an action bar. It casts the right blessing on your friendly target: your planned one when they're in your plan (the Greater Blessing for their class in a raid), or for anyone else the best one from their class list that they don't already have. With no friendly target, it tops up whoever in your group needs it next. It shows the blessing's icon, range and cooldown like any spell.

### Good to know

- The game doesn't let addons change macros during combat, so in combat the macro keeps the blessing it had and catches up when combat ends.

## [1.0.0-beta.7] - 2026-11-21

### Changed

- **Dropdowns in the settings.** The blessing list, each choice in it, your leanings and the language are now picked from dropdowns instead of clicking through every option. Picking a blessing that's already in the list swaps the two.

## [1.0.0-beta.6] - 2026-11-21

### New

- **Blessing lists by spec.** Every class and spec has a recommended list, best first. For example, a rogue gets Might, Kings, Salvation, Light; a priest Wisdom, Kings, Salvation, Light; a Feral druid Kings, Might, Salvation, Light; and an Enhancement shaman Might, Kings, Wisdom, Salvation. When a player already has their first choice from someone else, they get their next one, and Top Up casts that.
- **Specs are learned by inspecting.** Out of combat, the addon inspects one nearby warrior, druid, shaman or paladin at a time, and shares what it learns with the other paladins running the addon. Until a player's spec is known, their group role is used.
- **Edit the lists** in the settings under Blessing lists: pick a list, then click each choice to change it. Right-click the list name to go back. In a group, the leader's lists are used, or the first paladin's by name, so every paladin plans the same way.
- Protection warriors and paladins are treated as tanks once their spec is known.

### Good to know

- The addon doesn't inspect while you have the inspect window open, and never in combat.
- `/nbless check` now shows each player's spec and list, and whose lists the group is using.

## [1.0.0-beta.5] - 2026-11-21

### Changed

- **The aura button only shows while your assigned aura is off.** Once it's on, the button goes away (in combat it fades instead, and goes away when combat ends). If your aura drops, for example after dying, the button and the list come back.

## [1.0.0-beta.4] - 2026-11-21

### Changed

- **The bar is now a list.** Top Up sits on top in gold and names who it will bless next, with your aura beside it. Below it, one row per party member (or class in a raid): the blessing it will cast, their full name in class colour, a bar for the time left on yours and the timer.
- **The list hides while every blessing is fresh** and comes back when one of yours is missing or under the warning time. You can turn this off in the settings; it always shows while unlocked so you can move it. This replaces the "stack the buttons vertically" setting.
- **Blessings already given are kept.** If you or another paladin running the addon already has a blessing on a player, the plan keeps it instead of asking for a switch, unless it clashes with someone else's blessing, isn't on that player's list or a lock says otherwise.

### Fixed

- No more red marks on the buttons during combat. The tooltip still says when the list is waiting for combat to end.

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
