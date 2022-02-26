import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter_with_mediapipe/utils/general.dart';
import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:ml_linalg/vector.dart';

import '../../constants/model.dart';
import '../../utils/image_utils.dart';
import '../ai_model.dart';
import 'anchors.dart';
import 'generate_anchors.dart';
import 'non_maximum_suppression.dart';
import 'options.dart';
import 'process.dart';

// ignore: must_be_immutable
class FaceDetection extends AiModel {
  FaceDetection({this.interpreter}) {
    loadModel();
  }

  final int inputSize = 128;
  final double threshold = 0.7;
  final outputSize = 36;

  @override
  Interpreter? interpreter;

  @override
  List<Object> get props => [];

  @override
  int get getAddress => interpreter!.address;

  late ImageProcessor _imageProcessor;
  late List<Anchor> _anchors;
  late TfLiteType _inputType;

  @override
  Future<void> loadModel() async {
    final anchorOption = AnchorOption(
        inputSizeHeight: 128,
        inputSizeWidth: 128,
        minScale: 0.1484375,
        maxScale: 0.75,
        anchorOffsetX: 0.5,
        anchorOffsetY: 0.5,
        numLayers: 4,
        featureMapHeight: [],
        featureMapWidth: [],
        strides: [8, 16, 16, 16],
        aspectRatios: [1.0],
        reduceBoxesInLowestLayer: false,
        interpolatedScaleAspectRatio: 1.0,
        fixedAnchorSize: true);
    try {
      final interpreterOptions = InterpreterOptions();

      _anchors = generateAnchors(anchorOption);
      interpreter = interpreter ??
          await Interpreter.fromAsset(
            ModelFile.faceDetection,
            options: interpreterOptions,
          );
      _inputType = interpreter!.getInputTensor(0).type;

      final outputTensors = interpreter!.getOutputTensors();

      outputTensors.forEach((tensor) {
        outputShapes.add(tensor.shape);
        outputTypes.add(tensor.type);
      });
    } catch (e) {
      print('Error while creating interpreter: $e');
    }
  }

  @override
  TensorImage getProcessedImage(TensorImage inputImage) {
    _imageProcessor = ImageProcessorBuilder()
        .add(ResizeOp(inputSize, inputSize, ResizeMethod.BILINEAR))
        .add(NormalizeOp(127.5, 127.5))
        .build();

    inputImage = _imageProcessor.process(inputImage);
    return inputImage;
  }

  Rect? _predict(image_lib.Image image) {
    if (interpreter == null) {
      print('Interpreter not initialized');
      return null;
    }

    final options = OptionsFace(
        numClasses: 1,
        numBoxes: 896,
        numCoords: 16,
        keypointCoordOffset: 4,
        ignoreClasses: [],
        scoreClippingThresh: 100.0,
        minScoreThresh: 0.75,
        numKeypoints: 6,
        numValuesPerKeypoint: 2,
        reverseOutputOrder: true,
        boxCoordOffset: 0,
        xScale: 128,
        yScale: 128,
        hScale: 128,
        wScale: 128);

    // if (Platform.isAndroid) {
    //   image = image_lib.copyRotate(image, -90);
    //   image = image_lib.flipHorizontal(image);
    // }
    final tensorImage = TensorImage(_inputType);
    tensorImage.loadImage(image);
    final inputImage = getProcessedImage(tensorImage);

    TensorBuffer outputFaces = TensorBufferFloat(outputShapes[0]);
    TensorBuffer outputScores = TensorBufferFloat(outputShapes[1]);

    final inputs = <Object>[inputImage.buffer];

    final outputs = <int, Object>{
      0: outputFaces.buffer,
      1: outputScores.buffer,
    };

    interpreter!.runForMultipleInputs(inputs, outputs);

    final rawBoxes = outputFaces.getDoubleList();
    final rawScores = outputScores.getDoubleList();
    var detections = process(
        options: options,
        rawScores: rawScores,
        rawBoxes: rawBoxes,
        anchors: _anchors);

    detections = nonMaximumSuppression(detections, threshold);
    if (detections.isEmpty) {
      return null;
    }

    // final rectFaces = <Map<String, dynamic>>[];

    Rect? bbox;
    for (var detection in detections) {
      final score = detection.score;
      if (score > threshold) {
        bbox = Rect.fromLTRB(
          inputImage.width * detection.xMin,
          inputImage.height * detection.yMin,
          inputImage.width * detection.width,
          inputImage.height * detection.height,
        );

        bbox = _imageProcessor.inverseTransformRect(
            bbox, image.height, image.width);
        break;
      }
    }
    // rectFaces.sort((a, b) => b['score'].compareTo(a['score']));

    // rectFaces.add({'bbox': bbox, 'score': score});
    return bbox;
  }

