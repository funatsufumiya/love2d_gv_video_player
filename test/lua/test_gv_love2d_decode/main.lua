local ffi = require("ffi")
local lib
local decoder
local width, height, frame_count, fps, frame_bytes
local frame = 0
local buf, tex
local elapsed = 0

ffi.cdef[[
    struct gv_video_decoder;
    struct gv_video_decoder* gv_video_decoder_open(const char* path);
    void gv_video_decoder_close(struct gv_video_decoder* decoder);
    uint32_t gv_video_decoder_get_width(struct gv_video_decoder* decoder);
    uint32_t gv_video_decoder_get_height(struct gv_video_decoder* decoder);
    uint32_t gv_video_decoder_get_frame_count(struct gv_video_decoder* decoder);
    float    gv_video_decoder_get_fps(struct gv_video_decoder* decoder);
    uint32_t gv_video_decoder_get_format(struct gv_video_decoder* decoder);
    uint32_t gv_video_decoder_get_frame_bytes(struct gv_video_decoder* decoder);
    uint32_t gv_video_decoder_decode_frame(struct gv_video_decoder* decoder, uint32_t frame, void* out_buf);
]]

function script_path()
   local str = debug.getinfo(2, "S").source:sub(2)
   return str:match("(.*/)") or "./"
end

function love.load()
    lib = ffi.load(script_path() .. "../../../build/Release/gv_video_decoder.dll")
    local video_path = script_path() .. "../../../test_assets/gv_assets_for_test/alpha-countdown.gv"
    decoder = lib.gv_video_decoder_open(video_path)
    assert(decoder, "Failed to open video file")
    width = lib.gv_video_decoder_get_width(decoder)
    height = lib.gv_video_decoder_get_height(decoder)
    frame_count = lib.gv_video_decoder_get_frame_count(decoder)
    fps = lib.gv_video_decoder_get_fps(decoder)
    frame_bytes = lib.gv_video_decoder_get_frame_bytes(decoder)
    print(string.format("%dx%d, %d frames, %.2f fps", width, height, frame_count, fps))
    buf = ffi.new("uint8_t[?]", frame_bytes)
    frame = 0
    local decoded = lib.gv_video_decoder_decode_frame(decoder, frame, buf)
    assert(decoded == frame_bytes, "decode failed")
    local compressed_data = love.data.newData(ffi.string(buf, frame_bytes))
    local image_data = love.image.newCompressedData(compressed_data)
    tex = love.graphics.newImage(image_data)
    elapsed = 0
end

function love.update(dt)
    elapsed = elapsed + dt
    if elapsed >= 1.0 / fps then
        elapsed = elapsed - 1.0 / fps
        frame = frame + 1
        if frame >= frame_count then frame = 0 end
        local decoded = lib.gv_video_decoder_decode_frame(decoder, frame, buf)
        if decoded == frame_bytes then
            local compressed_data = love.data.newData(ffi.string(buf, frame_bytes))
            local image_data = love.image.newCompressedData(compressed_data)
            tex = love.graphics.newImage(image_data)
        end
    end
end

function love.draw()
    if tex then
        love.graphics.draw(tex, 0, 0)
    end
end

function love.quit()
    if decoder then lib.gv_video_decoder_close(decoder) end
end
