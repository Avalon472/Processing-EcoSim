//Description will go here
World w; 

void setup(){
  size(600,400);
  w = new World(600, 400, 1, 10);
}

void draw() {
  background(0);
  w.update();
}
