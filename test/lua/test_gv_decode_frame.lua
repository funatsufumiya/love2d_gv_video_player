local lust = require 'lust'
local describe, it, expect = lust.describe, lust.it, lust.expect
local ffi = require("ffi")

ffi.cdef[[
    int gv_decode_frame(const uint8_t* input, int input_size, uint8_t* output, int output_size);
    int gv_lz4_roundtrip(const uint8_t* input, int input_size);
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

describe('gv_lz4_roundtrip', function()
    it('compresses and decompresses correctly', function()
        local input = ffi.new("uint8_t[8]", {10, 20, 30, 40, 50, 60, 70, 80})
        local ret = lib.gv_lz4_roundtrip(input, 8)
        expect(ret).to.equal(1)
    end)
    -- it('returns 0 for invalid input (NULL)', function()
    --     local ret = lib.gv_lz4_roundtrip(nil, 8)
    --     expect(ret).to.equal(0)
    -- end)
end)