local GVVideoPlayer = require("GVVideoPlayer")

package.path = "../../?.lua;" .. package.path

local player

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
    player = GVVideoPlayer.new(video_path)
    local w, h = player:getDimensions()
    local frames = player:getFrameCount()
    local fps = player:getFPS()
    print(string.format("%dx%d, %d frames, %.2f fps", w, h, frames, fps))
end

function love.update(dt)
    if player then player:update(dt) end
end

function love.draw()
    if player then
        local win_w, win_h = love.graphics.getDimensions()
        local w, h = player:getDimensions()
        local sx = win_w / w
        local sy = win_h / h
        player:draw(0, 0, 0, sx, sy)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 10, 10)
end

function love.quit()
    if player then player:release() end
end
