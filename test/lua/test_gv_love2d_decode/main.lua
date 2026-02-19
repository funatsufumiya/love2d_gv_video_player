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

local function normalize_path(path, sep)
    local t = {}
    local drive = path:match("^([A-Za-z]:)")
    local start = drive and #drive + 1 or 1
    if path:sub(start, start) == sep then start = start + 1 end
    for part in path:sub(start):gmatch("[^/\\]+") do
        if part == ".." then
            if #t > 0 then table.remove(t) end
        elseif part ~= "." and part ~= "" then
            table.insert(t, part)
        end
    end
    return (drive and drive .. sep or sep) .. table.concat(t, sep)
end

local function to_abs_path(relpath)
    local is_windows = package.config:sub(1,1) == "\\"
    local sep = is_windows and "\\" or "/"
    local base = love.filesystem.getSourceBaseDirectory and love.filesystem.getSourceBaseDirectory() or "."
    if relpath:match("^%a:[/\\]") or relpath:sub(1,1) == "/" or relpath:sub(1,1) == "\\" then
        return normalize_path(relpath, sep)
    end
    local path = base .. sep .. relpath
    path = normalize_path(path, sep)
    return path
end

local function file_exists(path)
    local f = io.open(path, "rb")
    if f then f:close() return true end
    return false
end

local function get_love_compressed_format(fmt)
    -- C++側 enum GPU_COMPRESS: DXT1=1, DXT3=3, DXT5=5, BC7=7
    if fmt == 1 then return "dxt1"
    elseif fmt == 3 then return "dxt3"
    elseif fmt == 5 then return "dxt5"
    elseif fmt == 7 then return "bc7"
    else return nil end
end

local function get_supported_compressed_formats()
    local t = {}
    for k, v in pairs(love.graphics.getCompressedImageFormats()) do
        if v then t[k] = true end
    end
    return t
end

local function make_compressed_image(byte_data, ext)
    -- ext: "dxt1", "dxt3", "dxt5", "bc7"
    local fake_name = "frame." .. ext
    return love.image.newCompressedData(byte_data, fake_name)
end

function love.load()
    lib = ffi.load("gv_video_decoder")
    local video_path = to_abs_path("../../test_assets/gv_assets_for_test/alpha-countdown.gv")
    assert(file_exists(video_path), "Video file not found: " .. video_path)
    decoder = lib.gv_video_decoder_open(video_path)
    assert(decoder, "Failed to open video file: " .. video_path)
    width = lib.gv_video_decoder_get_width(decoder)
    height = lib.gv_video_decoder_get_height(decoder)
    frame_count = lib.gv_video_decoder_get_frame_count(decoder)
    fps = lib.gv_video_decoder_get_fps(decoder)
    frame_bytes = lib.gv_video_decoder_get_frame_bytes(decoder)
    local format_id = lib.gv_video_decoder_get_format(decoder)
    local love_format = get_love_compressed_format(format_id)
    local supported = get_supported_compressed_formats()
    assert(love_format and supported[love_format], "Unsupported compressed format: " .. tostring(format_id))
    print(string.format("%dx%d, %d frames, %.2f fps, format: %s", width, height, frame_count, fps, love_format))
    buf = ffi.new("uint8_t[?]", frame_bytes)
    frame = 0
    local decoded = lib.gv_video_decoder_decode_frame(decoder, frame, buf)
    assert(decoded == frame_bytes, "decode failed")
    local compressed_data = love.data.newByteData(ffi.string(buf, frame_bytes))
    local image_data = make_compressed_image(compressed_data, love_format)
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
            local compressed_data = love.data.newByteData(ffi.string(buf, frame_bytes))
            local image_data = make_compressed_image(compressed_data, love_format)
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
