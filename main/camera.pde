class Camera {
  int x;
  int y;
  int cols;
  int rows;
  int cellSize;

  int worldCols;
  int worldRows;

  Camera(int visibleCols, int visibleRows, int cellSizePixels, int maxWorldCols, int maxWorldRows) {
    cols = visibleCols;
    rows = visibleRows;
    cellSize = cellSizePixels;
    worldCols = maxWorldCols;
    worldRows = maxWorldRows;
    x = 0;
    y = 0;
  }

  void move(int dx, int dy) {
    x = constrain(x + dx, 0, max(0, worldCols - cols));
    y = constrain(y + dy, 0, max(0, worldRows - rows));
  }

  boolean isVisible(PVector worldPosition) {
    return worldPosition.x >= x
      && worldPosition.x < x + cols
      && worldPosition.y >= y
      && worldPosition.y < y + rows;
  }

  PVector worldToScreen(PVector worldPosition) {
    return new PVector((worldPosition.x - x) * cellSize, (worldPosition.y - y) * cellSize);
  }

  void drawGrid() {
    stroke(120, 110, 95, 80);

    for (int gridX = 0; gridX <= cols; gridX++) {
      line(gridX * cellSize, 0, gridX * cellSize, rows * cellSize);
    }

    for (int gridY = 0; gridY <= rows; gridY++) {
      line(0, gridY * cellSize, cols * cellSize, gridY * cellSize);
    }
  }
}
