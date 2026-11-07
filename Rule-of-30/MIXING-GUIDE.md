# Rule of 30 — Mixing Guide

A working, step-by-step procedure for finishing a track from an AI-generated
source (Suno/Udio) or a hybrid session, inside REAPER, using the plug-in
collections assumed below.

**Order of operations is the whole point.** Almost every "my mix sounds bad"
report is a stage crossed too early: EQ before restoration, compressor before
balance, limiter before the mix is clear. The eleven stages below are cumulative
— do not start stage 4 with stage 2 unfinished.

> **On the name.** "Rule of 30" is the existing name for this production system.
> The thirty numbered rules at the end are the operating spine of *this* guide —
> a checklist, not a doctrine that came from anywhere else.

**Assumed tools**

| Collection | What it is for here |
|---|---|
| iZotope RX (Advanced assumed) | Stage 2. Restoration, spectral repair, azimuth, de-reverb. Nothing else does this as well. |
| iZotope Ozone | Stage 11. Master bus, imager, stabilizer, maximizer. |
| Waves Ultimate | Stages 5–10. Dynamic EQ (F6/C6), buses (SSL G), transient (Smack Attack/Trans-X), bass (RBass/LoAir), vocal riding (Vocal Rider), modulation/doubling (Doubler). |
| Kilohearts Ultimate | Stages 4–8. **Carve EQ** (sidechain dynamic EQ — the de-masking workhorse), **Disperser** (allpass), **Slice EQ**, Snap Heap/Multipass for M/S chains, Phase Plant for layers. |
| REAPER stock | Routing, sidechain plumbing, ReaFIR, spectral edits, ReaEQ/ReaComp. |

Values below are **starting points**, not prescriptions. Every one needs an
A/B test on your own source, and every one should be checked in mono before it
is believed.

---

## Stage 0 — Source selection (before you touch a plug-in)

The single biggest quality decision, and it costs nothing.

1. **Generate more than you need.** Produce 4–6 candidates, then pick the one
   with the best arrangement and the *cleanest top end*. A better balance is
   fixable; baked-in generation artifacts are only partly fixable.
2. **Download WAV, not MP3 — and understand the caveat.** Suno's WAV is the
   "pristine" path out of the latent decoder, but support has confirmed it is not
   lossless in the usual sense: the model synthesises high frequencies at decode
   time, so the top octave is generated, not recorded. MP3 sometimes sounds
   *better* on harsh material precisely because it throws away some of that
   synthetic top end. Judge per track; do not assume WAV always wins.
3. **Use Studio 2.0 multitrack export where you can.** It gives 32-bit float /
   48 kHz stems (Auto Split = up to 12, Split from Mix, Advanced Split ≈100
   targetable instruments). Compare Auto Split with Advanced Split per stem —
   one is often clearly cleaner, and stems are where the useful control lives.
4. **Note the model and mode you used.** Max Mode is Suno's own recommendation
   for anything over ~2 minutes; several users report standard-mode mixes going
   muffled after about 2:30. If the back half of a track degrades, regenerate
   with Max Mode before you try to EQ the problem out.
5. **Check the length ceiling before arranging.** 8 minutes per generation on
   v6/v6-wild/v6-mini. Past that you must Extend, and every join is a drift risk
   (see `PROMPTS.md`).

**Do not** convert MP3 → WAV and call it an upgrade. Converting a container does
nothing for content.

---

## Stage 1 — Session prep and gain staging

1. **Import at native rate.** 48 kHz project if your stems are 48 kHz. Set
   project timebase appropriately; if stems came as "Tempo-Locked WAV", confirm
   the tempo before stretching anything.
2. **Label and colour-code by role**, not by instrument name: `KICK`, `BASS`,
   `DRUMS`, `RHYTHM`, `PADS`, `VOX LEAD`, `VOX SUPPORT`, `FX`. Role is what the
   de-masking in stage 4 is actually about.
3. **Gain stage by clip, not by fader.** Bring each stem down with item gain so
   it peaks around −12 to −18 dBFS before any processing. Suno output is dense
   and already limited; arriving at the chain hot makes every compressor and
   saturator overreact.
4. **Build the bus tree now**: drums, bass, guitars/synths, vocals, FX returns,
   and a mix bus. Two mix-bus points matter later — the reference bus and the
   master.
5. **Set a reference track** at the same perceived loudness as your working mix.
   Level-matched comparison only; unmatched references teach you the wrong thing.

---

