# LÖVE GV video player 

[gv-video](https://github.com/Ushio/ofxExtremeGpuVideo#binary-file-format-gv) player for LÖVE (Love2D)

## Demo

```bash
$ love --console test/lua/test_gv_love2d_decode/
```

## Build dynamic library

```bash
$ cmake -B build
$ cmake --build build --parallel 8 -j 8 --config Release
$ cp build\Release\gv_video_decoder.dll .
```