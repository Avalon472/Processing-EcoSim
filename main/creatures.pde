class Creature {
  PVector position;
  PVector velocity;
  PVector acceleration;
  PVector boundaries;

  int energyValue;
  float wanderAngle;
  float interactionRadius;

  boolean predator;
  String state;

  LifecycleSystem lifecycle;

  Creature(PVector pos, PVector worldSize, boolean isPredator) {
    position = pos.copy();
    boundaries = worldSize.copy();
    predator = isPredator;

    lifecycle = new LifecycleSystem(int(random(45, 75)), predator);
    velocity = PVector.random2D();
    velocity.mult(random(lifecycle.maxSpeed * 0.35, lifecycle.maxSpeed));
    acceleration = new PVector();

    energyValue = predator ? 35 : 20;
    interactionRadius = predator ? 1.2 : 1.0;
    wanderAngle = random(TWO_PI);
    state = "WANDER";
  }

  void update(World world) {
    if (!lifecycle.alive) {
      state = "DEAD";
      velocity.mult(0);
      acceleration.mult(0);
      return;
    }

    if (predator) {
      Creature nearestPrey = world.findNearestCreature(position, world.herbivores, lifecycle.detectionRange);

      if (nearestPrey != null) {
        state = "CHASE";
        seek(nearestPrey.position);

        if (isCloseTo(nearestPrey.position, interactionRadius)) {
          nearestPrey.lifecycle.die();
          nearestPrey.state = "DEAD";
          lifecycle.changeEnergy(energyValue);
        }
      } else {
        state = "WANDER";
        wander();
      }
    } else {
      Creature nearestPredator = world.findNearestCreature(position, world.carnivores, lifecycle.detectionRange);
      PVector nearestPlant = world.findNearestPlant(position, lifecycle.detectionRange);

      if (nearestPredator != null) {
        state = "FLEE";
        flee(nearestPredator.position);
      } else if (nearestPlant != null) {
        state = "SEEK";
        seek(nearestPlant);
      } else {
        state = "WANDER";
        wander();
      }

      if (nearestPlant != null && isCloseTo(nearestPlant, interactionRadius)) {
        world.consumePlant(nearestPlant);
        lifecycle.changeEnergy(energyValue);
      }
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
      velocity.mult(0);
    }
  }

  void draw(Camera camera, boolean showRanges) {
    if (!camera.isVisible(position)) {
      return;
    }

    PVector screenPos = camera.worldToScreen(position);
    float heading = velocity.magSq() > 0.0001 ? velocity.heading() : 0;

    pushMatrix();
    translate(screenPos.x, screenPos.y);
    rotate(heading);

    if (showRanges && lifecycle.alive) {
      noFill();
      stroke(255, 120);
      ellipse(0, 0, lifecycle.detectionRange * camera.cellSize * 2, lifecycle.detectionRange * camera.cellSize * 2);
    }

    noStroke();
    if (predator) {
      fill(lifecycle.alive ? color(220, 70, 70) : color(110, 55, 55));
    } else {
      fill(lifecycle.alive ? color(60, 120, 255) : color(45, 75, 110));
    }

    triangle(10, 0, -8, -6, -8, 6);
    popMatrix();

    fill(0);
    text(state, screenPos.x + 8, screenPos.y - 8);
  }

  void applyForce(PVector force) {
    acceleration.add(force);
  }

  void seek(PVector target) {
    PVector desired = PVector.sub(target, position);
    if (desired.magSq() == 0) {
      return;
    }

    desired.normalize();
    desired.mult(lifecycle.maxSpeed);

    PVector steer = PVector.sub(desired, velocity);
    steer.limit(lifecycle.maxForce);
    applyForce(steer);
  }

  void flee(PVector threat) {
    PVector desired = PVector.sub(position, threat);
    if (desired.magSq() == 0) {
      return;
    }

    desired.normalize();
    desired.mult(lifecycle.maxSpeed);

    PVector steer = PVector.sub(desired, velocity);
    steer.limit(lifecycle.maxForce * 1.3);
    applyForce(steer);
  }

  void wander() {
    wanderAngle += random(-0.35, 0.35);

    PVector circleCenter = velocity.copy();
    if (circleCenter.magSq() == 0) {
      circleCenter = PVector.random2D();
    }

    circleCenter.normalize();
    circleCenter.mult(2.0);

    PVector displacement = new PVector(cos(wanderAngle), sin(wanderAngle));
    displacement.mult(1.2);

    PVector wanderForce = PVector.add(circleCenter, displacement);
    wanderForce.limit(lifecycle.maxForce);
    applyForce(wanderForce);
  }

  void keepInBounds() {
    float edgeForce = 0.03;

    if (position.x < 3) {
      applyForce(new PVector(edgeForce, 0));
    }
    if (position.x > boundaries.x - 3) {
      applyForce(new PVector(-edgeForce, 0));
    }
    if (position.y < 3) {
      applyForce(new PVector(0, edgeForce));
    }
    if (position.y > boundaries.y - 3) {
      applyForce(new PVector(0, -edgeForce));
    }

    position.x = constrain(position.x, 0, boundaries.x - 0.01);
    position.y = constrain(position.y, 0, boundaries.y - 0.01);
  }

  boolean isCloseTo(PVector target, float radius) {
    return PVector.dist(position, target) <= radius;
  }
}
