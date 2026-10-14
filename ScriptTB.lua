local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats             = game:GetService("Stats")
local TweenService      = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Balls  = workspace:WaitForChild("Balls")

local parryRemote = nil
local function GetParryRemote()
    if parryRemote and parryRemote.Parent then return parryRemote end
    local candidates = { "ParryButtonPress", "Parry", "SwordParry", "ParryRemote", "ParryRequest" }
    for _, name in ipairs(candidates) do
        local r = ReplicatedStorage:FindFirstChild(name, true)
        if r and r:IsA("RemoteEvent") then parryRemote = r; return r end
    end
    for _, r in ipairs(ReplicatedStorage:GetDescendants()) do
        if r:IsA("RemoteEvent") and (r.Name:lower():find("parry") or r.Name:lower():find("block")) then
            parryRemote = r; return r
        end
    end
    for _, r in ipairs(game:GetDescendants()) do
        if r:IsA("RemoteEvent") and r.Name:lower():find("parry") then parryRemote = r; return r end
    end
    return nil
end

local triggerBotEnabled = true
local autoParryEnabled = false
local autoSpamEnabled = false
local menuOpen = true
local floatingTriggerVisible = true

local triggered_balls = {}
local parried_balls = {}
local triggerConnections = {}

local AUTO_SPAM_TRIGGER_DISTANCE = 40
local accuracyMultiplier = 20
local currentBallDistance = 0
local hasTargetBall = false
local lastParrySent = 0

local function ShowNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = duration or 3 })
    end)
end

local function GetPing()
    local ok, result = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return ok and result or 100
end

local function GetCPU()
    local ok, result = pcall(function()
        return Stats.PerformanceStats.CPU:GetValue()
    end)
    return ok and result or 0
end

local function GetMemory()
    local ok, result = pcall(function()
        return Stats:GetTotalMemoryUsageMb()
    end)
    return ok and result or 0
end

local function Parry()
    local remote = GetParryRemote()
    if not remote then return end
    pcall(function() remote:FireServer() end)
    pcall(function() remote:Fire() end)
    lastParrySent = tick()
    task.spawn(PlayGrabParry)
end

local SwordAPI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SwordAPI")
local AnimFix_Cache = {}
local Loaded_Tracks = {}
local LastPlayedTrack = nil
local LastPlayTime = 0
local ANIM_COOLDOWN = 0.05

local function GetParryAnimation(swordName)
    if not swordName or swordName == "" then
        return SwordAPI.Collection.Default:FindFirstChild("GrabParry")
    end
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
            if anim then AnimFix_Cache[swordName] = anim; return anim end
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
        Loaded_Tracks = { Character = char }
        LastPlayedTrack = nil
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

function PlayGrabParry()
    if tick() - LastPlayTime < ANIM_COOLDOWN then return end
    LastPlayTime = tick()
    local track = GetOrLoadTrack()
    if not track then return end
    pcall(function()
        if LastPlayedTrack and LastPlayedTrack ~= track then
            pcall(function() LastPlayedTrack:Stop(0) end)
        end
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
            if track.Name == "GrabParry" or track.Name == "Grab" then
                pcall(function() track:Stop(0.1) end)
            end
        end
        LastPlayedTrack = nil
    end)
end)

local function GetRealBalls()
    local out = {}
    for _, ball in ipairs(Balls:GetChildren()) do
        if ball:GetAttribute("realBall") == true then table.insert(out, ball) end
    end
    return out
end

local function GetNearestTargetBall()
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, 99999 end
    local nearestBall, minDist = nil, math.huge
    for _, ball in ipairs(GetRealBalls()) do
        if ball:GetAttribute("target") == Player.Name then
            local dist = (hrp.Position - ball.Position).Magnitude
            if dist < minDist then nearestBall = ball; minDist = dist end
        end
    end
    return nearestBall, minDist
end

