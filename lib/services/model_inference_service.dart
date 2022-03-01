import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter_with_mediapipe/utils/bpm_calculator.dart';
import 'package:image/image.dart' as image_lib;

import '../utils/isolate_utils.dart';
import 'ai_model.dart';
import 'face_detection/face_detection_service.dart';
import 'service_locator.dart';

enum Models {
  FaceDetection,
}

// class ModelInferenceService {
//   late AiModel model;
//   late Function handler;
//   // Map<String, dynamic>? inferenceResults;
//   List<FaceDetectionDebugData>? inferenceResults;

//   Future<List<FaceDetectionDebugData>?> inference({
//     required IsolateUtils isolateUtils,
//     // required List<CameraImage> cameraImages,
//     required Map<String, dynamic> params,
//   }) async {
//     final responsePort = ReceivePort();

//     isolateUtils.sendMessage(
//       handler: handler,
//       // params: {
//       //   'cameraImages': cameraImages,
//       //   'detectorAddress': model.getAddress,
//       // },
//       params: params,
//       sendPort: isolateUtils.sendPort,
//       responsePort: responsePort,
//     );

//     inferenceResults = await responsePort.first;
//     print('============== Inference results: $inferenceResults');
//     responsePort.close();
//   }

//   void setModelConfig() {
//     model = locator<FaceDetection>();
//     handler = runFaceDetector;
//   }
// }

class BpmModelInferenceService {
  late BpmAiModel model;
  late Function handler;
  // Map<String, dynamic>? inferenceResults;
  List<double>? bpmResults;

  Future<List<image_lib.Image>?> inference({
    required IsolateUtils isolateUtils,
    // required List<CameraImage> cameraImages,
    required Map<String, dynamic> params,
  }) async {
    final responsePort = ReceivePort();

    isolateUtils.sendMessage(
      handler: handler,
      // params: {
      //   'cameraImages': cameraImages,
      //   'detectorAddress': model.getAddress,
      // },
      params: params,
      sendPort: isolateUtils.sendPort,
      responsePort: responsePort,
    );

    bpmResults = await responsePort.first;
    print('============== Inference results: $bpmResults');
    responsePort.close();
  }

  void setModelConfig() {
    model = locator<BpmCalculator>();
    handler = runBpmCalculator;
  }
}
