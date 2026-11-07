# Suno / AI-generated audio — problem → fix reference

Every known signature problem of AI-generated audio, what actually causes it,
and what can be done about it. **The evidence column matters**: much of what
circulates in community threads is plausible mechanism plus small samples, and
some of it is marketing copy. This file separates the two so you don't spend
hours EQ'ing a problem that is not there.

**Evidence key**

- **Measured** — reproducible by looking at a spectrogram or null test.
- **Reported** — multiple independent community reports, not independently measured.
- **Claimed** — vendor or single-post assertion; treat as a hypothesis.
- **Mechanism** — follows from how the codec/model must work, regardless of who reports it.

---

## The diagnostic pass (do this first, ~10 minutes)

1. **Spectrogram the whole file** (RX, or REAPER's spectrogram peaks display).
   Look for: a hard horizontal line at the top (bandwidth cutoff); a bright
   gradient that rises across the track (progressive degradation); vertical
   stripes (periodic artifacts); a hazy wash above 5 kHz (codec residue).
2. **Mono fold-down.** If bass or kick *changes* rather than just narrowing, the
   source has phase/width damage.
3. **Short-term loudness graph.** AI sources often have section-level level steps
   that no compressor is the right fix for.
4. **Check the last third at higher volume.** Most degradation lives there.
5. **Note which model and mode generated it.** Every fix below is conditional on
   that.

---

## 1. The problems

### P1 — Hard high-frequency cutoff (~12–16 kHz)

**What you hear:** muffled, dull, "cassette", no air; cymbals sound like paper.

**Cause (Mechanism / Measured):** the audio is decoded from a compressed latent
representation which does not carry full-band information; the top octave is
generated, not encoded. Reported cutoffs range from about 12 kHz to 16 kHz
depending on model and version, and some user WAVs measure content to 20 kHz, so
this is not universal. Suno has also been reported (v4.5 era, official Discord) as
*intentionally* cutting high frequencies to suppress shimmer.

**What works**

- **Do not** boost a high shelf. You will raise residue, not content. This is the
  single most common wasted hour.
- **Check before you decide** — spectrogram, not assumption.
- **Accept and mix into it**: reduce expectations for "air", and instead create
  the *impression* of openness in the 6–12 kHz band via gentle dynamic lift on
  elements that genuinely have content there.
- **Regenerate on a newer model** where possible; v6-era exports are more
  variable but sometimes genuinely full-band.
- **Restoration reconstruction** (Spectral Recovery in RX Advanced for
  bandwidth-limited material; commercial "Suno upscaler" services) can
  plausibly extend bandwidth, but it is **synthesis**: it invents content. Judge
  it on whether the result sounds better, not on the spectrogram looking fuller.

### P2 — Shimmer / "watery" / metallic sheen (6–14 kHz)

**What you hear:** a hiss-like glaze over vocals and cymbals; "underwater";
sibilance that does not belong to any word.

**Cause (Mechanism / Reported):** neural-codec residue — spectral energy
concentrated in roughly 6–14 kHz that does not correlate with the musical content.
Community spectral analysis reports 6.4% of energy in that band on bad tracks vs
1.5% on clean ones.

**What works**

- **RX De-crackle** (high setting) is the most effective stock module — it targets
  the *statistical* signature rather than a fixed band.
- **Dynamic, narrow** cuts at the specific offending band, not a broad high shelf.
  Sweep with a Q of 10–15 to find it (often 3–5 kHz for vocal shimmer, 8–12 kHz
  for the glaze).
- **Per-stem**, never on the whole mix, where you have stems.
- **Soothe-style resonance suppression** if owned; it is the right shape of tool.
- **Do not** run a static 8 kHz cut. You will remove real cymbal and consonant
  energy first and the shimmer will still be there.

### P3 — Progressive degradation across the song

**What you hear:** first verse clean, second chorus congested, last third fizzy,
guitars smeared, distortion turning into noise.

**Cause (Reported / Mechanism):** autoregressive drift plus heavier processing
later in the generation; several accounts specifically describe standard-mode
mixes going muffled after ~2:30 on longer songs.

**What works**

- **Regenerate with Max Mode** (Suno's own recommendation for >2 minutes).
- **Generate short and Extend**, re-pasting the full style prompt into each
  extension — keeps each segment nearer the "clean early" regime.
- **Comp the last third** from a different generation rather than processing it.
- Accept a slightly different mix per section and **automate** the correction
  (different carve bands, different de-crackle amounts) per section.

### P4 — Mud / low-mid congestion (200–500 Hz)

**What you hear:** boxy, "blanket over the speakers", kick and bass
indistinguishable, small speakers sound congested.

**Cause (Reported / Mechanism):** the model's training prior favours the
"warmth" region and it bakes the whole arrangement in one pass, so no
mix-engineer role separation happened.

**What works**

1. **Stems first.** A global cut in that band thins the vocal and the snare.
2. Find the **masking layer** (usually pads, room mics, and doubled guitars, not
   the bass) and cut *that*.
3. 1–3 dB **dynamic**, automated per section.
4. **Filter the reverb returns** (300–500 Hz high-pass).
5. **Separate kick and bass by time**, not by EQ (see `TECHNIQUES.md` §4).
6. If the whole thing is cloudy: check whether it is really one layer at all —
   often the fix is a **mute**.

### P5 — Buried vocals / "Suno sheen" on the voice

**What you hear:** the voice is present but unintelligible; the words are smeared;
the vocal sounds distant in a small room.

**Cause (Reported):** reverb and delay are baked into the vocal as part of the
render. You cannot un-render them, but you can substantially reduce them.

**What works**

- **RX De-reverb** on the vocal stem; blend **~70% processed / 30% dry**. This
  alone often resolves half of the muddiness complaint without any EQ.
- **RX Dialogue Isolate** used *gently* for the remainder.
- **Carve** 1.5–3 kHz out of the instrumental bus, keyed from the vocal — instead
  of boosting the vocal's presence, which raises the baked reverb too.
- **Pre-delayed, filtered sends** on any reverb you add, so you don't re-smear it.
- Do **not** de-reverb the whole mix. It will suck the life out of the drums.

### P6 — Harshness and ear-fatigue (2–5 kHz, "sizzle")

**What you hear:** the mix is painful at 10 minutes; peaks screech; cymbals
splatter.

**Cause (Reported):** a narrow, often band-limited artifact zone reported by
users between roughly 2 and 5 kHz, plus genuine over-bright generation.

**What works**

- **Narrow dynamic cut** (Q 8–15) on the specific band; if it moves, automate it.
- **De-ess** where it is genuinely sibilance — but note that about half of what
  sounds like sibilance in AI audio is codec noise, and a de-esser will not
  remove noise. Try de-crackle first.
- **Tape saturation** can help by softening the top end — the one place where
  "add distortion to fix harshness" is legitimate.

### P7 — Sibilance that moves and cannot be de-essed

**What you hear:** the de-esser reduces the S but the "shhh" remains, and it
appears on notes with no consonants.

**Cause (Mechanism):** it is not sibilance, it is artifact energy in the same band.

**What works:** RX De-crackle / Spectral Repair on the artifact events; a
narrower dynamic EQ; and accepting that some of it can only be removed by
regenerating the line.

### P8 — Wide, unstable, or phasey low end

**What you hear:** bass is huge on headphones and absent in the car; the low end
wobbles; mono fold-down changes the whole balance.

**Cause (Mechanism / Reported):** the model produces a stereo image without any
physical mic arrangement, and often decorrelates low frequencies. Reported v6
symptom: the right channel structurally different from the left.

**What works**

- **Mono below 80–120 Hz** on the bus (M/S EQ or Ozone Imager).
- **RX Azimuth** for L/R timing offset — this is the direct fix for the
  comb-filter symptom.
- **Mid/side check per stem**: if a bass stem has significant side energy, fold it.
- **Correlation meter** on every bus, not just the master.

### P9 — Static, crackle, clicks, dropouts

**What you hear:** random crackles, or a "digital" ticking.

**Cause (Reported):** decode/render artifacts; sometimes isolated to one stem.

**What works:** RX De-click (low frequency pass for ticks, high for crackle),
Spectral Repair for individual events, and re-render if it is systemic. Systemic
crackle on every generation is a reason to change model/mode, not to process.

### P10 — The vocal "ghost" / bleed between stems

**What you hear:** a ghost of the vocal in the drum stem, or drums in the vocal
stem.

**Cause (Mechanism):** stem separation is approximate; it is a mask, not a
demix.

**What works:** choose the cleaner split mode per stem (Auto vs Advanced Split
often differ substantially); accept bleed as part of the texture; use a de-bleed
tool if owned; and **do not** hard-gate it, which makes the bleed pump.

### P11 — Level jumps and inconsistent dynamics between sections

**What you hear:** the chorus is 4 dB louder than the verse in a way that feels
unmusical; or the whole track is pre-limited flat.

**Cause (Mechanism):** the render has its own loudness automation baked in.

**What works:** section-level clip gain (not fader) matched by short-term LUFS;
**Vocal Rider** / **Bass Rider** for line-to-line; and gentle bus compression
*after* the level match, never instead of it.

### P12 — No headroom / pre-limited material

**What you hear:** the mix is dense and any processing makes it collapse; peaks
are flat.

**Cause (Reported):** the model output is already limited and "mixed".

**What works:** **De-clip** in RX; work at lower gain staging; prefer
compressors and clippers to maximisers; do **not** stack a limiter on top at
mastering. If you need more than ~4 dB of gain reduction at the master, go back
to the mix.

### P13 — Unwanted elements (crowd noise, extra drums, unwanted instruments)

**Cause:** prompt adherence is probabilistic; negatives in the style box are
frequently ignored.

**What works:** the **Exclude Styles** field (not inline "no X"), regeneration,
and RX spectral repair / source separation for a one-off. See `PROMPTS.md`.

### P14 — Style drift across Extend joins

**What you hear:** the tempo, key, or vocal character shifts at the join.

**Cause (Reported):** each extension is a new generation conditioned on a
truncated context.

**What works:** paste the **exact** full style prompt into every extension; keep
extensions short so drift is cheap to catch; use Cover to re-render a section;
and crossfade the join in the DAW at a transient (see `TECHNIQUES.md` §1.2).

### P15 — WAV is not lossless

**Cause (Official):** Suno support has confirmed WAV downloads are not lossless in
the conventional sense — both are decoded from the same latent representation,
and the high frequencies are synthesised at decode time.

**What works:** prefer WAV for the extra bit depth and absence of a second lossy
stage, **but do not assume it fixes artifacts** — and try the MP3 occasionally on
harsh material, because it can mask synthetic top end. This is one of the few
places where the "worse" file can sound better.

### P16 — 32-bit float stems that clip anyway

**Cause (Mechanism):** 32-bit float preserves headroom in the *container* but the
render was already normalised.

**What works:** treat the stem as peak-limited; de-clip if flat-topped;
gain-stage by item, not by trusting the bit depth.

---

## 2. What mastering can and cannot fix

| Problem class | Mastering fixes it? |
|---|---|
| Loudness, true peak, delivery format | **Fully** |
| Tonal balance, mild mud/harshness | Partly |
| Buried vocal, one layer masking another | **No** — remix |
| Baked reverb on the vocal | **Barely** — restore first |
| Shimmer / codec artifacts | **No** — and limiting makes it worse |
| Bandwidth cutoff | **No** |
| Phase damage, wide sub-bass | Partly (mono lows) |

The rule: **restoration → balance → master**, in that order. Every published
guide that disagrees is selling a mastering plug-in.

---

## 3. On the r/SunoAI resources

The subreddit's **wiki has been retired**; the `/wiki/` links that circulate in
older threads are dead. What is actually there now:

- The **"Megathread — Suno Tips & Tricks"** post (`comments/1c6qevk`) — prompting
  advice, not mixing advice.
- **"Common Issues in SunoAI v4 & How to Fix Them"** (`comments/1ila6pl`) — the
  best-organised community symptom list; the source for several entries above.
- **"SUNO sound quality"** (`comments/1mtulv5`) — mono/phase discussion, useful
  and correctly reasoned.
- **"Shimmer Fix Workflow"** (`comments/1hz0ieo`) — RX-based; the workflow is
  sound (stems → RX → recombine), one reply's "anti-copy protection" theory is
  **unsupported** and should be ignored.
- **"Suno v6: Progressive Audio Degradation…"** (`comments/1x842um`) — a
  detailed technical write-up, worth reading, single-tester.
- Successors to the wiki: `sunoaiwiki.com` (community-maintained) and
  `suno.wiki` (older, partly archived). Neither is authoritative.

**Caveats worth internalising:** the sub's threads mix measured observation,
plausible mechanism, and confident invention in the same paragraph. The
"6.4% vs 1.5% energy" figure and the "v6 anti-piracy watermark" story are good
examples — one is plausible and unverified, the other is not supported at all.
Treat all of it as hypotheses to test on your own file.