local function BindTriggerBot(ball)
    if not ball or not ball.Parent then return end
    if triggerConnections[ball] then return end
    triggerConnections[ball] = ball:GetAttributeChangedSignal("target"):Connect(function()
        if not ball or not ball.Parent then return end
        if not triggerBotEnabled then return end
        local target = ball:GetAttribute("target")
        local bID = ball:GetDebugId()
        if target ~= Player.Name then
            triggered_balls[bID] = nil
            parried_balls[bID] = nil
            return
        end
        Parry()
    end)
    ball.Destroying:Connect(function()
        local bID = ball:GetDebugId()
        triggered_balls[bID] = nil
        parried_balls[bID] = nil
        if triggerConnections[ball] then
            pcall(function() triggerConnections[ball]:Disconnect() end)
            triggerConnections[ball] = nil
        end
    end)
end

for _, ball in ipairs(Balls:GetChildren()) do BindTriggerBot(ball) end
Balls.ChildAdded:Connect(function(ball) BindTriggerBot(ball) end)
workspace.ChildAdded:Connect(function(child)
    if child.Name == "Balls" then
        task.wait(0.2)
        for _, ball in ipairs(child:GetChildren()) do BindTriggerBot(ball) end
        child.ChildAdded:Connect(function(ball) BindTriggerBot(ball) end)
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        for _, ball in ipairs(Balls:GetChildren()) do
            if not triggerConnections[ball] or not ball.Parent then
                triggerConnections[ball] = nil
                BindTriggerBot(ball)
            end
        end
    end
end)

local function GetTimeToImpact(ball, charPart)
    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return 999 end
    local velocity = zoomies.VectorVelocity
    local speed = velocity.Magnitude
    if speed < 1 then return 999 end
    local dist = (charPart.Position - ball.Position).Magnitude
    return dist / speed
end

local function GetReactionThreshold()
    local ping = GetPing()
    local pingSeconds = ping / 1000
    local accuracyFactor = 1 - (accuracyMultiplier / 200)
    local baseThreshold = 0.04 + accuracyFactor * 0.40
    local pingBuffer = pingSeconds * (0.3 + accuracyFactor * 1.5)
    return baseThreshold + pingBuffer
end

RunService.Heartbeat:Connect(function()
    local ball, dist = GetNearestTargetBall()
    if ball then currentBallDistance = dist; hasTargetBall = true
    else currentBallDistance = 0; hasTargetBall = false end
    if not autoSpamEnabled then return end
    if hasTargetBall and currentBallDistance <= AUTO_SPAM_TRIGGER_DISTANCE then Parry() end
end)

RunService.PreSimulation:Connect(function()
    local char = Player.Character
    local charPart = char and char:FindFirstChild("HumanoidRootPart")
    if not charPart then return end
    local balls = GetRealBalls()
    if triggerBotEnabled then
        for _, ball in ipairs(balls) do
            if ball:GetAttribute("target") == Player.Name then
                local bID = ball:GetDebugId()
                if not triggered_balls[bID] then
                    triggered_balls[bID] = true
                    Parry()
                    ball:GetAttributeChangedSignal("target"):Once(function() triggered_balls[bID] = nil end)
                end
            end
        end
    end
    if autoParryEnabled then
        for _, ball in ipairs(balls) do
            local bID = ball:GetDebugId()
            if ball:GetAttribute("target") == Player.Name and not parried_balls[bID] then
                local timeToImpact = GetTimeToImpact(ball, charPart)
                local threshold = GetReactionThreshold()
                if timeToImpact <= threshold then
                    parried_balls[bID] = true
                    Parry()
                    ball:GetAttributeChangedSignal("target"):Once(function() parried_balls[bID] = nil end)
                end
            end
        end
    end
end)

Player.CharacterAdded:Connect(function()
    Loaded_Tracks = {}
    triggered_balls = {}
    parried_balls = {}
    LastPlayedTrack = nil
    triggerConnections = {}
    task.spawn(function()
        task.wait(0.3)
        for _, ball in ipairs(Balls:GetChildren()) do BindTriggerBot(ball) end
    end)
end)