## Stage 2 — Restoration (iZotope RX) — do this *before* any EQ

Mastering makes generation artifacts worse. Restoration first, always.

Run **per stem** where you have stems, on the whole mix only where you don't.

Working order inside RX:

1. **De-clip** if anything is flat-topped.
2. **De-hum** (50/60 Hz) if there is mains buzz. Rare in generated audio, common
   in uploaded samples.
3. **Spectral De-noise** — a light pass only, learned from a genuinely quiet
   moment. Heavy de-noising dulls a dense mix faster than the noise ever did.
4. **De-reverb on the vocal stem.** This is the highest-value step in the whole
   stage: generated vocals arrive drowned in the model's own reverb and delay.
   Remove it and blend back to roughly **70% processed / 30% dry** (or automate
   the blend). Half the "muddy vocal" problem usually disappears and no EQ was
   involved.
5. **De-crackle / De-click** for the sparkle and crackle artifacts; De-plosive
   for p/b pops; De-ess for genuine sibilance (see the caveat in
   `SUNO-AI-SOURCE-FIXES.md` — about half of what sounds like sibilance in
   generated audio is codec noise, and a de-esser cannot remove noise).
6. **Spectral Repair for individual artifacts** — the scalpel. Modes matter:

   | Mode | Use when | Limit |
   |---|---|---|
   | Attenuate | Event does not fully hide the music (noise bursts, clicks) | Unlimited vertical, 10 s 2D |
   | Replace | Badly damaged tonal section | 10 s |
   | Pattern | Repeated event with similar surroundings | 4 s |
   | Partials + Noise | Sustained notes, vibrato, harmonically dense music | 4 s |

   Selection tool by shape: **Frequency (F)** for a narrow whistle or ring that
   runs across time, **Brush (B)** for a squeak, **Time-Frequency (R)** for a
   click. Always solo what the repair *removes*: if you can hear melody or drum
   attack in it, you are removing music.
7. **Azimuth** — check L/R timing alignment. This is the direct fix for the
   reported v6 symptom where the right channel sits slightly later/differently to
   the left, producing comb filtering and "fizzy" or crackly vocals.
8. **Loudness Control** — do not use it to make things loud. Use it only to
   document what you received; loudness belongs to stage 11.

### The no-RX route (REAPER only)

- **ReaFIR → Subtract mode**: build a noise profile from a section containing
  only the artifact, FFT 1024, "Precise". Ctrl/Cmd-drag the profile down until the
  robotic/flanging side-effect clears. Only works on *stationary* noise.
- **Spectral edits**: View → Peaks display settings → Spectrogram, then
  right-click the item → Spectral edits → Add spectral edit to item, and draw
  the band/time box directly over the artifact. This is a per-item, non-destructive
  notch and is excellent for a narrow ring that moves.
- **Item FX vs track FX**: put restoration on item/take FX so it travels with the
  clip when you comp or duplicate.

---

## Stage 3 — Corrective EQ

Corrective only. No tone shaping yet, no boosting into a problem.

1. **High-pass everything that is not a bass instrument**, but gently and by
   listening. Typical: vocals 80–100 Hz, snare 90–120, guitars 80–110,
   pads/keys 150–250, reverb returns 300–500. Do not make this a rule applied
   with your eyes closed; over-high-passing is the single most common way an
   AI-sourced mix ends up thin.
2. **Hunt, don't guess.** Narrow boost (Q 10–15), sweep, find the resonance, then
   invert it into a cut of the same width. Reset the boost.
3. **Cut the actual offender, not the whole bus.** If the mix is cloudy, find
   *which* layer is dumping 200–500 Hz. A 2 dB cut on one pad is worth 6 dB of
   master-bus surgery.
4. **Dynamic rather than static where the problem comes and goes.** AI sources
   vary section to section; a static cut that fixes the chorus will hollow the
   verse.
5. **Never cut to fix masking that de-masking would solve better.** Go to stage 4.

Reference ranges for generated/problem sources — treat as a map, not an order:

| Range | What lives there | Typical first move |
|---|---|---|
| < 30 Hz | Rumble, DC, sub-rumble | Gentle HPF, high-pass the reverb returns |
| 50–70 | Kick fundamental | Keep, do not scoop |
| 80–120 | Bass body / kick weight | Separate kick and bass roles before EQ |
| 200–500 | **Mud, boxiness** (the big one) | Small dynamic cut, 1–3 dB, on the offender |
| 800–1.2k | Growl, nasal | Narrow cut if congested |
| 2–4k | Presence, vocal intelligibility | Carve instruments here, not boost vocals |
| 5–9k | Harshness, sibilance, "AI fizz" | Dynamic cut + de-esser, narrow |
| 10–16k | Air — **and the AI cutoff** | Check the spectrogram first |
| > 16k | Often nothing but synthetic residue | Cut if fizzy; don't boost what isn't there |

