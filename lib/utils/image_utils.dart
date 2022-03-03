import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math' as math;
import 'package:ffi/ffi.dart' as ffi;
import 'dart:ffi';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image_lib;

/// ImageUtils
class ImageUtils {
  static List<dynamic> cropImage(CameraImage cameraImage, Rect cropRect) {
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      final stopwatch = Stopwatch();
      stopwatch.start();

      final planes = _cropYUV420(
        cameraImage,
        cropRect,
      );
      stopwatch.stop();
      // print(
      //     '================== _crop yuv time: ${stopwatch.elapsedMilliseconds}ms');

      stopwatch.start();
      final ret = _convertYUV420ToRGBImageBytesList(
        planes[0],
        planes[1],
        planes[2],
        // cameraImage.planes[1].bytesPerRow,
        (cropRect.width.toInt() / 2.0).ceil(),
        // cameraImage.planes[1].bytesPerPixel!,
        1,
        cropRect.width.toInt(),
        cropRect.height.toInt(),
      );
      stopwatch.stop();
      // print(
      //     '================= to image bytes list time: ${stopwatch.elapsedMilliseconds}');
      return ret;
    } else {
      final croppedImageBytes = _cropBGRA8888(cameraImage, cropRect);
      final image = _convertRGBAToImage(
        croppedImageBytes,
        cropRect.width.toInt(),
        cropRect.height.toInt(),
      );
      return [image, croppedImageBytes];
    }
  }
  // /// Converts a [CameraImage] in YUV420 format to [Image] in RGB format
  // static image_lib.Image? convertCameraImage(CameraImage cameraImage) {
  //   if (cameraImage.format.group == ImageFormatGroup.yuv420) {
  //     return convertYUV420ToImage(cameraImage);
  //   } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
  //     return convertBGRA8888ToImage(cameraImage);
  //   } else {
  //     return null;
  //   }
  // }

  static Uint8List _cropBGRA8888(CameraImage cameraImage, Rect cropRect) {
    var cropRectWidth = cropRect.width.toInt();
    var cropRectHeight = cropRect.height.toInt();
    var cropRectTop = cropRect.top.toInt();
    var cropRectLeft = cropRect.left.toInt();

    // Crop
    final imgWidth = cameraImage.planes[0].width!;
    final bytes = cameraImage.planes[0].bytes;
    var croppedImageBytes = Uint8List(cropRectWidth * cropRectHeight * 4);
    for (var i = 0; i < cropRectHeight; i++) {
      var imgPos =
          4 * (cropRectTop + i) * imgWidth + cropRectLeft; // 4 each pixel
      var croppedImgPos = 4 * i * cropRectWidth;
      List.copyRange(
        croppedImageBytes,
        croppedImgPos,
        bytes,
        imgPos,
        imgPos + cropRectWidth * 4,
      );
    }

    final rgbaBytes = Uint8List(cropRectWidth * cropRectHeight * 4);
    for (var i = 0; i < cropRectWidth * cropRectHeight; i++) {
      var srcPixel = croppedImageBytes.sublist(i * 4, (i + 1) * 4);
      // Swap r and b
      final tmp = srcPixel[0];
      srcPixel[0] = srcPixel[2];
      srcPixel[2] = tmp;
      List.copyRange(rgbaBytes, i * 4, srcPixel, 0, 4);
    }
    return rgbaBytes;
  }

  // /// Converts a [CameraImage] in BGRA888 format to [Image] in RGB format
  static image_lib.Image _convertRGBAToImage(
      Uint8List bytes, int width, int height) {
    var img = image_lib.Image.fromBytes(
      width,
      height,
      bytes,
      format: image_lib.Format.rgba,
    );
    return img;
  }

  static List<Uint8List> _cropYUV420(CameraImage cameraImage, Rect cropRect) {
    if (Platform.isAndroid) {
      return _cropYUV420Android(cameraImage, cropRect);
    } else {
      return _cropYUV420IOS(cameraImage, cropRect);
    }
  }

  static List<Uint8List> _cropYUV420Android(
      CameraImage cameraImage, Rect cropRect) {
    final plane0 = cameraImage.planes[0].bytes;
    final plane1 = cameraImage.planes[1].bytes;
    final plane2 = cameraImage.planes[2].bytes;
    final imgWidth = cameraImage.width.toInt();

    // 1.5 mean 1.0 for Y and 0.25 each for U and V
    var cropRectWidth = cropRect.width.toInt();
    var cropRectHeight = cropRect.height.toInt();
    var cropRectTop = cropRect.top.toInt();
    var cropRectLeft = cropRect.left.toInt();
    if (cropRectLeft % 2 == 1) {
      cropRectLeft -= 1;
    }
    if (cropRectTop % 2 == 1) {
      cropRectTop -= 1;
    }

    // var croppedImgSize = (cropRectWidth * cropRectHeight * 1.5).floor();
    // var croppedImg = List<int>.filled(croppedImgSize, 0);
    final yPlaneSize = cropRectWidth * cropRectHeight;
    final uPlaneHeight = (cropRectHeight / 2.0).ceil();
    final uPlaneWidth = (cropRectWidth / 2.0).ceil();
    final uPlaneSize = uPlaneWidth * uPlaneHeight;
    final vPlaneHeight = (cropRectHeight / 2.0).ceil();
    final vPlaneWidth = (cropRectWidth / 2.0).ceil();
    final vPlaneSize = vPlaneWidth * vPlaneHeight;
    // final bytes = Uint8List(croppedImgYPlaneSize + uPlaneSize + vPlaneSize);

    // Start points of UV plane
    // var imgYPlaneSize = (src.length / 1.5).ceil();
    var imgYPlaneSize = plane0.length;

    // Y plane copy
    var outPlane0 = Uint8List(yPlaneSize);
    for (var i = 0; i < cropRectHeight; i++) {
      var imgPos = (cropRectTop + i) * imgWidth + cropRectLeft;
      var croppedImgPos = i * cropRectWidth;
      // System.arraycopy(img, imgPos, croppedImg, croppedImgPos, cropRect.width());
      // List.copyRange(
      //   croppedImg,
      //   croppedImgPos,
      //   src,
      //   imgPos,
      //   imgPos + cropRectWidth,
      // );
      // bytes.putUint8List(plane0.sublist(imgPos, imgPos + cropRectWidth));
      List.copyRange(
          outPlane0, croppedImgPos, plane0, imgPos, imgPos + cropRectWidth);
    }

    // U plane copy
    var outPlane1 = Uint8List(uPlaneSize);
    for (var i = 0; i < uPlaneHeight; i++) {
      var imgPos =
          (cropRectTop ~/ 2 + i) * (imgWidth ~/ 2) + (cropRectLeft ~/ 2);
      var croppedImgPos = i * uPlaneWidth;
      // System.arraycopy(
      //     img, imgPos, croppedImg, croppedImgPos, cropRect.width());
      // List.copyRange(
      //   croppedImg,
      //   croppedImgPos,
      //   src,
      //   imgPos,
      //   imgPos + cropRectWidth,
      // );

      // bytes.putUint8List(plane1.sublist(imgPos, imgPos + uPlaneWidth));
      List.copyRange(
          outPlane1, croppedImgPos, plane1, imgPos, imgPos + uPlaneWidth);
    }

    // V plane copy
    var outPlane2 = Uint8List(vPlaneSize);
    for (var i = 0; i < vPlaneHeight; i++) {
      // print('=================== $i $yPlaneHeight ${plane2.length}');
      var imgPos =
          (cropRectTop ~/ 2 + i) * (imgWidth ~/ 2) + (cropRectLeft ~/ 2);

      // bytes.putUint8List(plane2.sublist(imgPos, imgPos + yPlaneWidth));

      // var croppedImgPos = croppedImgYPlaneSize + uPlaneSize + (i * vPlaneWidth);
      var croppedImgPos = i * vPlaneWidth;
      // print(
      //     '======= imgPos $imgPos crop Pos $croppedImgPos width $cropRectWidth bytes size ${bytes.length} $croppedImgYPlaneSize $uPlaneSize');
      List.copyRange(
          outPlane2, croppedImgPos, plane2, imgPos, imgPos + vPlaneWidth);
    }
    // print('============== ok');
    // final retPlane0 = bytes.sublist(0, croppedImgYPlaneSize);
    // final retPlane1 =
    //     bytes.sublist(croppedImgYPlaneSize, croppedImgYPlaneSize + uPlaneSize);
    // final retPlane2 = bytes.sublist(croppedImgYPlaneSize + uPlaneSize);

    // final planes = bytes.done().buffer.asUint8List();
    // return [retPlane0, retPlane1, retPlane2];
    return [outPlane0, outPlane1, outPlane2];
  }

  static List<Uint8List> _cropYUV420IOS(
      CameraImage cameraImage, Rect cropRect) {
    final plane0 = cameraImage.planes[0].bytes; // y plane
    final plane1 = cameraImage.planes[1].bytes; // uv plane
    final imgWidth = cameraImage.width.toInt();

    // 1.5 mean 1.0 for Y and 0.25 each for U and V
    var cropRectWidth = cropRect.width.toInt();
    var cropRectHeight = cropRect.height.toInt();
    var cropRectTop = cropRect.top.toInt();
    var cropRectLeft = cropRect.left.toInt();
    if (cropRectLeft % 2 == 1) {
      cropRectLeft -= 1;
    }
    if (cropRectTop % 2 == 1) {
      cropRectTop -= 1;
    }

    // var croppedImgSize = (cropRectWidth * cropRectHeight * 1.5).floor();
    // var croppedImg = List<int>.filled(croppedImgSize, 0);
    final yPlaneSize = cropRectWidth * cropRectHeight;
    final uPlaneHeight = (cropRectHeight / 2.0).ceil();
    final uPlaneWidth = (cropRectWidth / 2.0).ceil();
    final uPlaneSize = uPlaneWidth * uPlaneHeight;
    final vPlaneHeight = (cropRectHeight / 2.0).ceil();
    final vPlaneWidth = (cropRectWidth / 2.0).ceil();
    final vPlaneSize = vPlaneWidth * vPlaneHeight;
    var outPlane0 = Uint8List(yPlaneSize);

    // Y plane copy
    for (var i = 0; i < cropRectHeight; i++) {
      var imgPos = (cropRectTop + i) * imgWidth + cropRectLeft;
      var croppedImgPos = i * cropRectWidth;
      List.copyRange(
          outPlane0, croppedImgPos, plane0, imgPos, imgPos + cropRectWidth);
    }

    // UV plane copy
    var outPlane1 = Uint8List(uPlaneSize);
    var outPlane2 = Uint8List(vPlaneSize);
    final index1 = List.generate(uPlaneWidth, (index) => index * 2);
    final index2 = List.generate(vPlaneWidth, (index) => index * 2 + 1);
    for (var i = 0; i < uPlaneHeight; i++) {
      // Get the uv row
      var imgPos = (cropRectTop ~/ 2 + i) * imgWidth + cropRectLeft;
      final uvRow = plane1.sublist(imgPos, imgPos + cropRectWidth);
      final uRow = index1.map((idx) => uvRow[idx]).toList();
      final vRow = index2.map((idx) => uvRow[idx]).toList();

      List.copyRange(outPlane1, i * uPlaneWidth, uRow, 0, uPlaneWidth);
      List.copyRange(outPlane2, i * vPlaneWidth, vRow, 0, vPlaneWidth);
    }

    return [outPlane0, outPlane1, outPlane2];
  }

  /// Converts a [CameraImage] in YUV420 format to [Image] in RGB format
  // static List<int> _convertYUV420ToRGBImageBytesList(
  //   Uint8List plane0,
  //   Uint8List plane1,
  //   Uint8List plane2,
  //   int bytesPerRow,
  //   int bytesPerPixel,
  //   int width,
  //   int height,
  // ) {
  //   // final width = cameraImage.width;
  //   // final height = cameraImage.height;

  //   final uvRowStride = bytesPerRow;
  //   final uvPixelStride = bytesPerPixel;

  //   // final image = image_lib.Image(width, height);

  //   var retImage = List<int>.filled(width * height * 3, 0);
  //   var index = 0;
  //   for (var w = 0; w < width; w++) {
  //     for (var h = 0; h < height; h++) {
  //       final uvIndex =
  //           uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
  //       final yindex = h * width + w;

  //       final y = plane0[yindex];
  //       final u = plane1[uvIndex];
  //       final v = plane2[uvIndex];

  //       // image.data[index] = ImageUtils.yuv2rgb(y, u, v);
  //       var color = ImageUtils._yuv2rgb(y, u, v);
  //       // final r = color & 0xff;
  //       // final g = (color >> 8) & 0xff;
  //       // final b = (color >> 16) & 0xff;

  //       // if (r > 255 || g > 255 || b > 255 || r < 0 || g < 0 || b < 0) {
  //       //   throw Exception('============= rgb $r $g $b');
  //       // }
  //       // retImage[index++] = color & 0xff;
  //       // retImage[index++] = (color >> 8) & 0xff;
  //       // retImage[index++] = (color >> 16) & 0xff;
  //       retImage[index++] = color[0];
  //       retImage[index++] = color[1];
  //       retImage[index++] = color[2];
  //     }
  //   }
  //   return retImage;
  // }

  // /// Converts a [CameraImage] in YUV420 format to [Image] in RGB format
  // static image_lib.Image convertYUV420ToImage(CameraImage cameraImage) {
  static List<dynamic> _convertYUV420ToRGBImageBytesList(
    Uint8List plane0,
    Uint8List plane1,
    Uint8List plane2,
    int bytesPerRow,
    int bytesPerPixel,
    int width,
    int height,
  ) {
    final uvRowStride = bytesPerRow;
    final uvPixelStride = bytesPerPixel;

    final image = image_lib.Image(height, width); // Rotate
    var bytes = Uint8List(width * height * 3);
    var bytesIndex = 0;
    for (var w = 0; w < width; w++) {
      for (var h = 0; h < height; h++) {
        final uvIndex =
            uvPixelStride * (w / 2).floor() + uvRowStride * (h / 2).floor();
        final index = h * width + w;

        final y = plane0[index];
        final u = plane1[uvIndex];
        final v = plane2[uvIndex];

        // image.data[index] = ImageUtils.yuv2rgb(y, u, v);
        var r = (y + v * 1436 / 1024 - 179).round().clamp(0, 255);
        var g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        var b = (y + u * 1814 / 1024 - 227).round().clamp(0, 255);
        // image.data[index] = 0xff | (b << 16) | (g << 8) | r;
        // In Android, we need to rotate image by 90 degrees in counter-clockwise
        // so must do a transformation in the index
        var rotateIndex = (width - 1 - w) * height + h;
        image.data[rotateIndex] = 0xff000000 |
            ((b << 16) & 0xff0000) |
            ((g << 8) & 0xff00) |
            (r & 0xff);

        // Fill bytes
        bytes[rotateIndex] = r;
        bytes[rotateIndex + 1] = g;
        bytes[rotateIndex + 2] = b;
      }
    }
    return [image, bytes];
  }

  /// Convert a single YUV pixel to RGB
  static List<int> _yuv2rgb(int y, int u, int v) {
    // Convert yuv pixel to rgb
    var r = (y + v * 1436 / 1024 - 179).round();
    var g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
    var b = (y + u * 1814 / 1024 - 227).round();

    // Clipping RGB values to be inside boundaries [ 0 , 255 ]
    r = r.clamp(0, 255);
    g = g.clamp(0, 255);
    b = b.clamp(0, 255);
    return [r, g, b];

    // return 0xff000000 |
    //     ((b << 16) & 0xff0000) |
    //     ((g << 8) & 0xff00) |
  }
}
