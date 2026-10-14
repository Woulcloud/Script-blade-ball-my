--[[
    I See You Ap Macro — Blade Ball
    • Название: I See You Ap Macro
    • Мелкое чёрное меню
    • Белые кнопки
    • Spam + Show Spam (floating moveable кнопка)
    • CPS до 1000
    • Boost FPS (auto-boost during clash)
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats             = game:GetService("Stats")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")

local Player = Players.LocalPlayer

--=== hookfunction ===--
local hook = rawget(getfenv(), "hookfunction")
    or (getgenv and getgenv().hookfunction)
    or rawget(_G, "hookfunction")
    or (hookfunction ~= nil and hookfunction)

--=== Константы ===--
local HASH = "5455ef47-de02-4074-808c-8d82c2cd12ec"
local byte, char  = string.byte, string.char
local floor, bxor = math.floor, bit32.bxor

--=== Состояние ===--
local captured, votes, key = {}, {}, nil
local spamRunning = false
local spamThread = nil
local spamHeartbeat = nil
local spamUIVisible = false
local menuOpen = true

local boostEnabled = false
local originalSettings = nil
local lastBallCheck = 0

-- CPS: 50..1000, по умолчанию 500
local spamCPS = 500
local spamDelay = 1 / spamCPS

--=== Утилиты ===--
local function timestamp()
    return tostring(floor(workspace:GetServerTimeNow() * 100))
end

local function ShowNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text  = text,
            Duration = duration or 3,
        })
    end)
end

local function GetPing()
    local ok, result = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return ok and result or 100
end

--=== XOR обучение ===--
local function learn(token, stamp)
    if #token ~= #stamp then return false end
    for i = 1, #token do
        local value = bxor(byte(token, i), (byte(stamp, i) + i) % 256)
        local counts = votes[i] or {}
        votes[i] = counts
        counts[value] = (counts[value] or 0) + 1
    end
    local nextKey = {}
    for i = 1, #token do
        local best, highest = 0, -1
        for value, count in pairs(votes[i]) do
            if count > highest then best, highest = value, count end
        end
        nextKey[i] = best
    end
    key = nextKey
    return true
end

