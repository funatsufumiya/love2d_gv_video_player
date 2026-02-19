#!/bin/bash

cd "$(dirname "$0")"
lua_exe=${LUAJIT:-luajit}

$lua_exe test_gv_decode_frame.lua
