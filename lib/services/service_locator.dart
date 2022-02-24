import 'package:flutter_with_mediapipe/utils/bpm_calculator.dart';
import 'package:get_it/get_it.dart';

import 'face_detection/face_detection_service.dart';
import 'model_inference_service.dart';

final locator = GetIt.instance;

void setupLocator() {
  locator.registerSingleton<FaceDetection>(FaceDetection());
  locator.registerSingleton<BpmCalculator>(BpmCalculator());

  locator.registerLazySingleton<ModelInferenceService>(
      () => ModelInferenceService());
  locator.registerLazySingleton<BpmModelInferenceService>(
      () => BpmModelInferenceService());
}
