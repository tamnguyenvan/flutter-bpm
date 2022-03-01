import 'dart:collection';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_with_mediapipe/constants/model.dart';
import 'package:flutter_with_mediapipe/services/ai_model.dart';
import 'bpm_utils.dart';
import 'general.dart';
import 'signals.dart';
import 'package:image/image.dart' as imglib;
// import 'package:google_ml_vision/google_ml_vision.dart';
import 'package:ml_linalg/matrix.dart';
import 'package:ml_linalg/vector.dart';
import 'package:scidart/numdart.dart';
import 'package:scidart/scidart.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';

import 'bpm_utils.dart';
import 'signals.dart';

// class InputBuffer {
//   final int bufferSize;
//   InputBuffer({this.bufferSize = 101});

//   ListQueue<Vector> frames = ListQueue<Vector>();

//   Vector imageToVector(imglib.Image image) {
//     var imageFloat = imageToFloat32List(image);
//     return Vector.fromList(imageFloat);
//   }

//   update(imglib.Image image) {
//     if (frames.length == bufferSize) {
//       frames.removeFirst();
//     }
//     frames.add(imageToVector(image));
//   }

//   List<Matrix> prepareInputs() {
//     if (!ready) {
//       throw Exception("The input buffer was not ready yet.");
//     }
//     Matrix xSub = Matrix.fromRows(frames.toList());
//     xSub = xSub / 255;

//     final normLen = xSub.length - 1;
//     List<Vector> dXsubTemp = [];
//     for (var i = 0; i < normLen - 1; i++) {
//       var normedVec = (xSub[i + 1] - xSub[i]) / (xSub[i + 1] + xSub[i] + 1e-12);
//       dXsubTemp.add(normedVec);
//     }
//     dXsubTemp.add(Vector.filled(dXsubTemp[0].length, 0));

//     // Normalize dXsub
//     var dXsub = Matrix.fromRows(dXsubTemp);
//     var dMean = dXsub.sum() / (dXsub.columnsNum * dXsub.rowsNum);
//     var dStd = math.sqrt(
//       (dXsub - dMean).pow(2).sum() / (dXsub.columnsNum * dXsub.rowsNum),
//     );
//     dXsub = dXsub / dStd;

//     // Normalize xSub
//     var mean = xSub.sum() / (xSub.columnsNum * xSub.rowsNum);
//     xSub = xSub - mean;

//     var mean2 = xSub.sum() / (xSub.columnsNum * xSub.rowsNum);
//     var std = math.sqrt(
//       (xSub - mean2).pow(2).sum() / (xSub.columnsNum * xSub.rowsNum),
//     );
//     xSub = xSub / std;
//     xSub =
//         xSub.sample(rowIndices: List<int>.generate(normLen, (index) => index));
//     return [dXsub, xSub];
//   }

//   Vector elementAt(int index) {
//     return frames.elementAt(index);
//   }

//   clear() {
//     frames.clear();
//   }

//   bool get ready {
//     return frames.length == bufferSize;
//   }
// }

// class BPMIsolateData {
//   List<List<double>> inputs;
//   double fps;
//   BPMIsolateData(this.inputs, this.fps);
// }

// ignore: must_be_immutable
class BpmCalculator extends BpmAiModel {
  // Default range
  final List<double> bpmRange = [40, 200];
  final List<double> hrvRange = [1, 1000];
  final List<double> siRange = [1, 10];

  // Tflite model
  final int inputSize = 36;
  // final String modelName;
  // bool _isLoaded = false;

  // late Interpreter _interpreter;
  // late InterpreterOptions _interpreterOptions;

  // late List<int> _inputShape0;
  // late TfLiteType _inputType0;
  // late TensorBuffer _output;
  // late List<int> _outputShape;
  // late TfLiteType _outputType;

  // Moving average
  // final avg = MovingAverage();

  BpmCalculator({this.interpreter}) {
    loadModel();
  }

  @override
  Interpreter? interpreter;

  @override
  List<Object> get props => [];

  @override
  int get getAddress => interpreter!.address;

