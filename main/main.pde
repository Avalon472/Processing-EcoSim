// ============================================================
//  EcoSim – main.pde
//  Entry point: setup / draw / key forwarding
// ============================================================

World w;

void setup() {
  size(800, 800);
  textSize(12);
  w = new World(200, 200, 8, 70, 30, 120, 100, 100);
}

void draw() {
  background(214, 190, 140);
  w.update();
}

void keyPressed() {
  w.handleKeyPressed(key, keyCode);
}
