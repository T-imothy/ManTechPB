ManTechPB 0.10.1

0.10.1: Spec now lists exact talent builds for every supported class/job in
Classic, TBC and Wrath, with separate Auto choices. Classic Warrior tanks
include pve prot, furyprot, furyprot (slam), and furyprot (demo shout).
Long menus are paged and show full names; hover the selected row for details.
Version-specific catalogue choices are verified against the bot's live list
before applying. Missing exact choices stop rather than silently substituting.
Identically named builds share one choice because the server command uses names.

0.10.0: Group Builder now has separate Class and Spec selectors.
Instructions beside Help opens the quick Play & go guide, plus tabs explaining
slots, other options and what to do if preparation stops.
Select the spec you want (for example Enhancement vs Elemental or Cat vs Balance), then
Build / Resume. PvE-only is the default; Allow PvP fallback is explicit for
versions/specs whose server catalogue only supplies a PvP build. Unlabelled
weapon and supported hybrid presets remain eligible. No silent spec switching.
Preparation and READY share one checked profile, including class utilities,
positioning, no Passive/hold conflicts, and optional healer DPS disabled.
Totems, poisons and hunter pet maintenance are enabled where appropriate.
Combat, noncombat, reaction and dead settings are checked. In a raid only
the first tank slot is configured to pull. Keep members remain untouched.
Healer support Judgements/totems may still cause damage; this is not a
promise to prevent every damaging action in the core. No core changes needed.

ManTechPB is a standalone CMaNGOS PlayerBots manager. It does not require the
Mangosbot addon and does not overwrite it.

Design goals:
- one compact window instead of several independent control windows
- Play, Setup, Combat, World, and Expert tabs
- Party or individual-bot scope is always visible
- Party and My Alts sidebar filters keep grouped bots separate from account alts
- always-visible selected-bot and all-account-bot login/logout controls
- raid and battleground-raid roster, command-channel, and talent-reply compatibility
- selected-bot scope is saved per character and stale cross-character selections are never auto-contacted
- class-aware AI role/spec setup with mutually exclusive roles
- plain-English labels, descriptions, tooltips, and command feedback
- advanced features split into focused Bots, Tactics, Mark, CC, Loot, RPG,
  Class, Setup, and Character pages
- restored legacy tactics such as Passive, Aggressive/Grind, Tank Attack,
  Close/Ranged, Pull Back, Avoid Mobs, and group formations
- persistent roll-policy controls (Auto, Pass, Greed, Need) for updated cores
- core role/build/pull readiness status shown without exposing command chatter
- mana conservation levels 1 through 10
- larger readable text and blue beveled buttons across all three clients
- contextual Help buttons on the Manager, Individual, Talents, and Bot Bar windows
- top-down formation previews with confirmed and mixed-party state highlighting
- title-bar controls use separate click and drag regions on every supported client
- Healer DPS reads and changes combat-only offdps strategies without requiring a nonexistent non-combat copy
- separate Group Builder window opened by LFG or /mtp lfg
- paged 5/10/20/25/40-slot plans, explicit roles and protected existing members
- per-slot tank, healer, DPS class/style preferences and selectable level range
- one-click, paced /who discovery with bot-response checks before invitations
- automatic server talent-build selection, role sync, gearing, supplies, tank pull/assist, and healer-DPS-off defaults

Open ManTechPB with /mtp, /mantechpb, or its movable minimap button.
Alt-left-click a PlayerBot in the 3D world to open its compact individual-control window.
The full manager and individual window can remain open together. The individual
Tactic, Fight, and Support tabs expose detailed controls without overflowing the frame.
The compact movable Bot Bar is visible by default. Use /mtp bar to show or hide it,
and /mtp bar reset to restore its default position.
Recognized PlayerBot command/reply traffic is hidden from whisper and party chat
by default while ManTechPB still reads it. Use the Bot Chat button or /mtp chat to
toggle it, /mtp chat hide to hide it, and /mtp chat show to display it again.
Manually typed talent commands remain visible with their replies even while the
manager's own background command traffic is hidden.

GROUP BUILDER
-------------
0.9.2: Invites remain one at a time. Confirm a named roster member, wait two
seconds for the party to settle, then continue. Unknown/missing/localized loading
names hold commands for up to ten seconds, never become human/Keep assignments.
Actual unexpected players still require role review. If an older release kept
your newly joined bot after a false stop, confirm its role and choose Prepare bot.

0.9.1: Stop each class search when enough distinct candidates fill the requested
slots. Complete candidates kept after Preview/Cancel are reused, then freshly
verified before inviting. CANDIDATE does not mean JOINED. Raw protocol messages
for this addon's own IDs are hidden from chat; useful status/errors stay in the
window. /mtprecruit debug on (or debug off) controls raw diagnostic visibility.

