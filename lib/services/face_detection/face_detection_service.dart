import 'dart:io';
import 'dart:ui';

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

    if (Platform.isAndroid) {
      image = image_lib.copyRotate(image, -90);
      image = image_lib.flipHorizontal(image);
    }
    final tensorImage = TensorImage(TfLiteType.float32);
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
  List<List<double>>? predict(List<image_lib.Image> images) {
    var bboxes = <Rect?>[];
    var xs = <double>[];
    var ys = <double>[];
    var ws = <double>[];
    var hs = <double>[];
    var cnt = 0;
    for (var image in images) {
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

    var retFaces = <List<double>>[];
    var xmean = 0.0, ymean = 0.0, wmean = 0.0, hmean = 0.0;
    xmean = Vector.fromList(xs).mean();
    ymean = Vector.fromList(ys).mean();
    wmean = Vector.fromList(ws).mean();
    hmean = Vector.fromList(hs).mean();
    for (var i = 0; i < images.length; i++) {
      image_lib.Image face;
      if (bboxes[i] == null) {
        print('============= Bbox NULL!!!');
        face = image_lib.copyCrop(
          images[i],
          xmean.toInt(),
          ymean.toInt(),
          wmean.toInt(),
          hmean.toInt(),
        );
      } else {
        print('============= Bbox OK!!!');
        face = image_lib.copyCrop(
          images[i],
          bboxes[i]!.left.toInt(),
          bboxes[i]!.top.toInt(),
          bboxes[i]!.width.toInt(),
          bboxes[i]!.height.toInt(),
        );
      }
      face = image_lib.copyResize(face, width: outputSize, height: outputSize);
      retFaces.add(imageToFloat32List(face));
    }
    print('============ Len. of returned face images: ${retFaces.length}');
    return retFaces;
  }
}

List<List<double>>? runFaceDetector(Map<String, dynamic> params) {
  final faceDetection = FaceDetection(
      interpreter: Interpreter.fromAddress(params['detectorAddress']));

  var images = <image_lib.Image>[];
  for (var cameraImage in params['cameraImages']) {
    final image = ImageUtils.convertCameraImage(cameraImage)!;
    images.add(image);
  }
  final result = faceDetection.predict(images);

  return result;
}