  @override
  Future<void> loadModel() async {
    // try {
    final interpreterOptions = InterpreterOptions();

    interpreterOptions.threads = 4;
    // interpreter = await Interpreter.fromAsset(
    //   modelName,
    //   options: interpreterOptions,
    // );
    interpreter = interpreter ??
        await Interpreter.fromAsset(
          ModelFile.mttscan,
          options: interpreterOptions,
        );
    print('Interpreter Created Successfully');

    // _inputShape0 = _interpreter.getInputTensor(0).shape;
    // _outputShape = _interpreter.getOutputTensor(0).shape;
    // _inputType0 = _interpreter.getInputTensor(0).type;
    // _outputType = _interpreter.getOutputTensor(0).type;
    // _output = TensorBuffer.createFixedSize(_outputShape, _outputType);
    final outputTensors = interpreter!.getOutputTensors();

    outputTensors.forEach((tensor) {
      outputShapes.add(tensor.shape);
      outputTypes.add(tensor.type);
    });
    // } catch (e) {
    //   print('Unable to create interpreter, Caught Exception: ${e.toString()}');
    // }
  }

  @override
  List<double> calc(List<List<double>> inputs, double fps) {
    // final List<List<int>> inputs = args['inputs'];
    // final double fps = args['fps'];
    // final inputs = data.inputs;
    // final fps = data.fps;

    // var bpm = 0.0;
    // var hrv = 0.0;
    // var si = 0.0;

    // if (!_isLoaded) {
    //   return [bpm, hrv, si];
    // }

    var output = TensorBuffer.createFixedSize(outputShapes[0], outputTypes[0]);
    interpreter!.run(inputs, output.buffer);

    // Detrend the pulse predictions
    var pulsePred = output.getDoubleList();
    var ba = butter([0.75 / fps * 2, 2.5 / fps * 2]);
    // var ba = [
    //   [0.15635952, 0.0, -0.15635952],
    //   [1.0, -1.61758769, 0.68728096]
    // ];
    pulsePred = filtfilt(ba[0], ba[1], pulsePred);
    // var z = lfilter(Array(ba[0]), Array(ba[1]), Array(pulsePred));
    // pulsePred = [
    //   0.1060263544158138,
    //   0.30825308612647767,
    //   0.483262831951667,
    //   0.6244708870476103,
    //   0.7363352337893652,
    //   0.8151299988656397,
    //   0.8556469782812112,
    //   0.8321843609147954,
    //   0.6917794989991318,
    //   0.4257452929179669,
    //   0.12425953554907106,
    //   -0.08987685890594117,
    //   -0.16105393724513714,
    //   -0.11539590211142992,
    //   0.008303016916853909,
    //   0.18455655940492655,
    //   0.3699387822438188,
    //   0.4993126130753308,
    //   0.4968569117358763,
    //   0.3049782214034935,
    //   -0.004753561389992424,
    //   -0.26602401765585665,
    //   -0.42789810747323964,
    //   -0.5234661783501873,
    //   -0.5440315636853991,
    //   -0.4785095839956556,
    //   -0.36164638501052815,
    //   -0.2551285428827781,
    //   -0.21627231837402536,
    //   -0.25552549215535064,
    //   -0.3045991255375039,
    //   -0.2887067224206475,
    //   -0.20901996765548517,
    //   -0.1110935985655717,
    //   -0.02844539484579755,
    //   0.04022127177347618,
    //   0.10802725144144536,
    //   0.1577642523747951,
    //   0.1598232263715149,
    //   0.10193845366887894,
    //   0.026842473032659284,
    //   0.011007587733897019,
    //   0.06664856410910593,
    //   0.15128399767025308,
    //   0.22673878810391773,
    //   0.2729297362128131,
    //   0.2776984387091994,
    //   0.22784363054687937,
    //   0.11634883796438754,
    //   -0.045652492833121776
    // ];

    // Calculate heart rate
    var peakIndices = findPeaksByDistance(pulsePred, distance: 15);
    var rs = _calc(peakIndices, fps);
    print('=============== Raw results: $rs');
    // avg.update(rs);
    // return [avg.bpm, avg.hrv, avg.si];
    return rs;
  }