---

## Stage 4 — De-masking (frequency masking)

Masking is not an EQ problem at its root; it is a **role collision** problem.
Two elements claiming the same band at the same time cannot both be audible.

**The method — carve, don't boost:**

1. **Write the role map** for the chorus, the densest section, before touching
   anything. One element owns each band:

   | Band | Owner in a dense electronic/metal mix |
   |---|---|
   | 30–60 | Kick sub |
   | 60–120 | Kick body + bass fundamental (split by time, not by EQ) |
   | 120–300 | Bass upper body, low toms, low vocal body |
   | 300–800 | Guitar/throat body, vocal body — the crowding zone |
   | 800–2k | Bass growl, guitar bite, vocal core |
   | 2–4k | Vocal presence wins. Everything else yields. |
   | 5–9k | Snare snap, vocal air, hats |
   | 10k+ | Cymbals, air |

2. **Duck, don't slice.** Static EQ cuts are a compromise made 100% of the time
   to fix a problem that exists 20% of the time. Use **dynamic EQ keyed from the
   competing element** instead:
   - Kilohearts **Carve EQ** (sidechain input per band) — the cleanest tool for
     this in your collection.
   - Waves **F6** or **C6** in dynamic/sidechain mode.
   - REAPER + ReaEQ (parameter modulation) or Pro-Q-style dynamic bands.
3. **1–3 dB is a lot.** If you need 6 dB to hear the vocal, the arrangement or
   the balance is wrong, not the EQ.
4. **Re-evaluate at the section level.** Masking in the breakdown is different
   from the chorus; automate the carve bands in and out with the arrangement.
5. **The last resort is arrangement.** Muting a layer in a verse creates clarity
   no EQ can. This is free and always works.

---

## Stage 5 — Dynamics

Only now, and only if the balance is already right.

1. **Compress for consistency, not for volume.** Gain reduction peaks of 2–4 dB
   on a bus; 3–6 dB on a vocal.
2. **Set attack by what should survive.** Transient you want to keep: 10–30 ms.
   Control you want to impose: 1–5 ms. Release long enough to avoid pumping —
   100–250 ms typical, and always check it against the tempo.
3. **Suno output is already heavily limited and ducked.** If a stem fights the
   compressor, the stem was over-processed at generation time; back off rather
   than compress harder.
4. **Multiband only for a specific problem.** ReaXcomp / C6 / LinMB when one band
   is misbehaving — not as a default on every track.
5. **Transient design instead of compression** where the source is flat: Waves
   **Smack Attack** or **Trans-X**, or Kilohearts **Transient Shaper** inside
   Multipass. On AI drums this recovers punch that compression cannot.
6. **Ride, don't squash.** Waves **Vocal Rider** / **Bass Rider** for the
   line-to-line inconsistency that generated audio is full of. Clip-gain
   automation in REAPER can do the same job for free.

---

## Stage 6 — Sidechain

Full technique list is in `TECHNIQUES.md`. The routing, concretely, in REAPER:

**Kick → bass ducking (stock)**

1. Bass track: I/O → **Track channels: 4**. Leave *Parent channels* at `1-2` so
   channels 3/4 do not leak to the master.
2. Kick track: create a send to the bass track, **Audio 1/2 → 3/4**.
3. Bass track: add **ReaComp**. Set **Detector input = Auxiliary input (L+R)**.
4. Start: Threshold to give 3–5 dB of reduction on each kick, Ratio 2–4:1,
   Attack 5–10 ms, Release 80–150 ms, Pre-comp 0–3 ms.
5. **Tune the release to the track, not the genre.** At 100 BPM a quarter note is
   600 ms; a release that breathes back in before the next kick flattens the
   groove, one that's too slow swallows the offbeat.

**Cleaner version** — replace ReaComp with a dynamic EQ band (Carve EQ / F6) so
only the sub band ducks and the bass's midrange stays intact. This is almost
always better on dense material.

