# Rule of 30 — Technique List

Concrete mixing techniques, with numbers and the failure mode of each. Organised
by the problem you are trying to solve.

Everything here is a **starting point**. The maths is real; the taste is yours.

---

## 1. Comping

Comping an AI source is different from comping a performance: you are comping
*takes of the same prompt*, not takes of the same part. The material is
inconsistent by construction, which makes the seams the whole problem.

### 1.1 Take selection, not take splicing

1. Generate 4–6 candidates. Audition at matched level, chorus first — the chorus
   is where the arrangement and the top end fail first.
2. Mark **keepers** by section, not by whole song. A generation with a great
   chorus and a mushy verse is a keeper for the chorus only.
3. Do not comp between models. v6, v6-wild and v6-mini have different timbral
   signatures; the seam will be audible as a change of "room" even when the
   performance matches.

### 1.2 The seam itself

**The splice point is the technique.** Choose it at a transient, never in a
sustained note or a reverb tail.

| Splice at | Why | Watch for |
|---|---|---|
| Kick or snare hit (in a drum stem) | Transients mask the discontinuity | The two takes' kits differ — check the timbre before you cut |
| Consonant onset (in a vocal) | Plosive/attack conceals the join | Never mid-vowel; never inside a reverb tail |
| Downbeat of a new section | The arrangement change covers it | Levels and reverb depth may jump — automate |

Procedure for a vocal seam:

1. Split both items at the same transient, on the **zero crossing** (REAPER:
   `S` to split, then item → *Snap to zero crossing*, or `Alt+Z` mid-split).
2. Crossfade **5–15 ms** for a straight swap; **20–40 ms** if the two takes differ
   in room tone. Longer than 50 ms and you start hearing both performances.
3. Equal-power crossfade for anything wide or reverberant; linear for mono/narrow.
4. After the cut, **match the two sides' level within 0.5 dB** and their
   brightness. A seam is almost never heard as a click; it is heard as a level or
   tone step.
5. If the seam still reads, put a breath, an intake, a cymbal, or a reverb swell
   *across* it rather than trying to hide it with a longer fade.

### 1.3 Comping for word-level fixes

- For a single bad word: split tightly around the consonant, replace, and
  crossfade 5 ms. Keep the surrounding breaths from the original take — replacing
  a breath is what makes an edit obvious.
- For a bad *phrase*: replace the whole phrase, then re-time the phrase boundary,
  not the word.
- Keep a "ladder" track: a muted track holding every unused good line, aligned.
  Re-editing is then drag-and-drop rather than regeneration.

### 1.4 Comping when you cannot get clean stems

If all you have is the stereo mix, comping is limited to section-level swaps.
Then the technique is **level-matched section splice**: match LUFS of the
incoming section to the outgoing one (measure short-term, not integrated),
crossfade 30–100 ms at a transient, and re-check the mono image across the seam.

---

## 2. Layering

Layer to add what the source cannot give you — never to double what is already
there at full level.

### 2.1 The layer discipline

1. **Each layer owns a band or a role.** Two layers covering the same band at the
   same level is just a louder, muddier version of one layer.
2. **Layer for four specific jobs**: sub (30–60), body (60–200), presence
   (2–5 k), texture/air (8 k+). Pick at most two per element.
3. **High-pass and low-pass every layer to its job.** A pad layered under a
   vocal should be high-passed at 250–300 Hz and low-passed at 6–8 kHz.
4. **Level: the layer should be barely identifiable solo.** If you can name it in
   the mix, it is 3 dB too loud.
5. **Check the sum in mono.** Layers that are individually fine can cancel.

### 2.2 Kick layering

| Layer | Content | Band | Typical treatment |
|---|---|---|---|
| Sub | Sine/sub of the fundamental | 30–70 | Mono, HPF at 25–30, no compression |
| Body | The "thump" | 70–200 | Transient shaper, short comp |
| Click/attack | Beater, 2–6 k | 2–6 k | HPF, no reverb |
| Texture | Sample dirt, noise | wide | Parallel, very low |

Align all layers to the same **first transient**, not to the waveform's visual
start. Then check polarity: flip each layer and keep whichever gives more
low-end when summed.

### 2.3 Bass and kick — split the roles, not the frequencies

