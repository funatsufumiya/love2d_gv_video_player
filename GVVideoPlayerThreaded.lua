local ffi = require("ffi")
local love = require("love")

local GVVideoPlayerThreaded = {}
GVVideoPlayerThreaded.__index = GVVideoPlayerThreaded

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
]]

local function get_love_compressed_format(fmt)
    if fmt == 1 then return "DXT1"
    elseif fmt == 3 then return "DXT3"
    elseif fmt == 5 then return "DXT5"
    elseif fmt == 7 then return "BC7"
    else return nil end
end

-- Create a threaded player. It will spawn `threads/decoder_thread.lua` which
-- pushes compressed DDS frames into a channel. The main thread is expected
-- to drain that channel and set `player.tex` (see demo).
function GVVideoPlayerThreaded.new(path, loop, pause_on_last)
    local self = setmetatable({}, GVVideoPlayerThreaded)
    self.lib = ffi.load("gv_video_decoder")
    -- open briefly in main thread to query metadata, then close. The decoder
    -- thread will open its own instance.
    local decoder = self.lib.gv_video_decoder_open(path)
    assert(decoder, "Failed to open video file: " .. tostring(path))
    self.width = self.lib.gv_video_decoder_get_width(decoder)
    self.height = self.lib.gv_video_decoder_get_height(decoder)
    self.frame_count = self.lib.gv_video_decoder_get_frame_count(decoder)
    self.fps = self.lib.gv_video_decoder_get_fps(decoder)
    self.frame_bytes = self.lib.gv_video_decoder_get_frame_bytes(decoder)
    local format_id = self.lib.gv_video_decoder_get_format(decoder)
    self.format_id = format_id
    self.love_format = get_love_compressed_format(format_id)
    self.lib.gv_video_decoder_close(decoder)

    self.frame = 0
    self.is_playing = false
    self.is_paused = false
    self.loop = loop and true or false
    self.pause_on_last = pause_on_last and true or false
    self.tex = nil

    -- create unique channel names
    local uniq = tostring({}):gsub("%W","")
    self.channel_name = "gv_frame_" .. uniq
    self.ctrl_name = self.channel_name .. "_ctrl"
    self.fps_channel_name = self.channel_name .. "_fps"

    -- start decoder thread (inlined source to avoid a separate file)
    local thread_code = [=[
local love = require("love")
love.timer = require("love.timer")
local ffi = require("ffi")
local channel_name, path, fps, ctrl_name = ...
fps = tonumber(fps) or 30
local ch = love.thread.getChannel(channel_name)

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

local ok, err
local lib = ffi.load("gv_video_decoder")
local decoder = lib.gv_video_decoder_open(path)
if decoder == nil then
    ch:push(nil)
    return
end
local width = lib.gv_video_decoder_get_width(decoder)
local height = lib.gv_video_decoder_get_height(decoder)
local frame_count = lib.gv_video_decoder_get_frame_count(decoder)
local fps_native = lib.gv_video_decoder_get_fps(decoder)
local frame_bytes = lib.gv_video_decoder_get_frame_bytes(decoder)
local format_id = lib.gv_video_decoder_get_format(decoder)
local love_format = nil
if format_id == 1 then love_format = "DXT1"
elseif format_id == 3 then love_format = "DXT3"
elseif format_id == 5 then love_format = "DXT5"
elseif format_id == 7 then love_format = "BC7"
end

local interval = 1.0 / fps
local sleep = love.timer.sleep

local dds_header = make_dds_header(width, height, love_format, 1)
local total = 128 + frame_bytes
local out = ffi.new("uint8_t[?]", total)
ffi.copy(out, dds_header, 128)

local decode_frame = lib.gv_video_decoder_decode_frame
local ffi_string = ffi.string
local push = ch.push

local ctrl = love.thread.getChannel(ctrl_name or (channel_name .. "_ctrl"))
local active = ctrl:pop()
if active == nil then active = false end

-- FPS sampling (use elapsed + wait as actual frame period)
local fps_chan = love.thread.getChannel(channel_name .. "_fps")
local fps_buf = {}
local fps_idx = 1
local fps_sum = 0
local fps_count = 0
local fps_samples_total = 0

local frame = 0
while true do
    if active then
        local t0 = love.timer.getTime()

            local decoded = decode_frame(decoder, frame, out + 128)
            if decoded == frame_bytes then
                local s = ffi_string(out, total)
                push(ch, s)
            end

            local m = ctrl:pop()
            if m ~= nil then active = m end
            frame = frame + 1
            if frame >= frame_count then frame = 0 end

        local t1 = love.timer.getTime()
        local elapsed = t1 - t0
        local wait = interval - elapsed
        if wait > 0 then sleep(wait) end

        local period = elapsed + (wait > 0 and wait or 0)
        if period > 0 then
            local sample = 1 / period
            if fps_count < 100 then
                fps_count = fps_count + 1
                fps_buf[fps_idx] = sample
                fps_sum = fps_sum + sample
            else
                fps_sum = fps_sum - (fps_buf[fps_idx] or 0) + sample
                fps_buf[fps_idx] = sample
            end
            fps_idx = fps_idx + 1
            if fps_idx > 100 then fps_idx = 1 end
            fps_samples_total = fps_samples_total + 1
            if fps_samples_total >= 100 then
                local avg = fps_sum / fps_count
                fps_chan:push(avg)
                fps_samples_total = 0
            end
        end
    else
        active = ctrl:demand()
    end
end
]=]

    local thread = love.thread.newThread(thread_code)
    thread:start(self.channel_name, path, tostring(self.fps or 30), self.ctrl_name)
    self.thread = thread
    self.channel = love.thread.getChannel(self.channel_name)
    self.ctrl = love.thread.getChannel(self.ctrl_name)
    self.fps_channel = love.thread.getChannel(self.fps_channel_name)

    -- start paused by default; user should call :play()
    return self
