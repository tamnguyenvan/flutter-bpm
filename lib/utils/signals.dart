import 'dart:math' as math;
import 'package:ml_linalg/linalg.dart';
import 'package:scidart/numdart.dart';
import 'package:ml_linalg/vector.dart';
import 'package:scidart/scidart.dart';

class ZpkData {
  final ArrayComplex z;
  final ArrayComplex p;
  final double k;

  ZpkData({required this.z, required this.p, required this.k});
}

List<List<double>> butter(List<double> frequencies,
    {String btype = 'bandpass', String output = 'ba'}) {
  // buttap
  ZpkData zpkData = buttap();
  var z = zpkData.z;
  var p = zpkData.p;
  var k = zpkData.k;

  // Not analog
  var fs = 2.0;
  var warped = Array(
    [
      2 * fs * math.tan(math.pi * frequencies[0] / fs),
      2 * fs * math.tan(math.pi * frequencies[1] / fs)
    ],
  );

  var bw = warped[1] - warped[0];
  var wo = math.sqrt(warped[0] * warped[1]);
  zpkData = lp2bpZpk(z, p, k, wo: wo, bw: bw);

  // not analog
  zpkData = bilinearZpk(zpkData.z, zpkData.p, zpkData.k, fs);

  return zpk2tf(zpkData.z, zpkData.p, zpkData.k);
}

//     Filter implemented using state-space representation.
// Assume a filter with second order difference equation (assuming a[0]=1):
//     y[n] = b[0]*x[n] + b[1]*x[n-1] + b[2]*x[n-2] + ...
//                      - a[1]*y[n-1] - a[2]*y[n-2]
List<double> customLfilter(List<double> b, List<double> a, List<double> x) {
  // var bVec = Vector.fromList(b);
  // var aVec = Vector.fromList(a);
  // var xVec = Vector.fromList(x);

  var AM = Matrix.fromList([
    [-a[1], 1],
    [-a[2], 0],
  ]);
  var B = Array2d([
    Array([b[1] - b[0] * a[1]]),
    Array([b[2] - b[0] * a[2]]),
  ]);
  final BVec = Vector.fromList([b[1] - b[0] * a[1], b[2] - b[0] * a[2]]);
  var C = Vector.fromList([1, 0]);
  var D = b[0];

  // Determine initial state (solve zi = A*zi + B, see scipy.signal.lfilter_zi)
  final AList =
      (Matrix.scalar(1, 2) - AM).map((row) => Array(row.toList())).toList();
  final A = Array2d(AList);
  var ziArray2d = matrixSolve(A, B); // 2-d array shape of (1, 2)

  // Scale the initial state vector zi by the first input value
  final zi = Vector.fromList(matrixColumnToArray(ziArray2d, 0).toList());
  var z = zi * x[0];

  // Apply filter
  var y = List<double>.filled(x.length, 0);
  for (var n = 0; n < x.length; n++) {
    // Determine n-th output value (note this simplifies to y[n] = z[0] + b[0]*x[n])
    y[n] = C.dot(z) + D * x[n];

    // Determine next state (i.e. z[n+1])
    z = (AM * z).getColumn(0) + BVec * x[n];
  }
  return y;
}

List<double> filtfilt(List<double> b, List<double> a, List<double> x) {
  // Apply 'odd' padding to input signal
  final int padLen =
      3 * math.max(a.length, b.length); // the scipy.signal.filtfilt default
  final len = x.length;

  final leftExt =
      x.sublist(1, 1 + padLen).reversed.map((e) => 2 * x.first - e).toList();
  final rightExt = x.reversed
      .toList()
      .sublist(1, 1 + padLen)
      .map((e) => 2 * x.last - e)
      .toList();
  var xForward = leftExt + x + rightExt;
  final xForwardLen = xForward.length;

  // Filter forward
  var yForward = customLfilter(b, a, xForward);

  // Filter backward
  var xBackward = yForward.reversed.toList();
  var yBackward = customLfilter(b, a, xBackward);

  var result = yBackward.reversed.toList();
  return result.sublist(padLen, xForwardLen - padLen);
}

// List<double> lfilterZi(List<double> b, List<double> a) {
//   while (a.length > 1 && a[0] == 0) {
//     a = a.sublist(1);
//   }

//   if (a.isEmpty) {
//     throw Exception('There must be at least one nonzero `a` coefficient.');
//   }

//   var aVec = Vector.fromList(a);
//   var bVec = Vector.fromList(b);
//   if (a[0] != 1) {
//     // Normalize the coefficients so a[0] == 1.
//     bVec = bVec / a[0];
//     aVec = aVec / a[0];
//   }

//   var n = math.max(a.length, b.length);

//   // Pad a or b with zeros so they are the same length.
//   if (aVec.length < n) {
//     final pad = n - aVec.length;
//     aVec = Vector.fromList(aVec.toList() + List<double>.filled(pad, 0));
//   } else {
//     final pad = n - bVec.length;
//     bVec = Vector.fromList(bVec.toList() + List<double>.filled(pad, 0));
//   }