ShowNotification("I See You", "Loaded!", 3)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ISeeYouMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local IconBtn = Instance.new("TextButton")
IconBtn.Size = UDim2.new(0, 45, 0, 45)
IconBtn.Position = UDim2.new(0, 15, 0, 60)
IconBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
IconBtn.BorderSizePixel = 0
IconBtn.Text = "tog"
IconBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
IconBtn.TextSize = 12
IconBtn.Font = Enum.Font.GothamBold
IconBtn.Active = true
IconBtn.Draggable = true
IconBtn.Parent = ScreenGui

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(0, 4)
IconCorner.Parent = IconBtn

local IconStroke = Instance.new("UIStroke")
IconStroke.Color = Color3.fromRGB(0, 0, 0)
IconStroke.Thickness = 1
IconStroke.Parent = IconBtn

local FloatingTriggerBtn = Instance.new("TextButton")
FloatingTriggerBtn.Size = UDim2.new(0, 45, 0, 45)
FloatingTriggerBtn.Position = UDim2.new(0, 15, 0, 110)
FloatingTriggerBtn.BackgroundColor3 = Color3.fromRGB(220, 255, 220)
FloatingTriggerBtn.BorderSizePixel = 0
FloatingTriggerBtn.Text = "trg"
FloatingTriggerBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
FloatingTriggerBtn.TextSize = 12
FloatingTriggerBtn.Font = Enum.Font.GothamBold
FloatingTriggerBtn.Active = true
FloatingTriggerBtn.Draggable = true
FloatingTriggerBtn.Visible = true
FloatingTriggerBtn.Parent = ScreenGui

local FloatingCorner = Instance.new("UICorner")
FloatingCorner.CornerRadius = UDim.new(0, 4)
FloatingCorner.Parent = FloatingTriggerBtn

local FloatingStroke = Instance.new("UIStroke")
FloatingStroke.Color = Color3.fromRGB(0, 0, 0)
FloatingStroke.Thickness = 1
FloatingStroke.Parent = FloatingTriggerBtn

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 480, 0, 240)
MainFrame.Position = UDim2.new(0, 70, 0, 30)
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 6)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(50, 50, 50)
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleBarCorner = Instance.new("UICorner")
TitleBarCorner.CornerRadius = UDim.new(0, 6)
TitleBarCorner.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 20)
Title.Position = UDim2.new(0, 0, 0, 3)
Title.BackgroundTransparency = 1
Title.Text = "I See You"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Center
Title.Parent = TitleBar

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, 0, 0, 12)
Subtitle.Position = UDim2.new(0, 0, 0, 20)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Trigger Bot"
Subtitle.TextColor3 = Color3.fromRGB(160, 160, 160)
Subtitle.TextSize = 9
Subtitle.Font = Enum.Font.Gotham
Subtitle.TextXAlignment = Enum.TextXAlignment.Center
Subtitle.Parent = TitleBar

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -12, 1, -46)
ContentFrame.Position = UDim2.new(0, 6, 0, 40)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ClipsDescendants = true
ContentFrame.Parent = MainFrame

local LeftColumn = Instance.new("Frame")
LeftColumn.Size = UDim2.new(0.5, -3, 1, 0)
LeftColumn.Position = UDim2.new(0, 0, 0, 0)
LeftColumn.BackgroundTransparency = 1
LeftColumn.Parent = ContentFrame

local LeftLayout = Instance.new("UIListLayout")
LeftLayout.Padding = UDim.new(0, 4)
LeftLayout.SortOrder = Enum.SortOrder.LayoutOrder
LeftLayout.Parent = LeftColumn

local RightColumn = Instance.new("Frame")
RightColumn.Size = UDim2.new(0.5, -3, 1, 0)
RightColumn.Position = UDim2.new(0.5, 3, 0, 0)
RightColumn.BackgroundTransparency = 1
RightColumn.Parent = ContentFrame

