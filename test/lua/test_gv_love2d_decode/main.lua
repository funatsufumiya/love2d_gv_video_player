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
    if fmt == 1 then return "DXT1"
    elseif fmt == 3 then return "DXT3"
    elseif fmt == 5 then return "DXT5"
    elseif fmt == 7 then return "BC7"
    else return nil end
end

local function get_supported_compressed_formats()
    local t = {}
    for k, v in pairs(love.graphics.getImageFormats()) do
        if v then t[k] = true end
    end
    return t
end

local function print_supported_compressed_formats()
    local t = {}
    for k, v in pairs(love.graphics.getImageFormats()) do
        if v then
            print("O: " .. k)
        else
            print("X: " .. k)
        end
    end
    return t
end


local function make_dds_header(width, height, dxt_type, mipmaps)
    -- dxt_type: "DXT1", "DXT3", "DXT5"
    local fourcc = { DXT1 = 0x31545844, DXT3 = 0x33545844, DXT5 = 0x35545844 }
    local blocksize = (dxt_type == "DXT1") and 8 or 16
    local mipmaps = mipmaps or 1
    local linearsize = math.max(1, math.floor((width+3)/4)) * math.max(1, math.floor((height+3)/4)) * blocksize

    local header = ffi.new("uint8_t[128]", 0)
    local function set32(offset, value)
        ffi.cast("uint32_t*", header + offset)[0] = value
    end

    set32(0,  0x20534444)      -- dwMagic "DDS "
    set32(4,  124)             -- dwSize
    set32(8,  0x00021007)      -- dwFlags (DDSD_CAPS|DDSD_HEIGHT|DDSD_WIDTH|DDSD_PIXELFORMAT|DDSD_LINEARSIZE)
    set32(12, height)          -- dwHeight
    set32(16, width)           -- dwWidth
    set32(20, linearsize)      -- dwPitchOrLinearSize
    set32(24, 0)               -- dwDepth
    set32(28, mipmaps)         -- dwMipMapCount
    -- dwReserved1[11] = 0
    set32(76, 32)              -- dwPfSize
    set32(80, 0x00000004)      -- dwPfFlags (DDPF_FOURCC)
    set32(84, fourcc[dxt_type])-- dwFourCC
    set32(88, 0)               -- dwRGBBitCount
    set32(92, 0)               -- dwRBitMask
    set32(96, 0)               -- dwGBitMask
    set32(100, 0)              -- dwBBitMask
    set32(104, 0)              -- dwRGBAlphaBitMask
    set32(108, 0x1000)         -- dwCaps (DDSCAPS_TEXTURE)
    set32(112, 0)              -- dwCaps2
    -- dwReservedCaps[2] = 0
    set32(124, 0)              -- dwReserved2

    return header
end

local function make_compressed_image(dxt_data, ext, width, height, mipmaps, dxt_size)
    -- ext: "DXT1", "DXT3", "DXT5"
    -- dxt_size: DXTデータのバイト数
    -- print(ext)
    local dds_header = make_dds_header(width, height, ext:upper(), mipmaps or 1)
    local total_size = 128 + dxt_size
    local dds_bytes = ffi.new("uint8_t[?]", total_size)
    ffi.copy(dds_bytes, dds_header, 128)
    ffi.copy(dds_bytes + 128, dxt_data, dxt_size)
    local byte_data = love.data.newByteData(ffi.string(dds_bytes, total_size))
    local fake_name = "frame." .. ext:lower()
    return love.image.newCompressedData(byte_data, fake_name)
end

function love.load()
    lib = ffi.load("gv_video_decoder")
    local video_path = to_abs_path("../../test_assets/gv_assets_for_test/alpha-countdown-blue.gv")
    assert(file_exists(video_path), "Video file not found: " .. video_path)
    decoder = lib.gv_video_decoder_open(video_path)
    assert(decoder, "Failed to open video file: " .. video_path)
    width = lib.gv_video_decoder_get_width(decoder)
    height = lib.gv_video_decoder_get_height(decoder)
    frame_count = lib.gv_video_decoder_get_frame_count(decoder)
    fps = lib.gv_video_decoder_get_fps(decoder)
    frame_bytes = lib.gv_video_decoder_get_frame_bytes(decoder)
    
    local format_id = lib.gv_video_decoder_get_format(decoder)
    love_format = get_love_compressed_format(format_id)
    -- print_supported_compressed_formats()
    local supported = get_supported_compressed_formats()
    assert(love_format ~= nil, "Format is nil")
    assert(love_format and supported[love_format], "Unsupported compressed format: " .. tostring(love_format))
    
    print(string.format("%dx%d, %d frames, %.2f fps, format: %s", width, height, frame_count, fps, love_format))
    buf = ffi.new("uint8_t[?]", frame_bytes)
    frame = 0
    local decoded = lib.gv_video_decoder_decode_frame(decoder, frame, buf)
    assert(decoded == frame_bytes, "decode failed")
    -- bufはDXT圧縮データの生バッファ
    local image_data = make_compressed_image(buf, love_format, width, height, 1, frame_bytes)
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
            local image_data = make_compressed_image(buf, love_format, width, height, 1, frame_bytes)
            tex = love.graphics.newImage(image_data)
        end
    end
end

function love.draw()
    if tex then
        local win_w, win_h = love.graphics.getDimensions()
        local sx = win_w / width
        local sy = win_h / height
        love.graphics.draw(tex, 0, 0, 0, sx, sy)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 10, 10)
end

function love.quit()
    if decoder then lib.gv_video_decoder_close(decoder) end
end
