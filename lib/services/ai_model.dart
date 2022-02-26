import 'package:camera/camera.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_with_mediapipe/services/face_detection/face_detection_service.dart';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:google_ml_vision/google_ml_vision.dart';

// ignore: must_be_immutable
abstract class AiModel extends Equatable {
  AiModel({this.interpreter});

  final inputShape = <int>[];
  // final TfLiteType inputType;
  final outputShapes = <List<int>>[];
  final outputTypes = <TfLiteType>[];

  Interpreter? interpreter;

  @override
  List<Object> get props => [];

  int get getAddress;

  Future<void> loadModel();
  TensorImage getProcessedImage(TensorImage inputImage);
  List<FaceDetectionDebugData>? predict(List<image_lib.Image> images);
}

// // ignore: must_be_immutable
// abstract class AiModel extends Equatable {
//   AiModel({this.faceDetector});

//   FaceDetector? faceDetector;

//   @override
//   List<Object> get props => [];

//   // int get getAddresss;

//   List<FaceDetectionDebugData>? predict(
//     List<image_lib.Image> images,
//     // int imageRotation,
//     // CameraLensDirection dir,
//   );
// }

// ignore: must_be_immutable
abstract class BpmAiModel extends Equatable {
  BpmAiModel({this.interpreter});

  final outputShapes = <List<int>>[];
  final outputTypes = <TfLiteType>[];

  Interpreter? interpreter;

  @override
  List<Object> get props => [];

  int get getAddress;

  Future<void> loadModel();
  // TensorImage getProcessedImage(TensorImage inputImage);
  List<double> calc(List<List<double>> faces, double fps);
}
