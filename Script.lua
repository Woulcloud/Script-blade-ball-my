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
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return nil end
    for _, name in ipairs({"ParryButtonPress", "Parry", "SwordParry", "ParryRemote"}) do
        local r = remotes:FindFirstChild(name)
        if r and r:IsA("RemoteEvent") then
            parryRemote = r
            return r
        end
    end
    for _, r in ipairs(remotes:GetDescendants()) do
        if r:IsA("RemoteEvent") and r.Name:lower():find("parry") then
            parryRemote = r
            return r
        end
    end
    return nil
end

local autoParryEnabled  = false
local triggerBotEnabled = false
local menuOpen          = true
local triggerUIVisible  = true

local AUTO_PARRY_DISTANCE = 20
local TRIGGER_DISTANCE    = 50

local lastParryTime = 0
local PARRY_COOLDOWN = 0.08
local lastParrySent = 0
local parryCount = 0

local parried_balls, triggered_balls = {}, {}
local triggerConnections = {}

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

-- === АНИМАЦИЯ ===
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
            if anim then
                AnimFix_Cache[swordName] = anim
                return anim
            end
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

    if Loaded_Tracks[currentSword] then
        return Loaded_Tracks[currentSword]
    end

    local animation = GetParryAnimation(currentSword)
    if not animation then return nil end

    local ok, track = pcall(function()
        return animator:LoadAnimation(animation)
    end)

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

-- === ПАРИНГ ===
local function Parry(source)
    local now = tick()

    if source == "auto" and now - lastParryTime < PARRY_COOLDOWN then
        return
    end

    lastParryTime = now

    local remote = GetParryRemote()
    if not remote then return end

    pcall(function()
        remote:FireServer()
        lastParrySent = tick()
        parryCount = parryCount + 1
    end)

    task.spawn(PlayGrabParry)
end

-- === TRIGGER BOT ===
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

        if triggered_balls[bID] then return end
        triggered_balls[bID] = true
        parried_balls[bID] = true

        Parry("auto")
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

for _, ball in ipairs(Balls:GetChildren()) do
    BindTriggerBot(ball)
end

Balls.ChildAdded:Connect(function(ball)
    BindTriggerBot(ball)
end)

workspace.ChildAdded:Connect(function(child)
    if child.Name == "Balls" then
        task.wait(0.2)
        for _, ball in ipairs(child:GetChildren()) do
            BindTriggerBot(ball)
        end
        child.ChildAdded:Connect(function(ball)
            BindTriggerBot(ball)
        end)
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

-- === AUTO PARRY ===
local function GetRealBalls()
    local out = {}
    for _, ball in ipairs(Balls:GetChildren()) do
        if ball:GetAttribute("realBall") == true then
            table.insert(out, ball)
        end
    end
    return out
end

local function ProcessAutoParry(ball, charPart)
    if not autoParryEnabled then return end

    local bID = ball:GetDebugId()
    if ball:GetAttribute("target") ~= Player.Name or parried_balls[bID] then return end

    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return end

    local velocity = zoomies.VectorVelocity
    local dist = (charPart.Position - ball.Position).Magnitude

    if dist <= AUTO_PARRY_DISTANCE then
        parried_balls[bID] = true
        Parry("auto")
        ball:GetAttributeChangedSignal("target"):Once(function()
            parried_balls[bID] = nil
        end)
    end
end

RunService.Heartbeat:Connect(function()
    local char = Player.Character
    local charPart = char and char:FindFirstChild("HumanoidRootPart")
    if not charPart then return end

    if autoParryEnabled then
        for _, ball in ipairs(GetRealBalls()) do
            ProcessAutoParry(ball, charPart)
        end
    end

    if triggerBotEnabled then
        for _, ball in ipairs(GetRealBalls()) do
            local bID = ball:GetDebugId()
            if ball:GetAttribute("target") == Player.Name and not triggered_balls[bID] then
                local dist = (charPart.Position - ball.Position).Magnitude
                if dist <= TRIGGER_DISTANCE then
                    triggered_balls[bID] = true
                    parried_balls[bID] = true
                    Parry("auto")
                end
            end
        end
    end
end)

Player.CharacterAdded:Connect(function()
    Loaded_Tracks = {}
    parried_balls = {}
    triggered_balls = {}
    LastPlayedTrack = nil
    lastParryTime = 0
    triggerConnections = {}

    task.spawn(function()
        task.wait(0.3)
        for _, ball in ipairs(Balls:GetChildren()) do
            BindTriggerBot(ball)
        end
    end)
end)

ShowNotification("I See You", "Script loaded and active!", 3)

-- === UI ===
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ISeeYouMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 270, 0, 270)
MainFrame.Position = UDim2.new(0, 20, 0, 80)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
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
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 28)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.BorderSizePixel = 0
Title.Text = "  I See You"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = Title

