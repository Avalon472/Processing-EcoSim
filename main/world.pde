// ============================================================
//  EcoSim – world.pde
//  World: entity collections, update loop, rendering helpers,
//  reproduction, population graph, HUD.
//
//  CHANGES FROM ORIGINAL:
//   - findNearestReadyMate(): finds a same-species creature that
//     also has enough energy to mate, excluding self.
//   - spawnOffspring(): deducts reproductionCost from both
//     parents, crossbreeds their LifecycleSystems, and inserts
//     the child into the appropriate list. Births are capped so
//     the simulation doesn't explode.
//   - Dead creatures are pruned after exceeding MAX_CORPSES so
//     memory doesn't grow unbounded.
//   - Population history tracked for a scrolling side graph.
//   - HUD extended: shows per-stat averages and birth counts.
//   - handleKey() renamed from handleKeyPressed() to match
//     original; alias kept for compatibility.
// ============================================================

// ── Global population caps ────────────────────────────────────
final int MAX_HERBIVORES = 80;
final int MAX_CARNIVORES = 40;
final int MAX_CORPSES    = 30;   // dead creatures kept for inspection
final int GRAPH_HISTORY  = 300;  // frames of pop history to display

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
  ArrayList<PVector>  plants;
  Camera camera;

  boolean showRanges  = false;
  boolean paused      = false;

  // terrain palette
  color grassColor = color(134, 180, 80);
  color brushColor = color(107, 142, 60);
  color waterColor = color(70, 130, 180);
  color rockColor  = color(160, 145, 120);

  // plant regrowth settings
  int   plantCap       = 60;   // max plants that can exist at once
  int   regrowInterval = 120;  // every N frames
  int   regrowCounter  = 0;
  boolean showGraph   = true;

  // Birth counters (displayed in HUD)
  int herbBirths = 0;
  int carnBirths = 0;

  // Pending offspring queued during update to avoid
  // ConcurrentModificationException mid-loop
  ArrayList<Creature> pendingHerbivores;
  ArrayList<Creature> pendingCarnivores;

  // Population history for scrolling graph
  int[] herbHistory;
  int[] carnHistory;
  int   historyHead = 0;

  // Carnivore lair
  PVector carnivoreLairCenter;
  float carnivoreLairRadius = 20;
  float carnivoreRestRadius = 12;
  int maxCarnivoreLairResidents = 5;
  PVector[] carnivoreGuardPosts;

  World(int widthUnits, int heightUnits, int unitSize,
        int herbivoreCount, int carnivoreCount, int plantCount,
        int cameraWidthUnits, int cameraHeightUnits) {

    gridSize    = unitSize;
    worldWidth  = widthUnits;
    worldHeight = heightUnits;
    worldSize   = new PVector(worldWidth, worldHeight);

    // build the terrain 
    terrain = new int[worldWidth][worldHeight];
    generateTerrain();

    // Collections
    herbivores       = new ArrayList<Creature>();
    carnivores       = new ArrayList<Creature>();
    plants           = new ArrayList<PVector>();
    pendingHerbivores = new ArrayList<Creature>();
    pendingCarnivores = new ArrayList<Creature>();

    herbHistory = new int[GRAPH_HISTORY];
    carnHistory = new int[GRAPH_HISTORY];

    camera = new Camera(cameraWidthUnits, cameraHeightUnits,
                        gridSize, worldWidth, worldHeight);

    carnivoreLairCenter = findNearestLandPosition(worldWidth * 0.68,
                                                  worldHeight * 0.34);
    updateCarnivoreGuardPosts();

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

  // ── Main update / render loop ─────────────────────────────────
  void update() {
    if (!paused) {
      updateCreatures();
      updatePlantRegrowth();
      flushPending();
      pruneCorpses();
      recordHistory();
    }

    drawTerrain();    // biome colred tiles
    drawCarnivoreLair();
    camera.drawGrid();
    drawPlants();
    drawCreatures();
    drawHUD();
    if (showGraph) drawGraph();
  }

  // Plant Regrowth
  void updatePlantRegrowth() {
    regrowCounter++;
    if (regrowCounter >= regrowInterval && plants.size() < plantCap) {
      plants.add(randomPlantPosition());
      regrowCounter = 0;
    }
  }

  // ── Entity updates ────────────────────────────────────────────
  void updateCreatures() {
    for (Creature h : herbivores) h.update(this);
    for (Creature c : carnivores) c.update(this);
  }

  // Add queued offspring now that iteration is complete
  void flushPending() {
    for (Creature c : pendingHerbivores) herbivores.add(c);
    for (Creature c : pendingCarnivores) carnivores.add(c);
    pendingHerbivores.clear();
    pendingCarnivores.clear();
  }

  // Remove excess dead creatures to keep list sizes bounded
  void pruneCorpses() {
    pruneList(herbivores, MAX_CORPSES);
    pruneList(carnivores, MAX_CORPSES);
  }

  void pruneList(ArrayList<Creature> list, int maxDead) {
    int dead = 0;
    for (int i = list.size() - 1; i >= 0; i--) {
      if (!list.get(i).lifecycle.alive) {
        dead++;
        if (dead > maxDead) list.remove(i);
      }
    }
  }

  void recordHistory() {
    herbHistory[historyHead] = countAlive(herbivores);
    carnHistory[historyHead] = countAlive(carnivores);
    historyHead = (historyHead + 1) % GRAPH_HISTORY;
  }

  // ── Reproduction ──────────────────────────────────────────────
  // Called from Creature when two ready mates overlap.
  // Both parents pay the energy cost; a child is queued.
  void spawnOffspring(Creature parentA, Creature parentB,
                      ArrayList<Creature> list) {
    // Sanity – both parents must still be alive and willing
    if (!parentA.lifecycle.canReproduce() ||
        !parentB.lifecycle.canReproduce()) return;

    // Population cap
    if (list == herbivores && countAlive(herbivores) >= MAX_HERBIVORES) return;
    if (list == carnivores && countAlive(carnivores) >= MAX_CARNIVORES) return;

    // Deduct energy from parents
    parentA.lifecycle.changeEnergy(-parentA.lifecycle.reproductionCost);
    parentB.lifecycle.changeEnergy(-parentB.lifecycle.reproductionCost);

    // Child spawns at midpoint between parents
    PVector childPos = PVector.lerp(parentA.position, parentB.position, 0.5);

    // Build crossbred genome
    LifecycleSystem childLife =
      crossbreed(parentA.lifecycle, parentB.lifecycle);

    Creature child = new Creature(childPos, worldSize,
                                  parentA.predator, childLife);

    // Queue to avoid modifying lists during iteration
    if (list == herbivores) {
      pendingHerbivores.add(child);
      herbBirths++;
    } else {
      pendingCarnivores.add(child);
      carnBirths++;
    }

    // Force parents back to WANDER so they don't immediately try
    // to mate again (energy gate re-applies naturally)
    parentA.state = "WANDER";
    parentB.state = "WANDER";
  }

  // ── Spatial queries ───────────────────────────────────────────
  PVector findNearestPlant(PVector from, float range) {
    PVector best = null;
    float bestDist = range;
    for (PVector plant : plants) {
      float d = PVector.dist(from, plant);
      if (d < bestDist) { bestDist = d; best = plant; }
    }
    return best;
  }

  PVector findNearestPlantOutsideLair(PVector from, float range) {
    PVector best = null;
    float bestDist = range;
    for (PVector plant : plants) {
      if (isInCarnivoreLair(plant)) continue;
      float d = PVector.dist(from, plant);
      if (d < bestDist) { bestDist = d; best = plant; }
    }
    return best;
  }

  Creature findNearestCreature(PVector from, ArrayList<Creature> list,
                                float range) {
    Creature best = null;
    float bestDist = range;
    for (Creature c : list) {
      if (!c.lifecycle.alive) continue;
      float d = PVector.dist(from, c.position);
      if (d < bestDist) { bestDist = d; best = c; }
    }
    return best;
  }

  // Finds all alive carnivores within range, excluding self.
  ArrayList<Creature> findNearbyCarnivores(PVector pos, float range, Creature self) {
    ArrayList<Creature> nearby = new ArrayList<Creature>();

    for (Creature c : carnivores) {
      if (c == self) continue;
      if (!c.lifecycle.alive) continue;

      if (PVector.dist(pos, c.position) <= range) {
        nearby.add(c);
      }
    }

    return nearby;
  }

  boolean isInCarnivoreLair(PVector pos) {
    return PVector.dist(pos, carnivoreLairCenter) <= carnivoreLairRadius;
  }

  boolean isInCarnivoreRestArea(PVector pos) {
    return PVector.dist(pos, carnivoreLairCenter) <= carnivoreRestRadius;
  }

  Creature getCarnivoreGuard(int slot) {
    int found = 0;
    for (Creature c : carnivores) {
      if (!c.lifecycle.alive) continue;
      if (found == slot) return c;
      found++;
    }
    return null;
  }

  boolean isCarnivoreGuard(Creature candidate) {
    return candidate == getCarnivoreGuard(0) ||
           candidate == getCarnivoreGuard(1);
  }

  PVector getCarnivoreGuardPost(Creature guard) {
    if (guard == getCarnivoreGuard(0)) return carnivoreGuardPosts[0].copy();
    return carnivoreGuardPosts[1].copy();
  }

  Creature findNearestHerbivoreInLair(PVector from, float range) {
    Creature best = null;
    float bestDist = range;

    for (Creature h : herbivores) {
      if (!h.lifecycle.alive) continue;
      if (!isInCarnivoreLair(h.position)) continue;

      float d = PVector.dist(from, h.position);
      if (d < bestDist) {
        bestDist = d;
        best = h;
      }
    }

    return best;
  }

  int countCarnivoreLairResidents() {
    int count = 0;
    for (Creature c : carnivores) {
      if (!c.lifecycle.alive) continue;
      if (isCarnivoreGuard(c)) continue;
      if (!isInCarnivoreLair(c.position)) continue;
      count++;
    }
    return count;
  }

  boolean isCarnivoreLairOverCapacity() {
    return countCarnivoreLairResidents() > maxCarnivoreLairResidents;
  }

  Creature findStrongestCarnivoreInLair() {
    Creature strongest = null;

    for (Creature c : carnivores) {
      if (!c.lifecycle.alive) continue;
      if (isCarnivoreGuard(c)) continue;
      if (!isInCarnivoreLair(c.position)) continue;

      if (strongest == null || c.lifecycle.energy > strongest.lifecycle.energy) {
        strongest = c;
      }
    }

    return strongest;
  }

  boolean shouldLeaveOvercrowdedLair(Creature candidate) {
    if (candidate == null) return false;
    if (!candidate.lifecycle.alive) return false;
    if (isCarnivoreGuard(candidate)) return false;
    if (!isInCarnivoreLair(candidate.position)) return false;

    ArrayList<Creature> residents = new ArrayList<Creature>();
    for (Creature c : carnivores) {
      if (!c.lifecycle.alive) continue;
      if (isCarnivoreGuard(c)) continue;
      if (!isInCarnivoreLair(c.position)) continue;
      residents.add(c);
    }

    while (residents.size() > maxCarnivoreLairResidents) {
      Creature strongest = residents.get(0);
      for (Creature c : residents) {
        if (c.lifecycle.energy > strongest.lifecycle.energy) {
          strongest = c;
        }
      }

      if (strongest == candidate) {
        return true;
      }
      residents.remove(strongest);
    }

    return false;
  }

  // Finds the nearest alive, reproduction-ready creature in list
  // that is not the caller itself.
  Creature findNearestReadyMate(PVector from, ArrayList<Creature> list,
                                 Creature self, float range) {
    Creature best = null;
    float bestDist = range;
    for (Creature c : list) {
      if (c == self) continue;
      if (!c.lifecycle.alive) continue;
      if (!c.lifecycle.canReproduce()) continue;
      float d = PVector.dist(from, c.position);
      if (d < bestDist) { bestDist = d; best = c; }
    }
    return best;
  }

  void consumePlant(PVector plant) {
    if (plant == null) {
      return;
    }

    plant.set(randomPlantPosition());
  }

  // ── Drawing ───────────────────────────────────────────────────
  void drawPlants() {
    noStroke();
    fill(70, 150, 70);
    for (PVector plant : plants) {
      if (!camera.isVisible(plant)) continue;
      PVector sp = camera.worldToScreen(plant);
      ellipse(sp.x, sp.y, 8, 8);
    }
  }

  void drawCarnivoreLair() {
    if (!camera.isVisible(carnivoreLairCenter)) return;

    PVector screenCenter = camera.worldToScreen(carnivoreLairCenter);
    float lairDiameter = carnivoreLairRadius * 2 * camera.cellSize;
    float restDiameter = carnivoreRestRadius * 2 * camera.cellSize;

    noStroke();
    fill(140, 55, 55, 80);
    ellipse(screenCenter.x, screenCenter.y, lairDiameter, lairDiameter);
    fill(180, 85, 85, 110);
    ellipse(screenCenter.x, screenCenter.y, restDiameter, restDiameter);

    stroke(120, 35, 35, 190);
    noFill();
    ellipse(screenCenter.x, screenCenter.y, lairDiameter, lairDiameter);

    fill(255, 230, 220);
    textSize(12);
    text("Carnivore Lair", screenCenter.x - 36, screenCenter.y - lairDiameter * 0.55);
  }

  void drawCreatures() {
    for (Creature h : herbivores) h.draw(camera, showRanges);
    for (Creature c : carnivores) c.draw(camera, showRanges);
  }

  // ── HUD ───────────────────────────────────────────────────────
  void drawHUD() {
    int aH = countAlive(herbivores);
    int aC = countAlive(carnivores);

    fill(0, 170);
    noStroke();
    rect(10, 10, 350, 220, 6);

    fill(255);
    textSize(18);
    text("Processing EcoSim", 20, 32);
    textSize(15);
    fill(200);
    text("Arrow keys: camera  |  R: ranges  |  P: pause  |  G: graph", 20, 50);

    fill(255);
    text("Herbivores alive : " + aH +
         "  (births: " + herbBirths + ")", 20, 72);
    text("Carnivores alive : " + aC +
         "  (births: " + carnBirths + ")", 20, 88);
    text("Plants           : " + plants.size(), 20, 104);
    text("Carnivore lair   : 5 residents max, 2 guards defend and cull extras", 20, 120);

    // Average stats for each species
    text("Herbivore avg stats: ", 20, 138);
    text(avgStatsLabel(herbivores), 20, 154);
    text("Carnivore avg stats: ", 20, 170);
    text(avgStatsLabel(carnivores), 20, 186);

    text("Camera: (" + camera.x + ", " + camera.y + ")", 20, 202);
    text("Repro threshold: 75 energy  |  Cost: 25 / parent", 20, 218);
  }

  String avgStatsLabel(ArrayList<Creature> list) {
    int n = 0;
    float sumSpd = 0, sumMet = 0, sumDet = 0;
    for (Creature c : list) {
      if (!c.lifecycle.alive) continue;
      sumSpd += c.lifecycle.maxSpeed;
      sumMet += c.lifecycle.metabolism;
      sumDet += c.lifecycle.detectionRange;
      n++;
    }
    if (n == 0) return "  (none alive)";
    return String.format("  speed:%.3f  metabolism:%.3f  detection range:%.1f",
      sumSpd/n, sumMet/n, sumDet/n);
  }

  // ── Population graph (scrolling) ──────────────────────────────
  void drawGraph() {
    int gx = width - GRAPH_HISTORY - 15;
    int gy = height - 80;
    int gh = 60;

    fill(0, 160);
    noStroke();
    rect(gx - 5, gy - gh - 15, GRAPH_HISTORY + 10, gh + 30, 4);

    fill(180);
    textSize(10);
    text("Population (last " + GRAPH_HISTORY + " frames)", gx, gy - gh - 2);

    // Find max for scaling
    int peak = 10;
    for (int i = 0; i < GRAPH_HISTORY; i++) {
      peak = max(peak, herbHistory[i], carnHistory[i]);
    }

    // Draw lines
    for (int i = 1; i < GRAPH_HISTORY; i++) {
      int prev = (historyHead + i - 1) % GRAPH_HISTORY;
      int curr = (historyHead + i)     % GRAPH_HISTORY;

      float x0 = gx + i - 1;
      float x1 = gx + i;

      // Herbivore – blue
      stroke(80, 140, 255, 200);
      line(x0, gy - gh * herbHistory[prev] / (float)peak,
           x1, gy - gh * herbHistory[curr] / (float)peak);

      // Carnivore – red
      stroke(220, 80, 80, 200);
      line(x0, gy - gh * carnHistory[prev] / (float)peak,
           x1, gy - gh * carnHistory[curr] / (float)peak);
    }

    noStroke();
    fill(80, 140, 255); rect(gx, gy + 5, 10, 8);
    fill(200); text("Herb", gx + 14, gy + 13);
    fill(220, 80, 80); rect(gx + 50, gy + 5, 10, 8);
    fill(200); text("Carn", gx + 64, gy + 13);
  }

  // ── Controls ──────────────────────────────────────────────────
  void handleKeyPressed(char pressedKey, int pressedKeyCode) {
    handleKey(pressedKey, pressedKeyCode);
  }
  void handleKey(char pressedKey, int pressedKeyCode) {
    if (pressedKeyCode == LEFT)  camera.move(-4,  0);
    if (pressedKeyCode == RIGHT) camera.move( 4,  0);
    if (pressedKeyCode == UP)    camera.move( 0, -4);
    if (pressedKeyCode == DOWN)  camera.move( 0,  4);
    if (pressedKey == 'r' || pressedKey == 'R') showRanges = !showRanges;
    if (pressedKey == 'p' || pressedKey == 'P') paused     = !paused;
    if (pressedKey == 'g' || pressedKey == 'G') showGraph  = !showGraph;
  }

  // ── Utility ───────────────────────────────────────────────────
  int countAlive(ArrayList<Creature> creatures) {
    int n = 0;
    for (Creature c : creatures) if (c.lifecycle.alive) n++;
    return n;
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
      pos = new PVector(random(50, worldWidth-50), random(50, worldHeight-50));
      t = getTerrainAt(pos.x, pos.y);
      attempts++;
    } while (((t != GRASSLAND && t != BRUSH) || isInCarnivoreLair(pos)) &&
             attempts < 500);
    return pos;
  }

  PVector getCarnivoreLairExitPoint(PVector from) {
    PVector direction = PVector.sub(from, carnivoreLairCenter);
    if (direction.magSq() < 0.001) {
      direction = PVector.random2D();
    }

    direction.normalize();
    PVector target = PVector.add(carnivoreLairCenter,
      PVector.mult(direction, carnivoreLairRadius + 8));
    return findNearestLandPosition(target.x, target.y);
  }

  PVector findNearestLandPosition(float preferredX, float preferredY) {
    int baseX = constrain(round(preferredX), 0, worldWidth - 1);
    int baseY = constrain(round(preferredY), 0, worldHeight - 1);

    for (int radius = 0; radius < max(worldWidth, worldHeight); radius++) {
      for (int dx = -radius; dx <= radius; dx++) {
        for (int dy = -radius; dy <= radius; dy++) {
          int x = constrain(baseX + dx, 0, worldWidth - 1);
          int y = constrain(baseY + dy, 0, worldHeight - 1);
          if (isWalkable(x, y)) {
            return new PVector(x, y);
          }
        }
      }
    }

    return randomLandPosition();
  }

  void updateCarnivoreGuardPosts() {
    carnivoreGuardPosts = new PVector[2];
    carnivoreGuardPosts[0] = new PVector(
      constrain(carnivoreLairCenter.x - carnivoreLairRadius * 0.65, 1, worldWidth - 1),
      constrain(carnivoreLairCenter.y, 1, worldHeight - 1)
    );
    carnivoreGuardPosts[1] = new PVector(
      constrain(carnivoreLairCenter.x + carnivoreLairRadius * 0.65, 1, worldWidth - 1),
      constrain(carnivoreLairCenter.y, 1, worldHeight - 1)
    );
  }
}
