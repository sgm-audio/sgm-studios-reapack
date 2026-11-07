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
| **SGM-Essentials** | 5 actions + shared library | Mix bus routing, one-click mastering, bass FX chain toggle, theme colour generator + smart-tool mode reporter, DAW environment profiler |
| **Rule-of-30** | 2 actions + preset library | 48-track heavy metal session builder (Drop Bb, quad guitars), plugin chain reference, quad-DI phase alignment |

## Repository layout

```
index.xml                     ReaPack package index (generated, do not hand-edit)
SGM-Essentials/               Bundle sources + README / INSTALL / CHANGELOG / TEST_CASES
Rule-of-30/                   Bundle sources + README / INSTALL / CHANGELOG / TEST_CASES
tools/gen_index.py            Regenerates index.xml from the script headers
tools/check_api.py            Fails on any reaper.* call that is not real
tools/api_allowlist.json      The real ones (REAPER 7.83 SDK header)
tests/                        Mock-API suites (91 cases, no REAPER needed):
                              run_tests.lua (22), run_phase_tests.lua (18),
                              run_builder_tests.lua (26), run_theme_tests.lua (25)
tests/fixtures/               Real .ReaperTheme sample + the published key list
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
lua5.4 tests/run_theme_tests.lua     # 25 theme-format / colour / claim checks
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

Everything in this repository is MIT — see [LICENSE](LICENSE). Free for personal
and commercial use, no strings attached beyond the usual two conditions:

- **Keep the copyright notice.** If you redistribute these scripts (in a bundle,
  a course, a starter template, a fork), keep the `@license` line and the
  `LICENSE` file with them. Every script carries the line in its header, so this
  is hard to do by accident.
- **No warranty.** These scripts change project state. Nothing here comes with
  any guarantee that it does the right thing in your session.

You do not need to ask before forking, rebranding, selling a product built with
these, or shipping modified copies. There is no attribution requirement beyond
the notice above, no share-alike clause, and no restriction on commercial use.

### What "MIT" covers here, and what it does not

- **Covered:** all Lua scripts in `SGM-Essentials/` and `Rule-of-30/`, the test
  suite, and this repository's documentation. All of it is MIT.
- **Not covered:** REAPER itself, the SWS extension, and any plug-in these
  scripts drive. Those are their owners' software. The scripts call the ReaScript
  API; they do not contain or redistribute any of it.
- **Theme output:** a `.ReaperTheme` file produced by
  `SGM_reaper_ultra_hd_smart_tools.lua` is derived from the theme you had loaded
  at the time. It inherits that theme's images, fonts and remaining colours, so
  it is a derivative of *that* theme, not of this MIT-licensed code.

  The colour values the script writes are MIT. Everything it carried over is
  not — and that is the part people get caught by when they share a recolour.
  **[LICENSE-THEMES.md](LICENSE-THEMES.md)** sets out what you may share, what
  to carry with it, and the one way to build a theme with no obligations at all
  (start from REAPER's stock Default theme). Generated files now carry the
  source theme's name in their header so this is checkable after the fact.
- **Paid products:** the Suno AI Workflow Suite and Hip-Hop/EDM Session Builder
  listed above are sold separately and are not part of this repository or this
  licence.
