# ManTechPB

ManTechPB is a standalone in-game manager for CMaNGOS PlayerBots. It provides a compact interface for party and individual bot control, role and talent setup, combat behavior, formations, loot policy, advanced class controls, a staged `/who` Group Builder, and a movable bot bar.

This project is a modern standalone successor inspired by the original [Mangosbot UI addon by ike3](https://github.com/ike3/mangosbot-addon). Full credit and thanks go to ike3 and the original addon contributors for pioneering the in-game PlayerBots control interface. ManTechPB is built for the actively maintained [CMaNGOS PlayerBots project](https://github.com/cmangos/playerbots).

## Supported clients

| Client | Interface | Release |
| --- | ---: | --- |
| Vanilla / Classic | 11200 | 0.8.0 |
| The Burning Crusade | 20400 | 0.8.0-TBC.1 |
| Wrath of the Lich King | 30300 | 0.8.0-WotLK.1 |

## Installation

1. Open the folder for your game version in this repository.
2. Copy the enclosed `ManTechPB` folder into your client's `Interface/AddOns` directory.
3. Restart the client or reload the UI.

Open the manager with `/mtp`, `/mantechpb`, or the minimap button. Each version folder also contains a detailed `README.txt`.

## Group / Raid Builder

Open **LFG** or `/mtp lfg`. Choose Party (5) or a 10/20/25/40-slot raid plan. Edit tank/healer/DPS roles and bot class/style preferences on the paged rows. A raid plan is a requested group size, not a claim that every dungeon supports that size.

Existing members default to **Keep member**, regardless of whether they might be bots. Confirm the role for each newly discovered member by choosing their Role dropdown. This only reserves a composition slot; it does not respec a human. Choose **Prepare bot** explicitly to include an existing bot in summoning and preparation. Your own character is always kept unchanged. Empty slots recruit bots. Humans have no class or level-range restrictions imposed by the builder.

**Build / Resume** runs these phases:

1. Search matching classes/levels and verify bot replies; fill vacant slots with confirmed joins.
2. Summon all included bots that are not already nearby and ready.
3. Confirm arrival for every included bot before starting any preparation.
4. Confirm server talent presets and role settings, then random gear and supplies.

Choosing a raid size explicitly authorizes party-to-raid conversion when needed. It does not disband a raid, move existing subgroups, kick members, or steal bots from another group. You must lead the group. Battleground/arena use is blocked.

Tanks receive Tank Assist, Pull and Pull Back. Healers receive a healing preset and Healer DPS OFF. Supported AoE, cooldowns, buffs/cleansing, food/drink and potions are enabled; class-specific exceptions including Death Knights are respected. Gear follows confirmed talents/settings. Each food, potion, consumable, reagent and ammunition operation waits for its server reply.

### Summons, interruptions and resume

The existing bot `summon` command is used; normal server policy still applies. Arrival requires an online, alive, noncombat unit that is visible and within the client's follow-interaction distance. Visibility and interaction range prevent treating a same-map/different-instance bot as nearby. A sent command or accepted teleport alone is not success.

Each bot gets at most two summon requests over a 45-second arrival window. Dead/ghost, combat, loading, inaccessible destinations or denied summons stop prep if readiness never becomes true. No addon-side resurrection or forced teleport is attempted. Human/Keep members are never summoned or prepared.

Failed invitations try alternative candidates. Candidate exhaustion permits one additional paced search, not an endless loop. New/unexpected members, departures or leadership changes stop the run for review; humans are not overwritten to satisfy an old plan. Existing groups must fit the selected size and every existing member must be accounted for.

**Cancel** drops unsent steps without undoing completed changes or removing members. **Build / Resume** retains in-session confirmed gear/supply checkpoints for the same bot, role and build. Completed steps are not repeated. Changing a role or explicitly choosing Prepare bot again deliberately clears that slot's checkpoint. Checkpoints do not survive UI reload/logout, and a lost server acknowledgement cannot prove whether a command executed; the future core protocol needs idempotent requests for that case. Closing the window does not cancel.

### Discovery limitations / pending core integration

This version still uses legacy `/who` and bot `who` replies. The normal `/who` list does **not** prove bot identity. No new core endpoint is assumed or invented.

**The known pre-invite reply-permission problem still requires the core task's fix or a defined replacement protocol.** On affected cores the builder cannot safely auto-invite unverified candidates and will stop with an explanation. It does not bypass this by inviting arbitrary human results. Bots reporting another master are skipped; normal invitations cannot pull candidates out of another group. Server restrictions on summons, respecs, gear and supplies also remain authoritative.

Queries are deduplicated by class, not repeated per raid slot. At level 43 +/-2 a Warrior query is `/who c-"Warrior" 41-45`. They run at least eight seconds apart with one timeout retry. Preview /who is optional; empty rows search their role and named candidates cycle alternatives. Avoid competing Who-search addons/manual queries during a run because legacy replies have no request ID. Results may also be server-capped.

Recruitment is sequential, with a bounded probe budget (at most 120 for large plans), at most three consecutive unanswered identification probes, one replacement search round, and one active invite/summon/prep step at a time. Roster reads are cached within a tick. This limits this client; server-wide throttling, reliable bot-only discovery, reservation conflicts and authoritative arrival/identity remain core responsibilities.

### Verification

`tests/group-builder.lua` is a deterministic mocked-client integration test, not live server or visual verification. Run with Lua 5.0 and the addon Lua path as the first argument. It covers full-group-before-summon and arrival-before-prep ordering, dead/refused summons, missing replies, replacement invites, cancellation, partial resume without repeated confirmed gear, protected human members, paged editing, solo-to-raid conversion, and a 40-slot mock raid with three kept humans plus 37 bots and two class queries. Live server permissions, response formats and actual server-wide load still require validation.

## Compatibility

ManTechPB is designed for CMaNGOS PlayerBots and the commands exposed by the ManTech PlayerBots integration. Available behavior may vary if the server core does not provide the corresponding PlayerBots commands or status responses.

## Credits and license

- Original PlayerBots UI concept: [ike3/mangosbot-addon](https://github.com/ike3/mangosbot-addon)
- CMaNGOS PlayerBots engine: [cmangos/playerbots](https://github.com/cmangos/playerbots)
- ManTechPB is distributed under the GNU General Public License, version 2. See `LICENSE` and `THIRD_PARTY_NOTICES.md`.

World of Warcraft and related names and game assets are trademarks or copyrighted works of Blizzard Entertainment. This community project is not affiliated with or endorsed by Blizzard Entertainment.

## Repository layout

- `Classic/ManTechPB` — Vanilla / Classic client
- `TBC/ManTechPB` — The Burning Crusade client
- `WotLK/ManTechPB` — Wrath of the Lich King client
