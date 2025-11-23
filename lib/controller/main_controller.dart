import 'package:flutter/material.dart';
import 'package:fluttervideocompressionwithcppffmpeg/model/compressionrequest.dart';
import 'package:fluttervideocompressionwithcppffmpeg/native_ffmpeg.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:isolate';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

class MainController extends ChangeNotifier {
  String _metadata = "Pick a video to see metadata";
  String _compressStatus = "";
  String? _pickedPath;
  String? _compressedPath;
  bool _isCompressing = false;
  int _progressTimer = 0;
  final ScrollController _scrollController = ScrollController();

  // Getters
  String get metadata => _metadata;
  String get compressStatus => _compressStatus;
  String? get pickedPath => _pickedPath;
  String? get compressedPath => _compressedPath;
  bool get isCompressing => _isCompressing;
  int get progressTimer => _progressTimer;
  ScrollController get scrollController => _scrollController;

  Future<void> pickVideoAndGetMetadata() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      _pickedPath = pickedFile.path;
      final result = await getVideoMetadataString(pickedFile.path);

      _metadata = result;
      _compressStatus = "";
      notifyListeners();
    }
  }

  // Isolate'de çalışacak fonksiyon
  static void _compressionIsolate(CompressionRequest request) async {
    try {
      final beforeBytes = await File(request.inputPath).length();
      final result = await compressVideoTo(
        request.inputPath,
        request.outputPath,
      );

      int? afterBytes;
      bool success = false;
      try {
        final f = File(request.outputPath);
        if (await f.exists()) {
          afterBytes = await f.length();
          success = true;
        }
      } catch (_) {}

      request.responsePort.send(
        CompressionResult(
          result,
          beforeBytes,
          afterBytes,
          request.outputPath,
          success,
        ),
      );
    } catch (e) {
      request.responsePort.send(
        CompressionResult("Error: $e", null, null, request.outputPath, false),
      );
    }
  }

  Future<void> compressPicked() async {
    if (_pickedPath == null || _isCompressing) return;

    Stopwatch stopwatch = Stopwatch()..start();

    _isCompressing = true;
    _compressStatus = "Compression starting...";
    notifyListeners();

    final input = _pickedPath!;
    final output = input.replaceFirst(
      RegExp(r'\.(mp4|mov|mkv|avi|webm)$', caseSensitive: false),
      '.compressed.mp4',
    );

    try {
      // Isolate oluştur ve mesajlaşma kur
      final receivePort = ReceivePort();
      final isolate = await Isolate.spawn(
        _compressionIsolate,
        CompressionRequest(input, output, receivePort.sendPort),
      );

      // Sonucu bekle
      final CompressionResult result = await receivePort.first;
      isolate.kill(priority: Isolate.immediate);

      _isCompressing = false;

      if (result.success) {
        _compressedPath = output;
        final sizeLine = result.afterBytes != null
            ? 'Output size: ${_formatBytes(result.afterBytes!)} (was ${_formatBytes(result.beforeBytes!)})'
            : 'Output file not created';
        _compressStatus = '${result.result}\n$sizeLine\nPath: $output';
        _scrollToBottom();
      } else {
        _compressStatus = 'Compression failed: ${result.result}';
      }

      notifyListeners();
    } catch (e) {
      _isCompressing = false;
      _compressStatus = 'Error: $e';
      notifyListeners();
    }

    stopwatch.stop();
    print('Compression took: ${stopwatch.elapsed.inSeconds} s');
    _progressTimer = stopwatch.elapsed.inSeconds;
    notifyListeners();
  }

  String _formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (bytes == 0) ? 0 : (math.log(bytes) / math.log(1024)).floor();
    final size = bytes / math.pow(1024, i);
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> saveVideoToGallery(
    String videoPath,
    BuildContext context,
  ) async {
    try {
      Permission permission;
      PermissionStatus status;

      if (Platform.isAndroid) {
        // Android 13+ (API 33+) için videos izni, Android 12 ve altı için storage
        // Önce videos iznini kontrol et
        final videosStatus = await Permission.videos.status;
        
        if (videosStatus.isGranted || videosStatus.isLimited) {
          // Videos izni verilmiş, direkt kullan
          permission = Permission.videos;
          status = videosStatus;
        } else {
          // Videos izni verilmemiş, storage iznini kontrol et (Android 12 ve altı için)
          final storageStatus = await Permission.storage.status;
          
          if (storageStatus.isGranted) {
            // Storage izni verilmiş
            permission = Permission.storage;
            status = storageStatus;
          } else {
            // Hiçbir izin verilmemiş, Android 13+ ise videos, değilse storage iste
            // Android 13+ için videos izni kullan
            permission = Permission.videos;
            status = await permission.request();
            
            // Eğer videos izni desteklenmiyorsa (Android 12 ve altı), storage dene
            if (!status.isGranted && !status.isLimited) {
              permission = Permission.storage;
              status = await permission.request();
            }
          }
        }
      } else {
        // iOS için
        permission = Permission.photos;
        status = await permission.status;
        
        if (!status.isGranted && !status.isLimited) {
          status = await permission.request();
        }
      }

      // İzin verilmişse veya limited ise kaydet
      if (status.isGranted || status.isLimited) {
        final file = File(videoPath);
        if (await file.exists()) {
          try {
            // PhotoManager ile direkt kaydet
            await PhotoManager.editor.saveVideo(
              file, 
              title: "compressedvideo_${DateTime.now().millisecondsSinceEpoch}",
            );

            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video saved successfully'),
                  backgroundColor: Color(0xFF10B981),
                ),
              );
            }
          } catch (e) {
            print("Error saving video: $e");
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error saving video: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          print("File does not exist at path: $videoPath");
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File does not exist'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        // İzin reddedildi
        print("Permission denied: $status");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission denied. Please grant storage permission in settings.'),
              duration: Duration(seconds: 3),
            ),
          );
          // Sadece kalıcı olarak reddedildiyse ayarlara yönlendir
          if (status.isPermanentlyDenied) {
            await openAppSettings();
          }
        }
      }
    } catch (e) {
      print("Error in saveVideoToGallery: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
