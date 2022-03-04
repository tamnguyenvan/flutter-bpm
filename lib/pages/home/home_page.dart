import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:camera/camera.dart';
import 'package:flutter_with_mediapipe/constants/model.dart';
// import 'package:flutter_with_mediapipe/pages/home/widgets/face_box_painter.dart';
import 'package:flutter_with_mediapipe/pages/success/success_view.dart';
import 'package:flutter_with_mediapipe/services/model_inference_service.dart';
import 'package:flutter_with_mediapipe/services/service_locator.dart';
import 'package:flutter_with_mediapipe/utils/bpm_calculator.dart';
import 'package:flutter_with_mediapipe/utils/bpm_utils.dart';
import 'package:flutter_with_mediapipe/utils/face_utils.dart';
import 'package:flutter_with_mediapipe/utils/image_utils.dart';
import 'package:flutter_with_mediapipe/utils/isolate_utils.dart';
import 'package:image/image.dart' as image_lib;
import 'package:path_provider/path_provider.dart';
import 'package:timer_count_down/timer_count_down.dart';
import 'package:wakelock/wakelock.dart';
import 'package:dotted_border/dotted_border.dart';
// import 'package:path_provider_ex/path_provider_ex.dart';
// import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraPage(),
    );
  }
}

class CameraPage extends StatefulWidget {
  const CameraPage({
    Key? key,
  }) : super(key: key);

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  late CameraDescription _cameraDescription;

  // Screen size
  double? _cropRectWidthNorm;
  double? _cropRectHeightNorm;

  late bool _isRun;
  bool _predicting = false;
  // bool _draw = false;

  // Face detection
  var numEliminateFirstFrame = 20;
  late IsolateUtils _isolateUtils;
  // late ModelInferenceService _modelInferenceService;
  late BpmModelInferenceService _bpmModelInferenceService;
  late InputBuffer _inputBuffer;
  late MovingAverage _avg;

  // For debug
  late image_lib.JpegEncoder _encoder;
  image_lib.Image? _avatar;

  // BPM
  double _bpm = 0.0;
  double _hrv = 0.0;
  double _si = 0.0;

  @override
  void initState() {
    // _modelInferenceService = locator<ModelInferenceService>();
    _bpmModelInferenceService = locator<BpmModelInferenceService>();
    _inputBuffer = InputBuffer(bufferSize: FaceDetectionParam.bufferSize);
    _avg = MovingAverage(alpha: 0.8);
    _encoder = image_lib.JpegEncoder();
    _initStateAsync();
    super.initState();
  }

  void _initStateAsync() async {
    _isolateUtils = IsolateUtils();
    await _isolateUtils.initIsolate();
    // locator<ModelInferenceService>().setModelConfig();
    locator<BpmModelInferenceService>().setModelConfig();
    await _initCamera();
    _predicting = false;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _cameraController = null;
    _isolateUtils.dispose();
    // _modelInferenceService.inferenceResults = null;
    _bpmModelInferenceService.bpmResults = null;
    Wakelock.disable();
    super.dispose();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    _cameraDescription = _cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    _isRun = false;
    _onNewCameraSelected(_cameraDescription);
  }

  void _onNewCameraSelected(CameraDescription cameraDescription) async {
    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.max,
      enableAudio: false,
    );

    _cameraController!.addListener(() {
      if (mounted) setState(() {});
      if (_cameraController!.value.hasError) {
        _showInSnackBar(
            'Camera error ${_cameraController!.value.errorDescription}');
      }
    });

    try {
      await _cameraController!.initialize().then((value) {
        if (!mounted) return;
      });
    } on CameraException catch (e) {
      _showInSnackBar('Error: ${e.code}\n${e.description}');
    }

    await Wakelock.enable();
    await _cameraController!.startImageStream(
      (CameraImage cameraImage) async => _inference(cameraImage: cameraImage),
    );

