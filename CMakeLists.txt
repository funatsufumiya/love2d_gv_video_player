cmake_minimum_required(VERSION 3.10)
project(gv_video_decoder CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(gv_video_decoder SHARED
    src/gv_video_decoder.cpp
)

target_include_directories(gv_video_decoder PUBLIC src lz4/lib)

set_source_files_properties(
    lz4/lib/lz4.c
    lz4/lib/lz4hc.c
    lz4/lib/lz4frame.c
    lz4/lib/xxhash.c
    PROPERTIES LANGUAGE C
)
add_library(lz4 STATIC
    lz4/lib/lz4.c
    lz4/lib/lz4hc.c
    lz4/lib/lz4frame.c
    lz4/lib/xxhash.c
)
target_include_directories(lz4 PUBLIC lz4/lib)

target_link_libraries(gv_video_decoder PRIVATE lz4)

if (WIN32)
    set_target_properties(gv_video_decoder PROPERTIES OUTPUT_NAME "gv_video_decoder")
endif()
