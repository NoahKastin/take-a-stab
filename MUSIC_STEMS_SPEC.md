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

### Harvested

Stems from these tracks already exist in `stems/` (audit the directory for the authoritative file list — this section is a summary):

- **Wonderful Day** — Core funk.
- **Alien Savannah** — Already loop-based.
- **Charge Night** — Middle-of-the-road; med-tier source.
- **Don't Let Go Of My Hand** — Neutral; low/med source.
- **You Have Incoming** — Far-out; peak/experimental tier.
- **Higher Love / Chameleon** — The riff. Peak tier. Hand-clapping energy.
- **Mama** — Richest source (10 stems). Fode Sissoko kora (lead, all tiers) + GarageBand MIDI arrangement (drums, bass). Originally 108 BPM, successfully lowered to 100.
- **Good Again** — 5 stems: drums_low, keys_low/med/high/peak.
- **I'll Just Let You Go** — 1 stem: lead_low.
- **Menace** — 7 stems: drums_low/med/high/peak, bass_med, keys_high. Wide spectrum.
- **Signature Banana Horse** — 2 stems: drums_low, keys_peak.
- **Doin' It: Ambient Version** — 2 stems: drums_high, keys_low.
- **FTLpunk** — 3 stems: keys_low/med/peak. Far-out/experimental.

### Remaining candidates

Listed alphabetically — order does **not** imply priority. Pull from whichever track is inspiring on a given night. Characterizations exist so a specific tier/instrument gap can be matched to a likely source when that's useful.

- **Give Me Up** — Already loop-based, like Alien Savannah.
- **Lights Up** — Funk potential; closer to the core ideal than the rock/experimental candidates.

### New candidates (art-style change)

The shift in art style opens up new tonal/mood possibilities. Add these tracks to the candidate pool (and create aliases to their private folders in the master private songs folder):

- **Wounded Skyline**
- **Throwing Paper Airplanes At Your Head**
- **Birdland / Sorceress** — only if non-derivative bits can be isolated
- **If I Knew**
- **Mars (Meow Meow Meow Meow)**
- **What We Lost**
- **I Don't Mind**

## What NOT to worry about
- Key matching across songs — groove-driven stems often layer fine across keys; pitch-shifting in Godot is possible if needed
- Perfection — 30-40 decent stems > 10 perfect ones

## How the in-game mixer will use these

The game calculates an intensity value (0.0–1.0) from kill rate, close calls, streaks:
- **Vertical mixing**: Adds/removes instrument layers as intensity changes (drums first, then bass, then keys, then lead)
- **Horizontal sequencing**: Selects which 8-bar loop plays next within each layer
- **Tier crossfading**: Swaps low→med→high→peak stems as intensity rises
- **Special events**: Streak → peak lead stem, death → everything drops to breakdown, reset → rebuild from low
