local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats             = game:GetService("Stats")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")

local Player = Players.LocalPlayer
local hook = getgenv and getgenv().hookfunction or hookfunction

local HASH = "5455ef47-de02-4074-808c-8d82c2cd12ec"
local byte, char  = string.byte, string.char
local floor, bxor = math.floor, bit32.bxor

local captured, votes, key = {}, {}, nil
local spamRunning = false
local spamHeartbeat = nil
local boostEnabled = false
local originalSettings = nil
local lastBallCheck = 0
local spamCPS = 500
local actualCPS = 0
local cpsCounter = 0
local lastCPSTime = tick()
local currentPing = 0
local lastPingUpdate = 0
local PING_UPDATE_INTERVAL = 1.0
local ANIM_COOLDOWN = 0.05
local LastPlayTime = 0
local Loaded_Tracks = {}
local AnimFix_Cache = {}
local LastPlayedTrack = nil

local function timestamp()
    return tostring(floor(workspace:GetServerTimeNow() * 100))
end

local function ShowNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 3,
        })
    end)
end

local function GetPing()
    local now = tick()
    if now - lastPingUpdate > PING_UPDATE_INTERVAL then
        lastPingUpdate = now
        local ok, result = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        currentPing = ok and result or 100
    end
    return currentPing
end

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

local fire
if hook then
    pcall(function()
        local template = Instance.new("RemoteEvent")
        fire = hook(template.FireServer, function(self, ...)
            local args = table.pack(...)
            if args[1] ~= HASH or type(args[3]) ~= "string" then
                return fire(self, ...)
            end
            captured = { remote = self, sessionKey = args[2], token = args[3], timing = args[4], tailBool = args[8] }
            learn(args[3], timestamp())
            return fire(self, ...)
        end)
    end)
end

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
            if root then pointsCache[character.Name] = camCache:WorldToScreenPoint(root.Position) end
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
    cpsCounter = cpsCounter + 1
end

local function Parry()
    if not captured.remote or not captured.sessionKey then return end
    replay()
end

local SwordAPI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SwordAPI")

local function GetParryAnimation(swordName)
    if not swordName or swordName == "" then return SwordAPI.Collection.Default:FindFirstChild("GrabParry") end
    if AnimFix_Cache[swordName] then return AnimFix_Cache[swordName] end
    local ok, swordData = pcall(function()
        return ReplicatedStorage.Shared.ReplicatedInstances.Swords.GetSword:Invoke(swordName)
    end)
    if not ok or type(swordData) ~= "table" or not swordData.AnimationType then
        AnimFix_Cache[swordName] = SwordAPI.Collection.Default:FindFirstChild("GrabParry")
        return AnimFix_Cache[swordName]
    end
    for _, obj in pairs(SwordAPI.Collection:GetChildren()) do
        if obj.Name == swordData.AnimationType then
            local anim = obj:FindFirstChild("GrabParry") or obj:FindFirstChild("Grab")
            if anim then AnimFix_Cache[swordName] = anim return anim end
        end
    end
    AnimFix_Cache[swordName] = SwordAPI.Collection.Default:FindFirstChild("GrabParry")
    return AnimFix_Cache[swordName]
end

local function GetOrLoadTrack()
    local char = Player.Character
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    local animator = humanoid:FindFirstChild("Animator")
    if not animator then return nil end
    local currentSword = char:GetAttribute("CurrentlyEquippedSword") or "Default"
    if Loaded_Tracks.Character ~= char then
        Loaded_Tracks = { Character = char } LastPlayedTrack = nil
    end
    if Loaded_Tracks[currentSword] then return Loaded_Tracks[currentSword] end
    local animation = GetParryAnimation(currentSword)
    if not animation then return nil end
    local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
    if ok and track then
        track.Priority = Enum.AnimationPriority.Action
        track.Looped = false
        Loaded_Tracks[currentSword] = track
        return track
    end
    return nil
end

local function PlayGrabParry()
    if tick() - LastPlayTime < ANIM_COOLDOWN then return end
    LastPlayTime = tick()
    local track = GetOrLoadTrack()
    if not track then return end
    pcall(function()
        if LastPlayedTrack and LastPlayedTrack ~= track then pcall(function() LastPlayedTrack:Stop(0) end) end
        track:Stop(0)
        track.TimePosition = 0
        track:Play(0, 1, 1)
        LastPlayedTrack = track
    end)
