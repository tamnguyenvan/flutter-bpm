List<int> findPeaksByDistance(List<double> pulsePred, {int distance = 15}) {
  var peaks = localMaxima1d(pulsePred);
  var priority = <double>[];
  for (var peak in peaks) {
    priority.add(pulsePred[peak]);
  }
  var keep = selectByPeakDistance(peaks, priority, distance);

  var keepPeaks = <int>[];
  for (var i = 0; i < keep.length; i++) {
    if (keep[i] > 0) {
      keepPeaks.add(peaks[i]);
    }
  }
  return keepPeaks;
}

List<int> localMaxima1d(List<double> x) {
  final len = x.length ~/ 2;
  var midPoints = List.filled(len, 0);
  var leftEdges = List.filled(len, 0);
  var rightEdges = List.filled(len, 0);

  var m = 0;
  var i = 1;
  var iMax = x.length - 1;

  while (i < iMax) {
    // Test if previous sample is smaller
    if (x[i - 1] < x[i]) {
      var iAhead = i + 1; // Index to look ahead of current sample

      // Find next sample that is unequal to x[i]
      while (iAhead < iMax && x[iAhead] == x[i]) {
        iAhead += 1;
      }

      // Maxima is found if next unequal sample is smaller than x[i]
      if (x[iAhead] < x[i]) {
        leftEdges[m] = i;
        rightEdges[m] = iAhead - 1;
        midPoints[m] = (leftEdges[m] + rightEdges[m]) ~/ 2;

        m += 1;
        // Skip samples that can't be maximum
        i = iAhead;
      }
    }

    i += 1;
  }

  var newMidPoints = <int>[];
  for (var point in midPoints) {
    if (point > 0) {
      newMidPoints.add(point);
    }
  }
  return newMidPoints;
}

List<int> selectByPeakDistance(
  List<int> peaks,
  List<double> priority,
  int distance,
) {
  final peaksSize = peaks.length;
  var keep = List<int>.filled(peaksSize, 1);

  var priorityAndIndex = <List<double>>[];
  for (var i = 0; i < priority.length; i++) {
    priorityAndIndex.add([priority[i], i.toDouble()]);
  }

  priorityAndIndex.sort((a, b) => a[0].compareTo(b[0]));
  var priorityToPosition = priorityAndIndex.map((e) => e[1].toInt()).toList();
  for (var i = peaksSize - 1; i >= 0; i--) {
    var j = priorityToPosition[i];

    if (keep[j] == 0) {
      // Skip evaluation for peak already marked as "don't keep"
      continue;
    }

    var k = j - 1;
    while (0 <= k && (peaks[j] - peaks[k] < distance)) {
      keep[k] = 0;
      k -= 1;
    }

    k = j + 1;
    // Flag "later" peaks for removal until minimal distance is exceeded
    while (k < peaksSize && (peaks[k] - peaks[j] < distance)) {
      keep[k] = 0;
      k += 1;
    }
  }
  return keep;
}
