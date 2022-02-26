mixin ModelFile {
  static const String faceDetection =
      'models/face_detection_short_range.tflite';
  static const String faceMesh = 'models/face_landmark.tflite';
  static const String hands = 'models/hand_landmark.tflite';
  static const String pose = 'models/pose_landmark_full.tflite';
  static const String mttscan = 'models/mtts_can_bs201.tflite';
}

mixin FaceDetectionParam {
  static const int bufferSize = 201;
}

mixin BpmCalculatorParam {
  static const int maxSeconds = 120;
}