end

pcall(function()
    ReplicatedStorage.Remotes.ParrySuccessAll.OnClientEvent:Connect(function()
        local char = Player.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local animator = humanoid:FindFirstChild("Animator")
        if not animator then return end
        for _, track in pairs(animator:GetPlayingAnimationTracks()) do
            if track.Name == "GrabParry" or track.Name == "Grab" then pcall(function() track:Stop(0.1) end) end
        end
        LastPlayedTrack = nil
    end)
end)

local function StartSpam()
    if spamRunning then return end
    spamRunning = true
    spamHeartbeat = RunService.Heartbeat:Connect(function()
        if not spamRunning then return end
        Parry()
        task.spawn(PlayGrabParry)
    end)
end

local function StopSpam()
    spamRunning = false
    if spamHeartbeat then spamHeartbeat:Disconnect() spamHeartbeat = nil end
end

local function SaveOriginalSettings()
    if originalSettings then return end
    originalSettings = {
        GlobalShadows = Lighting.GlobalShadows, Brightness = Lighting.Brightness,
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
        FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
        ClockTime = Lighting.ClockTime, GeographicLatitude = Lighting.GeographicLatitude,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    }
end

local function RestoreOriginalSettings()
    if not originalSettings then return end
    pcall(function()
        Lighting.GlobalShadows = originalSettings.GlobalShadows
        Lighting.Brightness = originalSettings.Brightness
        Lighting.Ambient = originalSettings.Ambient
        Lighting.OutdoorAmbient = originalSettings.OutdoorAmbient
        Lighting.FogEnd = originalSettings.FogEnd
        Lighting.FogStart = originalSettings.FogStart
        Lighting.ClockTime = originalSettings.ClockTime
        Lighting.GeographicLatitude = originalSettings.GeographicLatitude
        Lighting.EnvironmentDiffuseScale = originalSettings.EnvironmentDiffuseScale
        Lighting.EnvironmentSpecularScale = originalSettings.EnvironmentSpecularScale
    end)
    originalSettings = nil
end

local function EnableBoost()
    if boostEnabled then return end
    SaveOriginalSettings()
    boostEnabled = true
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
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") or effect:IsA("BlurEffect") or effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("DepthOfFieldEffect") then
            pcall(function() effect.Enabled = false end)
        end
    end
    task.spawn(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if not boostEnabled then break end
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then obj.Enabled = false end
            end)
        end
    end)
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
end

local function DisableBoost()
    if not boostEnabled then return end
    boostEnabled = false
    RestoreOriginalSettings()
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
end

local function AutoClashBoost()
    if not boostEnabled then return end
    local now = tick()
    if now - lastBallCheck < 1 then return end
    lastBallCheck = now
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local count = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and obj.Name:lower():find("ball") then
            if (obj.Position - hrp.Position).Magnitude < 50 then count += 1 end
        end
    end
    if count >= 3 then pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end) end
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ISeeYouAPMacro"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 380)
MainFrame.Position = UDim2.new(0, 20, 0, 80)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BackgroundTransparency = 0.05
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(60, 60, 60)
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 34)
Title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Title.BackgroundTransparency = 0.2
Title.BorderSizePixel = 0
Title.Text = "  I See You"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 30, 0, 22)
ToggleBtn.Position = UDim2.new(1, -38, 0, 6)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "-"
ToggleBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = Title

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 4)
ToggleCorner.Parent = ToggleBtn

local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Size = UDim2.new(1, -16, 1, -50)
ContentFrame.Position = UDim2.new(0, 8, 0, 48)
ContentFrame.BackgroundTransparency = 1
ContentFrame.BorderSizePixel = 0
ContentFrame.ScrollBarThickness = 4
ContentFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80)
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentFrame.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 4)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ContentFrame

local FULL_SIZE = UDim2.new(0, 220, 0, 380)
local MIN_SIZE  = UDim2.new(0, 220, 0, 34)
local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local menuOpen = true

