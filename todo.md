# todo.md — what is between this repository and "I can confidently load it in REAPER"

Written 2026-11-07, after a third audit pass. `AUDIT.md` §8 has the evidence for
every code bug listed here; this file is the work plan.

**The honest headline:** the packaging is now sound (ReaPack installs it, files
resolve, CI checks it), but *the scripts have never been run in REAPER.* Three
audit passes found 3 + 8 real defects, and every defect the static checks cannot
see turned out to be real. Two of the eight (BPM and the mastering chain) are
fatal-but-silent. Until the P0 gate below is closed, "load it in Reaper" means
"install it", not "trust it".

Legend: **P0** = blocks a confident release · **P1** = embarrassing if shipped ·
**P2** = nice to have. Each task says *how it is verified*, because "I read it
again" is what produced the bugs.

---

## P0 — must be fixed and verified in real REAPER before release

### 1. Fix the 8 confirmed defects (AUDIT.md §8 A–H)

- [ ] **A. `SGM_auto_master.lua` writes normalized values into every FX param.**
      `TrackFX_SetParam` expects 0..1. Threshold −18 dB, Ratio 2:1, Attack 10 ms,
      Release 100 ms and Ceiling −1.0 dB all become garbage; the "limiter" ends up
      at +1 dB. Fix by using `TrackFX_SetParamNormalized` with a dB→normalized
      conversion, or better, by setting normalized values that are read back with
      `TrackFX_GetParamEx` (min/max) rather than guessed.
      *Verify:* unit test that asserts the value written equals the value read back,
      plus a REAPER check that the ReaComp threshold display reads −18.0 dB.
- [ ] **B. `rule-of-30-session-builder.lua` builds every session at ~4 BPM.**
      `SetTempoTimeSigMarker` needs 9 args; the calls pass 8, shifting bpm into
      beatpos. Fix both calls, then assert the resulting tempo with
      `reaper.Master_GetTempo()` in a test instead of trusting the argument list.
- [ ] **C. `phase-alignment-tool.lua` reads the audio buffer off by one frame.**
      `new_array` is 1-based. Index with `(frame) * num_channels + 1`.
      Also: the analysis only looks at channel 1 of a stereo take — say so, or
      scan all channels.
- [ ] **D/E. Duplicate FX on repeat runs.** `TrackFX_AddByName(..., -1)` inserts a
      new instance every time. Either delete the previous instance first, or use
      `instantiate = 0`/"return existing" semantics, and make the master FX chain
      idempotent (it currently stacks ReaComp/ReaEQ on every build).
      *Verify:* run twice in a test, assert the FX count is unchanged.
- [ ] **F. Remove the fake "Alt key" check** in `SGM_reaper_ultra_hd_smart_tools.lua`
      (`GetToggleCommandState(1009)`). There is no modifier-key state API, so the
      stretch branch must go, not be disguised.
- [ ] **G. Fix the coordinate mix** in `_calculate_tool_mode` (TCP-relative,
      unscrolled `I_TCPY`/`I_TCPH` vs screen-space `GetMousePosition`). If it
      cannot be made correct, delete the ordering logic and keep the engine as a
      pure console logger — that is all `_update_cursor_visual` does anyway.
- [ ] **H. Replace action ID 40364.** It is "Options: Toggle metronome"; the
      analyzer toggles the click and tells the user it opened the Performance
      Meter. Resolve the action by name at run time with `kbd_enumerateActions` +
      `kbd_getCommandName` (prototypes confirmed in the SDK header) and print an
      honest message when it is not found. Do **not** substitute another guessed
      number.

### 2. Actually run every script in REAPER once

- [ ] `SGM_auto_master.lua` on a scratch project.
- [ ] `SGM_route_mix_bus.lua` with 3 flat tracks, then with a folder.
- [ ] `SGM_FieldyBagToggle.lua` on a track with 6 FX, then on a track with 2 FX.
- [ ] `rule-of-30-session-builder.lua` — every menu item 0–7, twice each.
- [ ] `phase-alignment-tool.lua` on two identical DI takes whose offset is known
      (e.g. duplicate an item and move one by exactly 10 ms; the tool must report
      ~10 ms and must not "fix" silence).
- [ ] `daw-discovery-analyzer.lua` — all four menu entries.
- [ ] `SGM_reaper_ultra_hd_smart_tools.lua` — theme write + smart tools start/stop.

*Why this is a task and not a footnote:* every defect this project has found was
found by reading, not by running. A single session in REAPER would have caught
BPM-in-4, the +1 dB limiter and the metronome toggle in about two minutes.

### 3. Decide what "v1.0" means for the two risky scripts

- [ ] `phase-alignment-tool` is the only near-killer feature here, and its core
      (transient detection → sample offset) is now known to be off by a frame plus
      a monotonic-only assumption. Either invest in making it correct
      (per-channel scan, cross-correlation instead of first-threshold crossing) and
      test it, or mark it experimental in the README and the ReaPack description.
- [ ] `SGM_reaper_ultra_hd_smart_tools` is two half-features in one file: a theme
      writer whose `[theme]`/`[color theme]` keys have never been checked against
      REAPER's real `.ReaperTheme` schema, and a "smart tool" engine that cannot
      change the cursor. Split them, or retire the smart-tool half.

---

## P1 — things a user will notice immediately

