import 'package:flutter/material.dart';
import 'package:foreignscan/screens/home_page.dart';
import 'utils/camera_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CameraManager.initialize();
  runApp(IndustrialInspectionApp());
}

class IndustrialInspectionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智能防异物检测系统',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Color(0xFFF5F5F5),
      ),
      home: HomePage(),
    );
  }
}