local function SetMenuOpen(open)
    menuOpen = open
    local targetSize = open and FULL_SIZE or MIN_SIZE
    TweenService:Create(MainFrame, tweenInfo, {Size = targetSize}):Play()
    if open then
        ContentFrame.Visible = true
        ToggleBtn.Text = "-"
    else
        task.delay(0.3, function() if not menuOpen then ContentFrame.Visible = false end end)
        ToggleBtn.Text = "+"
    end
end

ToggleBtn.MouseButton1Click:Connect(function() SetMenuOpen(not menuOpen) end)

local function CreateButton(name, order)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Btn"
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.Text = name .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamMedium
    btn.LayoutOrder = order
    btn.Parent = ContentFrame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = btn
    return btn
end

local SpamBtn      = CreateButton("Spam (E)", 1)
local ShowSpamBtn  = CreateButton("Show Spam", 2)
local BoostFPSBtn  = CreateButton("Boost FPS", 3)
local ShowStatsBtn = CreateButton("Show Stats", 4)

local StatsContainer = Instance.new("Frame")
StatsContainer.Size = UDim2.new(1, 0, 0, 50)
StatsContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
StatsContainer.BorderSizePixel = 0
StatsContainer.LayoutOrder = 5
StatsContainer.Parent = ContentFrame

local StatsCorner = Instance.new("UICorner")
StatsCorner.CornerRadius = UDim.new(0, 5)
StatsCorner.Parent = StatsContainer

local CPSLabel = Instance.new("TextLabel")
CPSLabel.Size = UDim2.new(1, -8, 0, 22)
CPSLabel.Position = UDim2.new(0, 4, 0, 3)
CPSLabel.BackgroundTransparency = 1
CPSLabel.Text = "CPS: 0 / 500"
CPSLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
CPSLabel.TextSize = 12
CPSLabel.Font = Enum.Font.GothamBold
CPSLabel.TextXAlignment = Enum.TextXAlignment.Left
CPSLabel.Parent = StatsContainer

local PingLabel = Instance.new("TextLabel")
PingLabel.Size = UDim2.new(1, -8, 0, 22)
PingLabel.Position = UDim2.new(0, 4, 0, 25)
PingLabel.BackgroundTransparency = 1
PingLabel.Text = "Ping: 0 ms"
PingLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
PingLabel.TextSize = 12
PingLabel.Font = Enum.Font.GothamBold
PingLabel.TextXAlignment = Enum.TextXAlignment.Left
PingLabel.Parent = StatsContainer

local CPSLabelText = Instance.new("TextLabel")
CPSLabelText.Size = UDim2.new(1, 0, 0, 16)
CPSLabelText.BackgroundTransparency = 1
CPSLabelText.Text = ("Target CPS: %d"):format(spamCPS)
CPSLabelText.TextColor3 = Color3.fromRGB(255, 255, 255)
CPSLabelText.TextSize = 11
CPSLabelText.Font = Enum.Font.GothamMedium
CPSLabelText.LayoutOrder = 6
CPSLabelText.Parent = ContentFrame

local CPSSlider = Instance.new("TextButton")
CPSSlider.Size = UDim2.new(1, 0, 0, 20)
CPSSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
CPSSlider.BorderSizePixel = 0
CPSSlider.Text = ""
CPSSlider.LayoutOrder = 7
CPSSlider.Parent = ContentFrame

local CPSSliderCorner = Instance.new("UICorner")
CPSSliderCorner.CornerRadius = UDim.new(0, 5)
CPSSliderCorner.Parent = CPSSlider

local CPSFill = Instance.new("Frame")
CPSFill.Size = UDim2.new(0.45, 0, 1, 0)
CPSFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CPSFill.BorderSizePixel = 0
CPSFill.Parent = CPSSlider

local CPSFillCorner = Instance.new("UICorner")
CPSFillCorner.CornerRadius = UDim.new(0, 5)
CPSFillCorner.Parent = CPSFill

local CPS_MIN, CPS_MAX = 50, 1100
local function SetCPSFromX(x)
    local rel = math.clamp((x - CPSSlider.AbsolutePosition.X) / CPSSlider.AbsoluteSize.X, 0, 1)
    spamCPS = math.floor(CPS_MIN + rel * (CPS_MAX - CPS_MIN) + 0.5)
    CPSFill.Size = UDim2.new(rel, 0, 1, 0)
    CPSLabelText.Text = ("Target CPS: %d"):format(spamCPS)
    if spamRunning then StopSpam() StartSpam() end
