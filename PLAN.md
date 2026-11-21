# Nullgate's Blessings - Forever: Plan

Status: phases 0 to 4 built as 1.0.0-beta.1 on 2026-11-20; the in-game checks wait for testers (`/nbless check`). Planned on 2026-11-20.

Built notes: wish lists are fixed in 1.0 (not settings) so every copy of the addon computes the same plan; tank marks (including "not a tank") are shared with the other paladins; Top Up covers missing blessings first, so there's no separate Bless Next button; in raids, Greater Blessings are planned per class and tanks are not excluded from Mass Salvation.

- **Folder:** `NullgatesBlessings-Forever`
- **Saved variables:** `NullgatesBlessingsDB` (per character)
- **Commands:** `/nbless` and `/blessings`

## Decisions made

- Paladin only: the addon stays off for other classes.
- **Smart assignment is the default.** It always checks what blessings each player already has and moves to their next choice. The leader grid only locks cells.
- **Tanks are detected, with hand-marking on top**: role selection first, then the raid's Main Tank, then a talent guess for paladins running the addon. A player's own marking always wins.
- PallyPower compatibility is not in 1.0; paladins without this addon are handled from the blessings they actually cast.
- Each paladin sets their own leanings and locks; locking other paladins' cells is leader and assistant only.
- Blessing data is generated from Forever client data (wago.tools), never typed by hand.
- Ships as 1.0.0-beta.1 for testers.

## Forever blessings (client build 1.60.1.70532)

| Blessing | Ranks (level) | Forever | Classic |
| :--- | :--- | :--- | :--- |
| Might | 7 (4 to 60) | 60 min | 5 min |
| Wisdom | 6 (14 to 60) | 60 min | 5 min |
| Kings | 1 (20) | 60 min | 5 min |
| Light | 3 (40, 50, 60) | 60 min | 5 min |
| Salvation (renamed from Blessing of Salvation) | 1 (26) | 60 min | 5 min |
| Greater Might / Wisdom | 2 each (52 or 54, 60) | 60 min | 15 min |
| Greater Kings / Light | 1 each (60) | 60 min | 15 min |
| Mass Salvation (renamed from Greater Salvation) | 1 (60) | 60 min | 15 min |
| Sanctuary | removed | | |

## The assignment engine

Every copy of the addon computes the whole group's plan from the same inputs and rules, so all paladins agree without negotiating.

**Inputs**

1. **Wish lists** per class and role (fixed so every copy agrees):
   - Rogue, Warrior: Might, Kings, Salvation, Light
   - Mage, Priest, Warlock: Wisdom, Kings, Salvation
   - Hunter: Kings, Wisdom, Salvation (Might doesn't raise ranged attack power)
   - Paladin, Druid, Shaman: by role
   - Tanks: Kings, Light, Wisdom; never Salvation
2. **Paladin leanings** (each paladin can change their own). Talent-based defaults:
   - Protection: Might, Kings
   - Holy: Wisdom, Kings, Light
   - Retribution: Might, Kings, Wisdom
3. **Blessings already on each player**, with who cast them. A blessing from a paladin without the addon is fixed and taken. Your own blessing never counts as taken.
4. **Locks** from paladins and the leader.

**Rules**

- One blessing per paladin per player, no duplicates between paladins.
- Only blessings that paladin knows (Kings is a talent).
- Choose the combination that gives each player their highest-wished blessings, then break ties by paladin leanings, then by paladin name. Up to four paladins and six blessings is at most 360 combinations per player, checked exhaustively.
- Recompute on roster changes, aura changes, sync messages and lock changes. Button changes wait until combat ends.

**Example, the case it was designed for:** Protection paladin (tank) and Holy paladin, both with Kings, plus a rogue, mage and hunter.

| Player | Protection gives | Holy gives |
| :--- | :--- | :--- |
| Rogue | Might | Kings |
| Mage | Kings | Wisdom |
| Hunter | Kings | Wisdom |
| Protection paladin | Kings | Wisdom |
| Holy paladin | Kings | Wisdom |

## Open check: Salvation

The rename may mean Salvation no longer uses a paladin's one blessing slot on a player. Phase 0 tests it:
- **Still shares the slot:** Salvation stays in the wish lists as above.
- **Separate:** Salvation becomes an extra, cast alongside the main blessing for players who want it, and never uses a choice.

---

## Phase 0: Repo and checks

- Repo, README, plan, license, logo, CurseForge workflow, `/zips` packaging, tests.
- `/nbless check` in-game self test. Confirm in the Forever client:
  - Blessing auras on group members report who cast them.
  - Greater Blessing coverage (whole class, raid-wide, range).
  - Whether Salvation shares the blessing slot.
  - `UnitGroupRolesAssigned` reports the Tank role from role selection.
  - Addon messages work in party and raid.

## Phase 1: Data and engine

- Generator script for blessings, ranks, levels and durations.
- Talent detection, wish lists, leanings.
- Assignment engine with unit tests, including the example above, paladins without the addon, missing Kings, and locks.

## Phase 2: Sync

- Share known blessings, talents, leanings and locks on the addon's own prefix; every copy computes the same plan.

## Phase 3: Buttons

- One button per party member with blessing and time left; red when missing or under 5 minutes (configurable).
- Top Up: refresh each of your blessings under 10 minutes, one per press. Bless Next for whoever is missing one (after a death, for example).
- Greater Blessing buttons per class in raids, with missing counts.

## Phase 4: Grid, auras, settings, languages, beta

- Leader grid and locks; aura assignments; announce to group chat; Symbol of Kings warning.
- Settings window and Nullgate's Addon Config page; the 10 client languages.
- DESCRIPTION.md, CHANGELOG.md, 1.0.0-beta.1.
