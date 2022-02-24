// import 'package:flutter/material.dart';
// import 'package:timer_count_down/timer_count_down.dart';

// import '../../success/success_view.dart';

// class InfoBoard extends StatelessWidget {
//   const InfoBoard({
//     Key? key,
//     required double bpm,
//     required double hrv,
//     required double si,
//     required this.maxSeconds,
//     required this.context,
//   })  : _bpm = bpm,
//         _hrv = hrv,
//         _si = si,
//         super(key: key);

//   final double _bpm;
//   final double _hrv;
//   final double _si;
//   final int maxSeconds;
//   final BuildContext context;

//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       mainAxisAlignment: MainAxisAlignment.end,
//       children: [
//         const SizedBox(
//           height: 20,
//         ),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.end,
//           children: [
//             IconButton(
//               onPressed: () {
//                 // TODO: Back to home screen
//                 print('================== Exit!');
//               },
//               icon: const Icon(
//                 Icons.exit_to_app_outlined,
//               ),
//             ),
//           ],
//         ),
//         const Spacer(),
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//           children: [
//             IndexCard(name: 'bpm', index: '${_bpm.toInt()}'),
//             IndexCard(name: 'hrv', index: '${_hrv.toInt()}'),
//             IndexCard(name: 'stress index', index: '${_si.toInt()}')
//           ],
//         ),
//         const SizedBox(
//           height: 10,
//         ),
//         Container(
//           width: 50,
//           height: 50,
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.8),
//             shape: BoxShape.circle,
//           ),
//           // child: Center(
//           //   child: Text(
//           //     seconds.toString(),
//           //     style: const TextStyle(
//           //       fontSize: 18,
//           //     ),
//           //   ),
//           // ),
//           child: Center(
//             child: Countdown(
//               seconds: maxSeconds,
//               interval: const Duration(seconds: 1),
//               build: (_, double time) {
//                 return Text(
//                   time.toInt().toString(),
//                   style: const TextStyle(fontSize: 18),
//                 );
//               },
//               onFinished: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const SuccessView(),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ),
//         const SizedBox(
//           height: 5,
//         ),
//       ],
//     );
//   }
// }

// class IndexCard extends StatelessWidget {
//   const IndexCard({
//     Key? key,
//     required this.name,
//     required this.index,
//   }) : super(key: key);

//   final String name;
//   final String index;

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 100,
//       height: 100,
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.7),
//         borderRadius: const BorderRadius.all(
//           Radius.circular(10.0),
//         ),
//       ),
//       child: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               index,
//               style: TextStyle(
//                 color: Colors.grey.shade700,
//                 fontSize: 40,
//               ),
//             ),
//             const SizedBox(height: 5),
//             Text(
//               name,
//               style: TextStyle(color: Colors.grey.shade700, fontSize: 18),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
