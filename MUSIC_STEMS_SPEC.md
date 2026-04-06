# Take a Stab — Music Stems Spec

## Master Settings
- **BPM**: Pick one BPM for all stems (target: 105-110, adjust to whatever most tracks cluster around)
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

## Source Tracks (in priority order)

1. **Wonderful Day** — Core funk example. Start here.
2. **Alien Savannah** — Already loop-based. Second priority.
3. **Menace** — Wide spectrum, good for stingers and multiple tiers.
4. **Charge Night** — Middle-of-the-road, good med-tier source.
5. **Don't Let Go Of My Hand** — Neutral, good low/med source.
6. **Good Again** — Cheer, good for high-energy positivity.
7. **You Have Incoming** — Far-out moments, peak/experimental tier.
8. **Higher Love / Chameleon** — The riff. Peak tier. Hand-clapping energy.

## What NOT to worry about
- Key matching across songs — groove-driven stems often layer fine across keys; pitch-shifting in Godot is possible if needed
- Perfection — 30-40 decent stems > 10 perfect ones

## How the in-game mixer will use these

The game calculates an intensity value (0.0–1.0) from kill rate, close calls, streaks:
- **Vertical mixing**: Adds/removes instrument layers as intensity changes (drums first, then bass, then keys, then lead)
- **Horizontal sequencing**: Selects which 8-bar loop plays next within each layer
- **Tier crossfading**: Swaps low→med→high→peak stems as intensity rises
- **Special events**: Streak → peak lead stem, death → everything drops to breakdown, reset → rebuild from low
