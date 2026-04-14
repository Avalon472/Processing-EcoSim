# Processing-EcoSim

Processing-EcoSim now uses the `main` sketch as the single source of truth for the movement demo and the shared class structure. The movement prototype that lived in `movement/` has been folded into the ecosystem classes in `main/`, so the project keeps one world model, one creature class, and one camera/rendering flow.

## What the sketch does

The simulation builds a grid-based world with:

- herbivores that wander, seek plants, and flee nearby carnivores
- carnivores that wander until prey enters range, then chase it
- plants that act as food targets and respawn elsewhere after being eaten
- a camera that renders only part of the world while the simulation continues everywhere

Each creature now combines the original `main` folder structure with the movement behaviors from the prototype:

- `Creature` keeps lifecycle-driven stats and state
- `LifecycleSystem` handles energy, death, and movement tuning values
- `World` owns plants, creature groups, camera state, updates, and HUD drawing
- `Camera` handles viewport movement, visibility checks, and grid-to-screen translation

## Controls

- Left Arrow: move camera left
- Right Arrow: move camera right
- Up Arrow: move camera up
- Down Arrow: move camera down
- `R`: show or hide detection ranges
- `P`: pause or resume the simulation

## Files

- `main/main.pde`: sketch entry point and key forwarding
- `main/world.pde`: world setup, entity collections, update loop, rendering helpers, HUD
- `main/creatures.pde`: creature movement, state changes, steering, and drawing
- `main/systems.pde`: lifecycle and movement tuning stats
- `main/camera.pde`: viewport movement and world-to-screen conversion

## Notes

- The merged version keeps the prototype's seek, flee, wander, chase, and boundary behaviors.
- Dead creatures remain visible so lifecycle state is still easy to inspect while testing.
- Reproduction and deeper ecosystem systems are still placeholders for later work.

## Running the sketch

1. Open the `project/Processing-EcoSim/main` folder as the Processing sketch.
2. Run `main.pde` in Processing or a compatible Processing extension.
