World w;

void setup() {
  size(800, 800);
  textSize(14);
  w = new World(200, 200, 8, 18, 4, 30, 100, 100);
}

void draw() {
  background(214, 190, 140);
  w.update();
}

void keyPressed() {
  w.handleKeyPressed(key, keyCode);
}
