local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats             = game:GetService("Stats")
local TweenService      = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Balls  = workspace:WaitForChild("Balls")

local hook = rawget(getfenv(), "hookfunction")
    or (getgenv and getgenv().hookfunction)
    or rawget(_G, "hookfunction")
    or (hookfunction ~= nil and hookfunction)

local HASH = "5455ef47-de02-4074-808c-8d82c2cd12ec"
local byte, char      = string.byte, string.char
local floor, bxor     = math.floor, bit32.bxor

local captured, votes, key = {}, {}, nil
local lastCaptureTime = 0

local parried_balls, triggered_balls = {}, {}
local triggerConnections = {}

local autoParryEnabled  = false
local triggerBotEnabled = false
local menuOpen          = true
local triggerUIVisible  = true

local accuracyMultiplier = 10

local lastParryTime = 0
local PARRY_COOLDOWN = 0.05
local lastParrySent = 0
local parryCount = 0

local cachedPing = 100
local lastPingUpdate = 0
local PING_UPDATE_INTERVAL = 1.0

local INSTANT_PARRY_DISTANCE = 40

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
    local now = tick()
    if now - lastPingUpdate > PING_UPDATE_INTERVAL then
        lastPingUpdate = now
        local ok, result = pcall(function()
            return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
        end)
        cachedPing = ok and result or 100
    end
    return cachedPing
end

local function GetPingHint()
    local ping = GetPing()
    if ping >= 200 then return " (high ping)"
    elseif ping >= 100 then return " (mid ping)"
    else return " (low ping)"
    end
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

            local oldKey = captured.sessionKey
            captured = {
                remote     = self,
                sessionKey = args[2],
                token      = args[3],
                timing     = args[4],
                tailBool   = args[8],
            }
            lastCaptureTime = tick()
            learn(args[3], timestamp())

            if oldKey ~= args[2] then
                parried_balls = {}
                triggered_balls = {}
            end

            return fire(self, ...)
        end)
    end)
end

local function replay()
    if not fire or not captured.remote or not captured.sessionKey then return end
    local token = makeToken()
    if not token then return end

    local camera = workspace.CurrentCamera
    if not camera then return end

    local points = {}
    local alive = workspace:FindFirstChild("Alive")
    if alive then
        for _, character in ipairs(alive:GetChildren()) do
            local root = character:FindFirstChild("HumanoidRootPart")
            if root then
                points[character.Name] = camera:WorldToScreenPoint(root.Position)
            end
        end
    end

    local mouse = UserInputService:GetMouseLocation()
    local timing = captured.timing or 0.5
    local tail   = captured.tailBool or false

    fire(captured.remote, HASH, captured.sessionKey, token, timing, camera.CFrame, points, { mouse.X, mouse.Y }, tail)
end

local function Parry(source)
    if not captured.remote or not captured.sessionKey then return end
    if not captured.remote.Parent then
        captured.remote = nil
        captured.sessionKey = nil
        return
    end

    local now = tick()

    if now - lastParryTime < PARRY_COOLDOWN then
        return
    end

    lastParryTime = now
    replay()
    lastParrySent = now
    parryCount = parryCount + 1

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

        Parry("instant")
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
    if ball:GetAttribute("target") ~= Player.Name then return end
    if parried_balls[bID] then return end

    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return end

    local velocity = zoomies.VectorVelocity
    local dist = (charPart.Position - ball.Position).Magnitude
    local ping = GetPing()
    local rawSpeed = velocity.Magnitude

    local accuracyFactor = 1 - (accuracyMultiplier / 100)

    local pingSeconds = ping / 1000
    local pingDistance = rawSpeed * pingSeconds

    local pingCompensation = pingDistance * (1.0 + accuracyFactor * 2.0)
    local accuracyBoost = 30 + accuracyFactor * 70
    local baseDistance = 15

    local targetDistance = baseDistance + pingCompensation + accuracyBoost

    if dist <= targetDistance then
        parried_balls[bID] = true
        Parry("auto")
        ball:GetAttributeChangedSignal("target"):Once(function()
            parried_balls[bID] = nil
        end)
    end
end

RunService.RenderStepped:Connect(function()
    local char = Player.Character
    local charPart = char and char:FindFirstChild("HumanoidRootPart")
    if not charPart then return end

    local balls = GetRealBalls()

    if autoParryEnabled then
        for _, ball in ipairs(balls) do
            ProcessAutoParry(ball, charPart)
        end
    end

    if triggerBotEnabled then
        for _, ball in ipairs(balls) do
            local bID = ball:GetDebugId()
            if ball:GetAttribute("target") == Player.Name and not triggered_balls[bID] then
                local dist = (charPart.Position - ball.Position).Magnitude
                if dist <= INSTANT_PARRY_DISTANCE then
                    triggered_balls[bID] = true
                    Parry("instant")
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

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ISeeYouMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 270, 0, 280)
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

local FULL_SIZE = UDim2.new(0, 270, 0, 280)
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

