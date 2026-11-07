# Screenshots

ReaPack shows `<link rel="screenshot">` images in the package browser. The index
advertises a screenshot for a package **only when the matching file exists here**,
so adding one is a two-step job:

1. Capture it in real REAPER, crop tightly, and save it as
   `docs/screenshots/<package file name>.png`
   (e.g. `docs/screenshots/SGM_auto_master.lua.png`).
2. Run `python3 tools/gen_index.py`, then commit the PNG and `index.xml` together.

Naming matters: `tools/gen_index.py` maps package → PNG by exact file name, so a
typo in the name means the screenshot is silently left out.

Keep PNGs under ~200 KB (ReaPack downloads them when the user opens the package
details, and the repository is fetched by every user who imports the index).

Nothing here is generated: a screenshot has to show the script actually doing
something in REAPER, otherwise it is worse than no screenshot.

## Suggested captures

| Script | Shot that sells it |
|--------|--------------------|
| `SGM_auto_master.lua` | Master FX chain after a run: ReaEQ with the 30 Hz high-pass, ReaComp, ReaLimit |
| `SGM_route_mix_bus.lua` | TCP with the Mix Bus folder and the send arrows from the selected tracks |
| `SGM_FieldyBagToggle.lua` | The bass track's FX chain, slots 1–3 lit and 4–6 dimmed (or vice versa) |
| `daw-discovery-analyzer.lua` | Console report plus the Performance Meter next to it |
| `rule-of-30-session-builder.lua` | The 48-track skeleton in the TCP, folders collapsed |
| `phase-alignment-tool.lua` | Two DI takes with transient markers before/after an align |