end

CPSSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then SetCPSFromX(input.Position.X) end
end)

CPSSlider.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then SetCPSFromX(input.Position.X) end
end)

local QuickFrame = Instance.new("Frame")
QuickFrame.Size = UDim2.new(1, 0, 0, 30)
QuickFrame.BackgroundTransparency = 1
QuickFrame.LayoutOrder = 8
QuickFrame.Parent = ContentFrame

local QuickLayout = Instance.new("UIListLayout")
QuickLayout.FillDirection = Enum.FillDirection.Horizontal
QuickLayout.Padding = UDim.new(0, 4)
QuickLayout.SortOrder = Enum.SortOrder.LayoutOrder
QuickLayout.Parent = QuickFrame

local function CreateQuickBtn(label, cpsValue, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 60, 1, 0)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.Text = label
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.LayoutOrder = order
    btn.Parent = QuickFrame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = btn
    btn.MouseButton1Click:Connect(function()
        spamCPS = cpsValue
        local rel = (spamCPS - CPS_MIN) / (CPS_MAX - CPS_MIN)
        CPSFill.Size = UDim2.new(rel, 0, 1, 0)
        CPSLabelText.Text = ("Target CPS: %d"):format(spamCPS)
        if spamRunning then StopSpam() StartSpam() end
    end)
    return btn
end

CreateQuickBtn("200", 200, 1)
CreateQuickBtn("500", 500, 2)
CreateQuickBtn("1100", 1100, 3)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 14)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Waiting for parry..."
StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
StatusLabel.TextSize = 10
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.LayoutOrder = 9
StatusLabel.Parent = ContentFrame

local FloatingSpamBtn = nil
local spamUIVisible = false

local function CreateFloatingSpam()
    if FloatingSpamBtn then return end
    FloatingSpamBtn = Instance.new("TextButton")
    FloatingSpamBtn.Size = UDim2.new(0, 120, 0, 40)
    FloatingSpamBtn.Position = UDim2.new(0, 20, 0, 480)
    FloatingSpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    FloatingSpamBtn.BorderSizePixel = 0
    FloatingSpamBtn.Text = "SPAM (E): OFF"
    FloatingSpamBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    FloatingSpamBtn.TextSize = 12
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
            FloatingSpamBtn.Text = "SPAM (E): OFF"
            FloatingSpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            SpamBtn.Text = "Spam (E): OFF"
            SpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        else
            StartSpam()
            FloatingSpamBtn.Text = "SPAM (E): ON"
            FloatingSpamBtn.BackgroundColor3 = Color3.fromRGB(180, 255, 180)
            SpamBtn.Text = "Spam (E): ON"
            SpamBtn.BackgroundColor3 = Color3.fromRGB(180, 255, 180)
        end
    end)
end

local function DestroyFloatingSpam()
    if FloatingSpamBtn then FloatingSpamBtn:Destroy() FloatingSpamBtn = nil end
end

local FloatingStatsWindow = nil
local statsVisible = false

