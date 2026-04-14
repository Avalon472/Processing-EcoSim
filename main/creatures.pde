// ============================================================
//  EcoSim – creatures.pde
//  Creature: movement, steering, state machine, drawing.
//
//  CHANGES FROM ORIGINAL:
//   - Stats come from the randomised LifecycleSystem (no more
//     hard-coded predator/herbivore speed literals here).
//   - New "REPRODUCE" state: when energy >= reproductionThreshold
//     a creature seeks its nearest ready mate instead of chasing
//     prey (carnivore) or seeking plants (herbivore).
//   - Reproduction is triggered in World so both parents lose
//     energy and a child is born at the midpoint.
//   - interactionRadius now comes from lifecycle.mateRange.
//   - Draw: creatures tinted by relative energy (greener = full,
//     darker = starving). A small heart icon appears while in
//     REPRODUCE state.
//   - Dead creatures no longer show a state label (cleaner HUD).
// ============================================================

class Creature {
  PVector position;
  PVector velocity;
  PVector acceleration;
  PVector boundaries;

  float energyValue;      // energy gained when this creature is eaten / eats
  float wanderAngle;

  boolean predator;
  String  state;

  LifecycleSystem lifecycle;

  // ── Standard spawn constructor ────────────────────────────────
  Creature(PVector pos, PVector worldSize, boolean isPredator) {
    position    = pos.copy();
    boundaries  = worldSize.copy();
    predator    = isPredator;

    lifecycle   = new LifecycleSystem(int(random(45, 75)), isPredator);

    velocity    = PVector.random2D();
    velocity.mult(random(lifecycle.maxSpeed * 0.35, lifecycle.maxSpeed));
    acceleration = new PVector();

    energyValue  = predator ? 35 : 20;
    wanderAngle  = random(TWO_PI);
    state        = "WANDER";
  }

  // ── Child constructor (born via reproduction) ─────────────────
  // Receives a pre-built crossbred LifecycleSystem from World.
  Creature(PVector pos, PVector worldSize, boolean isPredator,
           LifecycleSystem inheritedLifecycle) {
    position     = pos.copy();
    boundaries   = worldSize.copy();
    predator     = isPredator;
    lifecycle    = inheritedLifecycle;

    velocity     = PVector.random2D();
    velocity.mult(lifecycle.maxSpeed * 0.5);
    acceleration = new PVector();

    energyValue  = predator ? 35 : 20;
    wanderAngle  = random(TWO_PI);
    state        = "WANDER";
  }

  // ── Main update ───────────────────────────────────────────────
  void update(World world) {
    if (!lifecycle.alive) {
      state = "DEAD";
      velocity.set(0, 0);
      acceleration.set(0, 0);
      return;
    }

    if (predator) {
      updateCarnivore(world);
    } else {
      updateHerbivore(world);
    }

    velocity.add(acceleration);
    velocity.limit(lifecycle.maxSpeed);
    position.add(velocity);
    acceleration.mult(0);

    keepInBounds();

    lifecycle.changeEnergy(-lifecycle.metabolism);
    if (lifecycle.energy <= 0) {
      lifecycle.die();
      state = "DEAD";
      velocity.set(0, 0);
    }
  }

  // ── Carnivore behaviour ───────────────────────────────────────
  void updateCarnivore(World world) {
    // Priority 1: Reproduce (when well-fed)
    if (lifecycle.canReproduce()) {
      Creature mate = world.findNearestReadyMate(position, world.carnivores, this,
                                                  lifecycle.detectionRange*2);
      if (mate != null) {
        state = "REPRODUCE";
        seek(mate.position);

        if (isCloseTo(mate.position, lifecycle.mateRange)) {
          world.spawnOffspring(this, mate, world.carnivores);
        }
        return;
      }
    }

    // Priority 2: Chase prey
    Creature nearestPrey = world.findNearestCreature(position, world.herbivores,
                                                      lifecycle.detectionRange);
    if (nearestPrey != null) {
      state = "CHASE";
      seek(nearestPrey.position);

      if (isCloseTo(nearestPrey.position, 1.2)) {
        nearestPrey.lifecycle.die();
        nearestPrey.state = "DEAD";
        lifecycle.changeEnergy(energyValue);
      }
      return;
    }

    // Default: wander
    state = "WANDER";
    wander();
  }

  // ── Herbivore behaviour ───────────────────────────────────────
  void updateHerbivore(World world) {
    // Priority 1: Flee predators (always overrides everything)
    Creature nearestPredator = world.findNearestCreature(position, world.carnivores,
                                                          lifecycle.detectionRange);
    if (nearestPredator != null) {
      state = "FLEE";
      flee(nearestPredator.position);
      return;
    }

    // Priority 2: Reproduce (when well-fed and no predators nearby)
    if (lifecycle.canReproduce()) {
      Creature mate = world.findNearestReadyMate(position, world.herbivores, this,
                                                  lifecycle.detectionRange*2);
      if (mate != null) {
        state = "REPRODUCE";
        seek(mate.position);

        if (isCloseTo(mate.position, lifecycle.mateRange)) {
          world.spawnOffspring(this, mate, world.herbivores);
        }
        return;
      }
    }

    // Priority 3: Seek food
    PVector nearestPlant = world.findNearestPlant(position, lifecycle.detectionRange);
    if (nearestPlant != null) {
      state = "SEEK";
      seek(nearestPlant);

      if (isCloseTo(nearestPlant, 1.0)) {
        world.consumePlant(nearestPlant);
        lifecycle.changeEnergy(energyValue);
      }
      return;
    }

    // Default: wander
    state = "WANDER";
    wander();
  }

