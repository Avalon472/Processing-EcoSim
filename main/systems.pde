class LifecycleSystem {
  float energy;
  float maxEnergy;
  float metabolism;

  float speed;
  float maxSpeed;
  float maxForce;
  float detectionRange;

  float reproductionThreshold;
  float reproductionCost;

  boolean alive = true;

  LifecycleSystem(int initEnergy, boolean predator) {
    energy = initEnergy;
    maxEnergy = 100;
    metabolism = predator ? 0.055 : 0.04;

    speed = predator ? 0.11 : 0.09;
    maxSpeed = speed;
    maxForce = predator ? 0.010 : 0.008;
    detectionRange = predator ? 28 : 22;

    reproductionThreshold = 80;
    reproductionCost = 30;
  }

  void changeEnergy(float amount) {
    energy += amount;
    energy = constrain(energy, 0, maxEnergy);
  }

  boolean canReproduce() {
    return energy >= reproductionThreshold;
  }

  void reproduce(PVector position) {
    // Placeholder for later lifecycle expansion.
  }

  void die() {
    alive = false;
  }
}
