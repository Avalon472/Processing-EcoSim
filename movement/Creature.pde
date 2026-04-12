class Creature {
  // position, movement, and force values
  PVector pos;
  PVector vel;
  PVector acc;

  // movement settings
  float maxSpeed;
  float maxForce;
  float detectRange;
  float wanderAngle;
  boolean predator;
  String state;

  // tuning variables
  // used to adjust movement later without changing the whole code
  // float turnRate;
  // float wanderJitter;
  // float stopDistance;
  // float fleeDistance;
  // float catchDistance;
  // int chaseTimeout;
  // int chaseTimer;
  // float fovAngle;

  // constructor
  // sets up a creature with a starting position and type
  Creature(float x, float y, boolean isPredator) {
    pos = new PVector(x, y);
    vel = PVector.random2D();
    acc = new PVector();
    predator = isPredator;
    state = "WANDER";
    wanderAngle = random(TWO_PI);

    // predators move a little faster and detect farther
    if (predator) {
      maxSpeed = 0.11;
      maxForce = 0.010;
      detectRange = 28;
    } else {
      maxSpeed = 0.09;
      maxForce = 0.008;
      detectRange = 22;
    }
  }

  // adds a movement force to the creature
  void applyForce(PVector force) {
    acc.add(force);
  }

  // moves the creature toward a target
  void seek(PVector target) {
    PVector desired = PVector.sub(target, pos);
    desired.normalize();
    desired.mult(maxSpeed);

    PVector steer = PVector.sub(desired, vel);
    steer.limit(maxForce);
    applyForce(steer);
  }

  // moves the creature away from a threat
  void flee(PVector threat) {
    PVector desired = PVector.sub(pos, threat);
    desired.normalize();
    desired.mult(maxSpeed);

    PVector steer = PVector.sub(desired, vel);
    steer.limit(maxForce * 1.3);
    applyForce(steer);
  }

  // gives the creature random wandering movement
  void wander() {
    wanderAngle += random(-0.35, 0.35);

    PVector circleCenter = vel.copy();
    circleCenter.normalize();
    circleCenter.mult(2.0);

    PVector displacement = new PVector(cos(wanderAngle), sin(wanderAngle));
    displacement.mult(1.2);

    PVector wanderForce = PVector.add(circleCenter, displacement);
    wanderForce.limit(maxForce);
    applyForce(wanderForce);
  }

  // updates velocity and position each frame
  void update() {
    vel.add(acc);
    vel.limit(maxSpeed);
    pos.add(vel);
    acc.mult(0);
  }

  // keeps the creature inside the world bounds
  void keepInBounds(int cols, int rows) {
    float edgeForce = 0.03;

    if (pos.x < 3) applyForce(new PVector(edgeForce, 0));
    if (pos.x > cols - 3) applyForce(new PVector(-edgeForce, 0));
    if (pos.y < 3) applyForce(new PVector(0, edgeForce));
    if (pos.y > rows - 3) applyForce(new PVector(0, -edgeForce));

    pos.x = constrain(pos.x, 0, cols - 0.01);
    pos.y = constrain(pos.y, 0, rows - 0.01);
  }

  // draws the creature on the screen
  void display(color c) {
    if (!isVisible(pos)) return;

    float sx = (pos.x - camX) * cellSize;
    float sy = (pos.y - camY) * cellSize;

    pushMatrix();
    translate(sx, sy);
    rotate(vel.heading());

    // shows detection range if turned on
    if (showRanges) {
      noFill();
      stroke(255, 120);
      ellipse(0, 0, detectRange * cellSize * 2, detectRange * cellSize * 2);
    }

    // draws the creature as a triangle
    noStroke();
    fill(c);
    triangle(10, 0, -8, -6, -8, 6);
    popMatrix();

    // shows the current state above the creature
    fill(0);
    text(state, sx + 8, sy - 8);
  }

  /*
  // front-facing line of sight
  // used to check if something is in front of the creature
  boolean canSeeInFront(PVector target) {
    return false;
  }

  // close-range interaction check
  // used to check if a creature is close enough to a target
  boolean isCloseTo(PVector target, float radius) {
    return false;
  }

  // chase timeout
  // used so a carnivore stops chasing after too long
  void resetChaseTimer() {
  }

  void updateChaseTimer() {
  }

  boolean chaseTimedOut() {
    return false;
  }

  // obstacle response hook
  // used later for avoiding walls or blocked spaces
  void avoidObstacles() {
  }
  */
}