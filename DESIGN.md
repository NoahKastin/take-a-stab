# Take a Stab — Game Design Document

A first-person score-attack survival game where you stab brightly-colored zombies in the head with dual knives while listening to dynamically-mixed funk music.

## Core Concept

Inspired by the knife-only minigame in COD:BO6 Zombies — the satisfying part where you read zombie positioning and line up headstabs — stripped of everything frustrating (enemy variety forcing gun usage, overwhelming density that breaks the positioning game). One zombie type. Two knives. Funk music. Endlessly ramping difficulty that never plateaus.

## Engine & Platform

- **Engine**: Godot 4 (GDScript primary, C# available)
- **Platform**: PC (keyboard + mouse)
- **Art style**: Stylized low-poly

## Controls (6 inputs + mouse aim)

| Input | Action |
|-------|--------|
| W / Up | Move forward |
| S / Down | Move backward |
| A / Left | Strafe left |
| D / Right | Strafe right |
| Left click | Stab with left knife (arcs upward, forward, rightward) |
| Right click | Stab with right knife (arcs upward, forward, leftward) |
| Mouse movement | Adjust camera angle (±20° from straight ahead, both axes) |

Player movement is always faster than zombie movement.

## Core Mechanic: The Knife Geometry Puzzle

This is the central skill expression of the game. The two knives point in different directions:
- **Left knife** (left click): stabs inward — upward, forward, and to the right of the left hand
- **Right knife** (right click): stabs inward — upward, forward, and to the left of the right hand

Each stab follows the line the knife is pointed. A zombie slightly to the player's left is better reached by the right knife; slightly to the right, the left knife. Dead center, either works.

The ±20° camera, WASD strafing, and knife directionality combine to create a spatial puzzle for every encounter: read the zombie's position, choose the correct hand, time the stab. With multiple zombies, this becomes a sequencing and positioning problem.

**The knife-choice mechanic is not cosmetic — it is the game.**

## Player Character

A pair of arms in first-person view. No body, no face, no name — just arms and knives.

- **Character**: The arms of a strong young Black woman
- **Right hand**: Gold fingerless glove
- **Left wrist**: Gold watch (functional — serves as the only HUD)
- **Each hand**: Holds a knife

### The Watch (Diegetic HUD)

The watch on the left wrist is the game's only UI. No overlays, no menus, no HUD elements on screen.

- **Watch face** (visible during normal play at an angle): Displays time elapsed and zombies killed
- **Watch side button** (visible only when camera pans down on death): Displays "Play Again" text
- **Implementation**: Viewport texture on the watch mesh, rendering a 2D UI

## Knife Color System

Each knife has a `current_color` (default: original knife color, e.g. silver).

- On headstab kill: a spray of randomly-colored circles bursts out the far side of the zombie's head. The *used* knife changes to that color. The other knife is unchanged.
- Purpose of the blood spray: (1) confirms the headshot with visual punch, (2) "explains" the knife recoloring
- The color system is emergent customization — players develop attachment to particular knife colors through play

### Death Reset

On death, the "reset stab" (see Death & Respawn below) uses the original default knife color for its blood spray, and **both knives revert to the default color**. This is the only exception to normal blood mechanics.

## Zombies

**One type only.** No variety, no special types, no tanks, no speedsters. Difficulty comes from quantity and spacing, never from enemy complexity. The player should never be forced out of the positioning game.

### Appearance
- One base humanoid mesh, funk-inspired attire: bell-bottoms, platform shoes, open-collared shirt
- Per zombie, randomly-selected hex colors for: skin, each clothing piece
- Zombie head height matches the player's straight-ahead stab line

### Behavior
- Always spawn ahead of the player, never behind
- Path toward the player's front (not toward the player's back — avoid circling)
- Walk speed is always slower than player speed (zombie speed does NOT increase with difficulty)
- When in bite range: play bite animation toward the player
- Bite range < stab range (arm's reach > neck's reach — the player should be able to win)

### Spawning
- At least one zombie on-screen at all times
- After N kills, allow 2 simultaneous zombies, then 3, etc. (exact curve TBD via playtesting)
- Spawn rate increases over time (less downtime between zombies)

### Death Animation
- On headstab: random hex-colored circle burst out the opposite side of the head
- Zombie crumples downward, below camera view
- Knife emerges recolored to match the blood spray

## Hallway Environment

The game takes place in a procedurally-generated endless hallway.

### Base Design
- Muted, subdued aesthetic (concrete, industrial, subway tunnel feel)
- No flashy decorations — no disco balls, no vibrant decor. The zombies ARE the color
- Wide enough for the player to strafe and for zombies to walk toward the player with some lateral variation

### Terrain Changes (Increase with Difficulty)
- **Width changes**: Sections that narrow (harder to dodge) or widen (more flanking angles)
- **Gentle curves**: Gradually reveal what's ahead — **NO blind corners** (this is not a horror game)
- **Floor elevation**: Slight ramps or steps that change the knife-to-head angle
- **Lighting shifts**: Dimmer sections where zombie colors are harder to read, brighter sections as relief
- **Subtle environmental cues**: Cracks, pipes, different wall materials — just enough variety to prevent treadmill feeling

### Critical Constraint
Hallway generation must NEVER make the positioning game impossible. Even at maximum difficulty, the player must always have room to strafe, dodge, and choose their knife angle. If the hallway is too narrow or too crowded with zombies, the core mechanic breaks.

### Implementation
Modular tile segments assembled procedurally: straight, slight curve, narrow, wide, ramp. Each segment has defined entry/exit points for seamless tiling.

## Camera