-- === STATUS INDICATOR (в заголовке) ===
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(0, 80, 0, 28)
StatusLabel.Position = UDim2.new(1, -120, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "● IDLE"
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextXAlignment = Enum.TextXAlignment.Right
StatusLabel.Parent = Title

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 28, 0, 20)
ToggleBtn.Position = UDim2.new(1, -34, 0, 4)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "-"
ToggleBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
ToggleBtn.TextSize = 14
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = Title

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 5)
ToggleCorner.Parent = ToggleBtn

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "Content"
ContentFrame.Size = UDim2.new(1, -16, 1, -38)
ContentFrame.Position = UDim2.new(0, 8, 0, 32)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ClipsDescendants = true
ContentFrame.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 4)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ContentFrame

local FULL_SIZE = UDim2.new(0, 270, 0, 270)
local MIN_SIZE  = UDim2.new(0, 270, 0, 28)

local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function SetMenuOpen(open)
    menuOpen = open
    local targetSize = open and FULL_SIZE or MIN_SIZE
    TweenService:Create(MainFrame, tweenInfo, {Size = targetSize}):Play()
    if open then
        ContentFrame.Visible = true
        ToggleBtn.Text = "-"
    else
        task.delay(0.25, function()
            if not menuOpen then
                ContentFrame.Visible = false
            end
        end)
        ToggleBtn.Text = "[]"
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    SetMenuOpen(not menuOpen)
end)

local function CreateButton(name, order)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Btn"
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.Text = name .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamMedium
    btn.LayoutOrder = order
    btn.AutoButtonColor = true
    btn.Parent = ContentFrame

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = btn

    return btn
end

local AutoParryBtn  = CreateButton("Auto Parry", 1)
local TriggerBotBtn = CreateButton("Trigger Bot", 2)

-- === AUTO PARRY DISTANCE SLIDER ===
local AutoParryDistLabel = Instance.new("TextLabel")
AutoParryDistLabel.Size = UDim2.new(1, 0, 0, 16)
AutoParryDistLabel.BackgroundTransparency = 1
AutoParryDistLabel.Text = ("Auto Parry Distance: %d"):format(AUTO_PARRY_DISTANCE)
AutoParryDistLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoParryDistLabel.TextSize = 11
AutoParryDistLabel.Font = Enum.Font.GothamMedium
AutoParryDistLabel.LayoutOrder = 3
AutoParryDistLabel.Parent = ContentFrame

local AutoParryDistSlider = Instance.new("TextButton")
AutoParryDistSlider.Size = UDim2.new(1, 0, 0, 16)
AutoParryDistSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
AutoParryDistSlider.BorderSizePixel = 0
AutoParryDistSlider.Text = ""
AutoParryDistSlider.LayoutOrder = 4
AutoParryDistSlider.Parent = ContentFrame

local AutoParryDistCorner = Instance.new("UICorner")
AutoParryDistCorner.CornerRadius = UDim.new(0, 5)
AutoParryDistCorner.Parent = AutoParryDistSlider

local AutoParryDistFill = Instance.new("Frame")
AutoParryDistFill.Size = UDim2.new(0.4, 0, 1, 0)
AutoParryDistFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
AutoParryDistFill.BorderSizePixel = 0
AutoParryDistFill.Parent = AutoParryDistSlider

local AutoParryDistFillCorner = Instance.new("UICorner")
AutoParryDistFillCorner.CornerRadius = UDim.new(0, 5)
AutoParryDistFillCorner.Parent = AutoParryDistFill

local APD_MIN, APD_MAX = 5, 50

