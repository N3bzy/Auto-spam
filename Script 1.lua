
local HOLD_KEY   = 0x58 -- X
local PARRY_KEY  = 0x46 -- F
local TOGGLE_KEY = 0x70 -- F1
local LMB        = 0x01

local INTERVAL = 0.005
local BURST = 2

local enabled = false
local f1WasDown = false
local spamming = false
local dragging = false
local dragOffX, dragOffY = 0, 0

local posX, posY = 20, 300
local W, H = 230, 112

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

-- Matte black background
local bg = Drawing.new("Square")
bg.Size = Vector2.new(W, H)
bg.Color = Color3.fromRGB(15, 15, 15)
bg.Filled = true
bg.Transparency = 0
bg.Visible = false

-- Blue top accent
local header = Drawing.new("Square")
header.Size = Vector2.new(W, 3)
header.Color = Color3.fromRGB(75, 125, 255)
header.Filled = true
header.Transparency = 0
header.Visible = false

-- Dark gray divider
local divider = Drawing.new("Square")
divider.Size = Vector2.new(W - 24, 1)
divider.Color = Color3.fromRGB(55, 55, 55)
divider.Filled = true
divider.Transparency = 0
divider.Visible = false

-- White title
local title = Drawing.new("Text")
title.Text = "AUTO CLASH"
title.Size = 18
title.Color = Color3.fromRGB(245, 245, 245)
title.Outline = false
title.Visible = false

-- Gray subtitle
local subtitle = Drawing.new("Text")
subtitle.Text = "INPUT CONTROLLER"
subtitle.Size = 10
subtitle.Color = Color3.fromRGB(155, 155, 155)
subtitle.Outline = false
subtitle.Visible = false

-- Status dot
local dot = Drawing.new("Circle")
dot.Radius = 4
dot.Filled = true
dot.Color = Color3.fromRGB(140, 140, 140)
dot.Visible = false

-- Status text
local status = Drawing.new("Text")
status.Text = "READY  |  HOLD X"
status.Size = 13
status.Color = Color3.fromRGB(230, 230, 230)
status.Outline = false
status.Visible = false

-- CPS label
local cpsLabel = Drawing.new("Text")
cpsLabel.Text = "CLICKS / SEC"
cpsLabel.Size = 11
cpsLabel.Color = Color3.fromRGB(155, 155, 155)
cpsLabel.Outline = false
cpsLabel.Visible = false

-- CPS value
local cpsText = Drawing.new("Text")
cpsText.Text = "0 CPS"
cpsText.Size = 18
cpsText.Color = Color3.fromRGB(100, 155, 255)
cpsText.Outline = false
cpsText.Visible = false

local function layout()
    bg.Position = Vector2.new(posX, posY)
    header.Position = Vector2.new(posX, posY)
    title.Position = Vector2.new(posX + 12, posY + 9)
    subtitle.Position = Vector2.new(posX + 12, posY + 30)
    divider.Position = Vector2.new(posX + 12, posY + 49)
    dot.Position = Vector2.new(posX + 16, posY + 67)
    status.Position = Vector2.new(posX + 27, posY + 60)
    cpsLabel.Position = Vector2.new(posX + 12, posY + 83)
    cpsText.Position = Vector2.new(posX + 130, posY + 78)
end

local function setGui(v)
    bg.Visible = v
    header.Visible = v
    title.Visible = v
    subtitle.Visible = v
    divider.Visible = v
    dot.Visible = v
    status.Visible = v
    cpsLabel.Visible = v
    cpsText.Visible = v
end

local function setSpamming(v)
    if spamming == v then return end
    spamming = v

    if v then
        status.Text = "ACTIVE  |  HOLD X"
        status.Color = Color3.fromRGB(100, 225, 145)
        dot.Color = Color3.fromRGB(65, 220, 115)
        header.Color = Color3.fromRGB(65, 190, 110)
    else
        status.Text = "READY  |  HOLD X"
        status.Color = Color3.fromRGB(230, 230, 230)
        dot.Color = Color3.fromRGB(140, 140, 140)
        header.Color = Color3.fromRGB(75, 125, 255)
    end
end

local function updateDrag()
    if not enabled or spamming or not isrbxactive() then
        dragging = false
        return
    end

    local down = iskeypressed(LMB)
    local mx, my = mouse.X, mouse.Y

    if down then
        if not dragging then
            if mx >= posX and mx <= posX + W
            and my >= posY and my <= posY + H then
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

layout()

-- Rolling one-second CPS counter
local clickTimes = {}
local nextBurst = 0
local lastCpsUpdate = 0

while true do
    local now = os.clock()
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

        if now >= nextBurst then
            for i = 1, BURST do
                keypress(PARRY_KEY)
                keyrelease(PARRY_KEY)
                mouse1click()
                clickTimes[#clickTimes + 1] = os.clock()
            end

            nextBurst = now + INTERVAL
        end
    else
        setSpamming(false)
        nextBurst = 0
    end

    -- Remove clicks older than one second
    for i = #clickTimes, 1, -1 do
        if now - clickTimes[i] > 1 then
            table.remove(clickTimes, i)
        end
    end

    -- Refresh CPS display four times per second
    if now - lastCpsUpdate >= 0.25 then
        cpsText.Text = tostring(#clickTimes) .. " CPS"
        lastCpsUpdate = now
    end

    updateDrag()
    wait(0.01)
end