//   final companionMList = companionMatrix(aVec);
//   final companionM = Matrix.fromList(companionMList);
//   var identityMinusA = Matrix.identity(n - 1) - companionM.transpose();
//   var A = Array2d(identityMinusA.map((row) => Array(row.toList())).toList());
//   var bList = (bVec.subvector(1) - aVec.subvector(1) * bVec[0]).toList();
//   var bArr = arrayReshapeToMatrix(Array(bList), 1);

//   var zi = matrixSolve(A, bArr);
//   return matrixColumnToArray(zi, 0).toList();
// }

// List<List<double>> companionMatrix(Vector a) {
//   final firstRow = (a.subvector(1) * -1) / (a[0] * 1.0);
//   List<List<double>> compList = [firstRow.toList()];
//   final n = a.length;
//   for (var i = 0; i < n - 2; i++) {
//     var zeros = List<double>.filled(n - 1, 0);
//     zeros[i] = 0;
//     compList.add(zeros);
//   }
//   return compList;
// }

// ValidationData validatePad(List<double> x, int ntaps) {
//   var edge = ntaps * 3;
//   var ext = oddExt(x, edge);
//   return ValidationData(ext: ext, edge: edge);
// }

// class ValidationData {
//   final List<double> ext;
//   final int edge;
//   ValidationData({required this.ext, required this.edge});
// }

// oddExt(List<double> x, int n) {
//   final len = x.length;
//   final leftEnd = x.first;
//   final leftExt = Vector.fromList(x.sublist(1, 1 + n));
//   final rightEnd = x.last;
//   List<double> rightExtList = [];
//   int i = len - 2;
//   while (i >= len - 2 - n) {
//     rightExtList.add(x[i]);
//   }
//   final rightExt = Vector.fromList(rightExtList);

//   final left = (leftExt * -1 + 2 * leftEnd).toList();
//   final right = (rightExt * -1 + 2 * rightEnd).toList();
//   return left + x + right;
// }

// Buttap for order = 1 only
ZpkData buttap() {
  var z = ArrayComplex([]);
  var p = ArrayComplex([Complex(real: -1, imaginary: 0)]);
  double k = 1;
  return ZpkData(z: z, p: p, k: k);
}

ZpkData lp2bpZpk(ArrayComplex z, ArrayComplex p, double k,
    {double wo = 1.0, double bw = 1.0}) {
  final degree_ = relativeDegree(z, p);

  // Scale poles and zeros to desired bandwidth
  var zlpComp = arrayComplexMultiplyToScalar(z, bw / 2);
  var plp = arrayComplexMultiplyToScalar(p, bw / 2);

  // var zlpComp = arrayToComplexArray(zlp);

  // Duplicate poles and zeros and shift from baseband to +wo and -wo
  var zbpComp = arrayComplexConcat(
    arrayComplexAddToArrayComplex(
        zlpComp,
        arrayComplexSqrt(
            arrayComplexAddToScalar(arrayComplexPow(zlpComp, 2), -wo * wo))),
    arrayComplexSubToArrayComplex(
        zlpComp,
        arrayComplexSqrt(
            arrayComplexAddToScalar(arrayComplexPow(zlpComp, 2), -wo * wo))),
  );

  var power = arrayComplexPow(plp, 2);
  var add = arrayComplexAddToScalar(power, -wo * wo);
  var sqrt = arrayComplexSqrt(add);
  var add2 = arrayComplexAddToArrayComplex(plp, sqrt);

  var pbpComp = arrayComplexConcat(
    arrayComplexAddToArrayComplex(
        plp,
        arrayComplexSqrt(
            arrayComplexAddToScalar(arrayComplexPow(plp, 2), -wo * wo))),
    arrayComplexSubToArrayComplex(
        plp,
        arrayComplexSqrt(
            arrayComplexAddToScalar(arrayComplexPow(plp, 2), -wo * wo))),
  );

  // Move degree zeros to origin, leaving degree zeros at infinity for BPF
  zbpComp = arrayComplexConcat(
      zbpComp,
      ArrayComplex.fixed(degree_,
          initialValue: Complex(real: 0, imaginary: 0)));

  var kbpComp = k * math.pow(bw, degree_);
  return ZpkData(z: zbpComp, p: pbpComp, k: kbpComp);
}

int relativeDegree(ArrayComplex z, ArrayComplex p) {
  var degree = p.length - z.length;
  if (degree < 0) {
    throw Exception(
        'Improper transfer function. "Must have at least as many poles as zeros.');
  } else {
    return degree;
  }
}

