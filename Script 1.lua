local HOLD_KEY   = 0x58  -- X
local PARRY_KEY  = 0x46  -- F
local TOGGLE_KEY = 0x70  -- F1
local LMB        = 0x01  -- left mouse button
local DELAY      = 0.008
local BURST      = 3

local enabled = false
local f1WasDown = false
local spamming = false

-- panel position + size
local posX, posY = 20, 300
local W, H = 180, 60

-- drag state
local dragging = false
local dragOffX, dragOffY = 0, 0

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

-- GUI
local bg = Drawing.new("Square")
bg.Size = Vector2.new(W, H)
bg.Color = Color3.fromRGB(25, 25, 25)
bg.Filled = true
bg.Transparency = 0.9
bg.Visible = false

local title = Drawing.new("Text")
title.Text = "Auto Clash"
title.Size = 18
title.Color = Color3.fromRGB(255, 255, 255)
title.Outline = true
title.Visible = false

local status = Drawing.new("Text")
status.Text = "Hold X to spam"
status.Size = 15
status.Color = Color3.fromRGB(180, 180, 180)
status.Outline = true
status.Visible = false

local function layout()
    bg.Position = Vector2.new(posX, posY)
    title.Position = Vector2.new(posX + 10, posY + 6)
    status.Position = Vector2.new(posX + 10, posY + 31)
end
layout()

local function setGui(v)
    bg.Visible = v
    title.Visible = v
    status.Visible = v
end

local function setSpamming(v)
    if v == spamming then return end
    spamming = v
    if v then
        status.Text = "SPAMMING"
        status.Color = Color3.fromRGB(80, 255, 80)
    else
        status.Text = "Hold X to spam"
        status.Color = Color3.fromRGB(180, 180, 180)
    end
end

local function updateDrag()
    if not enabled or spamming or not isrbxactive() then
        dragging = false
        return
    end

    local lmbDown = iskeypressed(LMB)
    local mx, my = mouse.X, mouse.Y

    if lmbDown then
        if not dragging then
            -- start drag only if the click began on the panel
            if mx >= posX and mx <= posX + W and my >= posY and my <= posY + H then
                dragging = true
                dragOffX = mx - posX
                dragOffY = my - posY
            end
        else
            posX = mx - dragOffX
            posY = my - dragOffY
            layout()
        end
    else
        dragging = false
    end
end

while true do
    local f1Down = iskeypressed(TOGGLE_KEY)
    if f1Down and not f1WasDown then
        enabled = not enabled
        setGui(enabled)
        if not enabled then
            setSpamming(false)
            dragging = false
        end
    end
    f1WasDown = f1Down

    if enabled and isrbxactive() and iskeypressed(HOLD_KEY) then
        setSpamming(true)
        for i = 1, BURST do
            keypress(PARRY_KEY)
            keyrelease(PARRY_KEY)
            mouse1click()
        end
    else
        setSpamming(false)
    end

    updateDrag()
    wait(DELAY)
end