Open LFG or /mtp lfg. Select Party (5) or Raid (10/20/25/40).
Use the pages to assign roles and class/style preferences. Existing members default
to Keep member. Confirm each new member's role dropdown before building; this
reserves a slot and NEVER changes their character. Choose Prepare bot explicitly
to include an existing bot. Your character is always kept unchanged.

Build / Resume fills the vacancies first, then summons included bots, waits for
ALL included bots to arrive, and only then changes talents/settings and requests
gear/supplies. Selecting a raid size authorizes conversion to raid when needed.
The addon never disbands groups, kicks members, moves subgroups or summons humans.
Lead your group and stay outside combat, battlegrounds and arenas.

Tank gets Tank Assist, Pull and Pull Back. Healer gets a healing preset and Healer
DPS OFF. Supported AoE, cooldowns, buffs, cleansing, food/drink and potions are
enabled, using class-specific strategies where needed.

Protocol: Core v1 is the default. It integrates the released PlayerBots contract
c87bc38ef3da57282b3643da8e2cbdddb28c0a45. Discovery is bot-only and cursor-paged;
eligibility is checked again and a reservation is requested before invitation.
Only actual roster membership confirms joining. Known-GUID bots require the
server's arrived response AND client readiness before prep. The core requires
completed transfer, same map/instance, alive/out of combat, 10 yards and LOS.
Client CheckInteractDistance alone is not proof of those server conditions.

Core summon operations have a bounded 60-second client response window, including
queue allowance. Repeated transmissions reuse the SAME ID, never extend the
server's 40-second summon deadline. Dead/combat/unsafe destinations remain subject
to server rules. Cancellation cannot stop an already-started native teleport.

Invite failures try another candidate, with one bounded replacement search.
Unexpected joins/departures stop for roster/role review. Existing humans remain
protected and take precedence over a stale recruitment plan.

Cancel discards unsent steps and releases this builder's pending GUID requests;
members and completed work stay. Closing the window does not cancel. Structured
prep saves acknowledged steps and unknown results. Missing acknowledgments retry
the SAME ID/payload; explicit rate limits wait before a bounded NEW-ID retry.
An unknown prep result after interruption blocks fresh gear generation. Inspect
the bot, then /mtprecruit reconcile NAME only if you deliberately want to clear
its checkpoints and permit new preparation. Role/build changes invalidate matched
checkpoints; selecting Prepare alone does not erase the saved safety journal.
Core receipts last 10 minutes and do not survive server restart. SavedVariables
may be lost in a client crash. This is not durable exactly-once protection.

Select Protocol: Legacy explicitly for older cores. No reply is NOT proof that
v1 is unsupported, and there is no silent automatic mutation fallback. Legacy
handles Recruitment unavailable/pending whispers and readable system refusals.
It retains its existing WHO and summon behavior (two summons/45 seconds) and
in-session checkpoints. Existing selected bots without a client GUID also use
legacy commands; no false claim of authoritative server arrival is made for them.
V1 public discovery does not enumerate every authorized account/guild alt.

Preview search is optional. Both modes deduplicate classes. V1 discovery waits
at least 2.1 seconds between requests, follows cursors with a 128-page cap, and
handles server rate limits. Legacy WHO waits eight seconds; avoid simultaneous
manual WHO or other Who-search addons. Both paths have bounded attempts.
Exact server builds must be available; below-talent-level bots cannot be marked
specialized. Adequate supplies/inapplicable ammo are successful core no-ops.

Update all files, including Recruitment.lua and ManTechPB.toc, then restart the
client (or reload after a file update). Open /mtp lfg and use Core v1 on the updated
realm. The test suite is mocked; actual realm gameplay still needs verification.

Select one bot and open Setup > Talents. ManTechPB asks that bot for the exact
predefined builds configured on the current server; it never invents a cross-version
build name. Clicking a returned build privately sends the normal Playerbot talents
command to only the selected bot.
Full server build lists received in party chat are captured and paged ten at a time.
You can also inspect the current build, auto-pick talents, or reset with confirmation.
Current remains scoped to the selected bot and lets that one request and reply
appear in chat even when routine Bot Chat is hidden. Its window summary shows only
the confirmed spec name instead of the talent layout, link, and strategy details.
When a talent build name matches a known class role, ManTechPB waits for the server
to confirm the real build and then synchronizes its matching tank, healer, melee-DPS,
or ranged-DPS AI role. This works in either direction when changing roles.
Role changes synchronize Tank/Damage Assist in combat and non-combat contexts,
set Close/Ranged and Behind positioning, and add or remove Pull and Pull Back.
WotLK Death Knight Frost/Unholy AOE strategies follow the selected DK role.

The Setup tab changes AI strategies to match a bot's build. It does not spend
talent points. Character > Initialize and Random Gear make significant changes,
so use those controls deliberately.