local RightLayout = Instance.new("UIListLayout")
RightLayout.Padding = UDim.new(0, 4)
RightLayout.SortOrder = Enum.SortOrder.LayoutOrder
RightLayout.Parent = RightColumn

local FULL_SIZE = UDim2.new(0, 480, 0, 240)
local MIN_SIZE  = UDim2.new(0, 480, 0, 0)
local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function SetMenuOpen(open)
    menuOpen = open
    local targetSize = open and FULL_SIZE or MIN_SIZE
    TweenService:Create(MainFrame, tweenInfo, {Size = targetSize}):Play()
    if open then
        ContentFrame.Visible = true
        TitleBar.Visible = true
    else
        task.delay(0.25, function()
            if not menuOpen then
                ContentFrame.Visible = false
                TitleBar.Visible = false
            end
        end)
    end
end

local function CreateSquareButton(parent, name, text, order, height)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(1, 0, 0, height or 30)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.TextSize = 11
    btn.Font = Enum.Font.GothamBold
    btn.LayoutOrder = order
    btn.Parent = parent
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 0, 0)
    stroke.Thickness = 1
    stroke.Parent = btn
    return btn
end

local AutoParryBlock = Instance.new("Frame")
AutoParryBlock.Size = UDim2.new(1, 0, 0, 100)
AutoParryBlock.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
AutoParryBlock.BorderSizePixel = 0
AutoParryBlock.LayoutOrder = 2
AutoParryBlock.Parent = RightColumn

local BlockCorner = Instance.new("UICorner")
BlockCorner.CornerRadius = UDim.new(0, 4)
BlockCorner.Parent = AutoParryBlock

local BlockStroke = Instance.new("UIStroke")
BlockStroke.Color = Color3.fromRGB(60, 60, 60)
BlockStroke.Thickness = 1
BlockStroke.Parent = AutoParryBlock

local BlockTitle = Instance.new("TextLabel")
BlockTitle.Size = UDim2.new(1, -10, 0, 16)
BlockTitle.Position = UDim2.new(0, 5, 0, 4)
BlockTitle.BackgroundTransparency = 1
BlockTitle.Text = "Auto Parry"
BlockTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
BlockTitle.TextSize = 11
BlockTitle.Font = Enum.Font.GothamBold
BlockTitle.TextXAlignment = Enum.TextXAlignment.Left
BlockTitle.Parent = AutoParryBlock

local AutoParryBtn = Instance.new("TextButton")
AutoParryBtn.Size = UDim2.new(1, -10, 0, 24)
AutoParryBtn.Position = UDim2.new(0, 5, 0, 22)
AutoParryBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
AutoParryBtn.BorderSizePixel = 0
AutoParryBtn.Text = "OFF"
AutoParryBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
AutoParryBtn.TextSize = 11
AutoParryBtn.Font = Enum.Font.GothamBold
AutoParryBtn.Parent = AutoParryBlock

local AutoParryCorner = Instance.new("UICorner")
AutoParryCorner.CornerRadius = UDim.new(0, 4)
AutoParryCorner.Parent = AutoParryBtn

local AutoParryStroke = Instance.new("UIStroke")
AutoParryStroke.Color = Color3.fromRGB(0, 0, 0)
AutoParryStroke.Thickness = 1
AutoParryStroke.Parent = AutoParryBtn

local AccLabel = Instance.new("TextLabel")
AccLabel.Size = UDim2.new(1, -10, 0, 12)
AccLabel.Position = UDim2.new(0, 5, 0, 50)
AccLabel.BackgroundTransparency = 1
AccLabel.Text = ("Acc: %d"):format(accuracyMultiplier)
AccLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
AccLabel.TextSize = 9
AccLabel.Font = Enum.Font.GothamMedium
AccLabel.TextXAlignment = Enum.TextXAlignment.Left
AccLabel.Parent = AutoParryBlock

local AccSlider = Instance.new("TextButton")
AccSlider.Size = UDim2.new(1, -10, 0, 12)
AccSlider.Position = UDim2.new(0, 5, 0, 64)
AccSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
AccSlider.BorderSizePixel = 0
AccSlider.Text = ""
AccSlider.Parent = AutoParryBlock

