local env = (getgenv and getgenv()) or _G

-- Kill any leftover copy from a previous execution
if env.__AUTOCLASH_UNLOAD then
    pcall(env.__AUTOCLASH_UNLOAD)
    wait(0.2)
end

local HOLD_KEY    = 0x58 -- X (parry spam)
local PARRY_KEY   = 0x46 -- F
local TOGGLE_KEY  = 0x70 -- F1 (show/hide GUI)
local REBIND_KEY  = 0x71 -- F2 (change trigger keybind)
local UNLOAD_KEY  = 0x72 -- F3 (unload script)
local TRIGGER_KEY = 0x06 --  MB5 (default trigger key, changeable in-game with F2)
local LMB         = 0x01

local INTERVAL = 0.005
local BURST = 2

local TRIGGER_COOLDOWN = 0.1 -- minimum seconds between trigger parries

local running = true
local guiVisible = true
local f1WasDown = false
local f2WasDown = false
local f3WasDown = false
local lmbWasDown = false
local spamming = false
local triggering = false
local listening = false
local dragging = false
local dragOffX, dragOffY = 0, 0

local posX, posY = 20, 300
local W, H = 230, 160

local BTN_H = 20

local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

-- Re-grab player/mouse so rejoining doesn't leave stale references
local function refreshPlayer()
    local lp = game.Players.LocalPlayer
    if lp and (lp ~= player or not mouse) then
        player = lp
        mouse = player:GetMouse()
    end
end

-- Key name lookup for the GUI
local function keyName(k)
    if k >= 0x41 and k <= 0x5A then return string.char(k) end
    if k >= 0x30 and k <= 0x39 then return string.char(k) end
    if k >= 0x70 and k <= 0x7B then return "F" .. (k - 0x6F) end
    local names = {
        [0x20] = "SPACE", [0x09] = "TAB", [0x10] = "SHIFT", [0x11] = "CTRL",
        [0x12] = "ALT", [0x14] = "CAPS", [0x0D] = "ENTER", [0x08] = "BACK",
        [0x02] = "RMB", [0x04] = "MMB", [0x05] = "MB4", [0x06] = "MB5",
        [0xC0] = "TILDE", [0xBC] = ",", [0xBE] = ".", [0xBF] = "/",
        [0xBA] = ";", [0xDE] = "'", [0xDB] = "[", [0xDD] = "]",
    }
    return names[k] or string.format("0x%02X", k)
end

-- Matte black background
local bg = Drawing.new("Square")
bg.Size = Vector2.new(W, H)
bg.Color = Color3.fromRGB(15, 15, 15)
bg.Filled = true
bg.Transparency = 1
bg.Visible = false

-- Blue top accent
local header = Drawing.new("Square")
header.Size = Vector2.new(W, 3)
header.Color = Color3.fromRGB(75, 125, 255)
header.Filled = true
header.Transparency = 1
header.Visible = false

-- Dark gray divider
local divider = Drawing.new("Square")
divider.Size = Vector2.new(W - 24, 1)
divider.Color = Color3.fromRGB(55, 55, 55)
divider.Filled = true
divider.Transparency = 1
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

-- Trigger status
local trigText = Drawing.new("Text")
trigText.Size = 11
trigText.Color = Color3.fromRGB(155, 155, 155)
trigText.Outline = false
trigText.Visible = false

-- Unload button
local btn = Drawing.new("Square")
btn.Size = Vector2.new(W - 24, BTN_H)
btn.Color = Color3.fromRGB(150, 45, 45)
btn.Filled = true
btn.Transparency = 1
btn.Visible = false

local btnText = Drawing.new("Text")
btnText.Text = "UNLOAD  [F3]"
btnText.Size = 12
btnText.Color = Color3.fromRGB(245, 245, 245)
btnText.Outline = false
btnText.Visible = false

local allDrawings = {
    bg, header, divider, title, subtitle, dot, status,
    cpsLabel, cpsText, trigText, btn, btnText,
}

local function refreshTrigText()
    if listening then
        trigText.Text = "PRESS A KEY...  (ESC cancel)"
        trigText.Color = Color3.fromRGB(255, 200, 80)
    elseif triggering then
        trigText.Text = "TRIGGER  |  ARMED  [" .. keyName(TRIGGER_KEY) .. "]"
        trigText.Color = Color3.fromRGB(100, 225, 145)
    else
        trigText.Text = "TRIGGER  |  HOLD " .. keyName(TRIGGER_KEY) .. "  (F2 rebind)"
        trigText.Color = Color3.fromRGB(155, 155, 155)
    end
end

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
    trigText.Position = Vector2.new(posX + 12, posY + 107)
    btn.Position = Vector2.new(posX + 12, posY + 130)
    btnText.Position = Vector2.new(posX + 70, posY + 134)
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
    trigText.Visible = v
    btn.Visible = v
    btnText.Visible = v
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

