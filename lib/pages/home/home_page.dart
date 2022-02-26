// import 'dart:ui';

// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';

// import '../../constants/data.dart';
// import 'widgets/model_card.dart';

// class HomePage extends StatefulWidget {
//   const HomePage({Key? key}) : super(key: key);

//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   late PageController _pageController;
//   double _currentPageValue = 0.0;

//   @override
//   void initState() {
//     super.initState();
//     _pageController = PageController(viewportFraction: 0.8)
//       ..addListener(() {
//         setState(() {
//           _currentPageValue = _pageController.page!;
//         });
//       });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: AppBar(
//         centerTitle: true,
//         title: Text(
//           'Select Your Model',
//           style: TextStyle(
//               color: Colors.white,
//               fontSize: ScreenUtil().setSp(28),
//               fontWeight: FontWeight.bold),
//         ),
//       ),
//       body: Stack(
//         children: [
//           _BackGroundImage(currentPageValue: _currentPageValue),
//           _ModelPreview(
//             pageController: _pageController,
//             currentPageValue: _currentPageValue,
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _BackGroundImage extends StatelessWidget {
//   const _BackGroundImage({
//     Key? key,
//     required this.currentPageValue,
//   }) : super(key: key);

//   final double currentPageValue;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         image: DecorationImage(
//           image: AssetImage(
//             models[currentPageValue.round()]['image']!,
//           ),
//           fit: BoxFit.cover,
//         ),
//       ),
//       child: BackdropFilter(
//         filter: ImageFilter.blur(
//           sigmaX: 5.0,
//           sigmaY: 5.0,
//         ),
//         child: Container(
//           color: Colors.black.withOpacity(0.15),
//         ),
//       ),
//     );
//   }
// }

// class _ModelPreview extends StatelessWidget {
//   const _ModelPreview({
//     Key? key,
//     required this.pageController,
//     required this.currentPageValue,
//   }) : super(key: key);

//   final PageController pageController;
//   final double currentPageValue;

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: Container(
//         height: ScreenUtil().setHeight(450.0),
//         child: PageView.builder(
//           controller: pageController,
//           physics: const BouncingScrollPhysics(),
//           itemCount: models.length,
//           itemBuilder: (context, index) {
//             var scale = (currentPageValue - index).abs();
//             return ModelCard(
//               index: index,
//               scale: scale,
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_with_mediapipe/constants/model.dart';
import 'package:flutter_with_mediapipe/pages/success/success_view.dart';
import 'package:flutter_with_mediapipe/services/face_detection/face_detection_service.dart';
import 'package:flutter_with_mediapipe/services/model_inference_service.dart';
import 'package:flutter_with_mediapipe/services/service_locator.dart';
import 'package:flutter_with_mediapipe/utils/bpm_calculator.dart';
import 'package:flutter_with_mediapipe/utils/face_utils.dart';
import 'package:flutter_with_mediapipe/utils/isolate_utils.dart';
import 'package:image/image.dart' as image_lib;
import 'package:timer_count_down/timer_count_down.dart';

import 'widgets/index_box.dart';

// import 'success_view.dart';
// import 'package:timer_count_down/timer_count_down.dart';
// import '../utils/bpm_calculator.dart';
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

  late bool _isRun;
  bool _predicting = false;
  bool _draw = false;

  // Face detection
  var numEliminateFirstFrame = 20;
  late IsolateUtils _isolateUtils;
  late ModelInferenceService _modelInferenceService;
  late BpmModelInferenceService _bpmModelInferenceService;
  late RawInputBuffer _rawInputBuffer;
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
    _modelInferenceService = locator<ModelInferenceService>();
    _bpmModelInferenceService = locator<BpmModelInferenceService>();
    _rawInputBuffer = RawInputBuffer(bufferSize: FaceDetectionParam.bufferSize);
    _avg = MovingAverage();
    _encoder = image_lib.JpegEncoder();
    _initStateAsync();
    super.initState();
  }

  void _initStateAsync() async {
    _isolateUtils = IsolateUtils();
    await _isolateUtils.initIsolate();
    locator<ModelInferenceService>().setModelConfig();
    locator<BpmModelInferenceService>().setModelConfig();
    await _initCamera();
    _predicting = false;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _cameraController = null;
    _isolateUtils.dispose();
    _modelInferenceService.inferenceResults = null;
    _bpmModelInferenceService.bpmResults = null;
    super.dispose();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    _cameraDescription = _cameras[1];
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

    await _cameraController!.startImageStream(
      (CameraImage cameraImage) async =>
          await _inference(cameraImage: cameraImage),
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

    if (_modelInferenceService.model.interpreter != null) {
      if (_predicting) {
        return;
      } else {
        final now = DateTime.now().millisecondsSinceEpoch;
        print('============== Frame #${_rawInputBuffer.length} now $now');
        _rawInputBuffer.update(
          cameraImage,
          now,
        );

        // At the beginning, some frames seems too bright. That might affect
        // the accuracy so we want to eliminate those frames.
        if (_rawInputBuffer.buffer.isNotEmpty && numEliminateFirstFrame > 0) {
          print('============ Eliminating a frame');
          _rawInputBuffer.buffer.removeFirst();
          numEliminateFirstFrame--;
        }
      }

      if (_rawInputBuffer.ready) {
        setState(() {
          _predicting = true;
        });

        print('============ Start detecting faces');
        final cameraImages =
            _rawInputBuffer.buffer.map((e) => e.image).toList();
        final params = {
          'cameraImages': cameraImages,
          'detectorAddress': _modelInferenceService.model.getAddress,
          // 'imageRotation': _cameraDescription.sensorOrientation,
          // 'dir': _cameraDescription.lensDirection,
        };
        // isolates.spawn(
        //   runFaceDetector,
        //   name: 'face_detector',
        //   onReceive: calcBpm,
        //   onInitialized: () => isolates.send(params, to: 'face_detector'),
        // );
        await _modelInferenceService.inference(
          isolateUtils: _isolateUtils,
          // cameraImages: cameraImages,
          params: params,
        );
        final faces = _modelInferenceService.inferenceResults;
        if (faces != null) {
          // Debug with an avatar
          setState(() {
            _avatar =
                image_lib.copyResize(faces[0].image, width: 36, height: 36);
          });

          print('========== Number of faces: ${faces.length}');
          print('============ Stop detecting faces');

          print('============ Start calculating bpm');
          // Calculate real fps
          final fps = 1000 *
              _rawInputBuffer.length /
              (_rawInputBuffer.buffer.last.timestamp -
                  _rawInputBuffer.buffer.first.timestamp);
          print('============ FPS: $fps');
          final bpmParams = {
            'inputs': faces.map((e) => e.decodedImage).toList(),
            'fps': fps,
            'bpmCalculatorAddress': _bpmModelInferenceService.model.getAddress,
          };
          await _bpmModelInferenceService.inference(
            isolateUtils: _isolateUtils,
            params: bpmParams,
          );
          final bpmResults = _bpmModelInferenceService.bpmResults;
          print('============ bpm: $bpmResults');
          if (bpmResults != null) {
            _avg.update(bpmResults);
            setState(() {
              _bpm = _avg.bpm;
              _hrv = _avg.hrv;
              _si = _avg.si;
            });
          }
          print('============ Stop calculating bpm');
        }
        setState(() {
          _predicting = false;
          _rawInputBuffer.clear();
        });
      }
    }
  }

  // void calcBpm(List<FaceDetectionDebugData> faceResults) async {}

  Widget _buildInfoBoard() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(
          height: 20,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildAvatar(),
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

  Widget _buildAvatar() {
    if (_avatar == null) {
      return Container();
    }
    return Image.memory(Uint8List.fromList(_encoder.encodeImage(_avatar!)));
  }
}
