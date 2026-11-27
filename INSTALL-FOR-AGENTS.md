# Frostlands install guide for AI agents

You are an AI agent (Claude Code, Cursor, Codex or similar) installing **Frostlands** for a player. Follow the steps in order. Every step says how to check it worked. Ask the player before closing their Minecraft launcher or game, and before changing anything outside the folders named here.

**What gets installed**
- **Hearth**: a shader pack, `Hearth.zip`.
- **Hearth Christmas & Magic**: a Fabric mod, `hearth-christmas-1.0.0.jar`. It adds the **Frostlands** world type (a generator for the designed 15,000-block island world) plus Christmas items.
- What they need:
  - **Fabric Loader**, **Fabric API**, **Sodium**, **Iris**: required.
  - **Boats N Waves**: strongly recommended, for real ocean waves and boat physics.
  - **Distant Horizons**: optional, for far views.

**Target:** Minecraft Java **26.3**, Java 25. The Minecraft launcher ships its own Java.

---

## 0. Find the Minecraft folder and check the basics

| OS | Minecraft folder (`$MC`) |
|---|---|
| macOS | `~/Library/Application Support/minecraft` |
| Windows | `%APPDATA%\.minecraft` |
| Linux | `~/.minecraft` |

Check:
- `$MC/versions/26.3/26.3.json` exists. If it doesn't, ask the player to open the official Minecraft launcher and play **26.3 vanilla** once, then quit.
- The Minecraft launcher and game are **closed** before you edit files. Ask the player to close them.

Then check whether the player already has Fabric for 26.3:
- `ls "$MC/versions"` and look for `fabric-loader-*-26.3`.
- If it's there, skip step 1.

## 1. Install Fabric Loader (only if missing)

Download the official installer and run it in CLI mode with the Java that ships with Minecraft:

```bash
curl -L -o /tmp/fabric-installer.jar https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.1.2/fabric-installer-1.1.2.jar
```

Find a Java 25 runtime:
- macOS: look inside `$MC/runtime/java-runtime-*/mac-os-arm64/*/jre.bundle/Contents/Home/bin/java`.
- Windows and Linux: look inside `$MC/runtime/java-runtime-*/.../bin/java`.
- Or use any Java 25 on PATH.

```bash
"$JAVA" -jar /tmp/fabric-installer.jar client -dir "$MC" -mcversion 26.3 -loader 0.19.5
```

Check: `$MC/versions/fabric-loader-0.19.5-26.3/` now exists, and the launcher shows a **fabric-loader-0.19.5-26.3** installation. Newer loaders (0.20.x) also work.

## 2. Choose the mods folder

**Recommended:** give Frostlands its own game folder so the player's existing setup stays untouched.
1. Create `$MC/frostlands` with a `mods/` and a `shaderpacks/` folder inside it.
2. In the Minecraft launcher, go to Installations → New installation:
   - Version: `fabric-loader-0.19.5-26.3`
   - Game directory: `$MC/frostlands`
   - Name: "Frostlands"
   - JVM arguments: set `-Xmx6G` or more (`-Xmx4G` on 8 GB machines).

   If you edit `launcher_profiles.json` directly instead, only do it with the launcher closed.

Call that game folder `$GAME`. If the player says to use their existing Fabric profile instead, set `$GAME = $MC`.

**Do not delete** anything already in `$GAME/mods`. If a mod is already present at a 26.3 version, keep it and skip downloading it.

## 3. Download the required mods from Modrinth (with checksum check)

For each slug below, ask the Modrinth API for the newest **release** (not beta) for Fabric 26.3:

```bash
curl -s -G "https://api.modrinth.com/v2/project/<slug>/version" \
  --data-urlencode 'loaders=["fabric"]' --data-urlencode 'game_versions=["26.3"]'
```

For each one:
1. Take the first entry whose `version_type` is `"release"`.
2. Download its primary file (`files[].primary == true`) into `$GAME/mods/`.
3. Verify `files[].hashes.sha512` matches `shasum -a 512` (or `sha512sum`) of the download.
4. If the hash doesn't match, delete the file and stop.

