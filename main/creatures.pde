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
  static final int LAIR_REENTRY_COOLDOWN_FRAMES = 30 * 60;
  static final int LAIR_MIN_STAY_FRAMES = 5 * 60;

  PVector position;
  PVector velocity;
  PVector acceleration;
  PVector boundaries;

  float energyValue;      // energy gained when this creature is eaten / eats
  float wanderAngle;
  float boundaryTurn;
  float panicAngle;

  boolean predator;
  String  state;
  boolean wasInCarnivoreLair;
  int lairReentryBlockedUntilFrame;
  int enteredLairAtFrame;
  boolean leavingLairStartsCooldown;

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
    boundaryTurn = random(TWO_PI/4);
    panicAngle = random(TWO_PI/8);
    state        = "WANDER";
    wasInCarnivoreLair = false;
    lairReentryBlockedUntilFrame = 0;
    enteredLairAtFrame = -LAIR_MIN_STAY_FRAMES;
    leavingLairStartsCooldown = false;
  }
  //Perception syatem (Added by Mansa)
  //This function handles how a creature detects nearby entities and decides what actioon to take(flee,seek,chase,wander)
  void perceive(World world){
    if(!predator) {
      //check for nearby predator(danger)
      Creature danger = world.findNearestCreature(position, world.carnivores, lifecycle.detectionRange);
      //check for nearby food(plants)
      PVector food = world.findNearestPlant(position, lifecycle.detectionRange);
      
      if (danger != null) {
        state = "FLEE";
        flee(danger.position);
      }
      else if (food != null){
        state = "SEEK";
        seek(food);
      }
      else {
        state = "WANDER";
        wander();
      }
    } else {
      Creature prey = world.findNearestCreature(position, world.herbivores, lifecycle.detectionRange);
      
      if (prey != null) {
        state = "CHASE";
        seek(prey.position);
      } else {
        state = "WANDER";
        wander();
      }
    }
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
    wasInCarnivoreLair = false;
    lairReentryBlockedUntilFrame = 0;
    enteredLairAtFrame = -LAIR_MIN_STAY_FRAMES;
    leavingLairStartsCooldown = false;
  }

  // ── Main update ───────────────────────────────────────────────
  void update(World world) {
    if (!lifecycle.alive) {
      state = "DEAD";
      velocity.set(0, 0);
      acceleration.set(0, 0);
      return;
    }

    // Use the species-specific state machine each frame.
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
    if (predator && world.isCarnivoreGuard(this) &&
        !world.isInCarnivoreLair(position)) {
      position.set(world.getCarnivoreGuardPost(this));
      velocity.set(0, 0);
      acceleration.set(0, 0);
    }
    if (predator && !world.isCarnivoreGuard(this)) {
      boolean insideLairNow = world.isInCarnivoreLair(position);
      if (!wasInCarnivoreLair && insideLairNow) {
        enteredLairAtFrame = frameCount;
        leavingLairStartsCooldown = false;
      }
      if (wasInCarnivoreLair && !insideLairNow) {
        if (leavingLairStartsCooldown) {
          lairReentryBlockedUntilFrame =
            max(lairReentryBlockedUntilFrame, frameCount + LAIR_REENTRY_COOLDOWN_FRAMES);
        }
        leavingLairStartsCooldown = false;
      }
      wasInCarnivoreLair = insideLairNow;
    }

    lifecycle.changeEnergy(-lifecycle.metabolism);
    lifecycle.hunger = 1 - (lifecycle.energy/lifecycle.maxEnergy);
    if (predator && world.isCarnivoreGuard(this)) {
      lifecycle.energy = lifecycle.maxEnergy;
      lifecycle.hunger = 0;
    }
    if (lifecycle.energy <= 0) {
      lifecycle.die();
      state = "DEAD";
      velocity.set(0, 0);
    }
  }

  // ── Carnivore behaviour ───────────────────────────────────────
  void updateCarnivore(World world) {
    Creature lairIntruder = world.findNearestHerbivoreInLair(position,
      lifecycle.detectionRange * 1.35);
    Creature strongestResident = world.findStrongestCarnivoreInLair();
    boolean insideLair = world.isInCarnivoreLair(position);
    boolean reentryOnCooldown = frameCount < lairReentryBlockedUntilFrame;

    if (world.isCarnivoreGuard(this)) {
      lifecycle.energy = lifecycle.maxEnergy;
      PVector guardPost = world.getCarnivoreGuardPost(this);
      state = "GUARD";
      seek(guardPost);

      if (isCloseTo(guardPost, 1.4)) {
        velocity.mult(0.45);
      }

      if (world.isCarnivoreLairOverCapacity() && strongestResident != null &&
          world.shouldLeaveOvercrowdedLair(strongestResident) &&
          strongestResident.lifecycle.energy >= strongestResident.lifecycle.maxEnergy * 0.60 &&
          frameCount - strongestResident.enteredLairAtFrame >= LAIR_MIN_STAY_FRAMES) {
        strongestResident.beginLairExit(world, false);
      }
      return;
    }

    boolean tired = lifecycle.energy <= lifecycle.maxEnergy * 0.50;
    boolean recoveringInLair =
      insideLair && lifecycle.energy < lifecycle.maxEnergy;
    boolean minimumStaySatisfied =
      !insideLair || frameCount - enteredLairAtFrame >= LAIR_MIN_STAY_FRAMES;
    boolean healthyEnoughToYieldLair =
      lifecycle.energy >= lifecycle.maxEnergy * 0.60;
    boolean overcrowdedResident =
      insideLair && minimumStaySatisfied && healthyEnoughToYieldLair &&
      world.shouldLeaveOvercrowdedLair(this);
    boolean fullStamina =
      lifecycle.energy >= lifecycle.maxEnergy - max(0.10, lifecycle.metabolism * 2.0);

    if (overcrowdedResident) {
      beginLairExit(world, false);
      return;
    }

    if (insideLair && minimumStaySatisfied && fullStamina) {
      beginLairExit(world, true);
      return;
    }

    if (lairIntruder != null && (insideLair || recoveringInLair)) {
      state = "DEFEND";
      seek(lairIntruder.position);

      if (isCloseTo(lairIntruder.position, 1.2)) {
        lairIntruder.lifecycle.die();
        lairIntruder.state = "DEAD";
        lifecycle.changeEnergy(energyValue);
      }
      return;
    }

    if (insideLair && !minimumStaySatisfied) {
      state = "REST";
      velocity.mult(0.25);
      if (lifecycle.energy < lifecycle.maxEnergy) {
        lifecycle.changeEnergy(0.60);
      }
      return;
    }

    if (reentryOnCooldown && !insideLair) {
      state = "ROAM";
      wander();
      return;
    }

    if ((!reentryOnCooldown && tired) || recoveringInLair) {
      if (!world.isInCarnivoreRestArea(position)) {
        state = "RETURN";
        seek(world.carnivoreLairCenter);
      } else {
        lifecycle.changeEnergy(0.60);
        if (lifecycle.energy >= lifecycle.maxEnergy && minimumStaySatisfied) {
          beginLairExit(world, true);
        } else {
          state = "REST";
          velocity.mult(0.25);
        }
      }
      return;
    }

    // Priority 1: Reproduce outside the lair (when well-fed)
    if (lifecycle.canReproduce()) {
      Creature mate = world.findNearestReadyMate(position, world.carnivores, this,
                                                  lifecycle.detectionRange);
      if (mate != null) {
        if (insideLair || world.isInCarnivoreLair(mate.position)) {
          beginLairExit(world, false);
          return;
        }

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
                                                      lifecycle.detectionRange * (1 + lifecycle.hunger));
    if (nearestPrey != null && lifecycle.hunger > 0.25) {
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
    PVector nearestPlant = world.findNearestPlantOutsideLair(position,
      lifecycle.detectionRange * (1 + lifecycle.hunger));
    if (PVector.dist(position, world.carnivoreLairCenter) <= world.carnivoreLairRadius + 2.5) {
      state = "AVOID_LAIR";
      flee(world.carnivoreLairCenter);
      return;
    }

    if (nearestPredator != null && ((nearestPlant != null && PVector.dist(position, nearestPredator.position) < PVector.dist(position,nearestPlant) + 5) || nearestPlant == null)) {
      state = "FLEE";
      flee(nearestPredator.position);
      return;
    }

    // Priority 2: Reproduce (when well-fed and no predators nearby)
    if (lifecycle.canReproduce()) {
      Creature mate = world.findNearestReadyMate(position, world.herbivores, this,
                                                  lifecycle.detectionRange);
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
    if (nearestPlant != null && lifecycle.hunger > 0.25) {
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
      if (predator && state.equals("GUARD")) {
        fill(lerpColor(color(190), color(255), t));
      } else if (predator) {
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

  void beginLairExit(World world, boolean startCooldown) {
    state = "LEAVE_LAIR";
    leavingLairStartsCooldown = leavingLairStartsCooldown || startCooldown;
    seek(world.getCarnivoreLairExitPoint(position));
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
    desired.rotate(panicAngle);
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
    float ef = 0.045;
    if (position.x < 3) {
      applyForce(new PVector( ef,  0));
      velocity.rotate(boundaryTurn);
    }
    if (position.x > boundaries.x - 3){
      applyForce(new PVector(-ef,  0));
      velocity.rotate(boundaryTurn);
    }
      if (position.y < 3) {
      applyForce(new PVector( 0,  ef));
      velocity.rotate(boundaryTurn);
    }
    if (position.y > boundaries.y - 3){
      applyForce(new PVector(0,  -ef));
      velocity.rotate(boundaryTurn);
    }
    position.x = constrain(position.x, 1, boundaries.x - 1);
    position.y = constrain(position.y, 1, boundaries.y - 1);
  }

  boolean isCloseTo(PVector target, float radius) {
    return PVector.dist(position, target) <= radius;
  }
}
