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

### Remaining candidates

Listed alphabetically — order does **not** imply priority. Pull from whichever track is inspiring on a given night. Characterizations exist so a specific tier/instrument gap can be matched to a likely source when that's useful.

- **Doin' It: Ambient Version** — Clapping source; alternative if Higher Love / Chameleon doesn't yield enough claps.
- **FTLpunk** — Far-out/experimental, peak tier.
- **Give Me Up** — Already loop-based, like Alien Savannah.
- **Good Again** — Cheer / high-energy positivity. Planned source for **drums-low** (the last remaining vertical-mix blocker for the low tier).
- **I'll Just Let You Go** — Rock-leaning but would work.
- **Lights Up** — Funk potential; closer to the core ideal than the rock/experimental candidates.
- **Mama** — Two key elements: Fode Sissoko kora (likely peak-tier lead) and a lush background arrangement likely to yield multiple additional stems. **BPM caveat:** Mama is at 108 BPM. Everything except the kora is GarageBand MIDI — re-render those parts at 100 BPM natively in GarageBand. The kora is real audio and must be time-stretched separately; plan is to run it through [audiotrimmer.com's speed changer](https://audiotrimmer.com/audio-speed-changer/) at **0.93x** (closest available value to the true ratio 100/108 ≈ 0.9259, lands at ~100.44 BPM). Resulting drift (~83 ms over 8 bars) is masked by the 8-bar loop crop.
- **Menace** — Wide spectrum, good for stingers and multiple tiers.
- **Signature Banana Horse** — Funky once shifted to the 100/200 BPM family.

## What NOT to worry about
- Key matching across songs — groove-driven stems often layer fine across keys; pitch-shifting in Godot is possible if needed
- Perfection — 30-40 decent stems > 10 perfect ones

## How the in-game mixer will use these

The game calculates an intensity value (0.0–1.0) from kill rate, close calls, streaks:
- **Vertical mixing**: Adds/removes instrument layers as intensity changes (drums first, then bass, then keys, then lead)
- **Horizontal sequencing**: Selects which 8-bar loop plays next within each layer
- **Tier crossfading**: Swaps low→med→high→peak stems as intensity rises
- **Special events**: Streak → peak lead stem, death → everything drops to breakdown, reset → rebuild from low