| Slug | Mod | Known-good version (what Frostlands is tested with) |
|---|---|---|
| `fabric-api` | Fabric API | 0.165.2+26.3 or newer |
| `sodium` | Sodium | 0.9.2 / 0.9.3 (release, not the 0.9.4 betas) |
| `iris` | Iris Shaders | 1.11.7+mc26.3 |
| `distanthorizons` | Distant Horizons (optional) | 3.3.4-26.3 |

Check: all the `.jar` files are in `$GAME/mods/`, and each checksum matched.

## 4. Boats N Waves (CurseForge, the player clicks the download)

Boats N Waves isn't on Modrinth. It's on CurseForge: https://www.curseforge.com/minecraft/mc-mods/boats-n-waves

1. Open that page for the player and point them to **Files**.
2. The file to get is the **Fabric 26.3** file `ships-n-waves-0.1.0.jar` (or newer). It already contains the Realistic Waves and Slipway mods.
3. CurseForge usually needs a person to click Download. Ask the player to do it, then move the jar from their Downloads folder into `$GAME/mods/`.

Check: `$GAME/mods/ships-n-waves-*.jar` exists.

After the first launch, open `$GAME/config/realwaves.properties`:
- `vanillaWaves` **must be `false`**. Hearth draws the waves; the mod's own vanilla drawing glitches with shaders.
- `waveScale=1.4` gives Frostlands' big seas. 1.0 is calmer.

## 5. The Frostlands mod and the Hearth shader (from this repository's release)

Latest release: https://github.com/abizarresid/Frostlands-Minecraft/releases/latest

```bash
curl -L -o "$GAME/mods/hearth-christmas-1.0.0.jar" https://github.com/abizarresid/Frostlands-Minecraft/releases/latest/download/hearth-christmas-1.0.0.jar
curl -L -o "$GAME/shaderpacks/Hearth.zip"           https://github.com/abizarresid/Frostlands-Minecraft/releases/latest/download/Hearth.zip
```

Check:
- `unzip -l "$GAME/shaderpacks/Hearth.zip"` lists `shaders/...` at the top level. **Do not unzip it.**
- `unzip -l "$GAME/mods/hearth-christmas-1.0.0.jar" | grep frostlands/terrain.bin` finds the map data.

## 6. First launch and settings (tell the player to do these in game)

1. Launch the **Frostlands** installation.
2. Go to Options → Video Settings → **Shader Packs** → select **Hearth**.
3. Open **Shader Options** and pick a profile at the top:
   - **Laptop**: MacBooks and other laptops without strong cooling.
   - **Potato**: weak machines.
   - **Balanced** or **High**: gaming PCs.
4. Suggested video settings on laptops: Render Distance 10–12, Max Framerate 45–60.

Check: the Hearth options menu has Look Style, Sunset, Night & Moon, Lighting, Water, Atmosphere and Post.

## 7. Making a Frostlands world (single player)

1. Go to Singleplayer → Create New World → More World Options → **World Type: Frostlands**.
2. The player spawns on the shipwreck beach of the starting island.
3. Useful commands, with cheats on:
   - `/tp @s 205 225 5155`: Mount Ashen, the volcano on Si's island.
   - `/tp @s 0 110 0`: the mainland.
   - `/worldborder set 15000`: the world's edge.

**Important:** the Frostlands world is still in development:
- It has the terrain, lakes and rivers, caves, roads and bridges, and flat building sites, but no village buildings yet.
- Worlds made with this version **won't update** when the generator changes.
- If the player already has the older `hearth-christmas-1.0.0.jar`, replace it with the new download (same file name) and make a new world.

The real game will be one shared world that everyone joins. Use this version to look around, not to build anything permanent.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Crash: "requires fabric-api" | Fabric API is missing. Do step 3 again. |
| Shader pack shows an error | Make sure it's `Hearth.zip` (zipped) and Iris is 1.11.x for 26.3. |
| No "Frostlands" world type | `hearth-christmas-1.0.0.jar` is missing from `$GAME/mods`, or the game is using a different folder. |
| White blobs and smeared seagrass on water with shaders **off** | Set `vanillaWaves=false` in `realwaves.properties`. |
| Very hot laptop / low FPS | Hearth profile **Laptop** or **Potato**; render distance 10; Max Framerate 45; Distant Horizons LOD distance 64. |
| Odd behaviour with C2ME (alpha) installed | Remove C2ME for Frostlands worlds; it's an experimental chunk-generation optimiser. |