local function setTriggering(v)
    if triggering == v then return end
    triggering = v
    refreshTrigText()
end

local function unload()
    running = false
end

-- Lets a future execution shut this copy down
env.__AUTOCLASH_UNLOAD = unload

local function updateDrag()
    if not guiVisible or spamming or not isrbxactive() then
        dragging = false
        lmbWasDown = iskeypressed(LMB)
        return
    end

    local down = iskeypressed(LMB)
    local justPressed = down and not lmbWasDown
    lmbWasDown = down
    local mx, my = mouse.X, mouse.Y

    if down then
        if not dragging then
            if justPressed then
                -- Unload button click
                if mx >= posX + 12 and mx <= posX + W - 12
                and my >= posY + 130 and my <= posY + 130 + BTN_H then
                    unload()
                    return
                end
            end

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

-- ===== Triggerbot (exactly one parry per time the ball targets you) =====

local lastFire = 0
local armed = true -- false after a parry, true again only once the target leaves you

local function getBall()
    local folder = game:GetService("Workspace"):FindFirstChild("Balls")
    if not folder then return nil end

    for _, b in ipairs(folder:GetChildren()) do
        if b:GetAttribute("realBall") ~= false then
            return b
        end
    end
    return nil
end

-- Runs every loop. Returns true if the ball is on you.
-- Re-arms the trigger whenever the ball is NOT on you.
local function updateTarget()
    local ball = getBall()
    if not ball or ball:GetAttribute("target") ~= player.Name then
        armed = true
        return false
    end
    return true
end

-- Wait for the next key/mouse button press and set it as the trigger key
-- Mouse buttons: 0x02 RMB, 0x04 MMB, 0x05 MB4, 0x06 MB5 (LMB excluded so GUI clicks don't bind)
local function pollRebind()
    if iskeypressed(0x1B) then -- ESC cancels
        listening = false
        refreshTrigText()
        return
    end

    for k = 0x02, 0xFE do
        if k ~= 0x01 and k ~= 0x03 and k ~= 0x07
        and k ~= REBIND_KEY and k ~= TOGGLE_KEY and k ~= UNLOAD_KEY and k ~= 0x1B then
            if iskeypressed(k) then
                TRIGGER_KEY = k
                listening = false
                refreshTrigText()
                return
            end
        end
    end
end

refreshTrigText()
layout()
setGui(guiVisible)

-- Rolling one-second CPS counter
local clickTimes = {}
local nextBurst = 0
local lastCpsUpdate = 0

local function step()
    local now = os.clock()

    -- Always use the current player/mouse (fixes rejoin)
    refreshPlayer()

    local f1Down = iskeypressed(TOGGLE_KEY)
    local f2Down = iskeypressed(REBIND_KEY)
    local f3Down = iskeypressed(UNLOAD_KEY)

    -- F1 only shows/hides the GUI
    if f1Down and not f1WasDown then
        guiVisible = not guiVisible
        setGui(guiVisible)
        if not guiVisible then
            dragging = false
        end
    end
    f1WasDown = f1Down

    -- F2 starts keybind listening
    if f2Down and not f2WasDown and isrbxactive() then
        listening = true
        setTriggering(false)
        refreshTrigText()
    end
    f2WasDown = f2Down

    -- F3 unloads the script
    if f3Down and not f3WasDown and isrbxactive() then
        unload()
    end
    f3WasDown = f3Down

    local active = isrbxactive()

    if listening then
        pollRebind()
    end

    -- Track whether the ball is on you (also re-arms the trigger)
    local ballOnMe = updateTarget()

    -- Hold X: parry spam (works with GUI hidden)
    if running and active and iskeypressed(HOLD_KEY) then
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

    -- Hold trigger key: one parry per targeting
    if running and active and not listening and iskeypressed(TRIGGER_KEY) then
        setTriggering(true)

        if armed and ballOnMe and now - lastFire >= TRIGGER_COOLDOWN then
            keypress(PARRY_KEY)
            keyrelease(PARRY_KEY)
            clickTimes[#clickTimes + 1] = os.clock()
            lastFire = now
            armed = false
        end
    else
        setTriggering(false)
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
end

while running do
    local ok = pcall(step)
    if not ok then
        -- Don't unload on errors: just re-grab fresh refs and keep going
        pcall(function()
            player = game.Players.LocalPlayer
            mouse = player:GetMouse()
        end)
        armed = true
    end
    wait()
end

-- ===== Cleanup: remove everything from the screen =====
for _, d in ipairs(allDrawings) do
    pcall(function() d.Visible = false end)
    pcall(function() d:Remove() end)
end

if env.__AUTOCLASH_UNLOAD == unload then
    env.__AUTOCLASH_UNLOAD = nil
end
