# ManTechPB

ManTechPB is a standalone in-game manager for CMaNGOS PlayerBots. It provides a compact interface for party and individual bot control, role and talent setup, combat behavior, formations, loot policy, advanced class controls, a staged `/who` Group Builder, and a movable bot bar.

This project is a modern standalone successor inspired by the original [Mangosbot UI addon by ike3](https://github.com/ike3/mangosbot-addon). Full credit and thanks go to ike3 and the original addon contributors for pioneering the in-game PlayerBots control interface. ManTechPB is built for the actively maintained [CMaNGOS PlayerBots project](https://github.com/cmangos/playerbots).

## Supported clients

| Client | Interface | Release |
| --- | ---: | --- |
| Vanilla / Classic | 11200 | 0.7.0 |
| The Burning Crusade | 20400 | 0.7.0-TBC.1 |
| Wrath of the Lich King | 30300 | 0.7.0-WotLK.1 |

## Installation

1. Open the folder for your game version in this repository.
2. Copy the enclosed `ManTechPB` folder into your client's `Interface/AddOns` directory.
3. Restart the client or reload the UI.

Open the manager with `/mtp`, `/mantechpb`, or the minimap button. Each version folder also contains a detailed `README.txt`.

## Group Builder

Open Group Builder with the manager's **LFG** button or `/mtp lfg`. Select the role filled by your own character, choose class/style preferences for the other four party slots, select a level range, then run **Search /who**. ManTechPB auto-fills visible candidates; click any candidate to cycle through alternatives before choosing **Build Group**.

After selected candidates accept their invitations, the builder applies a matching server-provided talent build, synchronizes PlayerBots role strategies, generates appropriate gear, and prepares supplies. Tanks receive tank-assist/pull defaults, and healers have healer DPS explicitly disabled.

The standard WoW `/who` result does not identify whether a character is a PlayerBot. Always verify the four displayed names before building the group. A small optional core protocol would allow future releases to make discovery bot-only; it is not required for the staged `/who` workflow.

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
