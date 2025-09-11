import 'dart:isolate';

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
