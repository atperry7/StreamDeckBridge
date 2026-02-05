# StreamDeckBridge

A Windower addon that lets you control Final Fantasy XI from your Stream Deck.

## What It Does

StreamDeckBridge creates a local server that listens for commands from your Stream Deck. Any button press on your Stream Deck can send a command directly to Windower, letting you trigger macros, cast spells, change equipment, or run any Windower command with a single button press.

### Multi-Character Routing

StreamDeckBridge supports per-button command routing across multiple FFXI characters. The Stream Deck plugin sends a target with each command, and StreamDeckBridge routes it using Windower's native IPC:

- **Focus mode** (`@focus`) — Command executes on whichever FFXI window currently has focus
- **Server direct** (`@main`) — Command executes on the server character regardless of focus
- **Character name** — Command is routed to a specific character via IPC
- **@all** — Command executes on every character running the addon

Routing is configured per-button in the Stream Deck plugin UI. The addon on non-server characters listens for IPC messages and executes commands targeted at them.

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

3. Set the server character (on the character that should receive Stream Deck connections):
   ```
   //sdb enable
   ```

4. Load the addon on all other characters that should receive targeted or `@all` commands.

## Stream Deck Setup

You can find my custom built Stream Deck Plugin here: https://github.com/atperry7/FFXI-Stream-Deck-Plugin

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
| `//sdb enable` | Set this character as the server (listens for Stream Deck connections) |
| `//sdb disable` | Clear server character (disable server) |
| `//sdb status` | Show server status, connected clients, and focus state |

## Settings

Settings are stored in `data/settings.xml`:

- **port** - Server port (default: `19769`)
- **server_character** - The character that runs the TCP server

## TCP Protocol

The Stream Deck plugin sends commands in the format `<target>|<command>`. Commands without a `|` are treated as legacy and execute directly on the server character.

## Troubleshooting

**Stream Deck not connecting?**
- Make sure the addon is loaded (`//sdb status`)
- Check that nothing else is using port 19769
- Verify your Stream Deck plugin is sending to `127.0.0.1:19769`

**Commands not working?**
- Commands are sent exactly as typed - don't include `//`
- Check Windower's console for any error messages

**Commands not reaching other characters?**
- Make sure StreamDeckBridge is loaded on all characters (`//lua load streamdeckbridge`)
- Verify the character name in the Stream Deck button matches the in-game character name

## License

MIT License - Feel free to use and modify.