**Vocal → instrument ducking** — send the vocal bus to the instrument bus on 3/4,
then duck 1.5–4 kHz by 1–3 dB in Carve EQ keyed to that input. You get vocal
clarity without EQ'ing the vocal brighter, which is what makes vocals sound
artificial.

**Do not** sidechain-compress the whole instrument bus from the vocal. That
produces the "breathing mix" tell of amateur AI finishing.

---

## Stage 7 — Depth and width

This is where most of the internet's advice is wrong, so it is spelled out fully
in `TECHNIQUES.md` §Depth. The short version:

- **Real depth comes from four cues**: direct-to-reverb ratio, high-frequency
  loss with distance, transient smearing, and level. A millisecond offset is not
  a depth cue; it is a phase trick with a specific mono cost.
- **Offsetting a duplicate of the same take does not create depth — it creates
  comb filtering.** A delay of *d* ms puts its first null at `1000/(2d)` Hz and
  then nulls every `1000/d` Hz. 3 ms → first null at 167 Hz, then every 333 Hz.
  20 ms → first null at 25 Hz, then every 50 Hz. On a guitar that is heard as
  hollow, phasey, and it collapses in mono.
- **Offsetting two genuinely different takes** is fine and is just performance
  timing — but the depth you hear comes from them being different, not from the
  offset.
- **What to use instead**: detune-based double (Waves Doubler, ±5–9 cents with
  short modulated delay), allpass decorrelation (Kilohearts **Disperser** — mono
  compatible), M/S tools that keep the lows mono (Waves S1, Ozone Imager), and
  filtered early reflections.

**Width discipline**

1. Mono everything below 80–120 Hz (M/S EQ or Imager). AI sources routinely have
   wide sub-bass that vanishes on club systems.
2. Check correlation on every widened element, and check the *whole mix* in mono
   at each stage, not at the end.
3. A wide element and a centred element in the same band fight; widen the one
   that should be a texture, keep the one that carries the groove centred.

---

## Stage 8 — Harmonics and saturation

1. **Saturate to add density the source lacks, in parallel.** Duplicate the
   track/bus, distort hard, high-pass the distorted copy at 200–300 Hz, blend at
   −12 to −20 dB. This adds perceived loudness without the pumping of compression.
2. **Faturator / Kramer Tape / NLS / J37** for colour; **Disperser** for
   transient "smear" that reads as impact rather than distortion (allpass, so it
   stays phase-coherent — useful where a normal saturator smears the top).
3. **Rebuild a weak low end with harmonics, not sub.** Waves **RBass** /
   **MaxxBass** generate harmonics above the missing fundamental so small
   speakers imply the note. Suno bass is frequently weak in this exact way.
   **LoAir** / sub-synthesis should be a last resort and must be high-passed
   above ~30 Hz or it just eats headroom.
4. **Never saturate a signal that has not been de-noised.** Saturation amplifies
   artifacts along with harmonics.

---

## Stage 9 — Reverb and delay

1. **Filter every return.** High-pass at 300–500 Hz, low-pass at 6–10 kHz.
   Unfiltered returns are the second-biggest source of mud after stacked
   low-mids.
2. **Pre-delay for clarity, not for size.** 20–40 ms separates the word from the
   tail and keeps the vocal in front.
3. **Depth is dry/wet balance over time.** Automate the send up into the chorus
   and down in the verse; a static reverb is what makes a mix sound flat and
   "AI".
4. **Short room + long plate, low levels.** Two small reverbs beat one huge one.
5. **Delay: 1/8 dotted and 1/4 for the body, and duck the delay return** with a
   sidechain from the dry vocal so repeats never fight the words.

---

## Stage 10 — Bus and loudness

1. **Glue compression on the mix bus**: SSL G-Master / ReaComp, 1–2 dB of
   reduction, slow attack (10–30 ms), auto/fast release. Purpose is cohesion,
   not loudness.
2. **Check the mid/side balance** at the bus; if the side channel is louder than
   the mid on a dense mix, the mono fold-down will be thin.
3. **Do not stack limiters.** If the source arrived limited, your chain should be
   compressors and clippers, not another maximiser.

---

## Stage 11 — Master and delivery

1. **Ozone, in this order**: correct → balance → loudness. Master Assistant is a
   *starting point* to be judged, not an authority; it cannot hear that your
   vocal is buried by one bad layer.
2. **Maximizer**: target −14 LUFS integrated for streaming (−9 to −11 only if the
   client asks and accepts the loss), true peak ≤ −1.0 dBTP.
