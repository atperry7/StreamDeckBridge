# StreamDeckBridge

A Windower addon that lets you control Final Fantasy XI from your Stream Deck.

## What It Does

StreamDeckBridge creates a local server that listens for commands from your Stream Deck. Any button press on your Stream Deck can send a command directly to Windower, letting you trigger macros, cast spells, change equipment, or run any Windower command with a single button press.

## Installation

1. Download or clone this addon to your Windower addons folder:
   ```
   Windower/addons/StreamDeckBridge/
   ```

2. Load the addon in-game:
   ```
   //lua load streamdeckbridge
   ```

   Or add it to your Windower init file to load automatically.

## Stream Deck Setup

You'll need a Stream Deck plugin that can send TCP messages. A popular option is the **Advanced Launcher** plugin or any plugin that supports raw TCP socket connections.

Configure your Stream Deck buttons with:
- **Host:** `127.0.0.1`
- **Port:** `19769`
- **Message:** Any Windower command (without the `//` prefix)

### Example Commands

| Button Action | Command to Send |
|---------------|-----------------|
| Cast Cure | `input /ma "Cure" <t>` |
| Use a macro | `input /macro set 1` |
| Change job | `input /jobchange WAR` |
| Run GearSwap set | `gs c toggle` |
| Target nearest NPC | `target <stnpc>` |

## Addon Commands

| Command | Description |
|---------|-------------|
| `//sdb status` | Show server status and connected clients |
| `//sdb main <name>` | Only run the addon on a specific character |
| `//sdb main` | Show the current main character setting |

## Settings

Settings are stored in `data/settings.xml`:

- **port** - Server port (default: `19769`)
- **main_character** - Restrict addon to a specific character (leave empty for all characters)

## Troubleshooting

**Stream Deck not connecting?**
- Make sure the addon is loaded (`//sdb status`)
- Check that nothing else is using port 19769
- Verify your Stream Deck plugin is sending to `127.0.0.1:19769`

**Commands not working?**
- Commands are sent exactly as typed - don't include `//`
- Check Windower's console for any error messages

## License

MIT License - Feel free to use and modify.
