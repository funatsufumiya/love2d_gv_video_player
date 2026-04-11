local GVVideoPlayerThreaded = require("GVVideoPlayerThreaded")

package.path = "../../?.lua;" .. package.path

local player
local ch
local fps_ch
local decoded_fps = nil

local function to_abs_path(relpath)
    local is_windows = package.config:sub(1,1) == "\\"
    local sep = is_windows and "\\" or "/"
    local base = love.filesystem.getSourceBaseDirectory and love.filesystem.getSourceBaseDirectory() or "."
    if relpath:match("^%a:[/\\]") or relpath:sub(1,1) == "/" or relpath:sub(1,1) == "\\" then
        return relpath
    end
    return base .. sep .. relpath
end

function love.load()
    local video_path = to_abs_path("../../test_assets/gv_assets_for_test/alpha-countdown-blue.gv")
    player = GVVideoPlayerThreaded.new(video_path, true, true)
    ch = player:getChannel()
    fps_ch = player:getFPSChannel()
    local w, h = player:getDimensions()
    local frames = player:getFrameCount()
    local fps = player:getFPS()
    print(string.format("%dx%d, %d frames, %.2f fps", w, h, frames, fps))
    player:play()
end

function love.keypressed(key)
    if not player then return end
    if key == "space" then
        if player.is_playing and not player.is_paused then
            player:pause()
        else
            player:play()
        end
    elseif key == "l" then
        player:setLoop(not player:getLoop())
        print("Loop:", player:getLoop())
    elseif key == "p" then
        player:setPauseOnLast(not player:getPauseOnLast())
        print("PauseOnLast:", player:getPauseOnLast())
    end
end

function love.update(dt)
    if player then
        player:update(dt)
        if fps_ch then
            local v = fps_ch:pop()
            if v then decoded_fps = v end
        end
    end
end

function love.draw()
    if player then
        -- texture updated in player:update(dt)
        local win_w, win_h = love.graphics.getDimensions()
        local w, h = player:getDimensions()
        local sx = win_w / w
        local sy = win_h / h
        player:draw(0, 0, 0, sx, sy)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 10, 10)
        love.graphics.print(string.format("Decoder FPS: %s", decoded_fps and string.format("%.2f", decoded_fps) or "-"), 10, 28)
        love.graphics.print(string.format("Loop: %s  PauseOnLast: %s", tostring(player:getLoop()), tostring(player:getPauseOnLast())), 10, 46)
        love.graphics.print(string.format("is_playing: %s  is_paused: %s", tostring(player.is_playing), tostring(player.is_paused)), 10, 64)
    end
end

function love.quit()
    if player then player:release() end
end