local function makeToken()
    if not key then return nil end
    local stamp = timestamp()
    local out = {}
    for i = 1, #stamp do
        local value = key[i] or key[#key]
        if not value then return nil end
        out[i] = char(bxor((byte(stamp, i) + i) % 256, value))
    end
    return table.concat(out)
end

--=== Хук ===--
local fire
if hook then
    pcall(function()
        local template = Instance.new("RemoteEvent")
        fire = hook(template.FireServer, function(self, ...)
            local args = table.pack(...)
            if args[1] ~= HASH or type(args[3]) ~= "string" then
                return fire(self, ...)
            end
            captured = {
                remote     = self,
                sessionKey = args[2],
                token      = args[3],
                timing     = args[4],
                tailBool   = args[8],
            }
            learn(args[3], timestamp())
            return fire(self, ...)
        end)
    end)
end

--=== Replay ===--
local camCache = nil
local pointsCache = {}
local pointsCacheTime = 0
local POINTS_TTL = 0.05

local function refreshPoints()
    local now = tick()
    if now - pointsCacheTime < POINTS_TTL then return end
    pointsCacheTime = now
    pointsCache = {}
    local alive = workspace:FindFirstChild("Alive")
    if alive and camCache then
        for _, character in ipairs(alive:GetChildren()) do
            local root = character:FindFirstChild("HumanoidRootPart")
            if root then
                pointsCache[character.Name] = camCache:WorldToScreenPoint(root.Position)
            end
        end
    end
end

local function replay()
    if not fire or not captured.remote or not captured.sessionKey then return end
    local token = makeToken()
    if not token then return end

    camCache = workspace.CurrentCamera
    if not camCache then return end

    refreshPoints()

    local mouse = UserInputService:GetMouseLocation()
    local timing = captured.timing or 0.5
    local tail   = captured.tailBool or false

    fire(captured.remote, HASH, captured.sessionKey, token, timing, camCache.CFrame, pointsCache, { mouse.X, mouse.Y }, tail)
end

local function Parry()
    if not captured.remote or not captured.sessionKey then return end
    replay()
end

--=== Spam ===--
local function StartSpam()
    if spamRunning then return end
    spamRunning = true

    if spamCPS > 120 then
        spamHeartbeat = RunService.Heartbeat:Connect(function()
            if not spamRunning then return end
            Parry()
        end)
    else
        spamThread = task.spawn(function()
            while spamRunning do
                Parry()
                task.wait(spamDelay)
            end
            spamThread = nil
        end)
    end
end

local function StopSpam()
    spamRunning = false
    if spamHeartbeat then
        spamHeartbeat:Disconnect()
        spamHeartbeat = nil
    end
    if spamThread then
        pcall(function() task.cancel(spamThread) end)
        spamThread = nil
    end
end

--=== Boost FPS ===--
local function SaveOriginalSettings()
    if originalSettings then return end
    originalSettings = {
        GlobalShadows       = Lighting.GlobalShadows,
        Brightness          = Lighting.Brightness,
        Ambient             = Lighting.Ambient,
        OutdoorAmbient      = Lighting.OutdoorAmbient,
        FogEnd              = Lighting.FogEnd,
        FogStart            = Lighting.FogStart,
        ClockTime           = Lighting.ClockTime,
        GeographicLatitude  = Lighting.GeographicLatitude,
        EnvironmentDiffuseScale  = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    }
end

local function RestoreOriginalSettings()
    if not originalSettings then return end
    pcall(function()
        Lighting.GlobalShadows      = originalSettings.GlobalShadows
        Lighting.Brightness         = originalSettings.Brightness
        Lighting.Ambient            = originalSettings.Ambient
        Lighting.OutdoorAmbient     = originalSettings.OutdoorAmbient
        Lighting.FogEnd             = originalSettings.FogEnd
        Lighting.FogStart           = originalSettings.FogStart
        Lighting.ClockTime          = originalSettings.ClockTime
        Lighting.GeographicLatitude = originalSettings.GeographicLatitude
        Lighting.EnvironmentDiffuseScale  = originalSettings.EnvironmentDiffuseScale
        Lighting.EnvironmentSpecularScale = originalSettings.EnvironmentSpecularScale
    end)
    originalSettings = nil
end

local function EnableBoost()
    if boostEnabled then return end
    SaveOriginalSettings()
    boostEnabled = true

    -- Понижаем настройки графики
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.Brightness = 0
        Lighting.Ambient = Color3.fromRGB(128, 128, 128)
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
    end)

    -- Отключаем постобработку
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect")
        or effect:IsA("BlurEffect")
        or effect:IsA("BloomEffect")
        or effect:IsA("SunRaysEffect")
        or effect:IsA("ColorCorrectionEffect")
        or effect:IsA("DepthOfFieldEffect") then
            pcall(function() effect.Enabled = false end)
        end
    end

    -- Скрываем частицы / beam / trails в workspace
    task.spawn(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if not boostEnabled then break end
            pcall(function()
                if obj:IsA("ParticleEmitter") then
                    obj.Enabled = false
                elseif obj:IsA("Trail") then
                    obj.Enabled = false
                elseif obj:IsA("Beam") then
                    obj.Enabled = false
                elseif obj:IsA("Fire") then
                    obj.Enabled = false
                elseif obj:IsA("Smoke") then
                    obj.Enabled = false
                elseif obj:IsA("Sparkles") then
                    obj.Enabled = false
                elseif obj:IsA("Explosion") then
                    obj.BlastPressure = 0
                    obj.BlastRadius = 0
                end
            end)
        end
    end)

    -- Уменьшаем качество рендера
    pcall(function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
end

local function DisableBoost()
    if not boostEnabled then return end
    boostEnabled = false
    RestoreOriginalSettings()
end

-- Auto-boost during clash: если много мячей рядом — включаем boost
local function AutoClashBoost()
    if not boostEnabled then return end
    local now = tick()
    if now - lastBallCheck < 1 then return end
    lastBallCheck = now

    -- Если в радиусе 50 studs есть 3+ мяча или идёт clash — ужимаем ещё сильнее
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Balls" or obj:IsA("BasePart") and obj.Name:lower():find("ball") then
            if (obj.Position - hrp.Position).Magnitude < 50 then
                count += 1
            end
        end
    end

    if count >= 3 then
        -- Clash boost: уменьшаем ещё сильнее
        pcall(function()
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        end)
        -- Отключаем все BasePart с материалом ForceField / Neon (обычно тяжёлые)
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and (obj.Material == Enum.Material.Neon or obj.Material == Enum.Material.ForceField) then
                    obj.Material = Enum.Material.SmoothPlastic
                end
            end
        end)
    end