- **Kick owns 50–70 Hz**; **bass owns 60–120 Hz** *in the gaps*. That is a
  **time-domain** split, achieved by sidechain (see §4), not an EQ split.
- If you must split by frequency: notch the bass 2–3 dB at the kick fundamental
  and duck the kick's sub layer with a dynamic band keyed from the bass.
- The failure mode: both high-passed and low-passed into a narrow window, and the
  track has no weight anywhere. One of them must own the low end at any instant.

### 2.4 Vocal layering

- **Lead**: one take. Doubling a lead with a copy of itself is comb filtering.
- **Double**: a *different* take, panned wide, 6–10 dB down, often with a
  different (brighter or duller) chain.
- **Harmony**: thirds/sixths, filtered narrower than the lead, panned off-centre.
- **Whisper/ad-lib bus**: high-passed high, compressed hard, low level — adds
  presence without adding midrange.
- **Demon/octave layer**: pitched down an octave, low-passed at 3–4 kHz, heavily
  compressed, and *sidechained to the lead* so it never competes.

---

## 3. Frequency masking — the diagnosis

The core insight: masking is a **time-varying role collision**, so the fix is
almost always a *dynamic* tool keyed from the competing source.

### 3.1 Find the collision, don't guess it

1. **Solo-pair test**: solo the two suspects and A/B them together vs. each
   alone. If the sum is not louder *and* clearer, you have a collision.
2. **Sweep the survivor**: narrow boost on the element you want to keep, sweep to
   find where it *disappears* when the other is unmuted. That band is the
   collision.
3. **Crossover test**: put a temporary steep band-pass on the victim; if the
   element returns, that band is the masked region.
4. **Spectrum analyser overlay** (Ozone/Pro-Q with both visible) — useful for
   confirming what your ears already said, dangerous as a substitute for them.

### 3.2 Fix hierarchy — try in this order

1. **Move the arrangement** (mute, shorten, thin the layer in that section).
2. **Change level balance** by 1.5–3 dB. Masking is a level phenomenon first.
3. **Narrow/dynamic cut on the masker**, keyed from the victim (Carve EQ, F6).
4. **Static narrow cut on the masker** — last, because it applies 100% of the time.
5. **Boost the victim** — almost never; it raises the level of everything around
   it too, and on a limited AI source it just adds harshness.

### 3.3 The common pairs and their bands

| Pair | Band | Standard move |
|---|---|---|
| Kick vs bass | 60–120 | Sidechain duck (time split) |
| Vocal vs pads/synths | 1–3 k | Carve 1.5–3 dB keyed from vocal |
| Vocal vs distorted guitars | 2–4 k | Narrow guitar cut 2 k, or vocal-presence duck |
| Snare vs guitars | 200–400 and 4–6 k | Dynamic cut on guitars keyed from snare |
| Cymbals vs sibilance | 6–9 k | Dynamic cut on cymbals, de-ess vocal |
| Sub-bass vs kick sub | 30–60 | Choose one owner; mono both |
| Two pads | anywhere | One of them should not exist |

---

## 4. Sidechaining

### 4.1 What it is actually for

Three distinct jobs, often confused:

1. **Space (level)** — one element gets quieter so another is heard. Classic
   kick/bass.
2. **Movement (rhythm)** — the duck itself is part of the sound. Trance gate,
   the "pumping" bass.
3. **De-masking (frequency)** — only the colliding band is ducked, and the rest
   of the signal is untouched.

Job 3 is the one worth reaching for on dense material. Jobs 1 and 2 are old
tools and are overused.

### 4.2 Parameters, and what each actually does

| Control | Effect | Starting point |
|---|---|---|
| Source (key) | What triggers | The *transient*, not the whole bus |
| Threshold | Where ducking starts | Set so peaks give the target reduction, not to taste |
| Ratio | Depth per dB over threshold | 2:1 mild, 4:1 obvious, ∞ for gating |
| Attack | How fast the duck engages | 1–10 ms; slower = transient passes through |
| Release | How fast it lets go | 1/4 to 1/2 the beat, or 60–200 ms |
| Pre-comp / lookahead | Duck *before* the transient | 0–5 ms to preserve the kick's attack |
| Band | Which frequencies duck | The collision band only — the whole point |

