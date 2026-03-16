import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:camera/camera.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:logger/logger.dart';
import 'package:foreignscan/core/providers/app_providers.dart';

final imageServiceProvider = Provider<ImageService>((ref) {
  return ImageService(ref.read(loggerProvider));
});

final cachedImageProvider = FutureProvider.family<File?, String>((ref, imageUrl) async {
  final imageService = ref.read(imageServiceProvider);
  return await imageService.getCachedImage(imageUrl);
});

class ImageService {
  final Logger _logger;
  
  ImageService(this._logger);

  // 压缩图片
  Future<File> compressImage(File file, {
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1080,
  }) async {
    try {
      _logger.d('开始压缩图片: ${file.path}');
      
      // 读取原图片
      final bytes = await file.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      
      if (originalImage == null) {
        throw Exception('无法解码图片');
      }

      // 计算压缩尺寸
      final originalWidth = originalImage.width;
      final originalHeight = originalImage.height;
      
      int targetWidth = originalWidth;
      int targetHeight = originalHeight;
      
      // 如果图片尺寸超过最大值，按比例缩小
      if (originalWidth > maxWidth || originalHeight > maxHeight) {
        final widthRatio = maxWidth / originalWidth;
        final heightRatio = maxHeight / originalHeight;
        final ratio = widthRatio < heightRatio ? widthRatio : heightRatio;
        
        targetWidth = (originalWidth * ratio).round();
        targetHeight = (originalHeight * ratio).round();
      }
      
      // 调整图片尺寸
      final resizedImage = img.copyResize(
        originalImage,
        width: targetWidth,
        height: targetHeight,
      );
      
      // 压缩图片
      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
      
      // 保存压缩后的图片
      final tempDir = await getTemporaryDirectory();
      final fileName = 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final compressedFile = File(path.join(tempDir.path, fileName));
      
      await compressedFile.writeAsBytes(compressedBytes);
      
      final originalSize = await file.length();
      final compressedSize = compressedBytes.length;
      final compressionRatio = (1 - compressedSize / originalSize) * 100;
      
      _logger.d('图片压缩完成: 原始大小 ${(originalSize / 1024).toStringAsFixed(2)}KB, '
          '压缩后大小 ${(compressedSize / 1024).toStringAsFixed(2)}KB, '
          '压缩率 ${compressionRatio.toStringAsFixed(1)}%');
      
      return compressedFile;
    } catch (e, stackTrace) {
      _logger.e('图片压缩失败', error: e, stackTrace: stackTrace);
      throw Exception('图片压缩失败: $e');
    }
  }

  // 压缩相机拍摄的图片
  Future<File> compressCameraImage(XFile xFile) async {
    try {
      final file = File(xFile.path);
      
      // 检查文件大小
      final fileSize = await file.length();
      if (fileSize <= 5 * 1024 * 1024) { // 5MB
        _logger.d('图片大小合适，无需压缩: ${(fileSize / 1024).toStringAsFixed(2)}KB');
        return file;
      }
      
      return await compressImage(file);
    } catch (e, stackTrace) {
      _logger.e('相机图片压缩失败', error: e, stackTrace: stackTrace);
      throw Exception('相机图片压缩失败: $e');
    }
  }

  // 获取缓存图片
  Future<File?> getCachedImage(String imageUrl) async {
    try {
      final cacheManager = DefaultCacheManager();
      final file = await cacheManager.getSingleFile(imageUrl);
      
      if (await file.exists()) {
        _logger.d('从缓存获取图片: $imageUrl');
        return file;
      }
      
      return null;
    } catch (e) {
      _logger.e('获取缓存图片失败: $imageUrl', error: e);
      return null;
    }
  }

  // 缓存网络图片
  Future<File> cacheNetworkImage(String imageUrl) async {
    try {
      final cacheManager = DefaultCacheManager();
      final file = await cacheManager.getSingleFile(imageUrl);
      
      _logger.d('缓存网络图片: $imageUrl');
      return file;
    } catch (e, stackTrace) {
      _logger.e('缓存网络图片失败: $imageUrl', error: e, stackTrace: stackTrace);
      throw Exception('缓存网络图片失败: $e');
    }
  }

