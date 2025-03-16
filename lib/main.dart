import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const FotoPhrameApp());
}

class FotoPhrameApp extends StatelessWidget {
  const FotoPhrameApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Photo Frame',
      theme: ThemeData(primarySwatch: Colors.blue, brightness: Brightness.dark),
      home: const SetupScreen(),
    );
  }
}
