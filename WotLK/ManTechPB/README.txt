ManTechPB 0.7.0

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
- five-role composition editor with one player role and four bot slots
- per-slot tank, healer, DPS class/style preferences and selectable level range
- staged /who search with visible, cycleable candidate names before invites
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
Click LFG in the main title bar or use /mtp lfg. Choose the role your own
character fills, choose a class or damage style for the other four slots, and
select a level range. Search /who fills the four bot slots with online candidates.
Click a candidate name to cycle through other matches, then click Build Group.

After the selected characters join, ManTechPB processes them in sequence. It asks each bot for this
server's real talent builds, chooses a PvE-compatible build for the assigned role,
synchronizes the AI role, generates gear, and prepares supplies. Tank slots receive
Tank Assist, Pull, and Pull Back. Healer slots receive Damage Assist and explicitly
remove every Healer DPS/offdps variant.

WoW's normal /who result does not say whether a character is a PlayerBot. Verify
the four displayed names before clicking Build Group; ordinary players can appear
in the same class and level results.

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
