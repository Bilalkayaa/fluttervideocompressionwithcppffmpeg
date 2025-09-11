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
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      debugShowCheckedModeBanner: false,
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A0A), Color(0xFF1A1A2E), Color(0xFF16213E)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Consumer<MainController>(
              builder: (context, controller, child) {
                return SingleChildScrollView(
                  controller: controller.scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      _buildHeader(),
                      const SizedBox(height: 40),

                      // Pick Video Card
                      _buildPickVideoCard(controller, context),
                      const SizedBox(height: 24),

                      // Metadata Card
                      _buildMetadataCard(controller),
                      const SizedBox(height: 24),

                      // Compress Button Card
                      _buildCompressCard(controller, context),

                      // Progress Section
                      if (controller.isCompressing) _buildProgressSection(),

                      // Result Section
                      if (controller.compressStatus.isNotEmpty &&
                          !controller.isCompressing)
                        _buildResultSection(controller, context),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C5CE7).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.video_collection_outlined,
            size: 48,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          "Video Compressor",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const Text(
          "Compress your videos with ease",
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildPickVideoCard(MainController controller, BuildContext context) {
    return _buildGlassCard(
      child: Column(
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 48,
            color: controller.pickedPath != null
                ? const Color(0xFF10B981)
                : const Color(0xFF6C5CE7),
          ),
          const SizedBox(height: 16),
          _buildModernButton(
            onPressed: controller.isCompressing
                ? null
                : controller.pickVideoAndGetMetadata,
            text: controller.pickedPath != null ? "Change Video" : "Pick Video",
            icon: controller.pickedPath != null
                ? Icons.check_circle
                : Icons.add_circle_outline,
            isSuccess: controller.pickedPath != null,
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(MainController controller) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: _buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF6C5CE7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Video Information",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF374151).withOpacity(0.3),
                ),
              ),
              child: Text(
                controller.metadata,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFD1D5DB),
                  fontFamily: 'monospace',
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompressCard(MainController controller, BuildContext context) {
    return _buildGlassCard(
      child: Column(
        children: [
          Icon(
            Icons.compress,
            size: 48,
            color: controller.isCompressing
                ? const Color(0xFFF59E0B)
                : (controller.pickedPath != null
                      ? const Color(0xFF6C5CE7)
                      : const Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          _buildModernButton(
            onPressed:
                (controller.pickedPath == null || controller.isCompressing)
                ? null
                : controller.compressPicked,
            text: controller.isCompressing
                ? "Compressing..."
                : "Compress Video",
            icon: controller.isCompressing
                ? Icons.hourglass_empty
                : Icons.play_arrow,
            isLoading: controller.isCompressing,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.only(top: 24),
      child: _buildGlassCard(
        child: Column(
          children: [
            const Text(
              "Processing...",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C5CE7).withOpacity(0.2),
                    const Color(0xFFA29BFE).withOpacity(0.2),
                  ],
                ),
              ),
              child: const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6C5CE7)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection(MainController controller, BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      margin: const EdgeInsets.only(top: 24),
      child: _buildGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Compression Complete!",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats Row
            Row(
              children: [
                _buildStatChip(
                  icon: Icons.timer_outlined,
                  label: "Time",
                  value: "${controller.progressTimer}s",
                ),
                const SizedBox(width: 12),
                _buildStatChip(
                  icon: Icons.storage_outlined,
                  label: "Status",
                  value: "Done",
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Details Container
            Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF374151).withOpacity(0.3),
                ),
              ),
              child: SingleChildScrollView(
                child: Text(
                  controller.compressStatus,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFD1D5DB),
                    fontFamily: 'monospace',
                    height: 1.4,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Play Button
            Container(
              width: double.infinity,
              child: _buildModernButton(
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
                text: "Play Compressed Video",
                icon: Icons.play_circle_filled,
                isSuccess: true,
              ),
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              child: _buildModernButton(
                isSuccess: true,
                onPressed: () {},
                text: "Save",
                icon: Icons.save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildModernButton({
    required VoidCallback? onPressed,
    required String text,
    required IconData icon,
    bool isLoading = false,
    bool isSuccess = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        onPressed: onPressed,
        style:
            ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              backgroundColor: isSuccess
                  ? const Color(0xFF10B981)
                  : const Color(0xFF6C5CE7),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor:
                  (isSuccess
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6C5CE7))
                      .withOpacity(0.3),
            ).copyWith(
              elevation: MaterialStateProperty.all(onPressed != null ? 8 : 0),
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(icon, size: 20),
            const SizedBox(width: 12),
            Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF6C5CE7).withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6C5CE7)),
          const SizedBox(width: 6),
          Text(
            "$label: $value",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