**The release is the whole sound.** At 100 BPM: a quarter note is 600 ms. A
release of 600 ms breathes back exactly on the beat (obvious pumping); 150 ms
recovers in time for the offbeat (musical ducking); 60 ms is a stutter (effect).

### 4.3 REAPER routing, exactly

```
Bass track:  I/O -> Track channels: 4   (Parent channels stay 1/2)
Kick track:  Send -> Bass track, Audio 1/2 -> 3/4
Bass FX:     ReaComp, Detector input = Auxiliary input (L+R)
```

- If channels 3/4 leak to the master, you will hear the kick twice.
- For a multichannel-safe setup, use a dedicated **sidechain bus** track
  (record-disabled, muted from master) so the key survives track duplication.
- For the de-masking version: **Carve EQ**, one band at the collision frequency,
  sidechain input = the key track. 1.5–3 dB, attack fast, release tuned as above.

### 4.4 Rules that keep it musical

1. **Key from a transient, not from a full mix.** Keying from a bus makes the
   duck fight itself.
2. **Never more than 5–6 dB** of ducking unless the pumping is the effect.
3. **Check without the key.** Bypass the sidechain and confirm the track does not
   collapse when the key is silent.
4. **Tempo-lock the release**; write it in ms derived from BPM, not from a preset.
5. **Don't stack three sidechains on the same element.** Pick the two that matter.

---

## 5. Depth — what actually works

The internet's favourite trick ("nudge one guitar a few ms") is the least
reliable one in this list. Here is the real mechanism.

### 5.1 The four real depth cues

1. **Direct-to-reverberant ratio** — more reverb = farther away. The strongest cue.
2. **High-frequency loss** — air absorbs highs; distant sources are duller.
   A gentle low-pass moving with distance does more than any delay.
3. **Transient smearing** — distance softens attacks. Compression *adds* distance;
   transient shaping *removes* it.
4. **Level** — quieter reads as farther, and this is what the ear uses first.

**Practical application**: to push a layer back, cut 1–2 dB, low-pass to 8–10 k,
add 10–15% more send, and soften the attack. In that order. All four together
read as depth; any one alone reads as "EQ'd".

### 5.2 Why the millisecond offset does not do what people say

Delaying one side of a duplicated signal is the **Haas / precedence effect**. It
produces *width*, not depth, and it costs mono compatibility:

- Delay `d` ms → first cancellation at `f = 1000 / (2d)` Hz, then nulls every
  `1000 / d` Hz.
- 3 ms → null at 167 Hz, then 333 Hz spacing. That is guitar body being notched
  out — heard as hollow and phasey.
- 10 ms → null at 50 Hz, then every 100 Hz. The low end thins.
- 20 ms → null at 25 Hz, then every 50 Hz. Wide, but the bass disappears in mono.
- Under ~1 ms → pure comb filtering, no width at all.
- 1–30 ms → fused, perceived as width (the Haas zone).
- Above ~35–50 ms → a discrete echo, i.e. a delay, not a double.

**So**: if you offset a **copy** of the same guitar, you are comb-filtering it.
If you offset a **different performance**, you are just doing what double-tracking
always did — and the depth comes from the performance and mic differences, not
the offset.

### 5.3 The safe versions

| Tool | Mechanism | Mono-safe? |
|---|---|---|
| Waves Doubler | Modulated short delay + pitch offset | Reasonably |
| Detune ±5–9 cents on a copy | Beating instead of nulling | Yes, if small |
| Kilohearts Disperser | Allpass phase rotation | **Yes** — its design goal |
| Kilohearts Haas snapin | Deliberate Haas | No — check mono |
| Early reflections (short reverb, 20–60 ms, filtered) | Real depth cue | Yes |
| M/S with mono lows (S1, Ozone Imager) | Widens without touching bass | Yes |
| Re-amp / re-mic a DI | Genuinely different arrival | Yes |

### 5.4 The "3 ms guitar" claim, resolved

If you want the *effect* people describe, do this instead:

1. Duplicate take, pan hard L/R.
2. On the copy: **−6 to −9 dB**, 1.5–3 ms delay **with polarity inversion off**,
   and **low-pass at 7–9 kHz**.
