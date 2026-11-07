# Suno prompting — the practical version

What the model will actually act on, what it ignores, and a working example.
Written against v6 behaviour (v6 / v6-wild / v6-mini), September 2026 onward.

---

## 1. The four fields, and what belongs in each

| Field | Limit | What belongs there |
|---|---|---|
| **Style** | ~1,000 chars | Genre, era, instrumentation, production character, vocal type. |
| **Lyrics** | ~5,000 chars | Lyrics plus `[Section]` tags and performance cues. |
| **Exclude Styles** | ~1,000 chars | Everything you *don't* want, as **bare nouns**, no "no". |
| **Advanced** | — | Vocal gender, Duration, Max Mode, Weirdness, Style Influence, Variety. |

Two rules that solve most complaints:

1. **Negatives go in Exclude Styles, never inline.** Writing "no autotune" or
   "without synths" in the style box can cause the model to *add* them. v6
   ignores prompt-level "no X" (tested publicly at launch). There is no working
   inline negative.
2. **Structure lives in the lyrics field, not the style field.** `[Intro]`,
   `[Build]`, `[Drop]`, `[Breakdown]`, `[Outro]` in brackets on their own lines.

---

## 2. What the model can and cannot do

| You write | Reality |
|---|---|
| "128 BPM" | Sometimes honoured. Verify by measuring; don't build a session on faith. |
| "10-minute track" | **Ignored.** Ceiling is **8 minutes per generation**; length comes from sufficient lyrics/sections and slow BPM, or from Extend. |
| "360-degree spatial audio" | Not a controllable parameter. It will produce a wide-ish mix; that's it. |
| "Surgical side-chained pluck synths" | "Sidechained" is a mix process; at best it nudges pumping. The word is a hint, not a routing instruction. |
| "Integrated 40 Hz binaural beats" | **Cannot work.** Binaural requires a different frequency in each ear, survives only in headphones, and would break mono compatibility. Add it in the DAW if you want it. |
| "High-resolution audio, zero noise floor" | Noise floor is not a prompt parameter — and the decoder's residue is exactly what you can't prompt away. |
| "Deadmau5-style" | Usable as a *style pointer*; the model infers progressive house production habits from it. Fine in moderation. |
| A long list of 20 genre tags | Actively harmful: it averages them into mush. One primary identity, at most two modifiers. |
| Mixed languages in the same style box | Works, but each additional language dilutes adherence. Pick one per generation. |

**The governing principle:** *prioritised specificity, not micromanagement.*
One identity, two or three decisive instrument behaviours, one vocal behaviour,
one energy arc, one or two mix relationships, a short exclude list.

**Prompt architecture that maps to that:**

```
Identity → Pulse → Players → Performance → Arc → Mix → Constraints
```

---

## 3. Your example, reviewed

Your prompt was:

> Style: 10-minute Progressive House Marathon, Dark Neural Techno, 128 BPM.
> Deadmau5-style mathematical progression. Surgical side-chained analog pluck
> synths, monolithic 4/4 kick drum, deep transparent sub-bass. 360-degree spatial
> audio, evolving stereo imaging, rotating modular oscillators. High-resolution
> audio, zero noise floor. Integrated 40Hz binaural beats. Hypnotic, minimalist,
> gradually unfolding textures. High-fidelity transient response. Arrangement:
> [Extended Intro], [Atmospheric Build], [Main Progression], [Neural
> Breakdown], [Climax], [Outro]. … dub techno, métal, remix, mitreißend, smooth
> rhythm, dubstep, bass drop, plug, rhythmic basslines, crisp snare, slow vocal,
> build, emotionel, glitchy.

**What works:** the two identity tags (progressive house / dark techno), the BPM,
the "mathematical progression" idea, the instrument roles, and the section tags.

**What to cut:** "10-minute" (impossible in one pass), "360-degree" /
"rotating modular oscillators" / "high-resolution, zero noise floor" /
"binaural" (not parameters — they consume characters and dilute everything
else), and the eleven-tag tail (`métal`, `dubstep`, `bass drop`, `slow vocal`,
`glitchy`…). Those tail tags are the reason a progressive-house prompt comes back
as a genre soup: the model is averaging "dubstep bass drop" with "hypnotic
minimalist".

**What to move:** the arrangement tags out of the style box and into the lyrics
field, where they are actually read as structure.

---

## 4. Rewritten — the progressive house / dark techno track

**Style box** (fits comfortably under 1,000 characters):

```
Progressive house and dark melodic techno, 128 BPM, instrumental. Deadmau5-style
long-form mathematical progression: a single hypnotic arpeggiated pluck figure
repeating with slow filter movement, monolithic four-on-the-floor kick, deep
transparent sub-bass sitting under the kick without masking it, wide analog pads
that evolve over minutes. Minimal arrangement, few elements, each one audible and
clean. Tight low end, high-fidelity transient response, no mud in the low mids,
clear separation between kick, bass and pluck. Restrained, patient, hypnotic,
gradually unfolding rather than dropping. Analog synth character, subtle tape
saturation on the buses, tasteful dub-influenced delay throws on the pluck.
```