local function SetAutoParryDistFromX(x)
    local rel = math.clamp((x - AutoParryDistSlider.AbsolutePosition.X) / AutoParryDistSlider.AbsoluteSize.X, 0, 1)
    AUTO_PARRY_DISTANCE = math.floor(APD_MIN + rel * (APD_MAX - APD_MIN) + 0.5)
    AutoParryDistFill.Size = UDim2.new(rel, 0, 1, 0)
    AutoParryDistLabel.Text = ("Auto Parry Distance: %d"):format(AUTO_PARRY_DISTANCE)
end

AutoParryDistSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        SetAutoParryDistFromX(input.Position.X)
    end
end)

AutoParryDistSlider.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        SetAutoParryDistFromX(input.Position.X)
    end
end)

-- === TRIGGER DISTANCE SLIDER ===
local TriggerDistLabel = Instance.new("TextLabel")
TriggerDistLabel.Size = UDim2.new(1, 0, 0, 16)
TriggerDistLabel.BackgroundTransparency = 1
TriggerDistLabel.Text = ("Trigger Distance: %d"):format(TRIGGER_DISTANCE)
TriggerDistLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TriggerDistLabel.TextSize = 11
TriggerDistLabel.Font = Enum.Font.GothamMedium
TriggerDistLabel.LayoutOrder = 5
TriggerDistLabel.Parent = ContentFrame

local TriggerDistSlider = Instance.new("TextButton")
TriggerDistSlider.Size = UDim2.new(1, 0, 0, 16)
TriggerDistSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
TriggerDistSlider.BorderSizePixel = 0
TriggerDistSlider.Text = ""
TriggerDistSlider.LayoutOrder = 6
TriggerDistSlider.Parent = ContentFrame

local TriggerDistCorner = Instance.new("UICorner")
TriggerDistCorner.CornerRadius = UDim.new(0, 5)
TriggerDistCorner.Parent = TriggerDistSlider

local TriggerDistFill = Instance.new("Frame")
TriggerDistFill.Size = UDim2.new(1.0, 0, 1, 0)
TriggerDistFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TriggerDistFill.BorderSizePixel = 0
TriggerDistFill.Parent = TriggerDistSlider

local TriggerDistFillCorner = Instance.new("UICorner")
TriggerDistFillCorner.CornerRadius = UDim.new(0, 5)
TriggerDistFillCorner.Parent = TriggerDistFill

local TD_MIN, TD_MAX = 5, 50

local function SetTriggerDistFromX(x)
    local rel = math.clamp((x - TriggerDistSlider.AbsolutePosition.X) / TriggerDistSlider.AbsoluteSize.X, 0, 1)
    TRIGGER_DISTANCE = math.floor(TD_MIN + rel * (TD_MAX - TD_MIN) + 0.5)
    TriggerDistFill.Size = UDim2.new(rel, 0, 1, 0)
    TriggerDistLabel.Text = ("Trigger Distance: %d"):format(TRIGGER_DISTANCE)
end

TriggerDistSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        SetTriggerDistFromX(input.Position.X)
    end
end)

TriggerDistSlider.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        SetTriggerDistFromX(input.Position.X)
    end
end)

local ShowTriggerBotBtn = CreateButton("Show Trigger Bot", 7)

-- === LIVE STATUS PANEL ===
local StatusInfo = Instance.new("TextLabel")
StatusInfo.Size = UDim2.new(1, 0, 0, 14)
StatusInfo.BackgroundTransparency = 1
StatusInfo.Text = "Remote: searching..."
StatusInfo.TextColor3 = Color3.fromRGB(180, 180, 180)
StatusInfo.TextSize = 10
StatusInfo.Font = Enum.Font.Gotham
StatusInfo.TextXAlignment = Enum.TextXAlignment.Left
StatusInfo.LayoutOrder = 8
StatusInfo.Parent = ContentFrame

local StatsInfo = Instance.new("TextLabel")
StatsInfo.Size = UDim2.new(1, 0, 0, 14)
StatsInfo.BackgroundTransparency = 1
StatsInfo.Text = "Parries: 0 | Ping: --"
StatsInfo.TextColor3 = Color3.fromRGB(180, 180, 180)
StatsInfo.TextSize = 10
StatsInfo.Font = Enum.Font.Gotham
StatsInfo.TextXAlignment = Enum.TextXAlignment.Left
StatsInfo.LayoutOrder = 9
StatsInfo.Parent = ContentFrame

