# Hearth

A cosy, moody Iris shader pack for Minecraft 26.3, made for the **Frostlands** world.

It draws the big ocean waves from the **Boats N Waves** mod, so the boats ride the same sea you see. It also tries to stay cool on a fanless MacBook Air.

## Install

**Easiest:** ask your AI agent (Claude Code, Cursor and so on) to *"follow INSTALL-FOR-AGENTS.md in https://github.com/abizarresid/Frostlands-Minecraft"*. It has every step, with download links and checks. [Read it here](INSTALL-FOR-AGENTS.md).

**By hand:**

1. **Fabric** for Minecraft 26.3: run the installer from https://fabricmc.net/use/installer/ (Loader 0.19.5 or newer).
2. **Mods** go in your `mods` folder:
   - **Fabric API**: https://modrinth.com/mod/fabric-api
   - **Sodium**: https://modrinth.com/mod/sodium. Use a release, not a beta.
   - **Iris**: https://modrinth.com/mod/iris
   - **Boats N Waves**, for the real ocean waves: https://www.curseforge.com/minecraft/mc-mods/boats-n-waves (Fabric 26.3 file `ships-n-waves-0.1.0.jar`).
   - **Frostlands world + Christmas mod**: `hearth-christmas-1.0.0.jar` from the latest [Release](../../releases/latest).
   - **Distant Horizons**, optional, for far views: https://modrinth.com/mod/distanthorizons
3. **Shader:** put **`Hearth.zip`** from the latest [Release](../../releases/latest) in your `shaderpacks` folder. Don't unzip it.
4. **In game:** Video Settings → Shader Packs → **Hearth**, then pick a profile at the top of Shader Options.
5. **After the first launch:** in `config/realwaves.properties`, set `vanillaWaves=false` (Hearth draws the waves).

### The Frostlands world

Create New World → More World Options → **World Type: Frostlands**. You wake up on the shipwreck beach of the starting island.

This is a **preview**:
- Lakes and rivers have no water yet.
- There are no caves, roads or buildings yet.
- Preview worlds won't update when the generator changes.

The real game will be one shared world everyone joins.

## Picking a profile

At the top of **Shader Options** there's a profile button:

| Profile | For |
|---|---|
| **Potato** | weak laptops: no shadows, sun rays, bloom or reflections |
| **Laptop** (default) | fanless MacBooks: light shadows, no sun rays |
| **Balanced** | mid-range PCs |
| **High** | gaming PCs |

## Looks and moods

- **Look Style:** Hearth Classic, PNW Moody, Clear Winter or Dreamy.
- **Sunset, Night & Moon:** pick a mood for each part of the day: Sunrise, Morning, Midday, Afternoon, Sunset and Night. Each look has three choices per part of the day.
- **Surface detail:** Texture Depth, Coated Textures and Block Outlines, for the crisp look.
- **Water:** Auto water colour. The sea and lowland lakes are dark forest-lake water; mountain lakes are glacial turquoise.

## Credits

- `shaders/lib/realwaves.glsl` comes from the Realistic Waves mod (MIT licence; see `shaders/lib/LICENSE_realwaves.txt`).
- Everything else was written for Hearth.