local AccSliderCorner = Instance.new("UICorner")
AccSliderCorner.CornerRadius = UDim.new(0, 4)
AccSliderCorner.Parent = AccSlider

local AccStroke = Instance.new("UIStroke")
AccStroke.Color = Color3.fromRGB(0, 0, 0)
AccStroke.Thickness = 1
AccStroke.Parent = AccSlider

local AccFill = Instance.new("Frame")
AccFill.Size = UDim2.new(0.1, 0, 1, 0)
AccFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
AccFill.BorderSizePixel = 0
AccFill.Parent = AccSlider

local AccFillCorner = Instance.new("UICorner")
AccFillCorner.CornerRadius = UDim.new(0, 4)
AccFillCorner.Parent = AccFill

local ACC_MIN, ACC_MAX = 0, 200

local function SetAccFromX(x)
    local rel = math.clamp((x - AccSlider.AbsolutePosition.X) / AccSlider.AbsoluteSize.X, 0, 1)
    accuracyMultiplier = math.floor(ACC_MIN + rel * (ACC_MAX - ACC_MIN) + 0.5)
    AccFill.Size = UDim2.new(rel, 0, 1, 0)
    AccLabel.Text = ("Acc: %d"):format(accuracyMultiplier)
end

AccSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        SetAccFromX(input.Position.X)
    end
end)

AccSlider.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        SetAccFromX(input.Position.X)
    end
end)

local AccHint = Instance.new("TextLabel")
AccHint.Size = UDim2.new(1, -10, 0, 10)
AccHint.Position = UDim2.new(0, 5, 0, 78)
AccHint.BackgroundTransparency = 1
AccHint.Text = "0=200-300ms | 200=20-50ms"
AccHint.TextColor3 = Color3.fromRGB(140, 140, 140)
AccHint.TextSize = 8
AccHint.Font = Enum.Font.Gotham
AccHint.TextXAlignment = Enum.TextXAlignment.Left
AccHint.Parent = AutoParryBlock

local AccHint2 = Instance.new("TextLabel")
AccHint2.Size = UDim2.new(1, -10, 0, 10)
AccHint2.Position = UDim2.new(0, 5, 0, 88)
AccHint2.BackgroundTransparency = 1
AccHint2.Text = "low=early | high=late"
AccHint2.TextColor3 = Color3.fromRGB(140, 140, 140)
AccHint2.TextSize = 8
AccHint2.Font = Enum.Font.Gotham
AccHint2.TextXAlignment = Enum.TextXAlignment.Left
AccHint2.Parent = AutoParryBlock

local TriggerBtn = CreateSquareButton(LeftColumn, "TriggerBtn", "Trigger (E): ON", 1, 30)
local ShowTriggerBtn = CreateSquareButton(LeftColumn, "ShowTriggerBtn", "Show Trigger: ON", 2, 30)
local AutoSpamBtn = CreateSquareButton(LeftColumn, "AutoSpamBtn", "Auto Spam: OFF", 3, 30)
local HideMenuBtn = CreateSquareButton(LeftColumn, "HideMenuBtn", "Hide Menu", 4, 30)

local DistanceBlock = Instance.new("Frame")
DistanceBlock.Size = UDim2.new(1, 0, 0, 30)
DistanceBlock.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
DistanceBlock.BorderSizePixel = 0
DistanceBlock.LayoutOrder = 3
DistanceBlock.Parent = LeftColumn

local DistanceCorner = Instance.new("UICorner")
DistanceCorner.CornerRadius = UDim.new(0, 4)
DistanceCorner.Parent = DistanceBlock

local DistanceStroke = Instance.new("UIStroke")
DistanceStroke.Color = Color3.fromRGB(60, 60, 60)
DistanceStroke.Thickness = 1
DistanceStroke.Parent = DistanceBlock

