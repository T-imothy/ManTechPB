# ManTechPB

ManTechPB is a standalone in-game manager for CMaNGOS PlayerBots. It provides party and individual bot control, role and talent setup, combat behavior, formations, loot policy, advanced class controls, a staged Group/Raid Builder, and a movable bot bar.

This project is a modern standalone successor inspired by the original [Mangosbot UI addon by ike3](https://github.com/ike3/mangosbot-addon). Full credit and thanks go to ike3 and the original addon contributors for pioneering the in-game PlayerBots control interface. ManTechPB is built for the actively maintained [CMaNGOS PlayerBots project](https://github.com/cmangos/playerbots).

## Supported clients

| Client | Interface | Release |
| --- | ---: | --- |
| Vanilla / Classic | 11200 | 0.10.0 |
| The Burning Crusade | 20400 | 0.10.0-TBC.1 |
| Wrath of the Lich King | 30300 | 0.10.0-WotLK.1 |

## Installation

1. Open the folder for your game version in this repository.
2. Copy the enclosed `ManTechPB` folder into your client's `Interface/AddOns` directory.
3. Restart the client or reload the UI.

Open the manager with `/mtp`, `/mantechpb`, or the minimap button. Each version folder also contains a detailed `README.txt`.

## Group / Raid Builder

### New in 0.10.0: explicit specs and verified class profiles

Choose **Role → Class → Spec**, then **Build / Resume**. Shaman DPS can be
Enhancement or Elemental; Druid DPS can be Cat or Balance; Priest healers can be
Holy or Discipline. All supported class/spec families have a selector. Classic
also exposes Fury/Prot separately from Protection; Death Knights are Wrath-only.
The bot's live server talent list remains authoritative. Missing selected specs
stop before talent/gear changes rather than silently selecting another spec.

**Builds: PvE only** excludes PvP-labelled presets by default. Choose **Allow PvP
fallback** deliberately where the server only provides a PvP build (for example
bundled Classic Enhancement). Unlabelled weapon/hybrid presets remain eligible;
farm/ambiguous hybrid presets are excluded from automated dungeon preparation.
Exact selected talent names appear during preparation. No universal best-DPS
claim is made for the server's preset ordering.

Configuration and READY now use the same required/forbidden class profile:
positioning, assist, buff/cooldown/CC utilities, cleanse where supported, food,
potions, Shaman totems, Rogue poisons and Hunter pet maintenance. Passive/hold
conflicts and incompatible spec flags are removed and checked, including dead
and reaction contexts. Optional healer DPS is disabled. Paladin support
Judgements and Shaman totems may still cause damage; the addon does not impose
a core-wide damage veto. Only the first tank slot is configured as raid puller.

The **Instructions** button beside Help opens a short **Play & go** guide:
choose classes/specs, press Build / Resume, wait for READY, then play. Separate
tabs explain slots, other options, and what to do if preparation stops.

The release includes an offline test fixture of all 258 bundled preset names
from the ManTech PlayerBots fork, plus class-profile and UI regression tests.
Client runtime and per-class live combat testing remain distinct from these
mocked tests. The profile changes do not modify PlayerBots core code.

Open **LFG** or `/mtp lfg`. Choose Party (5) or a 10/20/25/40-slot raid plan. Edit tank/healer/DPS roles and bot class/style preferences on the paged rows. A raid plan is a requested group size, not a claim that every dungeon supports that size.

Existing members default to **Keep member**, regardless of whether they might be bots. Confirm the role for each newly discovered member by choosing their Role dropdown. This only reserves a composition slot; it does not respec a human. Choose **Prepare bot** explicitly to include an existing bot in summoning and preparation. Your own character is always kept unchanged. Empty slots recruit bots. Humans have no class or level-range restrictions imposed by the builder.

**Build / Resume** runs these phases:

Search stops per class as soon as enough distinct candidates fit your selected slots; it does not exhaust the entire bot population first. A complete candidate set from Preview or Cancel is reused and freshly status-checked before invitation. Changing requirements triggers a new search when the saved set no longer fits. **CANDIDATE is not JOINED**: the status line distinguishes discovery from group membership.

Invitations are sequential: confirm the named member in the roster, wait two seconds for the party to settle, then continue to the next bot. Classic may report a member count before their name loads. Unknown, missing, localized placeholder or duplicate transient names hold workflow commands for up to ten seconds instead of becoming a fake human/Keep assignment. Real unexpected members still stop the builder for role review. Unresolved names time out safely. If an older release already stopped and kept a newly invited bot, explicitly confirm its role and choose Prepare bot before resuming.

1. Search matching classes/levels, recheck bot eligibility and reserve before invitation; fill vacancies with confirmed joins.
2. Summon all included bots that are not already nearby and ready.
3. Confirm arrival for every included bot before starting any preparation.
4. Confirm server talent presets and role settings, then random gear and supplies.

Choosing a raid size explicitly authorizes party-to-raid conversion when needed. It does not disband a raid, move existing subgroups, kick members, or steal bots from another group. You must lead the group. Battleground/arena use is blocked.

Tanks receive Tank Assist, Pull and Pull Back. Healers receive a healing preset and Healer DPS OFF. Supported AoE, cooldowns, buffs/cleansing, food/drink and potions are enabled; class-specific exceptions including Death Knights are respected. Gear follows confirmed talents/settings. Each food, potion, consumable, reagent and ammunition operation waits for its server reply.

### Summons, interruptions and resume

Core v1 uses the released `.bot recruit v1` contract from PlayerBots revision `c87bc38ef3da57282b3643da8e2cbdddb28c0a45`. Bots with a known GUID require a correlated server `arrived` response plus client readiness before prep. The core checks completed transfer, same map AND instance, alive/out of combat, within 10 yards and line of sight. Client follow-interaction distance alone does not prove that stricter condition.

One logical v1 summon uses one ID and a bounded 60-second response window to accommodate the core's 40-second deadline plus queue delay. Unknown replies retry the same ID/payload, never reset the server deadline. A pre-existing summon is checked with fresh status IDs. Legacy mode retains up to two raw requests and a 45-second window. Dead/ghost, combat, loading or denied destinations stop prep if readiness never becomes true. No forced teleport/resurrection is attempted.

Failed invitations try alternative candidates. Candidate exhaustion permits one additional paced search, not an endless loop. New/unexpected members, departures or leadership changes stop the run for review; humans are not overwritten to satisfy an old plan. Existing groups must fit the selected size and every existing member must be accounted for.

**Cancel** drops unsent steps and sends bounded cancellation/release commands for GUIDs touched by this builder. It never removes members or undoes completed preparation. A started native teleport may still complete. Closing the window does not cancel.

Structured preparation records acknowledged steps and unknown results in SavedVariables, scoped to realm/player/bot and role/build. Resume skips acknowledged work. Unknown/lost replies retry the SAME ID and payload (up to three transmissions); explicit rate-limit refusals use delayed NEW IDs (up to three retries). Successful no-op supply/ammo replies count as completion. Below-talent-level bots or missing builds do not count as specialized.

After reload or an unresolved mutation, the addon does not blindly regenerate gear. Inspect the bot and use `/mtprecruit reconcile NAME` only when you deliberately want to clear its prep checkpoints and permit new gear/supplies. Core receipts last ten minutes and are not persistent across server restarts; SavedVariables are also not guaranteed to survive a client crash. This is not durable exactly-once protection. Legacy operations retain in-session checkpoints only. A role/build change invalidates matching structured checkpoints; reselecting Prepare alone does not erase the saved safety journal.

### Core v1 and Legacy modes

The bottom-right **Protocol** button selects Core v1 (default) or Legacy while idle. Selection is not a claim that the server supports v1: only a correlated response confirms support. A timeout never automatically downgrades to mutating legacy commands. Select Legacy explicitly on an older server. Preview search is optional.

V1 discovery returns public eligible random-holder bots, not every authorized account/guild alt. Direct Prepare selection remains useful for existing alts. Existing member GUIDs are resolved through the client where available or retained from this session's discovery. On clients without those GUIDs, that explicitly selected bot uses the legacy identification/invite/summon/prep path; it does not gain an invented authoritative arrival proof. Humans are never considered bots merely because WHO returned their name.

V1 queries deduplicate classes, follow cursor pages (at most 128 pages per search), and wait at least 2.1 seconds between discovery requests. Only a matching completion commits a candidate batch; retries deduplicate candidates. Requests use stable GUIDs and unique IDs; one logical operation runs at a time. Reservations are requested immediately before inviting. Full-group/leadership races stop for review. Rate limits produce bounded waits, not request storms.

Raw `PBRECRUIT` replies and outbound SAY commands for this addon's own request IDs are hidden from chat presentation, while the addon still processes them. Progress/refusal messages remain in the builder. Other players' messages, manual/unrelated IDs, and ordinary system errors are not hidden by this filter. For diagnostics, use `/mtprecruit debug on`; turn it off with `/mtprecruit debug off`.

Legacy queries use `/who c-"Warrior" 41-45` for a level-43 Warrior search at +/-2, at least eight seconds apart. Avoid simultaneous manual/other-addon Who searches. Bot whispers must establish identity; `Recruitment unavailable: <reason>` and `Recruitment pending: transfer` are handled explicitly. Native invitations expire on the released core after 15 seconds; the client allows a short roster-update margin. No mode bypasses server permissions, ownership, group capacity or instance policies.

### Verification

`tests/group-builder.lua` and `tests/runtime-smoke.lua` load both addon chunks in a mocked client; run with Lua 5.0 and the main addon Lua path as the first argument. They cover legacy party/raid behavior plus v1 staged parties, a mixed 40-slot raid with 37 bots, cursor paging, reversed batches, lost gear replies, repeated IDs, rate limits, wrong GUID/ID and stale replies, full-group races, cancellation with late teleport completion, unknown-prep checkpoints, and client GUID parsing. These are not live realm, visual, inventory-content or server-wide load tests.

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
