import 'package:flutter/material.dart';
import 'package:fluttervideocompressionwithcppffmpeg/native_ffmpeg.dart';
import 'package:fluttervideocompressionwithcppffmpeg/video_player.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:isolate';

import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// Isolate için mesaj sınıfları
class CompressionRequest {
  final String inputPath;
  final String outputPath;
  final SendPort responsePort;

  CompressionRequest(this.inputPath, this.outputPath, this.responsePort);
}

class CompressionResult {
  final String result;
  final int? beforeBytes;
  final int? afterBytes;
  final String outputPath;
  final bool success;

  CompressionResult(
    this.result,
    this.beforeBytes,
    this.afterBytes,
    this.outputPath,
    this.success,
  );
}

class _MyHomePageState extends State<MyHomePage> {
  String metadata = "Pick a video to see metadata";
  String compressStatus = "";
  String? pickedPath;
  String? compressedPath;
  bool isCompressing = false;

  int progressTimer = 0;

  void _pickVideoAntGetMetadata() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      pickedPath = pickedFile.path;
      final result = await getVideoMetadataString(pickedFile.path);
      setState(() {
        metadata = result;
        compressStatus = "";
      });
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

  void _compressPicked() async {
    print("Başladı");

    if (pickedPath == null || isCompressing) return;
    Stopwatch stopwatch = Stopwatch()..start();
    setState(() {
      isCompressing = true;

      compressStatus = "Compression starting...";
    });

    final input = pickedPath!;
    final output = input.replaceFirst(
      RegExp(r'\.(mp4|mov|mkv|avi|webm)$', caseSensitive: false),
      '.compressed.mp4',
    );

    // Progress simülasyonu için timer (gerçek progress için FFmpeg callback gerekir)

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

      setState(() {
        isCompressing = false;

        if (result.success) {
          compressedPath = output;
          final sizeLine = result.afterBytes != null
              ? 'Output size: ${_formatBytes(result.afterBytes!)} (was ${_formatBytes(result.beforeBytes!)})'
              : 'Output file not created';
          compressStatus = '${result.result}\n$sizeLine\nPath: $output';
        } else {
          compressStatus = 'Compression failed: ${result.result}';
        }
      });
    } catch (e) {
      setState(() {
        isCompressing = false;
        compressStatus = 'Error: $e';
      });
    }
    stopwatch.stop();
    print('Compression took: ${stopwatch.elapsed.inSeconds} s');
    setState(() {
      progressTimer = stopwatch.elapsed.inSeconds;
    });
  }

  String _formatBytes(int bytes, [int decimals = 2]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (bytes == 0) ? 0 : (math.log(bytes) / math.log(1024)).floor();
    final size = bytes / math.pow(1024, i);
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: isCompressing ? null : _pickVideoAntGetMetadata,
                child: Text("Pick Video"),
              ),
              SizedBox(height: 20),
              Text(metadata, style: TextStyle(fontSize: 12)),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: (pickedPath == null || isCompressing)
                    ? null
                    : _compressPicked,
                child: Text(
                  isCompressing ? "Compressing..." : "Compress Picked Video",
                ),
              ),
              if (isCompressing) ...[
                SizedBox(height: 12),

                Center(child: CircularProgressIndicator()),
              ],
              if (compressStatus.isNotEmpty && !isCompressing) ...[
                SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Text(compressStatus, style: TextStyle(fontSize: 12)),
                        Text(
                          "Progress time: $progressTimer second",
                          textAlign: TextAlign.left,
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VideoPlayerPage(videoPath: compressedPath!),
                              ),
                            );
                          },
                          child: Text("Play Compressed Video"),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
