//sk03: Bouncing ball with a Ball class
Ball b;

void setup(){
  size(600,400);
  b = new Ball();
}

void draw() {
  background(0);
  b.move();
  b.display();
}