3. Check mono. If the low-mid thins, reduce the delay to under 1.5 ms or drop the
   copy below −12 dB and add a detune instead.

That is a decorrelated double. It is still not "depth" — it is width — but it is
the version that survives a mono check.

---

## 6. Groove, timing and feel

1. **Offsets are a musical decision, not just a mixing one.** A 5–12 ms late hit
   on a snare reads as laid-back; the same offset on a kick reads as sloppy.
   Apply per instrument, and always check the kick/bass relationship first.
2. **Pocket the bass to the kick**, not to the grid — nudge the bass so its
   transients land 0–8 ms after the kick's.
3. **Quantise the source, not the feel.** On generated audio, use dynamic split
   and re-groove rather than hard quantise.
4. **Never "humanise" with random timing on a bass/kick pair.** Randomisation on
   the low end is heard as instability, not humanity.

---

## 7. Stereo

1. **Three planes**: centre (kick, bass, lead vocal), mid-width (snare, main
   guitars), wide (pads, FX, doubles).
2. **Correlation-check every new element** (Ozone Imager or a correlation meter).
   Below 0 on a sustained element means it will vanish in mono.
3. **Mono the low end** at 80–120 Hz on the bus, not per track.
4. **Width is not size.** A mix that is uniformly wide has no depth; contrast is
   what reads as space.

---

## 8. Saturation and distortion

| Type | Sound | Use |
|---|---|---|
| Tape (Kramer, J37) | Compression + HF loss | Glue, taming harsh digital tops |
| Console (NLS) | Subtle harmonic edge | Buses |
| Tube | Even harmonics, warmth | Vocals, bass |
| Transformer | Low-mid thickening | Kick, snare |
| Hard clip | Odd harmonics, aggression | Metal guitars, transients |
| Bitcrush / decimate | Aliasing | Effects only, never on the mix |

Rules: parallel unless you want the colour; high-pass the parallel return; never
saturate before de-noising; and always A/B at matched level.

---

## 9. Automation — the thing that makes it not sound AI

Generated audio has one mix for the whole song. Humans move things.

1. **Vocal level**: ride ±1–3 dB per phrase, more in the chorus build.
2. **Send automation**: reverb up in the breakdown, down at the drop.
3. **EQ automation**: the carve bands in §3 come in and out with the arrangement.
4. **Width automation**: narrow the verses, widen the chorus.
5. **Filter automation**: high-pass sweep into a drop beats any riser.
6. **Mute automation is legitimate and free.** Use it.

---

## 10. Common failure modes and their causes

| Symptom | Actual cause | Fix |
|---|---|---|
| Mix sounds muddy | Multiple layers in 200–500 | Stage 4 de-mask, not master EQ |
| Vocal buried | Instruments in 2–4 k, baked reverb | De-reverb + Carve, not a brighter vocal |
| Thin in mono | Haas widening, wide sub-bass | Mono lows, drop the Haas |
| Harsh / ear-fatiguing | 5–9 k AI residue | Dynamic narrow cut + RX de-crackle |
| Flat / no punch | Over-compression, no transient repair | Transient shaper, back off comp |
| Dull / no air | Genuine bandwidth cutoff | Do not EQ it; accept or restore |
| Bass weak on small speakers | Missing harmonics, not missing sub | RBass/MaxxBass |
| Sounds "AI" | One static mix for the whole song | Automation, §9 |
| Pumping | Release not tempo-locked, or >6 dB duck | Retune release |
| Collapses at the end | Progressive generation degradation | Regenerate with Max Mode |

---

## Sources

- Comb-filter maths and Haas window: `kernaudio.io/guides/stereo/haas-and-allpass-decorrelation`,
  `beatkitchen.io/guides/mixing-masterclass/08-delay-and-time-based-effects/`.
- Masking/de-masking workflow on AI sources: `bchillmix.com/blogs/news/how-to-fix-muddy-low-mids-in-suno-and-udio-songs`.
- Sidechain routing values and release-vs-tempo reasoning: standard practice; the
  REAPER 4-channel method is documented in the REAPER user guide (ReaComp
  "Detector input: auxiliary").
- Saturation types and order-of-use: Ozone/Neutron documentation, Waves
  plug-in manuals (RBass/MaxxBass harmonic generation).
