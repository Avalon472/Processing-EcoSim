// Terrain type constants
final int GRASSLAND = 0;
final int BRUSH = 1;
final int WATER = 2;
final int ROCK = 3;

class World {
  int worldWidth;
  int worldHeight;
  PVector worldSize;
  int gridSize;

  int[][] terrain;  // terrain grid = every cell has a biome type

  ArrayList<Creature> herbivores;
  ArrayList<Creature> carnivores;
  ArrayList<PVector> plants;
  Camera camera;

  boolean showRanges = false;
  boolean paused = false;

  // terrain palette
  color grassColor = color(134, 180, 80);
  color brushColor = color(107, 142, 60);
  color waterColor = color(70, 130, 180);
  color rockColor  = color(160, 145, 120);

  // plant regrowth settings
  int   plantCap       = 60;   // max plants that can exist at once
  int   regrowInterval = 120;  // every N frames
  int   regrowCounter  = 0;

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

    // build the terrain 
    terrain = new int[worldWidth][worldHeight];
    generateTerrain();

    // Collections
    herbivores = new ArrayList<Creature>();
    carnivores = new ArrayList<Creature>();
    plants = new ArrayList<PVector>();
    camera = new Camera(cameraWidthUnits, cameraHeightUnits, gridSize, worldWidth, worldHeight);

    // spawn creatures on walkable land
    for (int i = 0; i < herbivoreCount; i++) {
      herbivores.add(new Creature(randomLandPosition(), worldSize, false));
    }

    for (int i = 0; i < carnivoreCount; i++) {
      carnivores.add(new Creature(randomLandPosition(), worldSize, true));
    }

    // spawn plants on grass or brush only
    for (int i = 0; i < plantCount; i++) {
      plants.add(randomPlantPosition());
    }
  }

  // Terrain generation
  void generateTerrain() {
    float scale = 0.035;          // bigger = smaller blobs
    float offsetX = random(1000); // random seed so every run is unique
    float offsetY = random(1000);

    for (int x = 0; x < worldWidth; x++) {
      for (int y = 0; y < worldHeight; y++) {
        float n = noise((x + offsetX) * scale, (y + offsetY) * scale);

        if (n < 0.30) {
          terrain[x][y] = WATER;
        } else if (n < 0.55) {
          terrain[x][y] = GRASSLAND;
        } else if (n < 0.75) {
          terrain[x][y] = BRUSH;
        } else {
          terrain[x][y] = ROCK;
        }
      }
    }
  }

  // Terrain Rendering
  void drawTerrain() {
    noStroke();

    int startX = camera.x;
    int startY = camera.y;
    int endX   = min(camera.x + camera.cols, worldWidth);
    int endY   = min(camera.y + camera.rows, worldHeight);

    for (int gx = startX; gx < endX; gx++) {
      for (int gy = startY; gy < endY; gy++) {
        int screenX = (gx - camera.x) * camera.cellSize;
        int screenY = (gy - camera.y) * camera.cellSize;

        switch (terrain[gx][gy]) {
          case GRASSLAND: fill(grassColor); break;
          case BRUSH:     fill(brushColor); break;
          case WATER:     fill(waterColor); break;
          case ROCK:      fill(rockColor);  break;
        }

        rect(screenX, screenY, camera.cellSize, camera.cellSize);
      }
    }
  }

  // Terrain query helpers
  int getTerrainAt(float wx, float wy) {
    int gx = constrain(int(wx), 0, worldWidth  - 1);
    int gy = constrain(int(wy), 0, worldHeight - 1);
    return terrain[gx][gy];
  }

  boolean isWalkable(float wx, float wy) {
    return getTerrainAt(wx, wy) != WATER;
  }

  void update() {
    if (!paused) {
      updateCreatures();
      updatePlantRegrowth();
    }

    drawTerrain();    // biome colred tiles
    camera.drawGrid();
    drawPlants();
    drawCreatures();
    drawHUD();
  }

  // Plant Regrowth
  void updatePlantRegrowth() {
    regrowCounter++;
    if (regrowCounter >= regrowInterval && plants.size() < plantCap) {
      plants.add(randomPlantPosition());
      regrowCounter = 0;
    }
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

      PVector sp = camera.worldToScreen(plant);
      // small tree look: trunk + canopy
      fill(100, 70, 40);
      rect(sp.x - 1, sp.y, 2, 5);
      fill(34, 120, 34);
      ellipse(sp.x, sp.y - 1, 9, 9);
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
    rect(10, 10, 310, 215);

    int livingH = countAlive(herbivores);
    int livingC = countAlive(carnivores);
    
    fill(255);
    text("Processing EcoSim", 20, 30);
    text("Arrow keys = move camera", 20, 50);
    text("R = toggle detection ranges", 20, 70);
    text("P = pause simulation", 20, 90);
    text("Herbivores seek plants and flee carnivores", 20, 110);
    text("Carnivores chase herbivores", 20, 130);
    text("Alive: " + livingH + " herbivores, " + livingC + " carnivores", 20, 150);
    text("Plants: " + plants.size(), 20, 170);
    text("Camera: (" + camera.x + ", " + camera.y + ")", 20, 190);

    // terrain legend
    int legendY = 220;
    fill(0, 160);
    noStroke();
    rect(10, legendY - 5, 170, 80);

    fill(255);
    text("Terrain:", 20, legendY + 10);

    fill(grassColor); noStroke(); rect(20, legendY + 18, 10, 10);
    fill(255);  text("Grassland", 35, legendY + 27);

    fill(brushColor); noStroke(); rect(100, legendY + 18, 10, 10);
    fill(255);  text("Brush", 115, legendY + 27);

    fill(waterColor); noStroke(); rect(20, legendY + 38, 10, 10);
    fill(255);  text("Water", 35, legendY + 47);

    fill(rockColor); noStroke(); rect(100, legendY + 38, 10, 10);
    fill(255);  text("Rock", 115, legendY + 47);
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

    plant.set(randomPlantPosition());
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

  // random position on any non-water tile
  PVector randomLandPosition() {
    PVector pos;
    int attempts = 0;
    do {
      pos = new PVector(random(worldWidth), random(worldHeight));
      attempts++;
    } while (!isWalkable(pos.x, pos.y) && attempts < 500);
    return pos;
  }

  // random position on grassland or brush only (for plants)
  PVector randomPlantPosition() {
    PVector pos;
    int t;
    int attempts = 0;
    do {
      pos = new PVector(random(worldWidth), random(worldHeight));
      t = getTerrainAt(pos.x, pos.y);
      attempts++;
    } while (t != GRASSLAND && t != BRUSH && attempts < 500);
    return pos;
  }
}
