// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:vision_vox/services/tts_service.dart';

// class RaspberryPiScreen extends StatelessWidget {
//   const RaspberryPiScreen({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final cs = Theme.of(context).colorScheme;
//     final tts = Provider.of<TtsService>(context, listen: false);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Raspberry Pi'),
//         centerTitle: true,
//       ),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Raspberry Pi Connection',
//                 style: TextStyle(
//                   fontSize: 20,
//                   fontWeight: FontWeight.w700,
//                   color: cs.primary,
//                 ),
//               ),
//               const SizedBox(height: 12),
//               const Text(
//                 'Use this screen to configure and control your Raspberry Pi device. '
//                 'Add your connection logic (SSH/Bluetooth/HTTP) here.',
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton.icon(
//                 onPressed: () {
//                   tts.speak('Attempting to connect to Raspberry Pi.');
//                   // TODO: Add actual connect logic here.
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Connect logic not implemented yet')),
//                   );
//                 },
//                 icon: const Icon(Icons.link),
//                 label: const Text('Connect'),
//               ),
//               const SizedBox(height: 12),
//               ElevatedButton.icon(
//                 onPressed: () {
//                   tts.speak('Testing Raspberry Pi connection.');
//                   // TODO: Add test/ping logic here.
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text('Ping logic not implemented yet')),
//                   );
//                 },
//                 icon: const Icon(Icons.wifi_protected_setup),
//                 label: const Text('Test Connection'),
//               ),
//               const Spacer(),
//               Center(
//                 child: Text(
//                   'Add specific controls (GPIO, camera stream, etc.) here.',
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
