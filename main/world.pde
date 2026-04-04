//This is a rough outline of the world class,
//currently there is an agnostic creature class,
//which will later get inherited by carnivores and herbivores

//Goals:
//generate world size
//starting creature count
//simulation speed?
//update method to call update for each creature
class World {
    int worldWidth;
    int worldHeight;
    PVector worldSize;
    int gridSize;
    // plant[] plants;
    // herbivore[] herbivores;
    // carnivore[] carnovires;

    Creature[] initCreatures;


    World(int widthUnits, int heightUnits, int unitSize, int hCount){ //add plant and carnivore count once behavior settled
        gridSize = unitSize;
        worldWidth = widthUnits * unitSize;
        worldHeight = heightUnits * unitSize;
        worldSize = new PVector(widthUnits * unitSize, heightUnits * unitSize);
        initCreatures = new Creature[hCount];
        for(int i = 0; i<hCount; i++){
            PVector initPosition = new PVector(int(random(50, worldWidth - 50)), int(random(50, worldHeight - 50)));
            // PVector bounds = new PVector(worldWidth, worldHeight);
            initCreatures[i] = new Creature(initPosition, worldSize);
        }

    }

    void update(){
        for(Creature c : initCreatures){
            c.update(this);
            c.draw();
        }
    }
}