ZpkData bilinearZpk(ArrayComplex z, ArrayComplex p, double k, double fs) {
  var degree_ = relativeDegree(z, p);
  var fs2 = 2 * fs;

  // Bilinear transform the poles and zeros
  var zz = arrayComplexDivToArrayComplex(
    arrayComplexAddToScalar(z, fs2),
    scalarSubToArrayComplex(fs2, z),
  );
  var pz = arrayComplexDivToArrayComplex(
    arrayComplexAddToScalar(p, fs2),
    scalarSubToArrayComplex(fs2, p),
  );

  // Any zeros that were at infinity get moved to the Nyquist frequency
  zz = arrayComplexConcat(
      zz,
      ArrayComplex.fixed(degree_,
          initialValue: Complex(real: -1, imaginary: 0)));

  var kz = k *
      divComplex(
        arrayComplexProd(
          scalarSubToArrayComplex(fs2, z),
        ),
        arrayComplexProd(
          scalarSubToArrayComplex(fs2, p),
        ),
      ).real;
  return ZpkData(z: zz, p: pz, k: kz);
}

List<List<double>> zpk2tf(ArrayComplex z, ArrayComplex p, double k) {
  var b = arrayMultiplyToScalar(Array(polyOfRoots(z)), k).toList();
  var a = polyOfRoots(p);
  return [b, a];
}

ArrayComplex arrayComplexPow(ArrayComplex a, num b) {
  var c = ArrayComplex.fixed(a.length);
  for (var i = 0; i < a.length; i++) {
    c[i] = complexPow(a[i], b);
  }

  return c;
}

Complex complexPow(Complex a, num b) {
  return Complex(
      real:
          (a.real * a.real).toDouble() - (a.imaginary * a.imaginary).toDouble(),
      imaginary: 2 * a.real * a.imaginary);
}

ArrayComplex arrayComplexAddToScalar(ArrayComplex a, num b) {
  var c = ArrayComplex.fixed(a.length);
  for (var i = 0; i < a.length; i++) {
    c[i] = Complex(real: a[i].real + b, imaginary: a[i].imaginary);
  }
  return c;
}

ArrayComplex scalarSubToArrayComplex(num a, ArrayComplex b) {
  var c = ArrayComplex.fixed(b.length);
  for (var i = 0; i < b.length; i++) {
    c[i] = Complex(real: a - b[i].real, imaginary: -b[i].imaginary);
  }
  return c;
}

ArrayComplex arrayComplexSqrt(ArrayComplex a) {
  var c = ArrayComplex.fixed(a.length);
  for (var i = 0; i < a.length; i++) {
    var real = a[i].real;
    var img = a[i].imaginary;

    double newReal = 0;
    double newImg = 0;
    if (img == 0) {
      if (real < 0) {
        newReal = 0;
        newImg = -math.sqrt(real.abs());
      } else {
        newReal = math.sqrt(real);
        newImg = 0;
      }
    } else {
      newReal = math.sqrt((math.sqrt(real * real + img * img) + img) / 2);
      newImg = math.sqrt((math.sqrt(real * real + img * img) - img) / 2);
      newImg = img > 0 ? newImg : -newImg;
    }

    c[i] = Complex(real: newReal, imaginary: newImg);
  }
  return c;
}

ArrayComplex arrayComplexAddToArrayComplex(ArrayComplex a, ArrayComplex b) {
  var c = ArrayComplex.fixed(a.length);
  for (var i = 0; i < a.length; i++) {
    c[i] = Complex(
      real: a[i].real + b[i].real,
      imaginary: a[i].imaginary + b[i].imaginary,
    );
  }
  return c;
}

ArrayComplex arrayComplexSubToArrayComplex(ArrayComplex a, ArrayComplex b) {
  var c = ArrayComplex.fixed(a.length);
  for (var i = 0; i < a.length; i++) {
    c[i] = Complex(
      real: a[i].real - b[i].real,
      imaginary: a[i].imaginary - b[i].imaginary,
    );
  }
  return c;
}

ArrayComplex arrayComplexDivToArrayComplex(ArrayComplex a, ArrayComplex b) {
  var c = ArrayComplex.fixed(a.length);
  for (var i = 0; i < a.length; i++) {
    c[i] = divComplex(a[i], b[i]);
  }
  return c;
}

Complex divComplex(Complex x, Complex y) {
  var a = x.real;
  var b = x.imaginary;
  var c = y.real;
  var d = y.imaginary;

  var newReal = (a * c + b * d) / (c * c + d * d);
  var newImg = (b * c - a * d) / (c * c + d * d);
  return Complex(real: newReal, imaginary: newImg);
}

Complex minusComplex(Complex a) {
  final c = Complex(
    real: a.real != 0 ? -a.real : 0,
    imaginary: a.imaginary != 0 ? -a.imaginary : 0,
  );
  return c;
}

Complex mulComplex(Complex x, Complex y) {
  final a = x.real;
  final b = x.imaginary;
  final c = y.real;
  final d = y.imaginary;
  final m = Complex(real: a * c - b * d, imaginary: a * d + b * c);
  return m;
}

Complex arrayComplexProd(ArrayComplex a) {
  var prod = Complex(real: 1, imaginary: 0);
  for (var i = 0; i < a.length; i++) {
    prod = prod * a[i];
  }
  return prod;
}

List<double> polyOfRoots(ArrayComplex a) {
  var first = a[0];
  var second = a[1];
  List<double> poly = [1];

  poly.add(minusComplex(first + second).real);
  poly.add(mulComplex(first, second).real);
  return poly;
}