local DistanceLabel = Instance.new("TextLabel")
DistanceLabel.Size = UDim2.new(1, -10, 1, 0)
DistanceLabel.Position = UDim2.new(0, 5, 0, 0)
DistanceLabel.BackgroundTransparency = 1
DistanceLabel.Text = "Ball: -- studs"
DistanceLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
DistanceLabel.TextSize = 10
DistanceLabel.Font = Enum.Font.GothamBold
DistanceLabel.TextXAlignment = Enum.TextXAlignment.Left
DistanceLabel.Parent = DistanceBlock

local StatsBlock = Instance.new("Frame")
StatsBlock.Size = UDim2.new(1, 0, 0, 76)
StatsBlock.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
StatsBlock.BorderSizePixel = 0
StatsBlock.LayoutOrder = 4
StatsBlock.Parent = LeftColumn

local StatsBlockCorner = Instance.new("UICorner")
StatsBlockCorner.CornerRadius = UDim.new(0, 4)
StatsBlockCorner.Parent = StatsBlock

local StatsBlockStroke = Instance.new("UIStroke")
StatsBlockStroke.Color = Color3.fromRGB(60, 60, 60)
StatsBlockStroke.Thickness = 1
StatsBlockStroke.Parent = StatsBlock

local StatsTitle = Instance.new("TextLabel")
StatsTitle.Size = UDim2.new(1, -10, 0, 14)
StatsTitle.Position = UDim2.new(0, 5, 0, 3)
StatsTitle.BackgroundTransparency = 1
StatsTitle.Text = "Stats"
StatsTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
StatsTitle.TextSize = 10
StatsTitle.Font = Enum.Font.GothamBold
StatsTitle.TextXAlignment = Enum.TextXAlignment.Left
StatsTitle.Parent = StatsBlock

local FPSLabel = Instance.new("TextLabel")
FPSLabel.Size = UDim2.new(1, -10, 0, 12)
FPSLabel.Position = UDim2.new(0, 5, 0, 18)
FPSLabel.BackgroundTransparency = 1
FPSLabel.Text = "FPS: 0"
FPSLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
FPSLabel.TextSize = 9
FPSLabel.Font = Enum.Font.Gotham
FPSLabel.TextXAlignment = Enum.TextXAlignment.Left
FPSLabel.Parent = StatsBlock

local PingLabel = Instance.new("TextLabel")
PingLabel.Size = UDim2.new(1, -10, 0, 12)
PingLabel.Position = UDim2.new(0, 5, 0, 30)
PingLabel.BackgroundTransparency = 1
PingLabel.Text = "Ping: 0 ms"
PingLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
PingLabel.TextSize = 9
PingLabel.Font = Enum.Font.Gotham
PingLabel.TextXAlignment = Enum.TextXAlignment.Left
PingLabel.Parent = StatsBlock

local CPULabel = Instance.new("TextLabel")
CPULabel.Size = UDim2.new(1, -10, 0, 12)
CPULabel.Position = UDim2.new(0, 5, 0, 42)
CPULabel.BackgroundTransparency = 1
CPULabel.Text = "CPU: 0%"
CPULabel.TextColor3 = Color3.fromRGB(180, 180, 180)
CPULabel.TextSize = 9
CPULabel.Font = Enum.Font.Gotham
CPULabel.TextXAlignment = Enum.TextXAlignment.Left
CPULabel.Parent = StatsBlock

local MemoryLabel = Instance.new("TextLabel")
MemoryLabel.Size = UDim2.new(1, -10, 0, 12)
MemoryLabel.Position = UDim2.new(0, 5, 0, 54)
MemoryLabel.BackgroundTransparency = 1
MemoryLabel.Text = "Memory: 0 MB"
MemoryLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
MemoryLabel.TextSize = 9
MemoryLabel.Font = Enum.Font.Gotham
MemoryLabel.TextXAlignment = Enum.TextXAlignment.Left
MemoryLabel.Parent = StatsBlock

