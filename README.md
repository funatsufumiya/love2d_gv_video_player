# LÖVE GV video player 

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