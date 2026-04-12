// lists for all creatures and plant targets
ArrayList<Creature> herbivores;
ArrayList<Creature> carnivores;
ArrayList<PVector> plants;

// world size and grid cell size
int worldCols = 200;
int worldRows = 200;
int cellSize = 8;

// camera view size and camera position
int cameraCols = 100;
int cameraRows = 100;
int camX = 0;
int camY = 0;

// toggles for showing ranges and pausing
boolean showRanges = false;
boolean paused = false;

void setup() {
  size(800, 800);

  // create the lists
  herbivores = new ArrayList<Creature>();
  carnivores = new ArrayList<Creature>();
  plants = new ArrayList<PVector>();

  // add herbivores to the world
  for (int i = 0; i < 18; i++) {
    herbivores.add(new Creature(random(worldCols), random(worldRows), false));
  }

  // add carnivores to the world
  for (int i = 0; i < 4; i++) {
    carnivores.add(new Creature(random(worldCols), random(worldRows), true));
  }

  // add plants to the world
  for (int i = 0; i < 30; i++) {
    plants.add(new PVector(random(worldCols), random(worldRows)));
  }

  textSize(14);
}

void draw() {
  // draws the background each frame
  background(214, 190, 140);

  // updates movement if not paused
  if (!paused) {
    updateCreatures();
  }

  // draws the world and interface
  drawGrid();
  drawPlants();
  drawCreatures();
  drawHUD();
}

void updateCreatures() {
  // herbivores flee predators, seek plants, or wander
  for (Creature h : herbivores) {
    PVector nearestPlant = findNearestPlant(h.pos, h.detectRange);
    Creature nearestPredator = findNearestCreature(h.pos, carnivores, h.detectRange);

    if (nearestPredator != null) {
      h.state = "FLEE";
      h.flee(nearestPredator.pos);
    } else if (nearestPlant != null) {
      h.state = "SEEK";
      h.seek(nearestPlant);
    } else {
      h.state = "WANDER";
      h.wander();
    }

    /*
    // close-range interaction check
    // used later for reaching plants
    if (nearestPlant != null && h.isCloseTo(nearestPlant, h.stopDistance)) {
    }
    */

    h.update();
    h.keepInBounds(worldCols, worldRows);
  }

  // carnivores chase herbivores or wander
  for (Creature c : carnivores) {
    Creature nearestPrey = findNearestCreature(c.pos, herbivores, c.detectRange);

    if (nearestPrey != null) {
      c.state = "CHASE";
      c.seek(nearestPrey.pos);

      /*
      // chase timeout
      // used so carnivores can give up a chase later
      c.updateChaseTimer();
      if (c.chaseTimedOut()) {
        c.state = "WANDER";
        c.resetChaseTimer();
      }
      */
    } else {
      c.state = "WANDER";
      c.wander();

      /*
      // chase timeout
      // used to reset chase timing when not chasing
      c.resetChaseTimer();
      */
    }

    /*
    // close-range interaction check
    // used later for catching prey
    if (nearestPrey != null && c.isCloseTo(nearestPrey.pos, c.catchDistance)) {
    }
    */

    c.update();
    c.keepInBounds(worldCols, worldRows);
  }
}

void drawGrid() {
  // draws the visible grid
  stroke(120, 110, 95, 80);
  for (int x = 0; x <= cameraCols; x++) {
    line(x * cellSize, 0, x * cellSize, cameraRows * cellSize);
  }
  for (int y = 0; y <= cameraRows; y++) {
    line(0, y * cellSize, cameraCols * cellSize, y * cellSize);
  }
}

void drawPlants() {
  // draws visible plants
  noStroke();
  fill(70, 150, 70);
  for (PVector p : plants) {
    if (isVisible(p)) {
      float sx = (p.x - camX) * cellSize;
      float sy = (p.y - camY) * cellSize;
      ellipse(sx, sy, 8, 8);
    }
  }
}

void drawCreatures() {
  // draws herbivores
  for (Creature h : herbivores) {
    h.display(color(60, 120, 255));
  }

  // draws carnivores
  for (Creature c : carnivores) {
    c.display(color(220, 70, 70));
  }
}

void drawHUD() {
  // draws the info box
  fill(0, 160);
  noStroke();
  rect(10, 10, 270, 120);

  fill(255);
  text("Movement Demo", 20, 30);
  text("Arrow keys = move camera", 20, 50);
  text("R = toggle ranges", 20, 70);
  text("P = pause", 20, 90);
  text("Herbivores seek plants, flee carnivores", 20, 110);
  text("Carnivores chase herbivores", 20, 130);
}

boolean isVisible(PVector p) {
  // checks if something is inside the camera view
  return p.x >= camX && p.x < camX + cameraCols && p.y >= camY && p.y < camY + cameraRows;
}

PVector findNearestPlant(PVector from, float range) {
  // finds the nearest plant in range
  PVector best = null;
  float bestDist = range;

  for (PVector p : plants) {
    float d = PVector.dist(from, p);
    if (d < bestDist) {
      bestDist = d;
      best = p.copy();
    }
  }

  return best;
}

Creature findNearestCreature(PVector from, ArrayList<Creature> list, float range) {
  // finds the nearest creature in range
  Creature best = null;
  float bestDist = range;

  for (Creature c : list) {
    float d = PVector.dist(from, c.pos);
    if (d < bestDist) {
      bestDist = d;
      best = c;
    }
  }

  return best;
}

void keyPressed() {
  // moves the camera with arrow keys
  if (keyCode == LEFT) camX = max(0, camX - 2);
  if (keyCode == RIGHT) camX = min(worldCols - cameraCols, camX + 2);
  if (keyCode == UP) camY = max(0, camY - 2);
  if (keyCode == DOWN) camY = min(worldRows - cameraRows, camY + 2);

  // toggles range circles
  if (key == 'r' || key == 'R') showRanges = !showRanges;

  // pauses the simulation
  if (key == 'p' || key == 'P') paused = !paused;
}