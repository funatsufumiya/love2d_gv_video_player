local lust = require 'lust'
local describe, it, expect = lust.describe, lust.it, lust.expect
local ffi = require("ffi")
ffi.cdef[[
    int gv_decode_frame(const uint8_t* input, int input_size, uint8_t* output, int output_size);
]]
local lib = ffi.load("../../build/Release/gv_video_decoder.dll")

describe('gv_decode_frame', function()
    it('copies input to output', function()
        local input = ffi.new("uint8_t[4]", {1, 2, 3, 4})
        local output = ffi.new("uint8_t[4]")
        local ret = lib.gv_decode_frame(input, 4, output, 4)
        expect(ret).to.equal(4)
        for i=0,3 do
            expect(output[i]).to.equal(input[i])
        end
    end)
end)