  @override
  List<FaceDetectionDebugData>? predict(List<image_lib.Image> images) {
    // Rotate if needs
    var newImages = [];
    for (var image in images) {
      if (Platform.isAndroid) {
        image = image_lib.copyRotate(image, -90);
        image = image_lib.flipHorizontal(image);
      }
      newImages.add(image);
    }

    var bboxes = <Rect?>[];
    var xs = <double>[];
    var ys = <double>[];
    var ws = <double>[];
    var hs = <double>[];
    var cnt = 0;
    for (var image in newImages) {
      print('============= Predicting frame #$cnt');
      cnt += 1;
      final bbox = _predict(image);
      if (bbox != null) {
        xs.add(bbox.left);
        ys.add(bbox.top);
        ws.add(bbox.width);
        hs.add(bbox.height);
      }
      bboxes.add(bbox);
      print('=============== Bbox: $bbox');
    }

    var results = <FaceDetectionDebugData>[];
    var xmean = 0.0, ymean = 0.0, wmean = 0.0, hmean = 0.0;
    if (xs.isNotEmpty) {
      xmean = Vector.fromList(xs).mean();
      ymean = Vector.fromList(ys).mean();
      wmean = Vector.fromList(ws).mean();
      hmean = Vector.fromList(hs).mean();
    }
    for (var i = 0; i < newImages.length; i++) {
      image_lib.Image face;
      const pad = 0;
      if (bboxes[i] == null && xs.isNotEmpty) {
        print('============= Bbox NULL and we have a mean image!!!');
        // Prefer square cropping
        final croppedSize = math.min(wmean, hmean);
        face = image_lib.copyCrop(
          newImages[i],
          xmean.toInt() - pad ~/ 2,
          ymean.toInt() - pad ~/ 2,
          wmean.toInt() + pad,
          hmean.toInt() + pad,
        );
      } else if (bboxes[i] == null && xs.isEmpty) {
        print('============== Bbox NULL, using whole image');
        face = newImages[i];
      } else {
        print('============= Bbox OK!!!');
        // Prefer square cropping
        final croppedSize = math.min(bboxes[i]!.width, bboxes[i]!.height);
        face = image_lib.copyCrop(
          newImages[i],
          bboxes[i]!.left.toInt() - pad ~/ 2,
          bboxes[i]!.top.toInt() - pad ~/ 2,
          bboxes[i]!.width.toInt() + pad,
          bboxes[i]!.height.toInt() + pad,
        );
      }
      face = image_lib.copyResize(face, width: outputSize, height: outputSize);
      final stopwatch = Stopwatch();
      stopwatch.start();
      results.add(
        FaceDetectionDebugData(
            decodedImage: imageToFloat32List(face), image: face),
      );
      stopwatch.stop();
      print('============ Converted time: ${stopwatch.elapsedMilliseconds}ms');
    }
    print('============ Len. of returned face images: ${results.length}');
    return results;
  }
}

List<FaceDetectionDebugData>? runFaceDetector(Map<String, dynamic> params) {
  final faceDetection = FaceDetection(
      interpreter: Interpreter.fromAddress(params['detectorAddress']));

  var stopwatch = Stopwatch();
  stopwatch.start();
  print('=========== Started converting CameraImage to image');
  var images = <image_lib.Image>[];
  for (var cameraImage in params['cameraImages']) {
    final image = ImageUtils.convertCameraImage(cameraImage)!;
    images.add(image);
  }
  final numFrames = params['cameraImages'].length;
  print(
      '========== Stopped converting CameraImage to image: ${stopwatch.elapsedMilliseconds / numFrames}ms');
  final results = faceDetection.predict(images);

  return results;
}

class FaceDetectionDebugData {
  final List<double> decodedImage;
  final image_lib.Image image;

  FaceDetectionDebugData({required this.decodedImage, required this.image});
}


// // ignore: must_be_immutable
// class FaceDetection {
//   final int bufferSize;
//   final outputSize = 36;
//   final faceDetector = GoogleVision.instance.faceDetector();

//   FaceDetection({this.bufferSize = 101});

//   // @override
//   // List<Object> get props => [];

//   // @override
//   // int get getAddress => faceDetector!.address;

