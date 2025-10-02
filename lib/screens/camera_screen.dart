import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../utils/camera_manager.dart';

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() {
    final camera = CameraManager.getFirstCamera();
    if (camera != null) {
      _controller = CameraController(camera, ResolutionPreset.high);
      _initializeControllerFuture = _controller!.initialize();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller!.takePicture();
      Navigator.pop(context, image.path);
    } catch (e) {
      print('拍照失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('拍照失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!CameraManager.hasCameras() || _controller == null) {
      return Scaffold(
        appBar: AppBar(title: Text('相机'), backgroundColor: Colors.black),
        body: Center(child: Text('无法访问相机')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('拍摄照片'), backgroundColor: Colors.black),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller!),
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(
                      onPressed: _takePicture,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.camera, color: Colors.black, size: 32),
                      heroTag: 'capture',
                    ),
                  ),
                ),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      backgroundColor: Colors.black,
    );
  }
}
