## Files

### MovementSim.pde
This is the main file. It sets up the world, plants, herbivores, carnivores, camera, drawing, and update loop.

### Creature.pde
This file has the creature class and the movement code. It controls things like position, velocity, wandering, 
seeking, fleeing, staying in bounds, and drawing the creatures.

It also has some commented placeholder skeletons for later features like:
- front-facing line of sight
- close-range interaction checks
- chase timeout
- obstacle response
- extra tuning variables

## What the program does

The program creates a grid world with herbivores, carnivores, and plants.

- Herbivores wander when nothing is nearby
- Herbivores move toward plants when they detect them
- Herbivores move away from predators when they detect them
- Carnivores wander when they do not see prey
- Carnivores chase herbivores when they detect them

The camera only shows part of the world at once, but the creatures still move in the full world.

## Controls

- Left Arrow = move camera left
- Right Arrow = move camera right
- Up Arrow = move camera up
- Down Arrow = move camera down
- R = show or hide detection ranges
- P = pause or resume the simulation

## Movement features included

- basic creature movement system
- wandering behavior
- steering behavior
- seek behavior
- flee behavior
- chase behavior
- movement priority logic
- boundary handling
- grid-to-screen support
- camera-independent movement
- reusable creature movement class
- simple test simulation

## Placeholder features

These are added as commented skeletons for later:
- front-facing line of sight
- close-range interaction checks
- chase timeout
- obstacle response hook
- tuning variables

## How to run

1. Put MovementSim.pde and Creature.pde in the same sketch folder
2. Open the sketch in Processing or VS Code with Processing support
3. Run the sketch

## Notes

This version is mainly for testing and showing how movement works.

Plants are just simple target points right now. The extra movement features are not active yet, 
but they are added as commented placeholders so they can be filled in later.