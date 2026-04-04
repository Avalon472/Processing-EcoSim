//The movement and perception systems can be put into separate files,
//but from what I understand processing doesn't like sub directories
//so I left everything in a single folder

//If we keep everything in one file, we can use region tags

// #region Lifecycle
class LifecycleSystem {
  //Core lifecycle stats
  float energy;
  float maxEnergy;
  float metabolism;     //Energy lost per tick

  //Behavior stats - get passed back in creature class to other systems?
  float speed;
  float detectionRange;

  //Reproduction
  float reproductionThreshold; //Energy needed to reproduce
  float reproductionCost;      //Energy spent to reproduce

  boolean alive = true;

  LifecycleSystem(int initEnergy){
    energy = initEnergy;
    maxEnergy = 100;
    metabolism = 0.1;

    speed = int(random(0.5, 3));
    detectionRange = 25;

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

  void reproduce(PVector position){
    //return creature @ posiiton with averaged stats
    //need other creature param to draw energy from both?
  }

  void die() {
    alive = false;
  }

}
// endregion

//#region Next system
// endregion