  // 保存图片到应用目录
  Future<File> saveImageToAppDirectory(File imageFile, {
    required String folderName,
    String? customFileName,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final targetDir = Directory(path.join(appDir.path, folderName));
      
      // 创建目录（如果不存在）
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }
      
      // 生成文件名
      final fileName = customFileName ?? 
          '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final targetPath = path.join(targetDir.path, fileName);
      
      // 复制文件
      final savedFile = await imageFile.copy(targetPath);
      
      _logger.d('保存图片到应用目录: $targetPath');
      return savedFile;
    } catch (e, stackTrace) {
      _logger.e('保存图片失败', error: e, stackTrace: stackTrace);
      throw Exception('保存图片失败: $e');
    }
  }

  // 删除图片
  Future<void> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        _logger.d('删除图片: $imagePath');
      }
    } catch (e, stackTrace) {
      _logger.e('删除图片失败: $imagePath', error: e, stackTrace: stackTrace);
      throw Exception('删除图片失败: $e');
    }
  }

  // 批量删除图片
  Future<void> deleteImages(List<String> imagePaths) async {
    try {
      for (final imagePath in imagePaths) {
        await deleteImage(imagePath);
      }
    } catch (e, stackTrace) {
      _logger.e('批量删除图片失败', error: e, stackTrace: stackTrace);
      throw Exception('批量删除图片失败: $e');
    }
  }

  // 清理临时图片
  Future<void> clearTempImages() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFiles = tempDir.listSync();
      
      for (final file in tempFiles) {
        if (file is File) {
          final fileName = path.basename(file.path);
          if (fileName.startsWith('compressed_') || fileName.startsWith('temp_')) {
            await file.delete();
          }
        }
      }
      
      _logger.d('清理临时图片完成');
    } catch (e, stackTrace) {
      _logger.e('清理临时图片失败', error: e, stackTrace: stackTrace);
      throw Exception('清理临时图片失败: $e');
    }
  }

  // 清理缓存
  Future<void> clearCache() async {
    try {
      final cacheManager = DefaultCacheManager();
      await cacheManager.emptyCache();
      
      _logger.d('清理图片缓存完成');
    } catch (e, stackTrace) {
      _logger.e('清理图片缓存失败', error: e, stackTrace: stackTrace);
      throw Exception('清理图片缓存失败: $e');
    }
  }

  // 获取图片信息
  Future<Map<String, dynamic>> getImageInfo(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('无法解码图片');
      }
      
      final fileSize = await imageFile.length();
      
      return {
        'width': image.width,
        'height': image.height,
        'size': fileSize,
        'sizeKB': (fileSize / 1024).toStringAsFixed(2),
        'format': path.extension(imageFile.path).toLowerCase(),
      };
    } catch (e, stackTrace) {
      _logger.e('获取图片信息失败', error: e, stackTrace: stackTrace);
      throw Exception('获取图片信息失败: $e');
    }
  }

  // 验证图片文件
  Future<bool> validateImageFile(File imageFile) async {
    try {
      // 检查文件是否存在
      if (!await imageFile.exists()) {
        _logger.e('图片文件不存在: ${imageFile.path}');
        return false;
      }
      
      // 检查文件大小
      final fileSize = await imageFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        _logger.e('图片文件过大: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');
        return false;
      }
      
      // 检查文件格式
      final extension = path.extension(imageFile.path).toLowerCase();
      if (!['jpg', 'jpeg', 'png'].contains(extension.substring(1))) {
        _logger.e('不支持的图片格式: $extension');
        return false;
      }
      
      // 尝试解码图片
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        _logger.e('无法解码图片文件: ${imageFile.path}');
        return false;
      }
      
      _logger.d('图片文件验证通过: ${imageFile.path}');
      return true;
    } catch (e) {
      _logger.e('图片文件验证失败: ${imageFile.path}', error: e);
      return false;
    }
  }

  // 创建图片缩略图
  Future<File> createThumbnail(File imageFile, {
    int maxWidth = 200,
    int maxHeight = 200,
    int quality = 80,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('无法解码图片');
      }
      
      // 计算缩略图尺寸
      final aspectRatio = image.width / image.height;
      int targetWidth = maxWidth;
      int targetHeight = (maxWidth / aspectRatio).round();
      
      if (targetHeight > maxHeight) {
        targetHeight = maxHeight;
        targetWidth = (maxHeight * aspectRatio).round();
      }
      
      // 创建缩略图
      final thumbnail = img.copyResize(
        image,
        width: targetWidth,
        height: targetHeight,
      );
      
      final thumbnailBytes = img.encodeJpg(thumbnail, quality: quality);
      
      // 保存缩略图
      final tempDir = await getTemporaryDirectory();
      final fileName = 'thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final thumbnailFile = File(path.join(tempDir.path, fileName));
      
      await thumbnailFile.writeAsBytes(thumbnailBytes);
      
      _logger.d('创建缩略图完成: ${thumbnailFile.path}');
      return thumbnailFile;
    } catch (e, stackTrace) {
      _logger.e('创建缩略图失败', error: e, stackTrace: stackTrace);
      throw Exception('创建缩略图失败: $e');
    }
  }
}