end

--=== UI ===--
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ISeeYouAPMacro"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 240, 0, 320)
MainFrame.Position = UDim2.new(0, 20, 0, 80)
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BackgroundTransparency = 0.15
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(50, 50, 50)
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 36)
Title.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
Title.BackgroundTransparency = 0.1
Title.BorderSizePixel = 0
Title.Text = "  I See You Ap Macro"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = Title

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 34, 0, 24)
ToggleBtn.Position = UDim2.new(1, -42, 0, 6)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "-"
ToggleBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
ToggleBtn.TextSize = 16
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = Title

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleBtn

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "Content"
ContentFrame.Size = UDim2.new(1, -20, 1, -46)
ContentFrame.Position = UDim2.new(0, 10, 0, 42)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ClipsDescendants = true
ContentFrame.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 6)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ContentFrame

local FULL_SIZE = UDim2.new(0, 240, 0, 320)
local MIN_SIZE  = UDim2.new(0, 240, 0, 36)
local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function SetMenuOpen(open)
    menuOpen = open
    local targetSize = open and FULL_SIZE or MIN_SIZE
    TweenService:Create(MainFrame, tweenInfo, {Size = targetSize}):Play()
    if open then
        ContentFrame.Visible = true
        ToggleBtn.Text = "-"
    else
        task.delay(0.3, function()
            if not menuOpen then ContentFrame.Visible = false end
        end)
        ToggleBtn.Text = "+"
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    SetMenuOpen(not menuOpen)
end)

local function CreateButton(name, order)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Btn"
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.Text = name .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamMedium
    btn.LayoutOrder = order
    btn.Parent = ContentFrame

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = btn

    return btn
end

local SpamBtn      = CreateButton("Spam", 1)
local ShowSpamBtn  = CreateButton("Show Spam", 2)
local BoostFPSBtn  = CreateButton("Boost FPS", 3)

local CPSLabel = Instance.new("TextLabel")
CPSLabel.Size = UDim2.new(1, 0, 0, 18)
CPSLabel.BackgroundTransparency = 1
CPSLabel.Text = ("CPS: %d"):format(spamCPS)
CPSLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
CPSLabel.TextSize = 12
CPSLabel.Font = Enum.Font.GothamMedium
CPSLabel.LayoutOrder = 4
CPSLabel.Parent = ContentFrame

local CPSSlider = Instance.new("TextButton")
CPSSlider.Size = UDim2.new(1, 0, 0, 22)
CPSSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
CPSSlider.BorderSizePixel = 0
CPSSlider.Text = ""
CPSSlider.LayoutOrder = 5
CPSSlider.Parent = ContentFrame

local CPSSliderCorner = Instance.new("UICorner")
CPSSliderCorner.CornerRadius = UDim.new(0, 6)
CPSSliderCorner.Parent = CPSSlider

local CPSFill = Instance.new("Frame")
CPSFill.Size = UDim2.new(1.0, 0, 1, 0)
CPSFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CPSFill.BorderSizePixel = 0
CPSFill.Parent = CPSSlider

local CPSFillCorner = Instance.new("UICorner")
CPSFillCorner.CornerRadius = UDim.new(0, 6)
CPSFillCorner.Parent = CPSFill

local CPS_MIN, CPS_MAX = 50, 1000
local function SetCPSFromX(x)
    local rel = math.clamp((x - CPSSlider.AbsolutePosition.X) / CPSSlider.AbsoluteSize.X, 0, 1)
    spamCPS = math.floor(CPS_MIN + rel * (CPS_MAX - CPS_MIN) + 0.5)
    spamDelay = 1 / spamCPS
    CPSFill.Size = UDim2.new(rel, 0, 1, 0)
    CPSLabel.Text = ("CPS: %d"):format(spamCPS)
    if spamRunning then
        StopSpam()
        StartSpam()
    end
end

CPSSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        SetCPSFromX(input.Position.X)
    end
end)

CPSSlider.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        SetCPSFromX(input.Position.X)
    end
end)