**Exclude Styles:**

```
vocals, vocal chops, crowd noise, applause, orchestral strings, brass, distorted
guitars, trap hi-hats, dubstep bass, wobble, supersaw leads, riser effects,
white noise sweeps, EDM festival drop, spoken word, lo-fi, vinyl crackle, excessive reverb
```

**Lyrics box** — this is where the arrangement goes, even for an instrumental:

```
[Extended Intro]
[Atmospheric Build]
[Main Progression]
[Neural Breakdown]
[Climax]
[Extended Outro]
```

**Advanced**

- Duration: longest available for the model, **Max Mode ON** (Suno's own
  recommendation above ~2 minutes, and the main defence against the back half
  going muffled).
- Style Influence: high (~75–85) for adherence; Variety: low (~0–25) for
  consistency if you plan to Extend.
- Vocal gender: n/a (instrumental).

**Getting to 10 minutes**

8 minutes is the per-generation ceiling. To reach 10:

1. Generate the first ~8 minutes.
2. **Extend** by the remaining ~2 minutes, and **paste the exact same style box**
   into the extension — this is the single most effective anti-drift measure.
3. Add `[Extended Outro]` and a length cue in the extension's lyrics.
4. In the DAW, crossfade the join at a downbeat with a 20–40 ms equal-power fade,
   and check the mono image across the seam.

---

## 5. The same treatment for *Human dot JSON*

Your pasted lyrics are a separate song — mid-tempo synth-pop / electronic with a
clean male-ish vocal, conversational verses, and a big repeated chorus. Structurally
it is already good: verses in short two-line fragments, a hook that repeats the
title, an outro tag. What the style box should say:

**Style box:**

```
Mid-tempo synth-pop with electronic production, 104 BPM, male lead vocal, clean and
close-miked, conversational verses with restrained delivery, wide open chorus with
stacked harmonies. Warm analog synths, soft electric piano, muted plucked arpeggio,
understated electronic drums with a tight snare and soft kick, rounded sub-bass.
Modern bedroom-pop intimacy with polished pop production: audible breath, dry
verses, wider reverb only in the chorus. Melancholy but hopeful, human and slightly
tired, never bombastic.
```

**Exclude Styles:**

```
autotune, hard tuning artifacts, screamed vocals, metal, distorted guitars, trap
hi-hats, dubstep bass, orchestral swells, crowd noise, applause, spoken word,
lo-fi vinyl crackle, EDM drop
```

**Lyrics** — keep what you wrote; make two changes:

1. Put `[Verse 1]`, `[Chorus]`, `[Verse 2]`, `[Chorus]`, `[Outro]` on their own
   lines (you have this) and add performance cues only where the delivery should
   change. Example: `[Chorus] (wide, stacked harmonies)` — one cue per section
   maximum.
2. The parenthetical `(Human dot JSON)` reads as a backing-vocal answer line,
   which is what you want — keep it, but it is worth deciding whether it appears
   in *both* choruses identically or only the second. Repetition of a hook tag is
   what makes it stick.

Nothing in that lyric needs rewriting for the model. It does need one thing for
release: Suno's structure tags and cue tags must be **stripped from the lyric
sheet** you register or print.

---

## 6. Working loop

1. **Generate 4–6 candidates** with the same prompt, Max Mode on if over 2 minutes.
2. **Pick by the chorus**, and by which one has the cleanest top end. Cheapest
   quality win available.
3. **Prefer to fix a weak section than regenerate the song.** Extend, Cover, or
   replace that section; regenerate only when the whole thing is wrong.
4. **Re-paste the style box in every Extend.** Every time, no exceptions.
5. **Change one variable per iteration.** Two changes at once teaches you nothing.
6. **Log what worked.** A `PROMPT-LOG.md` next to the project, with the prompt,
   the model, the mode, and one line on the result. Six weeks later this is worth
   more than any guide, including this one.

---

## Sources

- Field limits (style ~1,000 / lyrics ~5,000 / exclude ~1,000), Max Mode
  recommendation, sliders — Suno help centre and Advanced-mode documentation, as
  compiled in `bitwize-music-studio/claude-ai-music-skills`
  (`reference/suno/best-practices.md`) and `moelueker.com/blog/suno-v6-guide`.
- **8-minute per-generation ceiling** and Extend workflow — Suno help centre, via
  `undetectr.com/blog/suno-extend` and `songsmith.studio/blog/how-to-make-full-length-songs-on-suno`.
- Prompt-level negatives ignored in v6, and the Exclude Styles field as the only
  reliable negative path — launch-week testing reported by The Verge (Sep 2026),
  summarised in the same references.
- "Prompt like a producer giving a brief" / prioritised specificity — r/SunoAI
  v6 prompting compilation, `comments/1wehqi9`.