//   // @override
//   Future<List<FaceDetectionDebugData>?> predict(
//     List<CameraImage> cameraImages,
//     int imageRotation,
//     CameraLensDirection dir,
//   ) async {
//     var xs = <double>[];
//     var ys = <double>[];
//     var ws = <double>[];
//     var hs = <double>[];
//     var dets = List<Face?>.filled(cameraImages.length, null);

//     for (var i = 0; i < cameraImages.length; i++) {
//       var visionImage = GoogleVisionImage.fromBytes(
//         _concatenatePlanes(cameraImages[i].planes),
//         _buildMetaData(
//           cameraImages[i],
//           _rotationIntToImageRotation(imageRotation),
//         ),
//       );
//       final faces = await faceDetector.processImage(visionImage);
//       if (faces.isNotEmpty) {
//         final face = faces[0];
//         final bbox = face.boundingBox;
//         final x = bbox.left;
//         final y = bbox.top;
//         final w = bbox.width;
//         final h = bbox.height;
//         xs.add(x);
//         ys.add(y);
//         ws.add(w);
//         hs.add(h);
//       }
//     }

//     // Crop and resize faces. The missing frames will be filled out by mean
//     var x = Vector.fromList(xs).mean().toInt();
//     var y = Vector.fromList(ys).mean().toInt();
//     var w = Vector.fromList(ws).mean().toInt();
//     var h = Vector.fromList(hs).mean().toInt();
//     var missingCount = 0;
//     var results = <FaceDetectionDebugData>[];
//     for (var i = 0; i < dets.length; i++) {
//       final face = dets[i];
//       final image = convertCameraImage(cameraImages[i], dir);
//       var faceImage = image_lib.Image(outputSize, outputSize);

//       if (image != null) {
//         if (face != null) {
//           final bbox = face.boundingBox;
//           faceImage = image_lib.copyCrop(
//             image,
//             bbox.left.toInt(),
//             bbox.top.toInt(),
//             bbox.width.toInt(),
//             bbox.height.toInt(),
//           );
//         } else {
//           faceImage = image_lib.copyCrop(image, x, y, w, h);
//         }
//       } else {
//         print('Could not convert camera image to image');
//       }

//       results.add(FaceDetectionDebugData(
//         decodedImage: imageToFloat32List(faceImage).toList(),
//         image: faceImage,
//       ));
//     }
//     print('========= Missed: $missingCount');

//     return results;
//   }

//   Uint8List _concatenatePlanes(List<Plane> planes) {
//     final allBytes = WriteBuffer();
//     for (var plane in planes) {
//       allBytes.putUint8List(plane.bytes);
//     }
//     return allBytes.done().buffer.asUint8List();
//   }

//   GoogleVisionImageMetadata _buildMetaData(
//     CameraImage image,
//     ImageRotation rotation,
//   ) {
//     return GoogleVisionImageMetadata(
//       rawFormat: image.format.raw,
//       size: Size(image.width.toDouble(), image.height.toDouble()),
//       rotation: rotation,
//       planeData: image.planes.map(
//         (Plane plane) {
//           return GoogleVisionImagePlaneMetadata(
//             bytesPerRow: plane.bytesPerRow,
//             height: plane.height,
//             width: plane.width,
//           );
//         },
//       ).toList(),
//     );
//   }

//   ImageRotation _rotationIntToImageRotation(int rotation) {
//     switch (rotation) {
//       case 0:
//         return ImageRotation.rotation0;
//       case 90:
//         return ImageRotation.rotation90;
//       case 180:
//         return ImageRotation.rotation180;
//       default:
//         assert(rotation == 270);
//         return ImageRotation.rotation270;
//     }
//   }
// }

// // List<FaceDetectionDebugData>? runFaceDetector(
// //     Map<String, dynamic> params) async {
// //   // final faceDetection = FaceDetection(
// //   //     interpreter: Interpreter.fromAddress(params['detectorAddress']));
// //   // final result = faceDetection.predict(
// //   //   params['cameraImages'],
// //   //   // params['imageRotation'],
// //   //   // params['dir'],
// //   // );
// //   return result;
// // }

// void runFaceDetector(Map<String, dynamic> context) {
//   final messager = HandledIsolate.initialize(context);

//   final faceDetection = FaceDetection();
//   messager.listen((message) async {
//     final data = message as Map<String, dynamic>;
//     final cameraImages = data['cameraImages'];
//     final imageRotation = data['imageRotation'];
//     final dir = data['dir'];
//     final rs = await faceDetection.predict(cameraImages, imageRotation, dir);
//     messager.send(rs);
//   });
// }
