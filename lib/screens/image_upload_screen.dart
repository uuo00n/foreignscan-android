import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foreignscan/core/services/wifi_communication_service.dart';
import 'package:foreignscan/core/providers/app_providers.dart';
import 'package:camera/camera.dart';
import 'package:foreignscan/core/providers/camera_providers.dart' as camera_providers;

class ImageUploadScreen extends ConsumerStatefulWidget {
  final String? imagePath;
  
  const ImageUploadScreen({super.key, this.imagePath});

  @override
  ConsumerState<ImageUploadScreen> createState() => _ImageUploadScreenState();
}

class _ImageUploadScreenState extends ConsumerState<ImageUploadScreen> {
  final TextEditingController _serverIpController = TextEditingController(text: '192.168.1.100');
  final TextEditingController _portController = TextEditingController(text: '8080');
  bool _isUploading = false;
  String? _uploadStatus;
  String? _uploadedImageUrl;
  
  @override
  void initState() {
    super.initState();
    _checkWifiInfo();
  }
  
  @override
  void dispose() {
    _serverIpController.dispose();
    _portController.dispose();
    super.dispose();
  }
  
  Future<void> _checkWifiInfo() async {
    final wifiService = WiFiCommunicationService(ref.read(loggerProvider));
    final wifiInfo = await wifiService.getWiFiInfo();
    
    if (wifiInfo != null) {
      setState(() {
        _uploadStatus = '已连接到WiFi: ${wifiInfo['ssid'] ?? '未知'}';
      });
    } else {
      setState(() {
        _uploadStatus = '未连接到WiFi或无法获取WiFi信息';
      });
    }
  }
  
  Future<void> _uploadImage() async {
    if (widget.imagePath == null) {
      setState(() {
        _uploadStatus = '没有可上传的图片';
      });
      return;
    }
    
    setState(() {
      _isUploading = true;
      _uploadStatus = '正在上传图片...';
    });
    
    try {
      final wifiService = WiFiCommunicationService(ref.read(loggerProvider));
      wifiService.setServerAddress(
        _serverIpController.text, 
        int.tryParse(_portController.text) ?? 8080
      );
      
      final result = await wifiService.uploadImageFromCamera(widget.imagePath!);
      
      if (result != null && result['success'] == true) {
        setState(() {
          _isUploading = false;
          _uploadStatus = '图片上传成功!';
          _uploadedImageUrl = result['data']['url'];
        });
      } else {
        setState(() {
          _isUploading = false;
          _uploadStatus = '图片上传失败';
        });
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadStatus = '上传出错: $e';
      });
    }
  }
  
  Future<void> _takePicture() async {
    final cameraController = ref.read(camera_providers.cameraControllerProvider.notifier);
    try {
      final imagePath = await cameraController.takePicture();
      if (imagePath != null) {
        if (!mounted) return;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ImageUploadScreen(imagePath: imagePath),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍照失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图片上传'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // WiFi状态
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('WiFi状态', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_uploadStatus ?? '正在检查WiFi连接...'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _checkWifiInfo,
                      child: const Text('刷新WiFi状态'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 服务器设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('服务器设置', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serverIpController,
                      decoration: const InputDecoration(
                        labelText: '服务器IP地址',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: '端口',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 图片预览
            if (widget.imagePath != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('图片预览', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.file(
                          File(widget.imagePath!),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('没有图片', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: _takePicture,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('拍摄照片'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // 上传按钮
            if (widget.imagePath != null)
              ElevatedButton(
                onPressed: _isUploading ? null : _uploadImage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isUploading
                    ? const CircularProgressIndicator()
                    : const Text('上传图片到服务器'),
              ),
            
            const SizedBox(height: 16),
            
            // 上传结果
            if (_uploadedImageUrl != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('上传成功', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 8),
                      Text('图片URL: $_uploadedImageUrl'),
                      const SizedBox(height: 16),
                      const Text('在同一局域网内的设备可以通过此URL访问图片'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}