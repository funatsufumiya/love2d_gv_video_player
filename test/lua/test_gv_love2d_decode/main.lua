
local GVVideoPlayer = require("GVVideoPlayer")
package.path = "../../?.lua;" .. package.path
local player

local is_love = (_G.love ~= nil)
local is_lovr = (_G.lovr ~= nil)

local function to_abs_path(relpath)
    if is_love then
        local is_windows = package.config:sub(1,1) == "\\"
        local sep = is_windows and "\\" or "/"
        local base = love.filesystem.getSourceBaseDirectory and love.filesystem.getSourceBaseDirectory() or "."
        if relpath:match("^%a:[/\\]") or relpath:sub(1,1) == "/" or relpath:sub(1,1) == "\\" then
            return relpath
        end
        return base .. sep .. relpath
    elseif is_lovr then
        local sep = package.config:sub(1,1) == "\\" and "\\" or "/"
        local dir = lovr.filesystem.getRealDirectory and lovr.filesystem.getRealDirectory(relpath)
        if dir then
            local abs = dir .. sep .. relpath
            print("[to_abs_path][LoVR] relpath:", relpath)
            print("[to_abs_path][LoVR] getRealDirectory:", dir)
            print("[to_abs_path][LoVR] abs_path:", abs)
            local f = io.open(abs, "rb")
            print("[to_abs_path][LoVR] io.open(abs):", f and "OK" or "NG")
            if f then f:close() end
            return abs
        else
            print("[to_abs_path][LoVR] relpath:", relpath)
            print("[to_abs_path][LoVR] getRealDirectory:", dir)
            print("[to_abs_path][LoVR] abs_path:", relpath)
            local f = io.open(relpath, "rb")
            print("[to_abs_path][LoVR] io.open(relpath):", f and "OK" or "NG")
            if f then f:close() end
            return relpath
        end
    else
        return relpath
    end
end


if is_love then
    function love.load()
        local video_path = to_abs_path("../../test_assets/gv_assets_for_test/alpha-countdown-blue.gv")
        player = GVVideoPlayer.new(video_path, false, true)
        local w, h = player:getDimensions()
        local frames = player:getFrameCount()
        local fps = player:getFPS()
        print(string.format("%dx%d, %d frames, %.2f fps", w, h, frames, fps))
        player:play()
    end
elseif is_lovr then
    function lovr.load()
        local video_path = to_abs_path("../../test_assets/gv_assets_for_test/alpha-countdown-blue.gv")
        player = GVVideoPlayer.new(video_path, false, true)
        local w, h = player:getDimensions()
        local frames = player:getFrameCount()
        local fps = player:getFPS()
        print(string.format("%dx%d, %d frames, %.2f fps", w, h, frames, fps))
        player:play()
    end
end


if is_love then
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
end


if is_love then
    function love.update(dt)
        if player then player:update(dt) end
    end
elseif is_lovr then
    function lovr.update(dt)
        if player then player:update(dt) end
    end
end


if is_love then
    function love.draw()
        if player then
            local win_w, win_h = love.graphics.getDimensions()
            local w, h = player:getDimensions()
            local sx = win_w / w
            local sy = win_h / h
            player:draw(0, 0, 0, sx, sy)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 10, 10)
            love.graphics.print(string.format("Loop: %s  PauseOnLast: %s", tostring(player:getLoop()), tostring(player:getPauseOnLast())), 10, 30)
            love.graphics.print(string.format("is_playing: %s  is_paused: %s", tostring(player.is_playing), tostring(player.is_paused)), 10, 50)
        end
    end
elseif is_lovr then
    function lovr.draw(pass)
        if player and player.tex then
            -- Draw the video texture to a quad in front of the user
            local w, h = player:getDimensions()
            local scale = 2
            pass:setColor(1, 1, 1, 1)
            pass:draw(player.tex, 0, 1.5, -2, w/1000*scale, h/1000*scale, 1)
        end
    end
end


if is_love then
    function love.quit()
        if player then player:release() end
    end
elseif is_lovr then
    function lovr.quit()
        if player then player:release() end
    end
end