local SliderLabel = Instance.new("TextLabel")
SliderLabel.Size = UDim2.new(1, 0, 0, 16)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Text = ("Accuracy: %d%s"):format(accuracyMultiplier, GetPingHint())
SliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SliderLabel.TextSize = 11
SliderLabel.Font = Enum.Font.GothamMedium
SliderLabel.LayoutOrder = 3
SliderLabel.Parent = ContentFrame

local SliderHint = Instance.new("TextLabel")
SliderHint.Size = UDim2.new(1, 0, 0, 12)
SliderHint.BackgroundTransparency = 1
SliderHint.Text = "1 = high ping, 100 = low ping"
SliderHint.TextColor3 = Color3.fromRGB(160, 160, 160)
SliderHint.TextSize = 10
SliderHint.Font = Enum.Font.Gotham
SliderHint.LayoutOrder = 3
SliderHint.Parent = ContentFrame

local Slider = Instance.new("TextButton")
Slider.Size = UDim2.new(1, 0, 0, 16)
Slider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
Slider.BorderSizePixel = 0
Slider.Text = ""
Slider.LayoutOrder = 4
Slider.Parent = ContentFrame

local SliderCorner = Instance.new("UICorner")
SliderCorner.CornerRadius = UDim.new(0, 5)
SliderCorner.Parent = Slider

local ACC_MIN, ACC_MAX = 1, 100

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(0.09, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = Slider

local SliderFillCorner = Instance.new("UICorner")
SliderFillCorner.CornerRadius = UDim.new(0, 5)
SliderFillCorner.Parent = SliderFill

local function SetSliderFromX(x)
    local rel = math.clamp((x - Slider.AbsolutePosition.X) / Slider.AbsoluteSize.X, 0, 1)
    accuracyMultiplier = math.floor(ACC_MIN + rel * (ACC_MAX - ACC_MIN) + 0.5)
    SliderFill.Size = UDim2.new(rel, 0, 1, 0)
    SliderLabel.Text = ("Accuracy: %d%s"):format(accuracyMultiplier, GetPingHint())
end

Slider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        SetSliderFromX(input.Position.X)
    end
end)

Slider.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        SetSliderFromX(input.Position.X)
    end
end)

local ShowTriggerBotBtn = CreateButton("Show Trigger Bot", 5)

local StatusInfo = Instance.new("TextLabel")
StatusInfo.Size = UDim2.new(1, 0, 0, 14)
StatusInfo.BackgroundTransparency = 1
StatusInfo.Text = "Waiting for parry..."
StatusInfo.TextColor3 = Color3.fromRGB(180, 180, 180)
StatusInfo.TextSize = 10
StatusInfo.Font = Enum.Font.Gotham
StatusInfo.TextXAlignment = Enum.TextXAlignment.Left
StatusInfo.LayoutOrder = 6
StatusInfo.Parent = ContentFrame

local StatsInfo = Instance.new("TextLabel")
StatsInfo.Size = UDim2.new(1, 0, 0, 14)
StatsInfo.BackgroundTransparency = 1
StatsInfo.Text = "Parries: 0 | Ping: --"
StatsInfo.TextColor3 = Color3.fromRGB(180, 180, 180)
StatsInfo.TextSize = 10
StatsInfo.Font = Enum.Font.Gotham
StatsInfo.TextXAlignment = Enum.TextXAlignment.Left
StatsInfo.LayoutOrder = 7
StatsInfo.Parent = ContentFrame

task.spawn(function()
    while true do
        task.wait(0.5)

        local now = tick()
        local statusText, statusColor

        if not Balls or not Balls.Parent then
            statusText = "● FAIL"
            statusColor = Color3.fromRGB(255, 80, 80)
            StatusInfo.Text = "Balls folder missing"
        elseif not captured.sessionKey then
            statusText = "● WAIT"
            statusColor = Color3.fromRGB(255, 200, 80)
            StatusInfo.Text = "Do 1 manual parry to catch token"
        elseif not autoParryEnabled and not triggerBotEnabled then
            statusText = "● IDLE"
            statusColor = Color3.fromRGB(150, 150, 150)
            StatusInfo.Text = "Token: OK (ready)"
        elseif (now - lastParrySent) < 3 then
            statusText = "● WORK"
            statusColor = Color3.fromRGB(80, 255, 80)
            StatusInfo.Text = "Token: OK (active)"
        else
            statusText = "● READY"
            statusColor = Color3.fromRGB(120, 200, 255)
            StatusInfo.Text = "Token: OK (waiting)"
        end

        StatusLabel.Text = statusText
        StatusLabel.TextColor3 = statusColor
        StatsInfo.Text = ("Parries: %d | Ping: %d ms"):format(parryCount, math.floor(GetPing()))
    end
end)

local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Name = "FloatingTriggerBot"
FloatingBtn.Size = UDim2.new(0, 130, 0, 40)
FloatingBtn.Position = UDim2.new(0, 20, 0, 380)
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