-- Цикл обновления статуса
task.spawn(function()
    while true do
        task.wait(0.5)

        local remote = GetParryRemote()
        local now = tick()

        -- Определяем статус
        local statusText, statusColor

        if not Balls or not Balls.Parent then
            statusText = "● FAIL"
            statusColor = Color3.fromRGB(255, 80, 80)
            StatusInfo.Text = "Balls folder missing"
        elseif not remote then
            statusText = "● WAIT"
            statusColor = Color3.fromRGB(255, 200, 80)
            StatusInfo.Text = "Remote not found — do 1 manual parry"
        elseif not autoParryEnabled and not triggerBotEnabled then
            statusText = "● IDLE"
            statusColor = Color3.fromRGB(150, 150, 150)
            StatusInfo.Text = "Remote: " .. remote.Name .. " (ready)"
        elseif (now - lastParrySent) < 3 then
            statusText = "● WORK"
            statusColor = Color3.fromRGB(80, 255, 80)
            StatusInfo.Text = "Remote: " .. remote.Name .. " (active)"
        else
            statusText = "● READY"
            statusColor = Color3.fromRGB(120, 200, 255)
            StatusInfo.Text = "Remote: " .. remote.Name .. " (waiting for ball)"
        end

        StatusLabel.Text = statusText
        StatusLabel.TextColor3 = statusColor

        StatsInfo.Text = ("Parries: %d | Ping: %d ms"):format(parryCount, math.floor(GetPing()))
    end
end)

-- === FLOATING TRIGGER ===
local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Name = "FloatingTriggerBot"
FloatingBtn.Size = UDim2.new(0, 130, 0, 40)
FloatingBtn.Position = UDim2.new(0, 20, 0, 370)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
FloatingBtn.BorderSizePixel = 0
FloatingBtn.Text = "TRIGGER: OFF"
FloatingBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
FloatingBtn.TextSize = 13
FloatingBtn.Font = Enum.Font.GothamBold
FloatingBtn.Active = true
FloatingBtn.Draggable = true
FloatingBtn.Visible = true
FloatingBtn.Parent = ScreenGui

local FloatingCorner = Instance.new("UICorner")
FloatingCorner.CornerRadius = UDim.new(0, 8)
FloatingCorner.Parent = FloatingBtn

ShowTriggerBotBtn.MouseButton1Click:Connect(function()
    triggerUIVisible = not triggerUIVisible
    FloatingBtn.Visible = triggerUIVisible
    ShowTriggerBotBtn.Text = "Show Trigger Bot: " .. (triggerUIVisible and "ON" or "OFF")
    ShowTriggerBotBtn.BackgroundColor3 = triggerUIVisible and Color3.fromRGB(180, 255, 180) or Color3.fromRGB(255, 255, 255)
end)
ShowTriggerBotBtn.Text = "Show Trigger Bot: ON"
ShowTriggerBotBtn.BackgroundColor3 = Color3.fromRGB(180, 255, 180)

local function UpdateTriggerUI()
    local state = triggerBotEnabled and "ON" or "OFF"
    TriggerBotBtn.Text = "Trigger Bot: " .. state
    TriggerBotBtn.BackgroundColor3 = triggerBotEnabled and Color3.fromRGB(180, 255, 180) or Color3.fromRGB(255, 255, 255)
    FloatingBtn.Text = "TRIGGER: " .. state
    FloatingBtn.BackgroundColor3 = triggerBotEnabled and Color3.fromRGB(180, 255, 180) or Color3.fromRGB(255, 255, 255)
end

AutoParryBtn.MouseButton1Click:Connect(function()
    autoParryEnabled = not autoParryEnabled
    AutoParryBtn.Text = "Auto Parry: " .. (autoParryEnabled and "ON" or "OFF")
    AutoParryBtn.BackgroundColor3 = autoParryEnabled and Color3.fromRGB(180, 255, 180) or Color3.fromRGB(255, 255, 255)
end)

TriggerBotBtn.MouseButton1Click:Connect(function()
    triggerBotEnabled = not triggerBotEnabled
    UpdateTriggerUI()
end)

FloatingBtn.MouseButton1Click:Connect(function()
    triggerBotEnabled = not triggerBotEnabled
    UpdateTriggerUI()
end)