### 4. Recover the user's audio routing
- [ ] `SGM_route_mix_bus.lua` sets `B_MAINSEND = 0` on every routed track and saves
      **nothing** about which tracks had it before. There is no undo *inside* the
      session either (only one `Undo_EndBlock`, so Ctrl+Z does restore it — confirm
      that, and say so in the UI). Minimum: print what will change before changing
      it, and make DRY_RUN the default on first run.
- [ ] The mix bus is identified by track *name* only. One track called "Mix Bus"
      already in the project is adopted silently. Print which track was adopted and
      its index.

### 5. Stop shipping dead weight
- [ ] `SGM_Utils.lua` (1.0.1, ~500 lines, JSON parser, stem classifier, colour
      helpers) is imported by **nothing**. `rule-of-30-plugin-presets.lua` (a Waves
      /iZotope/NeuralDSP chain database) is indexed by the Rule-of-30 bundle but
      `require`d by nothing either. Both are installed for every user and can never
      run. Either wire them into the scripts that were supposed to use them, or mark
      them `@noindex` and drop them from `@provides`. Right now they are a support
      burden with zero benefit.
- [ ] `rule-of-30-session-builder.lua` also adds stock FX to tracks it never names
      in the log ("✓ Added chain: Kick In" is printed even when
      `TrackFX_AddByName` returned −1). Report per-plugin success/failure.

### 6. Size the session honestly
- [ ] The docs say "48-track session". Count the tracks the builder actually
      creates and put the real number in the README, the ReaPack description and
      the console summary — or add the missing tracks.

### 7. One-click safety net
- [ ] Every script is a **button you can press twice**. Add an explicit
      "already applied" check to auto_master (it prompts only when the master has
      FX, which is now the normal case) and to the drum/bass/guitar/vocal chain
      actions.
- [ ] Give each script a "Remove/Reset" counterpart, or at least documented manual
      undo steps in the README ("Ctrl+Z once reverts the whole chain").

### 8. Screenshots (already wired, still empty)
- [ ] Capture the six shots listed in `docs/screenshots/README.md` from real
      REAPER sessions and run `tools/gen_index.py`. ReaPack currently shows a
      website link and nothing else.

---

## P2 — make the next release cheap

### 9. Turn the new checks into tests of *behaviour*
- [ ] Extend `tests/reaper_mock.lua` so that `TrackFX_SetParam` records the value
      and `SetTempoTimeSigMarker` records all 9 args, then add the regression tests
      for A–E. All five are testable without REAPER; it is only the mock that lacks
      the fields.
- [ ] Add a test that runs every script **twice** and asserts the project is
      unchanged on the second run. That single property catches D, E and most of §7.
- [ ] Have `tools/check_api.py` flag `Main_OnCommand(<number literal>, …)` and any
      `local X_ACTION = <number>` — the class of bug in H. Require a comment with
      the action *name* and a runtime name lookup.

### 10. Release plumbing
- [ ] The ReaPack index currently deploys 1.0.x sources from commit `894f50a`,
      which still contains `GetCPUUsage`. Every fix in P0 needs a version bump in
      the header **and** a `tools/gen_index.py` run in the same commit, or users
      keep the broken build (the index pins by SHA, so nothing auto-updates).
- [ ] `.reapack-index.conf` has an unverified `--screenshot-link` and a commented
      `--donation-link`. Either fill them in correctly or delete them; a config file
      full of half-true flags is the same disease as the docs.
- [ ] Decide whether the audited `AUDIT.md` and this `todo.md` are part of the
      public face of the repo or should live in `.github/`.

### 11. Docs that match reality
- [ ] `SGM-Essentials/README.md` describes `daw-discovery-analyzer` as profiling
      "CPU/memory". It reads Lua's heap, not system RAM, and it has no CPU figure.
      Already partly fixed; confirm the wording after H lands.
- [ ] `TEST_CASES.md` files have 19 + 11 cases, all unticked, and none of them can
      be executed by CI. Convert the executable ones into `tests/run_tests.lua`
      cases so the tick boxes mean something.

---

## Definition of done

A release is "loadable with confidence" when all of these are true:

1. Every script in P0 §2 has been run in REAPER 7.x, on Windows **and** one other
   OS if available, and the observed result matches the README.
2. `python3 tools/check_api.py` and `lua5.4 tests/run_tests.lua` pass, and the test
   suite includes the A–E regressions plus a "run twice" idempotency test.
3. No script reports success for something it did not do, and no script can leave
   the UI frozen, an undo block open, or the metronome toggled.
4. Every indexed package does something its description claims; nothing is
   installed that can never run.
5. `index.xml` is regenerated, SHA-pinned to the release commit, version-matched,
   and CI proves it.

---

## Order of work I recommend

1. P0 §1 A–H in one pass (they are all in the same four files), each with a test.
2. P0 §2 — run the seven scripts once, fix what that finds.
3. P0 §3 — decide the fate of phase-alignment and smart tools.
4. P1 §4–6 — routing safety, dead weight, honest track count.
5. P2 §9 — turn it all into CI.
6. Release: version bump + `tools/gen_index.py` + PR.

Not in scope here, and deliberately so: ExtState settings, gfx menu UI, an ImGui
GUI for the analyzer. Those are product decisions, not defects. They belong after
the DoD above, not before it.
