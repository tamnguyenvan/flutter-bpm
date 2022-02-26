// import 'dart:async';
// import 'dart:collection';
// import 'dart:io';
import 'dart:typed_data';

// import 'package:camera/camera.dart';
// import 'package:google_ml_vision/google_ml_vision.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;
// import 'package:path_provider/path_provider.dart';

// class ImageWriter {
//   static Future<String> get _localPath async {
//     final directory = await getApplicationDocumentsDirectory();

//     return directory.path;
//   }

//   static Future<File> _localFile(String filename) async {
//     final path = await _localPath;
//     return File('$path/$filename');
//   }

//   static Future<File> write(String filename, String data) async {
//     final file = await _localFile(filename);
//     return file.writeAsString(data);
//   }

//   static String listToString(List<num> list) {
//     var buffer = StringBuffer();
//     for (var x in list) {
//       buffer.write("${x.toString()} ");
//     }
//     return buffer.toString().trim();
//   }

//   static String imageListToString(List<List<num>> images) {
//     var buffer = StringBuffer();
//     for (var image in images) {
//       String imageStr = listToString(image);
//       buffer.write(imageStr + "\n");
//     }
//     return buffer.toString().trim();
//   }
// }

// class Scheduler {
//   bool _scheduled = false;

//   final _queue = Queue<Future Function(dynamic)>();
//   final _args = Queue<dynamic>();
//   Queue<dynamic> results = Queue<dynamic>();

//   void schedule(Future Function(dynamic) task, dynamic args) {
//     _queue.add(task);
//     _args.add(args);
//     if (!_scheduled) {
//       _scheduled = true;
//       Timer(const Duration(seconds: 0), _execute);
//     }
//   }

//   Future _execute() async {
//     while (true) {
//       if (_queue.isEmpty) {
//         _scheduled = false;
//         return;
//       }

//       print('Executing...');
//       var first = _queue.removeFirst();
//       var arguments = _args.removeFirst();
//       var rs = await first(arguments);
//       results.add(rs);
//       print('Finished');
//     }
//   }
// }

// num median(List<num> x) {
//   if (x.isEmpty) {
//     return 0;
//   }

//   var clone = <num>[];
//   clone.addAll(x);
//   clone.sort();
//   final middle = clone.length ~/ 2;
//   if (clone.length % 2 == 1) {
//     return clone[middle];
//   } else {
//     return (clone[middle - 1] - clone[middle]) / 2;
//   }
// }

Float32List imageToFloat32List(imglib.Image image) {
  var convertedBytes = Float32List(1 * image.height * image.width * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  var pixelIndex = 0;
  for (var i = 0; i < image.height; i++) {
    for (var j = 0; j < image.width; j++) {
      var pixel = image.getPixel(j, i);
      buffer[pixelIndex++] = imglib.getRed(pixel).toDouble();
      buffer[pixelIndex++] = imglib.getGreen(pixel).toDouble();
      buffer[pixelIndex++] = imglib.getBlue(pixel).toDouble();
    }
  }
  return convertedBytes.buffer.asFloat32List();
}

imglib.Image? convertCameraImage(CameraImage image, CameraLensDirection _dir) {
  imglib.Image? img;
  try {
    if (image.format.group == ImageFormatGroup.yuv420) {
      img = _convertYUV420(image, _dir);
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      img = _convertBGRA8888(image, _dir);
    }
  } catch (e) {
    print(">>>>>>>>>>>> ERROR:" + e.toString());
  }
  return img;
}

imglib.Image _convertBGRA8888(CameraImage image, CameraLensDirection _dir) {
  var img = imglib.Image.fromBytes(
    image.width,
    image.height,
    image.planes[0].bytes,
    format: imglib.Format.bgra,
  );

  //var img1 = (_dir == CameraLensDirection.front)
  //    ? imglib.copyRotate(img, -90)
  //    : imglib.copyRotate(img, 90);
  return img;
}

imglib.Image _convertYUV420(CameraImage image, CameraLensDirection _dir) {
  var width = image.width;
  var height = image.height;
  var img = imglib.Image(width, height);
  const hexFF = 0xFF000000;
  final uvyButtonStride = image.planes[1].bytesPerRow;
  final uvPixelStride = image.planes[1].bytesPerPixel;
  for (var x = 0; x < width; x++) {
    for (var y = 0; y < height; y++) {
      final uvIndex =
          uvPixelStride! * (x / 2).floor() + uvyButtonStride * (y / 2).floor();
      final index = y * width + x;
      final yp = image.planes[0].bytes[index];
      final up = image.planes[1].bytes[uvIndex];
      final vp = image.planes[2].bytes[uvIndex];
      var r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
      var g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
          .round()
          .clamp(0, 255);
      var b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
      img.data[index] = hexFF | (b << 16) | (g << 8) | r;
    }
  }
  var img1 = (_dir == CameraLensDirection.front)
      ? imglib.copyRotate(img, -90)
      : imglib.copyRotate(img, 90);
  return img1;
}