CPSFill.Size = UDim2.new((500 - CPS_MIN) / (CPS_MAX - CPS_MIN), 0, 1, 0)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 16)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Waiting for parry..."
StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.LayoutOrder = 6
StatusLabel.Parent = ContentFrame

task.spawn(function()
    while StatusLabel.Parent do
        if captured.sessionKey then
            StatusLabel.Text = "Token: OK | Spam: " .. (spamRunning and "ON" or "OFF") .. " | FPS: " .. (boostEnabled and "BOOST" or "OFF")
            StatusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
        else
            StatusLabel.Text = "Do 1 manual parry to catch token"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 180, 100)
        end
        task.wait(1)
    end
end)

--=== Floating Spam ===--
local FloatingSpamBtn = nil

local function CreateFloatingSpam()
    if FloatingSpamBtn then return end
    FloatingSpamBtn = Instance.new("TextButton")
    FloatingSpamBtn.Name = "FloatingSpam"
    FloatingSpamBtn.Size = UDim2.new(0, 130, 0, 45)
    FloatingSpamBtn.Position = UDim2.new(0, 20, 0, 420)
    FloatingSpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    FloatingSpamBtn.BorderSizePixel = 0
    FloatingSpamBtn.Text = "SPAM: OFF"
    FloatingSpamBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    FloatingSpamBtn.TextSize = 13
    FloatingSpamBtn.Font = Enum.Font.GothamBold
    FloatingSpamBtn.Active = true
    FloatingSpamBtn.Draggable = true
    FloatingSpamBtn.Parent = ScreenGui

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = FloatingSpamBtn

    FloatingSpamBtn.MouseButton1Click:Connect(function()
        if spamRunning then
            StopSpam()
            FloatingSpamBtn.Text = "SPAM: OFF"
            FloatingSpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SpamBtn.Text = "Spam: OFF"
            SpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            StartSpam()
            FloatingSpamBtn.Text = "SPAM: ON"
            FloatingSpamBtn.BackgroundColor3 = Color3.fromRGB(180, 255, 180)
            SpamBtn.Text = "Spam: ON"
            SpamBtn.BackgroundColor3 = Color3.fromRGB(180, 255, 180)
        end
    end)
end

local function DestroyFloatingSpam()
    if FloatingSpamBtn then
        FloatingSpamBtn:Destroy()
        FloatingSpamBtn = nil
    end
end

--=== Обработчики ===--
SpamBtn.MouseButton1Click:Connect(function()
    if spamRunning then
        StopSpam()
        SpamBtn.Text = "Spam: OFF"
        SpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        if FloatingSpamBtn then
            FloatingSpamBtn.Text = "SPAM: OFF"
            FloatingSpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        end
    else
        StartSpam()
        SpamBtn.Text = "Spam: ON"
        SpamBtn.BackgroundColor3 = Color3.fromRGB(180, 255, 180)
        if FloatingSpamBtn then
            FloatingSpamBtn.Text = "SPAM: ON"
            FloatingSpamBtn.BackgroundColor3 = Color3.fromRGB(180, 255, 180)
        end
    end
end)

ShowSpamBtn.MouseButton1Click:Connect(function()
    spamUIVisible = not spamUIVisible
    if spamUIVisible then
        CreateFloatingSpam()
        ShowSpamBtn.Text = "Show Spam: ON"
        ShowSpamBtn.BackgroundColor3 = Color3.fromRGB(180, 255, 180)
    else
        DestroyFloatingSpam()
        ShowSpamBtn.Text = "Show Spam: OFF"
        ShowSpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end
end)

BoostFPSBtn.MouseButton1Click:Connect(function()
    if boostEnabled then
        DisableBoost()
        BoostFPSBtn.Text = "Boost FPS: OFF"
        BoostFPSBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    else
        EnableBoost()
        BoostFPSBtn.Text = "Boost FPS: ON"
        BoostFPSBtn.BackgroundColor3 = Color3.fromRGB(180, 255, 180)
    end
end)

-- Авто-boost при clash
RunService.Heartbeat:Connect(function()
    if boostEnabled then
        AutoClashBoost()
    end
end)

-- При респавне не сбрасываем boost
Player.CharacterAdded:Connect(function()
    if boostEnabled then
        task.wait(1)
        EnableBoost()
    end
end)

ShowNotification("I See You Ap Macro", "Сделай 1 ручной паринг для захвата токена", 5)
