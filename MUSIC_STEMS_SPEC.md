# Take a Stab — Music Stems Spec

## Master Settings
- **BPM**: Pick one BPM for all stems (target: 100 or 200 — these are half-time/double-time equivalents, so stems from either family lock to the same grid). Shift outliers (e.g. Signature Banana Horse) into this family as needed.
- **Sample rate**: 44.1kHz
- **Format**: .wav
- **Default loop length**: 8 bars (4 or 16 where the phrase demands it)
- **Loop alignment**: Start on downbeat of bar 1, end exactly on downbeat of bar 9. Leave natural reverb tail, no silence padding.

## Stem Types per Track

| Stem | What to include | Naming pattern |
|------|----------------|----------------|
| **Drums** | Kit, percussion, anything rhythmic | `trackname_drums_ENERGY.wav` |
| **Bass** | Bass instrument(s) | `trackname_bass_ENERGY.wav` |
| **Keys/Chords** | Piano, organ, synth pads, chord instruments | `trackname_keys_ENERGY.wav` |
| **Lead** | Melodic hooks, riffs, solos, horns | `trackname_lead_ENERGY.wav` |
| **Texture** | Atmosphere, effects, secondary elements | `trackname_texture_ENERGY.wav` |

## Energy Tiers

Tag each stem with one of these based on how intense it feels:

- **low** — Could play during idle moments. Sparse, grooving, atmospheric.
- **med** — Default gameplay. Solid rhythm, clear groove.
- **high** — Kill streaks, multiple zombies. Driving, layered, urgent.
- **peak** — Maximum energy. The Higher Love/Chameleon riff territory.

## Priority Variants

1. **2-3 drum patterns per energy tier** — biggest impact on freshness since drums are always playing
2. **Stripped "breakdown" versions** of strongest grooves (bass + one element) for post-death reset moments
3. **Short stingers** (1-2 bars) from Menace or Alien Savannah for kill confirmations (nice-to-have)

## Source Tracks

Listed alphabetically — order does **not** imply priority. Pull from whichever track is inspiring on a given night. Characterizations exist so a specific tier/instrument gap can be matched to a likely source when that's useful. Where stems exist in `stems/`, they're summarized below — audit that directory for the authoritative file list.

- **Alien Savannah** — Already loop-based.
- **Birdland / Sorceress** — Non-derivative bits confirmed isolable. No stems harvested yet.
- **Charge Night** — Middle-of-the-road; med-tier source.
- **Doin' It: Ambient Version** — 2 stems: drums_high, keys_low.
- **Don't Let Go Of My Hand** — Neutral; low/med source.
- **FTLpunk** — 3 stems: keys_low/med/peak. Far-out/experimental.
- **Give Me Up** — Already loop-based, like Alien Savannah. No stems harvested yet.
- **Good Again** — 5 stems: drums_low, keys_low/med/high/peak.
- **Higher Love / Chameleon** — The riff. Peak tier. Hand-clapping energy.
- **I'll Just Let You Go** — 1 stem: lead_low.
- **Mama** — Richest source (10 stems). Fode Sissoko kora (lead, all tiers) + GarageBand MIDI arrangement (drums, bass). Originally 108 BPM, successfully lowered to 100.
- **Menace** — 7 stems: drums_low/med/high/peak, bass_med, keys_high. Wide spectrum.
- **Signature Banana Horse** — 2 stems: drums_low, keys_peak.
- **Throwing Paper Airplanes At Your Head** — Exported, cropping pending.
- **What We Lost** — No stems harvested yet.
- **Wonderful Day** — Core funk.
- **Wounded Skyline** — Exported, cropping pending.
- **You Have Incoming** — Far-out; peak/experimental tier.

## Pitch-Shifting / Key Alignment

Most stems coexist without transposing. The clusters that already harmonize:
- **Eb Minor**: Charge Night, Higher Love / Chameleon, Throwing Paper Airplanes At Your Head
- **C Minor**: Give Me Up, Menace (keys_high)
- **D Minor / F Major**: I'll Just Let You Go, Birdland / Sorceress, Wonderful Day
- **F Minor**: Signature Banana Horse, Wounded Skyline (bass_low)
- **F# Minor**: Mama (kora lead — harmonizes broadly)
- **Other compatible**: Wounded Skyline keys_med (E Minor Pentatonic), Menace bass_high (A Major triad), YHI keys_peak (A Minor triad), YHI bass_high/lead_high (Bb Major — 1 note off C Minor or D Minor)

### Priority transpositions (9 stems)

These are the stems most likely causing audible discordance and should be addressed first. Target keys listed after the arrow:

1. `mama_bass_high` — F# Minor → **E Minor**
2. `mama_bass_peak` — F# Minor → **G Minor**
3. `doinit_keys_low` — B Minor → **G Minor**
4. `dontletgoofmyhand_keys_low` — B Minor → **G Minor**
5. `dontletgoofmyhand_keys_med` — B Minor → **G Minor**
6. `ftlpunk_keys_low` — A Harmonic Minor → **F Minor**
7. `ftlpunk_keys_med` — A Harmonic Minor → **F Minor**
8. `ftlpunk_keys_peak` — A Harmonic Minor → **F Minor**
9. `youhaveincoming_lead_peak` — B Minor Blues / D Major Blues → **A Minor Blues or C Major Blues**

### Flagged but likely fine in practice

These were identified as theoretically clashing but are probably tolerable due to passing-tone bass motion or limited note sets:

- `youhaveincoming_bass_low` — essentially chromatic (10/12 notes), but bass passing tones move fast
- `youhaveincoming_bass_med` / `youhaveincoming_keys_med` — C#, D, Eb, E, F#, Ab, B (unusual but not strongly tonal)

## What NOT to worry about
- Perfection — 30-40 decent stems > 10 perfect ones

## How the in-game mixer will use these

The game calculates an intensity value (0.0–1.0) from kill rate, close calls, streaks:
- **Vertical mixing**: Adds/removes instrument layers as intensity changes (drums first, then bass, then keys, then lead)
- **Horizontal sequencing**: Selects which 8-bar loop plays next within each layer
- **Tier crossfading**: Swaps low→med→high→peak stems as intensity rises
- **Special events**: Streak → peak lead stem, death → everything drops to breakdown, reset → rebuild from low