  List<double> _calc(List<int> peaks, double fps) {
    // Default values
    var bpm = 0.0;
    var hrv = 0.0;
    var si = 0.0;

    // Calculate RR-intervals (in ms) list from the given peaks and fps
    var rrList = <int>[];
    var cnt = 0;
    while (cnt < peaks.length - 1) {
      final rrInterval = peaks[cnt + 1] - peaks[cnt];
      var msDist = ((rrInterval / fps) * 1000).toInt();
      rrList.add(msDist);
      cnt += 1;
    }

    // BPM
    if (rrList.isNotEmpty) {
      bpm = 60000.0 / (Vector.fromList(rrList).mean() + 1e-12);
    }

    // Calculate HRV using SDNN method.
    // Ref: https://imotions.com/blog/heart-rate-variability/
    // HRV = sqrt(mean((RR1 - RR2)^2 + (RR2 - RR3)^2 + ...))
    if (rrList.length >= 2) {
      var sumSquaredIntervalDiff = 0.0;
      // var maxIntervalValue = rrList[0];
      // var minIntervalValue = rrList[0];
      // var mostFreqCounter = 0;
      // var mode = 0;
      // var rrIntervalToFreqMap = {};
      // rrIntervalToFreqMap[rrList[0]] = 1;
      for (var i = 1; i < rrList.length; i++) {
        // For calculating HRV then
        sumSquaredIntervalDiff += math.pow(rrList[i] - rrList[i - 1], 2);

        // // Find max R-R interval value
        // if (rrList[i] > maxIntervalValue) {
        //   maxIntervalValue = rrList[i];
        // }

        // // Find min R-R interval value
        // if (rrList[i] < minIntervalValue) {
        //   minIntervalValue = rrList[i];
        // }

        // // Calculate mode (the most recurring R-R value) and it's occurences
        // var rrKey = rrList[i];
        // if (rrIntervalToFreqMap.containsKey(rrKey)) {
        //   rrIntervalToFreqMap[rrKey] += 1;
        // } else {
        //   rrIntervalToFreqMap[rrKey] = 1;
        // }
        // if (rrIntervalToFreqMap[rrKey] > mostFreqCounter) {
        //   mode = rrKey;
        //   mostFreqCounter = rrIntervalToFreqMap[rrKey];
        // }
      }

      // It's time to calculate stress index
      // si = AMo / (2 * VR * Mo)
      // Ref: https://r-forge.r-project.org/forum/attachment.php?attachid=634&group_id=919&forum_id=2951
      hrv = math.sqrt(sumSquaredIntervalDiff / (rrList.length - 1));

      // var amo = 100 * mostFreqCounter / rrList.length;
      // var vr = (maxIntervalValue - minIntervalValue) / 1000; // ms
      // var modeInMs = mode / 1000; // ms
      // si = amo / (2 * vr * modeInMs + 1e-12);

      // Ref: https://www.kubios.com/hrv-analysis-methods/
      // Binarize the RR-intervals with bin size = 50ms
      const binSize = 50; // 50ms
      final firstBin = (rrList[0] / binSize).ceil();
      var maxInterval = firstBin;
      var minInterval = firstBin;
      var rrDist = {firstBin: 1};
      var maxFreqs = 0;
      var mode = 0;
      for (var i = 1; i < rrList.length; i++) {
        final bin = (rrList[i] / binSize).ceil();
        if (rrDist.containsKey(bin)) {
          rrDist[bin] = rrDist[bin]! + 1;
        } else {
          rrDist[bin] = 1;
        }
        if (rrDist[bin]! > maxFreqs) {
          mode = bin;
          maxFreqs = rrDist[bin]!;
        }

        if (bin > maxInterval) {
          maxInterval = bin;
        }

        if (bin < minInterval) {
          minInterval = bin;
        }
      }
      var mo = (mode * binSize).toDouble() / 1000.0;
      var mxDmn = (maxInterval - minInterval + 1e-12) * binSize / 1000.0;
      si = (maxFreqs / rrList.length) / (2 * mo * mxDmn);

      // Scale the Stress index for more user-friendly
      // si = 10 * si;
    }

    bpm = math.min(math.max(bpm, bpmRange[0]), bpmRange[1]);
    hrv = math.min(math.max(hrv, hrvRange[0]), hrvRange[1]);
    si = math.min(math.max(si, siRange[0]), siRange[1]);
    return [bpm, hrv, si];
  }
}

class MovingAverage {
  MovingAverage({this.alpha = 0.9});
  double alpha;
  double bpm = 0;
  double hrv = 0;
  double si = 0;
  bool init = true;

  void update(List<double> rs) {
    final _bpm = rs[0];
    final _hrv = rs[1];
    final _si = rs[2];

    if (init && (_bpm != 0 || _hrv != 0 || _si != 0)) {
      bpm = _bpm;
      hrv = _hrv;
      si = _si;
      init = false;
    } else {
      bpm = alpha * bpm + (1 - alpha) * _bpm;
      hrv = alpha * hrv + (1 - alpha) * _hrv;
      si = alpha * si + (1 - alpha) * _si;
    }
  }
}

List<double>? runBpmCalculator(Map<String, dynamic> params) {
  final bpmCalculator = BpmCalculator(
      interpreter: Interpreter.fromAddress(params['bpmCalculatorAddress']));

  final result = bpmCalculator.calc(params['inputs'], params['fps']);

  return result;
}
