local ffi = require("ffi")

local GVVideoPlayer = {}
GVVideoPlayer.__index = GVVideoPlayer

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

local function make_dds_header(width, height, dxt_type, mipmaps)
    local fourcc = { DXT1 = 0x31545844, DXT3 = 0x33545844, DXT5 = 0x35545844 }
    local blocksize = (dxt_type == "DXT1") and 8 or 16
    local mipmaps = mipmaps or 1
    local linearsize = math.max(1, math.floor((width+3)/4)) * math.max(1, math.floor((height+3)/4)) * blocksize
    local header = ffi.new("uint8_t[128]", 0)
    local function set32(offset, value)
        ffi.cast("uint32_t*", header + offset)[0] = value
    end
    set32(0,  0x20534444)
    set32(4,  124)
    set32(8,  0x00021007)
    set32(12, height)
    set32(16, width)
    set32(20, linearsize)
    set32(24, 0)
    set32(28, mipmaps)
    set32(76, 32)
    set32(80, 0x00000004)
    set32(84, fourcc[dxt_type])
    set32(88, 0)
    set32(92, 0)
    set32(96, 0)
    set32(100, 0)
    set32(104, 0)
    set32(108, 0x1000)
    set32(112, 0)
    set32(124, 0)
    return header
end

local function make_compressed_image(dxt_data, ext, width, height, mipmaps, dxt_size)
    local dds_header = make_dds_header(width, height, ext:upper(), mipmaps or 1)
    local total_size = 128 + dxt_size
    local dds_bytes = ffi.new("uint8_t[?]", total_size)
    ffi.copy(dds_bytes, dds_header, 128)
    ffi.copy(dds_bytes + 128, dxt_data, dxt_size)
    local byte_data = love.data.newByteData(ffi.string(dds_bytes, total_size))
    local fake_name = "frame." .. ext:lower()
    return love.image.newCompressedData(byte_data, fake_name)
end

function GVVideoPlayer.new(path)
    local self = setmetatable({}, GVVideoPlayer)
    self.lib = ffi.load("gv_video_decoder")
    self.decoder = self.lib.gv_video_decoder_open(path)
    assert(self.decoder, "Failed to open video file: " .. tostring(path))
    self.width = self.lib.gv_video_decoder_get_width(self.decoder)
    self.height = self.lib.gv_video_decoder_get_height(self.decoder)
    self.frame_count = self.lib.gv_video_decoder_get_frame_count(self.decoder)
    self.fps = self.lib.gv_video_decoder_get_fps(self.decoder)
    self.frame_bytes = self.lib.gv_video_decoder_get_frame_bytes(self.decoder)
    local format_id = self.lib.gv_video_decoder_get_format(self.decoder)
    self.love_format = get_love_compressed_format(format_id)
    local supported = get_supported_compressed_formats()
    assert(self.love_format ~= nil, "Format is nil")
    assert(self.love_format and supported[self.love_format], "Unsupported compressed format: " .. tostring(self.love_format))
    self.buf = ffi.new("uint8_t[?]", self.frame_bytes)
    self.frame = 0
    self.elapsed = 0
    
    -- first frame decoding
    local decoded = self.lib.gv_video_decoder_decode_frame(self.decoder, self.frame, self.buf)
    assert(decoded == self.frame_bytes, "decode failed")
    self.tex = love.graphics.newImage(make_compressed_image(self.buf, self.love_format, self.width, self.height, 1, self.frame_bytes))
    return self
end

function GVVideoPlayer:update(dt)
    self.elapsed = self.elapsed + dt
    if self.elapsed >= 1.0 / self.fps then
        self.elapsed = self.elapsed - 1.0 / self.fps
        self.frame = self.frame + 1
        if self.frame >= self.frame_count then self.frame = 0 end
        local decoded = self.lib.gv_video_decoder_decode_frame(self.decoder, self.frame, self.buf)
        if decoded == self.frame_bytes then
            self.tex = love.graphics.newImage(make_compressed_image(self.buf, self.love_format, self.width, self.height, 1, self.frame_bytes))
        end
    end
end

function GVVideoPlayer:draw(x, y, r, sx, sy)
    if self.tex then
        x = x or 0
        y = y or 0
        r = r or 0
        sx = sx or 1
        sy = sy or 1
        love.graphics.draw(self.tex, x, y, r, sx, sy)
    end
end

function GVVideoPlayer:getDimensions()
    return self.width, self.height
end

function GVVideoPlayer:getFrame()
    return self.frame
end

function GVVideoPlayer:getFrameCount()
    return self.frame_count
end

function GVVideoPlayer:getFPS()
    return self.fps
end

function GVVideoPlayer:release()
    if self.decoder then
        self.lib.gv_video_decoder_close(self.decoder)
        self.decoder = nil
    end
end

return GVVideoPlayer