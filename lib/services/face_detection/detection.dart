class Detection {
  final double score;
  final int classID;
  final double xMin;
  final double yMin;
  var xMax = 0.0;
  var yMax = 0.0;
  final double width;
  final double height;
  Detection(
      this.score, this.classID, this.xMin, this.yMin, this.width, this.height) {
    xMax = xMin + width;
    yMax = yMin + height;
  }
}
