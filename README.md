# ManTechPB

ManTechPB is a standalone in-game manager for CMaNGOS PlayerBots. It provides a compact interface for party and individual bot control, role and talent setup, combat behavior, formations, loot policy, advanced class controls, a staged `/who` Group Builder, and a movable bot bar.

This project is a modern standalone successor inspired by the original [Mangosbot UI addon by ike3](https://github.com/ike3/mangosbot-addon). Full credit and thanks go to ike3 and the original addon contributors for pioneering the in-game PlayerBots control interface. ManTechPB is built for the actively maintained [CMaNGOS PlayerBots project](https://github.com/cmangos/playerbots).

## Supported clients

| Client | Interface | Release |
| --- | ---: | --- |
| Vanilla / Classic | 11200 | 0.7.1 |
| The Burning Crusade | 20400 | 0.7.1-TBC.1 |
| Wrath of the Lich King | 30300 | 0.7.1-WotLK.1 |

## Installation

1. Open the folder for your game version in this repository.
2. Copy the enclosed `ManTechPB` folder into your client's `Interface/AddOns` directory.
3. Restart the client or reload the UI.

Open the manager with `/mtp`, `/mantechpb`, or the minimap button. Each version folder also contains a detailed `README.txt`.

## Group Builder

Open **LFG** or `/mtp lfg`, choose your own role, the other four class/style preferences, and the level range. Click **Build Group** once. No manual invitations are required.

The sequence is: class/level search → bot-response check → invite/join → confirm talent preset → confirm role/settings → random gear → food, potions, consumables, reagents and ammunition. Each bot is processed in turn. Gear is not requested until its spec and settings are confirmed; every supply command waits for the server's response. READY is reserved for completed slots.

At level 43 with ±2, a Warrior query is `/who c-"Warrior" 41-45`. Queries run at least eight seconds apart, with one retry on timeout. Results appear in the Group Builder, not necessarily the Blizzard Who window. **Search /who** is an optional preview; clicking an empty row searches that role. Clicking a name cycles candidates. Build Group searches afresh and honors manually cycled names if they remain available. Avoid manual `/who` and other Who-search addons during a run: legacy responses have no request identifier.

Tanks receive Tank Assist, Pull and Pull Back. Healers receive a healing preset and all Healer DPS variants OFF. Supported AoE, cooldowns, buffs and cleansing are enabled, plus food/drink and potions. Class-specific exceptions, including Death Knight strategies, are respected. Damage Assist on a healer selects hostile targets; it is not the Healer DPS switch.

The standard `/who` list cannot identify bots. Before inviting, ManTechPB looks for the existing bot `who` response and skips nonresponders or bots reporting another master, trying alternatives with a 24-probe limit. This recognizes the existing protocol; it is not authenticated bot discovery and busy bots can be skipped. Bot-only discovery with request IDs remains an optional core improvement, not an addon-side permission bypass.

Start outside combat, raids and battlegrounds, either solo or leading a compatible partial bot party. You fill one slot and four bots fill the others. Existing members must fit the selected class/level criteria and respond as available bots; nobody is automatically removed. Your server must permit respec/gear/supply commands and provide matching presets and acknowledgements. A refusal or missing confirmation stops the sequence with an explanation instead of pretending success.

**Cancel** discards unsent steps but keeps already joined bots and completed changes. Closing the window does not cancel. Restarting Build Group repeats setup, including random gear. Other addon command controls are paused during a build to prevent conflicting changes. This does not summon the party to a dungeon or override bot recruitment, equipment, inventory or command-permission rules.

### Verification

`tests/group-builder.lua` is a deterministic mocked-client integration test, not a live multiplayer test. Run with a Lua 5.0 interpreter and the addon Lua path as its first argument. It covers one-click setup, class/level queries, bot checking, command ordering, missing responses, refusals, cancellation, partial parties and raid/combat guards. Real server permissions and response formats still require in-game validation.

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
