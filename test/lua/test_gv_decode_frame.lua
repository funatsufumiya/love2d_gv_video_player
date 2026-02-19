local ffi = require("ffi")
ffi.cdef[[
    int gv_decode_frame(const uint8_t* input, int input_size, uint8_t* output, int output_size);
]]

local lib = ffi.load("../../build/Release/gv_video_decoder.dll")

local input = ffi.new("uint8_t[4]", {1, 2, 3, 4})
local output = ffi.new("uint8_t[4]")
local ret = lib.gv_decode_frame(input, 4, output, 4)

local ok = (ret == 4)
for i=0,3 do
    ok = ok and (input[i] == output[i])
end

if ok then
    print("test_gv_decode_frame: PASS")
    os.exit(0)
else
    print("test_gv_decode_frame: FAIL")
    os.exit(1)
end
