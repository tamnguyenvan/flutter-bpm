import 'dart:collection';

import 'package:camera/camera.dart';

class RawInputData {
  final CameraImage image;
  final int timestamp;
  RawInputData({required this.image, required this.timestamp});
}

class RawInputBuffer {
  final int bufferSize;
  ListQueue<RawInputData> buffer = ListQueue<RawInputData>();
  RawInputBuffer({this.bufferSize = 101});

  void update(CameraImage image, int timestamp) {
    if (buffer.length == bufferSize) {
      buffer.removeFirst();
    }
    buffer.addLast(RawInputData(image: image, timestamp: timestamp));
  }

  RawInputData elementAt(int index) {
    return buffer.elementAt(index);
  }

  void clear() {
    buffer.clear();
  }

  bool get ready {
    return buffer.length == bufferSize;
  }

  int get length {
    return buffer.length;
  }
}