- **Both axes**: ±20° from straight ahead (default)
- **Design rationale**: The restricted camera makes physical positioning (WASD) essential — you can't just mouse-aim your way out. This IS the positioning puzzle.
- **Open question**: If playtesting reveals zombies sometimes end up behind the player despite AI pathfinding, horizontal range may need to expand. Start with ±20° and test first. Prefer fixing zombie AI over expanding camera.

## Difficulty Scaling

**Difficulty ramps forever. It never plateaus.** (The plateau problem in Master Dungeon, where difficulty was capped by player loadout constraints, is explicitly avoided here.)

Difficulty drivers (all uncapped continuous values):
1. **More simultaneous zombies** (primary driver)
2. **Faster spawn rate** (less downtime)
3. **Hallway complexity** (more terrain variation at higher difficulty)

Difficulty does NOT increase:
- Zombie movement speed (always slower than player)
- Zombie toughness (always one headstab kill)
- New enemy types

The player eventually gets overwhelmed purely by quantity and spatial pressure — but the positioning game remains fair all the way up.

## Death & Respawn

1. Zombie bites the player
2. Camera pans down to the watch
3. Watch side button shows "Play Again" text (only visible at this angle)
4. Player clicks the button
5. Camera pans back up from the watch
6. The offending zombie is auto-stabbed (original default knife color blood spray)
7. Both knives reset to default color
8. Score and time reset to 0
9. Gameplay continues from current position in the hallway

No loading screen. No menu. No interruption beyond the brief watch animation.

## Game Start

No main menu. The game launches directly into the hallway. The watch shows 0:00 and 0 kills. A zombie approaches. You play.

Quitting: close the window.

High score persistence: not implemented initially. Can be added later if players request it.

## Audio

### Music Only
No sound effects. The adaptive funk music is the entire audio experience. This keeps the soundscape clean and reinforces the music as the game's aesthetic centerpiece.

### Adaptive Stem-Based Music System

**Source material** (the developer's own compositions):
- Wonderful Day — core funk example
- Alien Savannah — already built as a library of loops; more standard zombie-esque
- Charge Night — middle-of-the-road
- You Have Incoming — for far-out/experimental moments
- Higher Love / Chameleon — the riff that captures sing-uncontrollably hand-clapping energy
- Good Again — cheer
- Don't Let Go Of My Hand — neutral
- Menace — wide spectrum

### Approach: Curated Stems with Potential AI Augmentation

1. Break source tracks into stems (bass, drums, keys, etc.) — some are already stem-ready
2. Build a library of loops/phrases at compatible tempos
3. In-engine adaptive mixer selects and layers stems based on gameplay state
4. AI-generated additional stems are a stretch goal, not a requirement

### Gameplay-Driven Music Parameters
- **Kill rate** (kills/minute) → intensity, layer count
- **Close calls** (zombie got very close before being stabbed) → tension layers
- **Idle/low action** → breakdown/groove, fewer layers
- **Death** → music drops out or shifts during the watch sequence
- **Streak** (many kills without damage) → builds energy, adds layers, hand-clapping energy from Higher Love/Chameleon territory

### Implementation
Horizontal re-sequencing (select which segments play next) + vertical layering (fade stems in/out based on intensity). Pre-rendered stems at compatible tempos. Crossfade between intensity tiers.

## Art Asset Pipeline

The developer is not a 3D modeler. Asset sourcing:

| Asset | Approach |
|-------|----------|
| Zombie model | AI generation (Meshy/Tripo3D) → Blender cleanup → separate into body + clothing meshes for per-instance coloring → Mixamo for rigging + animations (walk, bite, death) |
| Player arms | Generate reference image first (AI image gen), then Meshy or commission on Fiverr (~$50-150 for rigged FP arms). Watch face is a viewport texture (code, not art) |
| Knives | Model in Blender or Godot CSG. Simple blade + handle. Material color changed at runtime |
| Hallway tiles | Modular pieces in Blender. Muted textures (concrete, industrial). Godot assembles procedurally |

## Development Phases

| Phase | Focus | Deliverable |
|-------|-------|-------------|
| **1 - Graybox** | Movement, camera (±20°), stab mechanic, basic zombie AI, hallway | Playable prototype: gray cubes in a gray hallway, left/right stab with different trajectories |
| **2 - Combat Polish** | Headshot detection, blood particle burst, knife color change, death/respawn cycle, watch viewport | Core loop complete with placeholder art |
| **3 - Art Pass** | Player arms + glove + watch, zombie model + funk attire + color randomization, hallway environment, knife models | Looks like the game. **Alpha candidate** — release for mechanical feedback |
| **4 - Music System** | Break tracks into stems, build adaptive mixer, hook to gameplay parameters | Sounds like the game. **Beta candidate** |
| **5 - Tuning** | Spawn curves, difficulty ramp, stab/bite range values, hallway generation parameters, music reactivity | Feels right to play. **Release candidate** |

### Backup Strategy
Initialize git immediately. Commit frequently. Push to GitHub for remote backup and rollback capability.

## Design Constraints (What NOT to Do)

These exist to protect the core experience:

- **No additional enemy types.** One zombie type, forever. Complexity comes from quantity and geometry.
- **No zombie speed increases.** Difficulty is about spatial pressure, not reaction time.
- **No difficulty plateau.** All scaling values are uncapped.
- **No blind corners.** Terrain changes gradually reveal what's ahead. This is not a horror game.
- **No zombies spawning behind the player.** They always come from ahead.
- **No forced weapon switching.** The player should never need anything but their two knives.
- **No screen-space UI.** The watch is the only HUD.
- **No sound effects (initially).** Music only.
- **No vibrant hallway decorations.** The zombies provide the color.
- **No main menu (initially).** Launch straight into gameplay.