  // ── Drawing ───────────────────────────────────────────────────
  void draw(Camera camera, boolean showRanges) {
    if (!camera.isVisible(position)) return;

    PVector screenPos = camera.worldToScreen(position);
    float   heading   = velocity.magSq() > 0.0001 ? velocity.heading() : 0;

    pushMatrix();
    translate(screenPos.x, screenPos.y);
    rotate(heading);

    // Detection-range ring
    if (showRanges && lifecycle.alive) {
      noFill();
      stroke(255, 100);
      float r = lifecycle.detectionRange * camera.cellSize;
      ellipse(0, 0, r * 2, r * 2);

      // Mate-range ring (pink when ready to reproduce)
      if (lifecycle.canReproduce()) {
        stroke(255, 150, 200, 160);
        float mr = lifecycle.mateRange * camera.cellSize;
        ellipse(0, 0, mr * 2, mr * 2);
      }
    }

    noStroke();

    if (!lifecycle.alive) {
      // Greyed-out corpse
      fill(predator ? color(90, 45, 45) : color(45, 60, 90));
      triangle(8, 0, -7, -5, -7, 5);
    } else {
      // Energy tint: full energy = bright species colour,
      // low energy = darker / more grey
      float t = lifecycle.energy / lifecycle.maxEnergy;  // 0..1
      if (predator) {
        fill(lerpColor(color(100, 30, 30), color(230, 80, 80), t));
      } else {
        fill(lerpColor(color(30, 50, 120), color(80, 140, 255), t));
      }
      triangle(10, 0, -8, -6, -8, 6);

      // Heart icon when in REPRODUCE state
      if (state.equals("REPRODUCE")) {
        popMatrix();
        // Draw heart in screen space above the creature
        pushMatrix();
        translate(screenPos.x, screenPos.y);
        fill(255, 100, 160);
        noStroke();
        textSize(11);
        text("♥", -4, -10);
        popMatrix();
        pushMatrix();
        translate(screenPos.x, screenPos.y);
        rotate(heading);
      }
    }

    popMatrix();

    // State label (only for live creatures)
    if (lifecycle.alive) {
      fill(0);
      textSize(10);
      text(state, screenPos.x + 8, screenPos.y - 8);

      // Tiny energy bar
      float barW = 14;
      float fill_ = barW * (lifecycle.energy / lifecycle.maxEnergy);
      noStroke();
      fill(60);
      rect(screenPos.x - 7, screenPos.y + 8, barW, 3);
      fill(predator ? color(220, 80, 80) : color(80, 160, 255));
      rect(screenPos.x - 7, screenPos.y + 8, fill_, 3);
    }
  }

  // ── Steering behaviours ───────────────────────────────────────
  void applyForce(PVector force) {
    acceleration.add(force);
  }

  void seek(PVector target) {
    PVector desired = PVector.sub(target, position);
    if (desired.magSq() == 0) return;
    desired.normalize();
    desired.mult(lifecycle.maxSpeed);
    PVector steer = PVector.sub(desired, velocity);
    steer.limit(lifecycle.maxForce);
    applyForce(steer);
  }

  void flee(PVector threat) {
    PVector desired = PVector.sub(position, threat);
    if (desired.magSq() == 0) return;
    desired.normalize();
    desired.mult(lifecycle.maxSpeed);
    PVector steer = PVector.sub(desired, velocity);
    steer.limit(lifecycle.maxForce * 1.3);
    applyForce(steer);
  }

  void wander() {
    wanderAngle += random(-0.35, 0.35);
    PVector circleCenter = velocity.copy();
    if (circleCenter.magSq() == 0) circleCenter = PVector.random2D();
    circleCenter.normalize();
    circleCenter.mult(2.0);
    PVector displacement = new PVector(cos(wanderAngle), sin(wanderAngle));
    displacement.mult(1.2);
    PVector wanderForce = PVector.add(circleCenter, displacement);
    wanderForce.limit(lifecycle.maxForce);
    applyForce(wanderForce);
  }

  void keepInBounds() {
    float ef = 0.03;
    if (position.x < 3)                  applyForce(new PVector( ef,  0));
    if (position.x > boundaries.x - 3)   applyForce(new PVector(-ef,  0));
    if (position.y < 3)                  applyForce(new PVector(  0, ef));
    if (position.y > boundaries.y - 3)   applyForce(new PVector(  0,-ef));
    position.x = constrain(position.x, 0, boundaries.x - 0.01);
    position.y = constrain(position.y, 0, boundaries.y - 0.01);
  }

  boolean isCloseTo(PVector target, float radius) {
    return PVector.dist(position, target) <= radius;
  }
}