3. **Stabilizer** for the low-end inconsistency AI sources have; **Imager** to
   keep the bass mono and re-widen the rest.
4. **Render 24-bit WAV at the project rate**, and keep the un-mastered mix.
5. **Deliver a mono reference too**, so any phase damage is caught before release.

---

## Translation QA — the last gate

Run all six; none are optional.

- [ ] Mono: bass and kick still present, vocals still intelligible.
- [ ] Phone speaker: the vocal is understandable at low volume.
- [ ] Car: no boominess between 100–300 Hz.
- [ ] Headphones: no artifacts you can only hear there — if you hear them, they
      are in the file, not in the room.
- [ ] Reference A/B level-matched, at least three times across the session.
- [ ] Loudness: −14 LUFS integrated, ≤ −1 dBTP, no inter-sample clipping.

---

## Plug-in → job map

| Job | First choice | Backup |
|---|---|---|
| Artifact removal | RX Spectral Repair / De-crackle | REAPER spectral edits, ReaFIR |
| De-reverb vocal | RX De-reverb | RX Dialogue Isolate (light) |
| L/R timing | RX Azimuth | Manual item nudge |
| Corrective EQ | Any EQ, narrow | ReaEQ |
| Dynamic EQ de-masking | Kilohearts Carve EQ (sidechain) | Waves F6 / C6 |
| Resonance taming | Dynamic EQ narrow band | Soothe-style if owned |
| Sidechain duck | Carve EQ band | ReaComp (Aux input) |
| Vocal consistency | Vocal Rider | Clip-gain automation |
| Transient repair | Smack Attack / Trans-X | Kilohearts Transient Shaper |
| Sub-harmonic / weak bass | RBass / MaxxBass | LoAir (careful) |
| Saturation | Faturator / Kramer Tape | Multipass parallel chain |
| Phase-coherent "smear" | Disperser | — |
| Widening | Waves Doubler, S1 | Ozone Imager, Kilohearts Haas |
| Glue | SSL G-Master buss | ReaComp |
| Loudness | Ozone Maximizer | L4 / L3-LL |

---

## The thirty rules

1. Fix the source before the mix.
2. Restore before you EQ.
3. Balance before you compress.
4. Mix before you master.
5. One element owns each band.
6. Cut the offender, not the bus.
7. Prefer dynamic over static.
8. 1–3 dB is a large move.
9. High-pass by ear, not by rule.
10. Never boost what is not there.
11. Check mono before you believe width.
12. Mono below 80–120 Hz.
13. A millisecond offset is not depth.
14. Depth = reverb ratio + HF loss + transients + level.
15. Filter every reverb and delay return.
16. Duck, don't slice.
17. Sidechain the band, not the whole bus.
18. Ride the level before compressing it.
19. Compress for consistency, limit for loudness — never both at once.
20. Saturate in parallel.
21. De-noise before saturation.
22. Automate the arrangement, not just the effects.
23. Mute a layer before adding an EQ.
24. Long release beats fast release on anything with a groove.
25. Compare level-matched or not at all.
26. If it only sounds better louder, it is not better.
27. Every artifact you can hear is in the file, not the room.
28. Keep the un-mastered mix.
29. Deliver a mono reference.
30. If two moves disagree, the arrangement is wrong.

---

## Sources

- iZotope RX module behaviour and Spectral Repair mode limits — iZotope documentation, summarised at `soundforgepro.com/izotope-rx-spectral-repair/`.
- Haas/precedence window and the comb-filter maths (`f = 1000/(2d)`, nulls every `1000/d` Hz) — `kernaudio.io/guides/stereo/haas-and-allpass-decorrelation`; Haas 1949, precedence effect.
- Suno stem export modes and 32-bit/48 kHz multitrack limits — Suno Studio 2.0 documentation; `suno.com/landing/stem-player/`.
- Suno WAV-is-not-lossless statement and community measurement threads — r/SunoAI, `comments/1pjz3ji`.
- Max Mode recommendation (Suno's own copy) and 8-minute per-generation ceiling — Suno help centre, as summarised in `undetectr.com/blog/suno-extend` and `songsmith.studio/blog/how-to-make-full-length-songs-on-suno`.
- De-reverb-then-blend-~70%-dry approach for generated vocals — `neuralanalog.com/docs/improve-suno-ai-audio-quality`.
- REAPER ReaFIR subtract-mode and spectral-edit workflow — `integraudio.com/how-remove-noise-in-reaper/`.
