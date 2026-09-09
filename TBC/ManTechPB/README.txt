ManTechPB 0.8.0

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

Summon uses the server's existing command and rules. Arrival requires the bot to
be online, alive, noncombat, visible and within follow-interaction distance.
Two summon requests over 45 seconds are allowed; unresolved combat/death/loading
or denied destinations STOP preparation. Sending a summon is not arrival.

Invite failures try another candidate, with one bounded replacement search.
Unexpected joins/departures stop for roster/role review. Existing humans remain
protected and take precedence over a stale recruitment plan.

Cancel discards unsent steps without undoing completed changes. Build / Resume
keeps confirmed gear/supply checkpoints for the same bot, role and build in this
UI session. Changing a role or explicitly choosing Prepare bot again clears that
slot's checkpoint. Reload/logout loses checkpoints; a lost server acknowledgement
still needs a future idempotent core protocol. Closing the window does not cancel.

IMPORTANT: Legacy /who cannot prove bot identity. This release still needs the
core task to resolve the pre-invite bot "who" reply-permission problem or provide
a defined replacement protocol. It never invites arbitrary unverified humans as
a workaround. Summon and prep permissions cannot be bypassed by an addon.

Preview /who is optional. Empty rows search their class/role. Queries deduplicate
classes across slots, wait at least eight seconds apart, retry a timeout once,
and have bounded replacement/probe budgets. Avoid simultaneous manual /who or
other Who-search addons: legacy responses have no request IDs or bot identity.
Core-wide scaling and authoritative reservations remain separate core work.

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
