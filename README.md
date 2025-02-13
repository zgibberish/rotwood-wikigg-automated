# Rotwood wiki.gg Automated

Scripts and tools to help generate wiki content for Rotwood.

## In-game tools

The `wikiggutil` script is used to generate formatted data from game content, you can run it straight from the in-game console and there's no need to install a Lua interpreter separately.

### Installation

#### Mod

If you've patched your [modloader](https://github.com/zgibberish/rotwood-modloader), you can install the mod provided in `src/` to automatically add `wikiggutil` to `GLOBAL`.

#### Manual

- Make sure you're using extracted scripts (see [here](https://github.com/zgibberish/rotwood-mods/blob/main/docs/extracting_game_scripts.md)).
- Copy `src/wikigg-automated/scripts/wikiggutil.lua` to `data/scripts/`.
- Launch Rotwood with the `-enable_debug_console` command line flag (Right click on Rotwood in your **Steam** library and go to **Properties**).
- Hit \` to open the in-game console.
- Run `wikiggutil = require "wikiggutil"` to load the script.

### Usage

You will run these commands in the in-game console, the result will be copied to clipboard.

Example: table of all obtainable Powers.

```lua
imgui:SetClipboardText(wikiggutil.Powers.PowersTable())
```

Example: table of all obtainable Gems.

```lua
imgui:SetClipboardText(wikiggutil.Gems.GemsTable())
```

See `wikiggutil.lua` for more details.
