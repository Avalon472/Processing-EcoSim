class World {
  int worldWidth;
  int worldHeight;
  PVector worldSize;
  int gridSize;

  ArrayList<Creature> herbivores;
  ArrayList<Creature> carnivores;
  ArrayList<PVector> plants;
  Camera camera;

  boolean showRanges = false;
  boolean paused = false;

  World(
    int widthUnits,
    int heightUnits,
    int unitSize,
    int herbivoreCount,
    int carnivoreCount,
    int plantCount,
    int cameraWidthUnits,
    int cameraHeightUnits
  ) {
    gridSize = unitSize;
    worldWidth = widthUnits;
    worldHeight = heightUnits;
    worldSize = new PVector(worldWidth, worldHeight);

    herbivores = new ArrayList<Creature>();
    carnivores = new ArrayList<Creature>();
    plants = new ArrayList<PVector>();
    camera = new Camera(cameraWidthUnits, cameraHeightUnits, gridSize, worldWidth, worldHeight);

    for (int i = 0; i < herbivoreCount; i++) {
      herbivores.add(new Creature(randomWorldPosition(), worldSize, false));
    }

    for (int i = 0; i < carnivoreCount; i++) {
      carnivores.add(new Creature(randomWorldPosition(), worldSize, true));
    }

    for (int i = 0; i < plantCount; i++) {
      plants.add(randomWorldPosition());
    }
  }

  void update() {
    if (!paused) {
      updateCreatures();
    }

    camera.drawGrid();
    drawPlants();
    drawCreatures();
    drawHUD();
  }

  void updateCreatures() {
    for (Creature herbivore : herbivores) {
      herbivore.update(this);
    }

    for (Creature carnivore : carnivores) {
      carnivore.update(this);
    }
  }

  void drawPlants() {
    noStroke();
    fill(70, 150, 70);

    for (PVector plant : plants) {
      if (!camera.isVisible(plant)) {
        continue;
      }

      PVector screenPos = camera.worldToScreen(plant);
      ellipse(screenPos.x, screenPos.y, 8, 8);
    }
  }

  void drawCreatures() {
    for (Creature herbivore : herbivores) {
      herbivore.draw(camera, showRanges);
    }

    for (Creature carnivore : carnivores) {
      carnivore.draw(camera, showRanges);
    }
  }

  void drawHUD() {
    fill(0, 160);
    noStroke();
    rect(10, 10, 305, 165);

    int livingHerbivores = countAlive(herbivores);
    int livingCarnivores = countAlive(carnivores);

    fill(255);
    text("Processing EcoSim", 20, 30);
    text("Arrow keys = move camera", 20, 50);
    text("R = toggle detection ranges", 20, 70);
    text("P = pause simulation", 20, 90);
    text("Herbivores seek plants and flee carnivores", 20, 110);
    text("Carnivores chase herbivores", 20, 130);
    text("Alive: " + livingHerbivores + " herbivores, " + livingCarnivores + " carnivores", 20, 150);
    text("Camera: (" + camera.x + ", " + camera.y + ")", 20, 170);
  }

  PVector findNearestPlant(PVector from, float range) {
    PVector best = null;
    float bestDist = range;

    for (PVector plant : plants) {
      float d = PVector.dist(from, plant);
      if (d < bestDist) {
        bestDist = d;
        best = plant;
      }
    }

    return best;
  }

  Creature findNearestCreature(PVector from, ArrayList<Creature> list, float range) {
    Creature best = null;
    float bestDist = range;

    for (Creature creature : list) {
      if (!creature.lifecycle.alive) {
        continue;
      }

      float d = PVector.dist(from, creature.position);
      if (d < bestDist) {
        bestDist = d;
        best = creature;
      }
    }

    return best;
  }

  void consumePlant(PVector plant) {
    if (plant == null) {
      return;
    }

    plant.set(randomWorldPosition());
  }

  void handleKeyPressed(char pressedKey, int pressedKeyCode) {
    if (pressedKeyCode == LEFT) {
      camera.move(-2, 0);
    }
    if (pressedKeyCode == RIGHT) {
      camera.move(2, 0);
    }
    if (pressedKeyCode == UP) {
      camera.move(0, -2);
    }
    if (pressedKeyCode == DOWN) {
      camera.move(0, 2);
    }

    if (pressedKey == 'r' || pressedKey == 'R') {
      showRanges = !showRanges;
    }

    if (pressedKey == 'p' || pressedKey == 'P') {
      paused = !paused;
    }
  }

  int countAlive(ArrayList<Creature> creatures) {
    int livingCount = 0;

    for (Creature creature : creatures) {
      if (creature.lifecycle.alive) {
        livingCount++;
      }
    }

    return livingCount;
  }

  PVector randomWorldPosition() {
    return new PVector(random(worldWidth), random(worldHeight));
  }
}