end

function GVVideoPlayerThreaded:getChannel()
    return self.channel
end

function GVVideoPlayerThreaded:getCtrlChannel()
    return self.ctrl
end

function GVVideoPlayerThreaded:play()
    if not self.ctrl then return end
    self.ctrl:push(true)
    self.is_playing = true
    self.is_paused = false
end

function GVVideoPlayerThreaded:pause()
    if not self.ctrl then return end
    self.ctrl:push(false)
    if self.is_playing then self.is_paused = true end
end

function GVVideoPlayerThreaded:stop()
    if not self.ctrl then return end
    self.ctrl:push(false)
    self.is_playing = false
    self.is_paused = false
    self.frame = 0
    self.tex = nil
end

function GVVideoPlayerThreaded:setLoop(loop)
    self.loop = loop and true or false
end

function GVVideoPlayerThreaded:getLoop()
    return self.loop
end

function GVVideoPlayerThreaded:setPauseOnLast(pause_on_last)
    self.pause_on_last = pause_on_last and true or false
end

function GVVideoPlayerThreaded:getPauseOnLast()
    return self.pause_on_last
end

function GVVideoPlayerThreaded:getTexture()
    return self.tex
end

local function drain_channel_set_texture_from_self(self)
    local ch = self.channel
    if not ch then return end
    local last = nil
    while true do
        local data = ch:pop()
        if not data then break end
        last = data
    end
    if last then
        local byte_data = love.data.newByteData(last)
        local ext = self.love_format and self.love_format:lower() or "dxt"
        local comp = love.image.newCompressedData(byte_data, "frame." .. ext)
        if self.tex ~= nil then
            self.tex:release()
        end
        self.tex = love.graphics.newImage(comp)

        comp:release()
        byte_data:release()

        -- advance local frame index
        if self.frame_count and self.frame_count > 0 then
            self.frame = (self.frame + 1) % self.frame_count
            -- optionally pause on last frame if requested
            if not self.loop and self.pause_on_last and self.frame == (self.frame_count - 1) then
                self:pause()
            end
        end
    end
end

function GVVideoPlayerThreaded:update(dt)
    -- Drain any available frames from the decoder thread and update texture.
    drain_channel_set_texture_from_self(self)
end

function GVVideoPlayerThreaded:draw(x,y,r,sx,sy)
    if not self.tex then return end
    x = x or 0; y = y or 0; r = r or 0; sx = sx or 1; sy = sy or 1
    love.graphics.draw(self.tex, x, y, r, sx, sy)
end

function GVVideoPlayerThreaded:getDimensions()
    return self.width, self.height
end

function GVVideoPlayerThreaded:getFrameCount()
    return self.frame_count
end

function GVVideoPlayerThreaded:getFPS()
    return self.fps
end

function GVVideoPlayerThreaded:getFormat()
    return self.format_id, self.love_format
end

function GVVideoPlayerThreaded:getFPSChannel()
    return self.fps_channel
end

function GVVideoPlayerThreaded:release()
    -- signal decoder thread to stop decoding and clear resources
    if self.ctrl then
        pcall(function() self.ctrl:push(false) end)
    end
    self.thread = nil
    self.channel = nil
    self.ctrl = nil
    self.fps_channel = nil
    if self.tex then
        pcall(function() self.tex:release() end)
        self.tex = nil
    end
end

return GVVideoPlayerThreaded
