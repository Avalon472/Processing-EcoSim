//This will be made into an abstract class once behavior is established
class Creature {
  //move these into movement system?
  PVector position;
  PVector velocity;
  PVector boundaries;
  int energyValue;
//   int despawnTimer;

 LifecycleSystem lifecycle;
//  MovementSystem movement;
//  PerceptionSystem perception;

  Creature(PVector pos, PVector worldSize) {
    position = pos.copy();
    boundaries = worldSize.copy();
    // initialize stats (will randomize later)
    lifecycle = new LifecycleSystem(int(random(10, 50)));
    velocity = new PVector(lifecycle.speed, lifecycle.speed);
  }

  void update(World world) {
    if(lifecycle.alive){
        //Creature uses perception system to determine direction of movement
        //Creature either then calls movement separately or it gets called within percieve
        // perception.percieve(world creature)
        // movement.move()

        position.add(velocity);
        if(position.x > boundaries.x - 10 || position.x < 10){
          velocity.x *= -1;
        }
        if(position.y > boundaries.y - 10 || position.y < 10){
          velocity.y *= -1;
        }
        lifecycle.changeEnergy(lifecycle.metabolism * -1);
        if(lifecycle.energy <= 0) lifecycle.die();
        println(lifecycle.energy);
    }
    // else{despawnTimer -= 1}

  }

  //Camera system can selectively call draw?
  void draw(){
    if(lifecycle.alive) fill (0, 255, 0);
    else fill(0,155,0);
    ellipse(position.x, position.y, 20,20);
  }

//   abstract void behave(World world);
}