task.spawn(function()
    local frames = 0
    local lastTime = tick()
    RunService.RenderStepped:Connect(function() frames = frames + 1 end)
    while true do
        task.wait(0.1)
        if hasTargetBall then
            DistanceLabel.Text = ("Ball: %d studs"):format(math.floor(currentBallDistance))
            if currentBallDistance <= AUTO_SPAM_TRIGGER_DISTANCE then
                DistanceLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
            else
                DistanceLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
            end
        else
            DistanceLabel.Text = "Ball: -- (no target)"
            DistanceLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
        end
        local now = tick()
        if now - lastTime >= 1 then
            local elapsed = now - lastTime
            local fps = math.floor(frames / elapsed)
            frames = 0
            lastTime = now
            local cpu = GetCPU() * 100
            local mem = GetMemory()
            local ping = math.floor(GetPing())
            FPSLabel.Text = ("FPS: %d"):format(fps)
            PingLabel.Text = ("Ping: %d ms"):format(ping)
            CPULabel.Text = ("CPU: %.1f%%"):format(cpu)
            MemoryLabel.Text = ("Memory: %d MB"):format(math.floor(mem))
        end
    end
end)

local function UpdateTriggerUI()
    if triggerBotEnabled then
        TriggerBtn.Text = "Trigger (E): ON"
        TriggerBtn.BackgroundColor3 = Color3.fromRGB(220, 255, 220)
        FloatingTriggerBtn.BackgroundColor3 = Color3.fromRGB(220, 255, 220)
    else
        TriggerBtn.Text = "Trigger (E): OFF"
        TriggerBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        FloatingTriggerBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end
end

local function UpdateAutoParryUI()
    if autoParryEnabled then
        AutoParryBtn.Text = "ON"
        AutoParryBtn.BackgroundColor3 = Color3.fromRGB(220, 255, 220)
    else
        AutoParryBtn.Text = "OFF"
        AutoParryBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end
end

local function UpdateAutoSpamUI()
    if autoSpamEnabled then
        AutoSpamBtn.Text = "Auto Spam: ON"
        AutoSpamBtn.BackgroundColor3 = Color3.fromRGB(255, 220, 180)
    else
        AutoSpamBtn.Text = "Auto Spam: OFF"
        AutoSpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end
end

local function UpdateShowTriggerUI()
    if floatingTriggerVisible then
        ShowTriggerBtn.Text = "Show Trigger: ON"
        ShowTriggerBtn.BackgroundColor3 = Color3.fromRGB(220, 255, 220)
    else
        ShowTriggerBtn.Text = "Show Trigger: OFF"
        ShowTriggerBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    end
end

local function ToggleTriggerBot()
    triggerBotEnabled = not triggerBotEnabled
    UpdateTriggerUI()
end

local function ToggleAutoParry()
    autoParryEnabled = not autoParryEnabled
    UpdateAutoParryUI()
end

local function ToggleAutoSpam()
    autoSpamEnabled = not autoSpamEnabled
    UpdateAutoSpamUI()
end

local function ToggleShowTrigger()
    floatingTriggerVisible = not floatingTriggerVisible
    FloatingTriggerBtn.Visible = floatingTriggerVisible
    UpdateShowTriggerUI()
end

TriggerBtn.MouseButton1Click:Connect(ToggleTriggerBot)
AutoParryBtn.MouseButton1Click:Connect(ToggleAutoParry)
AutoSpamBtn.MouseButton1Click:Connect(ToggleAutoSpam)
ShowTriggerBtn.MouseButton1Click:Connect(ToggleShowTrigger)
FloatingTriggerBtn.MouseButton1Click:Connect(ToggleTriggerBot)

HideMenuBtn.MouseButton1Click:Connect(function() SetMenuOpen(false) end)
IconBtn.MouseButton1Click:Connect(function() SetMenuOpen(not menuOpen) end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.E then ToggleTriggerBot() end
end)

UpdateTriggerUI()
UpdateAutoParryUI()
UpdateAutoSpamUI()
UpdateShowTriggerUI()
