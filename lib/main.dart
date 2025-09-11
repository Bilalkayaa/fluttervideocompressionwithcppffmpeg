import 'package:flutter/material.dart';
import 'package:fluttervideocompressionwithcppffmpeg/controller/main_controller.dart';
import 'package:fluttervideocompressionwithcppffmpeg/video_player.dart';

import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Compression App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: ChangeNotifierProvider(
        create: (context) => MainController(),
        child: const MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Consumer<MainController>(
            builder: (context, controller, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: controller.isCompressing
                        ? null
                        : controller.pickVideoAndGetMetadata,
                    child: const Text("Pick Video"),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    controller.metadata,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed:
                        (controller.pickedPath == null ||
                            controller.isCompressing)
                        ? null
                        : controller.compressPicked,
                    child: Text(
                      controller.isCompressing
                          ? "Compressing..."
                          : "Compress Picked Video",
                    ),
                  ),
                  if (controller.isCompressing) ...[
                    const SizedBox(height: 12),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (controller.compressStatus.isNotEmpty &&
                      !controller.isCompressing) ...[
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Text(
                              controller.compressStatus,
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              "Progress time: ${controller.progressTimer} second",
                              textAlign: TextAlign.left,
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VideoPlayerPage(
                                      videoPath: controller.compressedPath!,
                                    ),
                                  ),
                                );
                              },
                              child: const Text("Play Compressed Video"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
