cmake_minimum_required(VERSION 3.22.1)

project("native_ffmpeg_flutter")


set(ffmpeg_dir ${CMAKE_SOURCE_DIR}/ffmpeg/output)
# Use ABI-specific include and lib directories
set(ffmpeg_include_dir ${ffmpeg_dir}/include/${ANDROID_ABI})
set(ffmpeg_libs_dir ${ffmpeg_dir}/lib/${ANDROID_ABI})

include_directories(${ffmpeg_include_dir})


set(ffmpeg_libs_names
    avcodec
    avdevice
    avfilter
    avformat
    avutil
    swresample
    swscale
)


foreach(lib ${ffmpeg_libs_names})
    add_library(${lib} SHARED IMPORTED)
    set_target_properties(${lib} PROPERTIES IMPORTED_LOCATION ${ffmpeg_libs_dir}/lib${lib}.so)
endforeach()


add_library(native_ffmpeg SHARED ../lib/ffi/native_ffmpeg.cpp)

find_library(
    cpp_shared_lib
    c++_shared
)


target_link_libraries(
    native_ffmpeg
    ${cpp_shared_lib}
    log
    jnigraphics
    ${ffmpeg_libs_names}
)