    if (mounted) {
      setState(() {});
    }
  }

  void _showInSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Container(
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    var scale = screenSize.aspectRatio * _cameraController!.value.aspectRatio;

    // to prevent scaling down, invert the value
    if (scale < 1) scale = 1 / scale;

    // return Transform.scale(
    //   scale: scale,
    //   child: Center(
    //     child: CameraPreview(_cameraController!),
    //   ),
    // );
    //     InfoBoard(
    //         bpm: _bpm,
    //         hrv: _hrv,
    //         si: _si,
    //         maxSeconds: maxSeconds,
    //         context: context),
    // final facePainter = FaceBoxCustomPainter(
    //   bbox: Rect.fromCenter(
    //     center: const Offset(0.0, 0.0),
    //     width: BpmCalculatorParam.inputSize * 6,
    //     height: BpmCalculatorParam.inputSize * 6,
    //   ),
    // );
    final rectDisplayWidth = screenSize.width / 2;
    // final rectDisplayHeight = screenSize.height / 3;
    final rectDisplayHeight = rectDisplayWidth;
    // final rectDisplayHeight = rectDisplayWidth;
    _cropRectWidthNorm = rectDisplayWidth / (screenSize.width * scale);
    _cropRectHeightNorm = _cropRectWidthNorm;
    return Scaffold(
      body: Stack(
        // fit: StackFit.expand,
        children: [
          Transform.scale(
            scale: scale,
            child: Center(
              child: CameraPreview(_cameraController!),
            ),
          ),
          // CameraPreview(_cameraController!),
          _buildInfoBoard(),
          _buildFaceRect(rectDisplayHeight, rectDisplayWidth),
          // InfoBoard(
          //   bpm: _bpm,
          //   hrv: _hrv,
          //   si: _si,
          //   maxSeconds: BpmCalculatorParam.maxSeconds,
          //   context: context,
          // ),
        ],
      ),
    );
  }

  Future<void> _inference({required CameraImage cameraImage}) async {
    if (!mounted) return;

    if (!_isRun) {
      return;
    }

    // if (_modelInferenceService.model.interpreter != null) {
    if (_bpmModelInferenceService.model.interpreter != null) {
      if (_predicting) {
        return;
      } else {
        // final now = DateTime.now().millisecondsSinceEpoch;
        // _rawInputBuffer.update(
        //   cameraImage,
        //   now,
        // );
        // print('============== Frame #${_rawInputBuffer.length} now $now');

        // // At the beginning, some frames seems too bright. That might affect
        // // the accuracy so we want to eliminate those frames.
        // if (_rawInputBuffer.buffer.isNotEmpty && numEliminateFirstFrame > 0) {
        //   print('============ Eliminating a frame');
        //   _rawInputBuffer.buffer.removeFirst();
        //   numEliminateFirstFrame--;
        // }
        if (numEliminateFirstFrame > 0) {
          numEliminateFirstFrame--;
          // print('============ Eliminating a frame');
          return;
        }
      }

      // if (_rawInputBuffer.ready) {
      // print('========== buffer len.: ${_inputBuffer.length}');
      if (_inputBuffer.ready) {
        setState(() {
          _predicting = true;
        });

        // // For debug only
        // final decodedImages =
        //     _inputBuffer.buffer.map((e) => e.decodedImage).toList();

        // var buffer = StringBuffer();
        // for (var img in decodedImages) {
        //   for (var pix in img) {
        //     buffer.write('${pix.toInt()} ');
        //   }
        //   buffer.write('\n');
        // }
        // final content = buffer.toString();
        // // final storageInfo = await PathProviderEx.getStorageInfo();
        // // final rootDir = storageInfo[0].rootDir;
        // final extDirs = await getExternalStorageDirectories();
        // final rootDir = extDirs![0].path;
        // // final appDocumentsDir = await getApplicationDocumentsDirectory();
        // final videoPath = '$rootDir/vid_${_inputBuffer.length}.txt';
        // final file = File(videoPath);

        // if (await Permission.storage.request().isGranted) {
        //   await file.writeAsString(content);
        //   print('============== Wrote file ok: $videoPath');
        // }

        // print('============ Start calculating bpm');
        // print('============ FPS: ${_inputBuffer.fps}');
        final bpmParams = {
          'inputs': _inputBuffer.buffer.map((e) => e.decodedImage).toList(),
          'fps': _inputBuffer.fps,
          'bpmCalculatorAddress': _bpmModelInferenceService.model.getAddress,
        };
        await _bpmModelInferenceService.inference(
          isolateUtils: _isolateUtils,
          params: bpmParams,
        );
        final bpmResults = _bpmModelInferenceService.bpmResults;
        // print('============ bpm: $bpmResults');
        if (bpmResults != null) {
          _avg.update(bpmResults);
          setState(() {
            _bpm = _avg.bpm;
            _hrv = _avg.hrv;
            _si = _avg.si;
          });
        }
        // print('============ Stop calculating bpm');

        setState(() {
          _predicting = false;
          _inputBuffer.clear();
        });
      } else {
        if (_cropRectHeightNorm == null || _cropRectWidthNorm == null) {
          return;
        }

        var cropRectSize = Platform.isAndroid
            ? _cropRectWidthNorm! * cameraImage.height
            : _cropRectWidthNorm! * cameraImage.width;
        var center = const Offset(0.0, 0.0);
        center = Offset(cameraImage.width / 2, cameraImage.height / 2);
        final stopwatch = Stopwatch();
        stopwatch.start();
        final results = ImageUtils.cropImage(
          cameraImage,
          Rect.fromCenter(
            center: center,
            width: cropRectSize,
            height: cropRectSize,
          ),
        );
        stopwatch.stop();
        // print(
        //     '================= Crop time: ${stopwatch.elapsedMilliseconds}ms');
        final now = DateTime.now().millisecondsSinceEpoch;
        _inputBuffer
            .update(InputData(results[0] as image_lib.Image, now.toDouble()));

        // for debug only
        // final cropRectWidth = _cropRectWidthNorm! * cameraImage.width;
        // final cropRectHeight = cropRectWidth;
        // setState(() {
        //   // final rgb = image_lib.Image.fromBytes(
        //   //   cropRectSize.toInt() % 2 == 1
        //   //       ? cropRectSize.toInt() - 1
        //   //       : cropRectSize.toInt(),
        //   //   cropRectSize.toInt() % 2 == 1
        //   //       ? cropRectSize.toInt() - 1
        //   //       : cropRectSize.toInt(),
        //   //   _inputBuffer.buffer.last.image,
        //   // );
        //   // print(
        //   //     '========== rgb len: ${_inputBuffer.buffer.last.image.length} ${rgb.width} ${rgb.height}');
        //   // _avatar = results[0] as image_lib.Image;
        //   // _avatar = image_lib.copyResize(
        //   //   rgb,
        //   //   width: 36,
        //   //   height: 36,
        //   // );
        //   // _avatar = rgb;
        // });
      }
    }

    // print('============ Started detecting faces');
    // // final cameraImages =
    // //     _rawInputBuffer.buffer.map((e) => e.image).toList()[0];

    // final params = {
    //   'cameraImages': [cameraImage],
    //   'detectorAddress': _modelInferenceService.model.getAddress,
    //   // 'imageRotation': _cameraDescription.sensorOrientation,
    //   // 'dir': _cameraDescription.lensDirection,
    // };

    // await _modelInferenceService.inference(
    //   isolateUtils: _isolateUtils,
    //   // cameraImages: cameraImages,
    //   params: params,
    // );
    // final faces = _modelInferenceService.inferenceResults;

    // print('========== Number of faces: ${faces != null ? faces.length : 0}');
    // print('============ Stop detecting faces');
    // if (faces != null) {
    //   // Debug with an avatar
    //   setState(() {
    //     _avatar = image_lib.copyResize(faces[0].image, width: 36, height: 36);
    //   });

    // final center = Offset(cameraImage.width / 2, cameraImage.height / 2);
    // final cropRect = Rect.fromCenter(
    //   center: center,
    //   width: BpmCalculatorParam.inputSize * 6,
    //   height: BpmCalculatorParam.inputSize * 6,
    // );
    // final croppedImage = ImageUtils.cropImage(cameraImage, cropRect);
    // _rawInputBuffer.update(croppedImage);
    // if (_rawInputBuffer.ready) {}

    //   print('============ Start calculating bpm');
    //   // Calculate real fps
    //   final fps = 1000 *
    //       _rawInputBuffer.length /
    //       (_rawInputBuffer.buffer.last.timestamp -
    //           _rawInputBuffer.buffer.first.timestamp);
    //   print('============ FPS: $fps');
    //   final bpmParams = {
    //     'inputs': faces.map((e) => e.decodedImage).toList(),
    //     'fps': fps,
    //     'bpmCalculatorAddress': _bpmModelInferenceService.model.getAddress,
    //   };
    //   await _bpmModelInferenceService.inference(
    //     isolateUtils: _isolateUtils,
    //     params: bpmParams,
    //   );
    //   final bpmResults = _bpmModelInferenceService.bpmResults;
    //   print('============ bpm: $bpmResults');
    //   if (bpmResults != null) {
    //     _avg.update(bpmResults);
    //     setState(() {
    //       _bpm = _avg.bpm;
    //       _hrv = _avg.hrv;
    //       _si = _avg.si;
    //     });
    //   }
    //   print('============ Stop calculating bpm');
    // }
    // setState(() {
    //   _predicting = false;
    //   _rawInputBuffer.clear();
    // });
    // }
    // }
  }

  // void calcBpm(List<FaceDetectionDebugData> faceResults) async {}

  Widget _buildInfoBoard() {
    if (_isRun) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(
            height: 20,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // _buildAvatar(),
              IconButton(
                onPressed: () {
                  // TODO: Back to home screen
                  print('================== Exit!');
                },
                icon: const Icon(
                  Icons.exit_to_app_outlined,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildIndexCard(name: 'bpm', index: '${_bpm.toInt()}'),
              _buildIndexCard(name: 'hrv', index: '${_hrv.toInt()}'),
              _buildIndexCard(name: 'stress index', index: '${_si.toInt()}')
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            // child: Center(
            //   child: Text(
            //     seconds.toString(),
            //     style: const TextStyle(
            //       fontSize: 18,
            //     ),
            //   ),
            // ),
            child: Center(
              child: Countdown(
                seconds: BpmCalculatorParam.maxSeconds,
                interval: const Duration(seconds: 1),
                build: (_, double time) {
                  return Text(
                    time.toInt().toString(),
                    style: const TextStyle(fontSize: 18),
                  );
                },
                onFinished: () async {
                  await _cameraController?.stopImageStream();
                  _isolateUtils.dispose();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SuccessView(),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(
            height: 5,
          ),
        ],
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Center(
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: () {
                setState(() {
                  _isRun = true;
                });
              },
              elevation: 12,
              foregroundColor: Colors.black,
              child: const Icon(Icons.qr_code_scanner_outlined),
            ),
          ),
          const SizedBox(
            height: 50,
          )
        ],
      );
    }
  }

  Widget _buildIndexCard({required String index, required String name}) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: const BorderRadius.all(
          Radius.circular(10.0),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              index,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 40,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              name,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaceRect(double rectDisplayHeight, double rectDisplayWidth) {
    return Stack(
      children: [
        Center(
          child: DottedBorder(
            color: Colors.white,
            dashPattern: [6, 6],
            borderType: BorderType.RRect,
            strokeWidth: 3,
            radius: const Radius.circular(12),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(12),
              ),
              child: Container(
                height: rectDisplayHeight,
                width: rectDisplayWidth,
              ),
            ),
          ),
        ),
        Center(
          child: Container(
            height: 5,
            width: 5,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }

  // Widget _buildAvatar() {
  //   if (_avatar == null) {
  //     return Container();
  //   }
  //   // try {
  //   final resized = image_lib.copyResize(_avatar!, width: 72, height: 72);
  //   final encoded = _encoder.encodeImage(resized);
  //   // } on Exception catch (e) {
  //   //   print('================= $e');
  //   // }
  //   return Image.memory(Uint8List.fromList(encoded));
  //   // return Container();
  // }
}
