# SGM Studios — REAPER Scripts

Free REAPER ReaScripts by **Scott Mills / SGM Studios**, distributed via [ReaPack](https://reapack.com).

## Installation

1. In REAPER: **Extensions** → **ReaPack** → **Import repositories…**
2. Paste this URL:

   ```
   https://raw.githubusercontent.com/sgm-audio/sgm-studios-reapack/main/index.xml
   ```

3. **Extensions** → **ReaPack** → **Browse packages…** → install **SGM Studios Essentials** and/or **SGM Rule of 30** → click **Apply**

## Bundles

| Bundle | Scripts | What it does |
|---|---|---|
| **SGM-Essentials** | 5 actions + shared library | Mix bus routing, one-click mastering, bass FX chain toggle, 4K theme generator + smart tools, DAW environment profiler |
| **Rule-of-30** | 2 actions + preset library | 48-track heavy metal session builder (Drop Bb, quad guitars), plugin chain reference, quad-DI phase alignment |

## Repository layout

```
index.xml                     ReaPack package index (generated, do not hand-edit)
SGM-Essentials/               Bundle sources + README / INSTALL / CHANGELOG / TEST_CASES
Rule-of-30/                   Bundle sources + README / INSTALL / CHANGELOG / TEST_CASES
tools/gen_index.py            Regenerates index.xml from the script headers
tools/check_api.py            Fails on any reaper.* call that is not real
tools/api_allowlist.json      The real ones (REAPER 7.83 SDK header)
tests/                        Mock-API suites (66 cases, no REAPER needed):
                              run_tests.lua (22), run_phase_tests.lua (18),
                              run_builder_tests.lua (26)
docs/screenshots/             ReaPack screenshots (see the README there)
.github/workflows/ci.yml      Syntax + API + tests + index validation
.reapack-index.conf           reapack-index settings (name, about, amend, links)
```

Package versions live in each script's `@version` header, and `index.xml` is
derived from those headers. After editing a header:

```sh
python3 tools/gen_index.py     # rewrite versions, changelogs and sources
python3 tools/check_api.py     # no phantom reaper.* calls
lua5.4 tests/run_tests.lua           # 22 regression cases against a mock API
lua5.4 tests/run_phase_tests.lua     # 18 phase-alignment cases (known offsets)
lua5.4 tests/run_builder_tests.lua   # 26 builder / preset / parameter cases
```

CI fails if any of the three disagrees with the repository. Sources in
`index.xml` are pinned to a commit SHA (what `reapack-index` does with its
`$commit` URL template), so a branch push cannot change the content of a
version ReaPack has already cached.

## Requirements

- REAPER 7.0+ (Lua 5.4)
- SWS/S&M Extension — optional (routing detail in the DAW analyzer and the smart-tool cursor engine)
- All scripts use REAPER stock FX by default — no paid plugins required

## Also from SGM Studios (paid)

- **Suno AI Workflow Suite** ($24) — six-script pipeline for importing and producing Suno AI tracks in REAPER
- **Hip-Hop/EDM Session Builder** ($12) — 23-track West Coast hip-hop × progressive house session

Available on Gumroad.

## License

MIT — see [LICENSE](LICENSE). Free for personal and commercial use.
