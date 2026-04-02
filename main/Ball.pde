//Ball class using RGB
class Ball {
  int xpos, ypos;
  int w, h;
  int xspeed, yspeed;
  color c;
  
  Ball() {
    w = int(random(10,51));
    h = int(random(10,51));
    xpos = int(random(w, width-w));
    ypos = int(random(h, height-h));
    xspeed = int(random(5, 11));
    yspeed = int(random(5, 11));
    int r = int(random(0, 256));
    int g = int(random(0, 256));
    int b = int(random(0, 256));
    c =  color(r, g, b);
  }
  void move() {
    xpos += xspeed;
    ypos += yspeed;
    if (xpos >= width - w/2 || xpos < w/2) {
    xspeed = -xspeed;
    }
    if (ypos >= height - h/2 || ypos < h/2) {
    yspeed = -yspeed;
    }
  }
  
  void display() {
    fill(c);
    ellipse(xpos, ypos, w, h);
  }

}
