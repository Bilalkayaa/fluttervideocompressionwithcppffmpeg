import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef GetVideoMetadataNative = Pointer<Utf8> Function(Pointer<Utf8> path);
typedef GetVideoMetadata = Pointer<Utf8> Function(Pointer<Utf8> path);

typedef CompressVideoNative =
    Pointer<Utf8> Function(Pointer<Utf8> inputPath, Pointer<Utf8> outputPath);
typedef CompressVideo =
    Pointer<Utf8> Function(Pointer<Utf8> inputPath, Pointer<Utf8> outputPath);

typedef FreeCStringNative = Void Function(Pointer<Utf8> str);
typedef FreeCString = void Function(Pointer<Utf8> str);

final DynamicLibrary ffmpegLib = Platform.isAndroid
    ? DynamicLibrary.open("libnative_ffmpeg.so")
    : DynamicLibrary.process();

final GetVideoMetadata getVideoMetadata = ffmpegLib
    .lookup<NativeFunction<GetVideoMetadataNative>>('get_video_metadata')
    .asFunction();

final CompressVideo compressVideo = ffmpegLib
    .lookup<NativeFunction<CompressVideoNative>>('compress_video')
    .asFunction();

final FreeCString freeCString = ffmpegLib
    .lookup<NativeFunction<FreeCStringNative>>('free_cstring')
    .asFunction();

Future<String> getVideoMetadataString(String path) async {
  final pathPtr = path.toNativeUtf8();
  try {
    final resPtr = getVideoMetadata(pathPtr);
    final result = resPtr.toDartString();
    freeCString(resPtr);
    return result;
  } finally {
    calloc.free(pathPtr);
  }
}

Future<String> compressVideoTo(String inputPath, String outputPath) async {
  final inPtr = inputPath.toNativeUtf8();
  final outPtr = outputPath.toNativeUtf8();
  try {
    final resPtr = compressVideo(inPtr, outPtr);
    final result = resPtr.toDartString();
    freeCString(resPtr);
    return result;
  } finally {
    calloc.free(inPtr);
    calloc.free(outPtr);
  }
}