local function CreateFloatingStats()
    if FloatingStatsWindow then return end
    FloatingStatsWindow = Instance.new("Frame")
    FloatingStatsWindow.Size = UDim2.new(0, 160, 0, 80)
    FloatingStatsWindow.Position = UDim2.new(0, 20, 0, 550)
    FloatingStatsWindow.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    FloatingStatsWindow.BackgroundTransparency = 0.1
    FloatingStatsWindow.BorderSizePixel = 0
    FloatingStatsWindow.Active = true
    FloatingStatsWindow.Draggable = true
    FloatingStatsWindow.Parent = ScreenGui
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = FloatingStatsWindow
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = FloatingStatsWindow
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 24)
    title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    title.BackgroundTransparency = 0.2
    title.BorderSizePixel = 0
    title.Text = "  STATS"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 11
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = FloatingStatsWindow
    local tCorner = Instance.new("UICorner")
    tCorner.CornerRadius = UDim.new(0, 8)
    tCorner.Parent = title
    local realCpsLabel = Instance.new("TextLabel")
    realCpsLabel.Name = "RealCpsLabel"
    realCpsLabel.Size = UDim2.new(1, -8, 0, 22)
    realCpsLabel.Position = UDim2.new(0, 4, 0, 28)
    realCpsLabel.BackgroundTransparency = 1
    realCpsLabel.Text = "Real CPS: 0"
    realCpsLabel.TextColor3 = Color3.fromRGB(80, 255, 80)
    realCpsLabel.TextSize = 13
    realCpsLabel.Font = Enum.Font.GothamBold
    realCpsLabel.TextXAlignment = Enum.TextXAlignment.Left
    realCpsLabel.Parent = FloatingStatsWindow
    local realPingLabel = Instance.new("TextLabel")
    realPingLabel.Name = "RealPingLabel"
    realPingLabel.Size = UDim2.new(1, -8, 0, 22)
    realPingLabel.Position = UDim2.new(0, 4, 0, 50)
    realPingLabel.BackgroundTransparency = 1
    realPingLabel.Text = "Ping: 0 ms"
    realPingLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
    realPingLabel.TextSize = 13
    realPingLabel.Font = Enum.Font.GothamBold
    realPingLabel.TextXAlignment = Enum.TextXAlignment.Left
    realPingLabel.Parent = FloatingStatsWindow
end

local function DestroyFloatingStats()
    if FloatingStatsWindow then FloatingStatsWindow:Destroy() FloatingStatsWindow = nil end
end

local function ToggleSpam()
    if spamRunning then
        StopSpam()
        SpamBtn.Text = "Spam (E): OFF"
        SpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        if FloatingSpamBtn then
            FloatingSpamBtn.Text = "SPAM (E): OFF"
            FloatingSpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        end
    else
        StartSpam()
        SpamBtn.Text = "Spam (E): ON"
        SpamBtn.BackgroundColor3 = Color3.fromRGB(180, 255, 180)
        if FloatingSpamBtn then
            FloatingSpamBtn.Text = "SPAM (E): ON"
            FloatingSpamBtn.BackgroundColor3 = Color3.fromRGB(180, 255, 180)
        end
    end
end

SpamBtn.MouseButton1Click:Connect(ToggleSpam)

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

ShowStatsBtn.MouseButton1Click:Connect(function()
    statsVisible = not statsVisible
    if statsVisible then
        CreateFloatingStats()
        ShowStatsBtn.Text = "Show Stats: ON"
        ShowStatsBtn.BackgroundColor3 = Color3.fromRGB(180, 255, 180)
    else
        DestroyFloatingStats()
        ShowStatsBtn.Text = "Show Stats: OFF"
        ShowStatsBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.E then ToggleSpam() end
end)

RunService.Heartbeat:Connect(function()
    if boostEnabled then AutoClashBoost() end
end)

Player.CharacterAdded:Connect(function()
    Loaded_Tracks = {}
    LastPlayedTrack = nil
    if boostEnabled then task.wait(1) EnableBoost() end
end)

task.spawn(function()
    while true do
        task.wait(1)
        local now = tick()
        if now - lastCPSTime >= 1 then
            actualCPS = cpsCounter
            cpsCounter = 0
            lastCPSTime = now
        end
        local ping = GetPing()
        CPSLabel.Text = ("CPS: %d / %d"):format(actualCPS, spamCPS)
        PingLabel.Text = ("Ping: %d ms"):format(math.floor(ping))
        if captured.sessionKey then
            StatusLabel.Text = ("Token: OK | Spam: %s | FPS: %s"):format(
                spamRunning and "ON" or "OFF",
                boostEnabled and "BOOST" or "OFF"
            )
            StatusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
        else
            StatusLabel.Text = "Do 1 manual parry to catch token"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 180, 100)
        end
        if FloatingStatsWindow then
            local realCpsLabel = FloatingStatsWindow:FindFirstChild("RealCpsLabel")
            local realPingLabel = FloatingStatsWindow:FindFirstChild("RealPingLabel")
            if realCpsLabel then realCpsLabel.Text = ("Real CPS: %d"):format(actualCPS) end
            if realPingLabel then realPingLabel.Text = ("Ping: %d ms"):format(math.floor(ping)) end
        end
    end
end)

ShowNotification("I See You", "E = Spam toggle | Сделай 1 ручной паринг", 5)
