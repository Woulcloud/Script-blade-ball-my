repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatsService = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local SwordAPI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SwordAPI")
local player = Players.LocalPlayer

local BLACK = Color3.fromRGB(15, 15, 15)
local BLACK_UI = Color3.fromRGB(20, 20, 20)
local WHITE = Color3.fromRGB(255, 255, 255)

local cfg = {
    parry = true,
    spam = false,
    trigger = false,
    accuracy = 3.3,
    animfix = true,
    showStats = true,
    curveType = 'straight',
    showBindWindow = false
}

local spamBindKey = "P"
local isWaitingForBind = false
local parried_balls = {}
local triggered_balls = {}
local AnimationCache = {}
local spamActive = false

local hook = hookfunction or (getgenv and getgenv().hookfunction)
local HASH = "5455ef47-de02-4074-808c-8d82c2cd12ec"
local byte, char = string.byte, string.char
local floor, bxor = math.floor, bit32.bxor
local captured, votes, key = {}, {}, nil

local function timestamp()
    return tostring(floor(workspace:GetServerTimeNow() * 100))
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
    if not key then return end
    local stamp = timestamp()
    local token = {}
    for i = 1, #stamp do
        local value = key[i] or key[#key]
        if not value then return end
        token[i] = char(bxor((byte(stamp, i) + i) % 256, value))
    end
    return table.concat(token)
end

local function getTail()
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
    return captured.timing or 0.5, camera.CFrame, points, { mouse.X, mouse.Y }, captured.tailBool or false
end

local fire
local function replay()
    local token = makeToken()
    if not captured.remote or not captured.sessionKey or not token then return end
    local timing, camera, points, mouse, tail = getTail()
    if not timing then return end
    fire(captured.remote, HASH, captured.sessionKey, token, timing, camera, points, mouse, tail)
end

if hook then
    fire = hook(Instance.new("RemoteEvent").FireServer, function(self, ...)
        local args = table.pack(...)
        if args[1] ~= HASH or type(args[3]) ~= "string" then
            return fire(self, ...)
        end
        captured = {
            remote = self,
            sessionKey = args[2],
            token = args[3],
            timing = args[4],
            tailBool = args[8],
            args = args
        }
        learn(args[3], timestamp())
        return fire(self, ...)
    end)
end

local ballStats = { current = 0, peak = 0 }
local statsFrame = nil
local currentLabel = nil

local function GetBallSpeed()
    for _, v in pairs(workspace.Balls:GetChildren()) do
        if v:GetAttribute("realBall") then
            if v.Velocity then
                return v.Velocity.Magnitude
            end
            local z = v:FindFirstChild("zoomies")
            if z and z:FindFirstChild("VectorVelocity") then
                return z.VectorVelocity.Magnitude
            end
        end
    end
    return 0
end

local function UpdateBallStats()
    local speed = GetBallSpeed()
    ballStats.current = math.floor(speed)
    if speed > ballStats.peak then
        ballStats.peak = math.floor(speed)
    end
    if statsFrame and statsFrame.Visible and currentLabel then
        currentLabel.Text = "Velocity " .. ballStats.current .. " | Peak " .. ballStats.peak
    end
end

local lastBallId = nil
task.spawn(function()
    while true do
        local newId = nil
        for _, v in pairs(workspace.Balls:GetChildren()) do
            if v:GetAttribute("realBall") then
                newId = v:GetDebugId()
                break
            end
        end
        if newId and newId ~= lastBallId then
            ballStats.peak = 0
            lastBallId = newId
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    while true do
        if cfg.showStats and statsFrame and statsFrame.Visible then
            UpdateBallStats()
        end
        task.wait(0.05)
    end
end)

local function GetPing()
    local success, result = pcall(function()
        return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return success and result or 100
end

local Lerp_Radians = 0
local Last_Warping = tick()

local function Is_Curved(ball)
    local Zoomies = ball:FindFirstChild("zoomies")
    if not Zoomies then
        return false
    end
    local Velocity = Zoomies.VectorVelocity
    local Character = player.Character
    if not Character or not Character.PrimaryPart then
        return false
    end
    local distanceToBall = (Character.PrimaryPart.Position - ball.Position).Magnitude
    if distanceToBall <= 25 then
        return false
    end
    local Speed = Velocity.Magnitude
    local Direction = (Character.PrimaryPart.Position - ball.Position).Unit
    local Dot = Direction:Dot(Velocity.Unit)
    local Ping = GetPing() / 1000
    local Distance = (Character.PrimaryPart.Position - ball.Position).Magnitude
    local Reach_Time = Distance / Speed - Ping
    local Radians = math.rad(math.asin(math.clamp(Dot, -1, 1)))
    Lerp_Radians = Lerp_Radians + (Radians - Lerp_Radians) * 0.8
    if Lerp_Radians < 0.018 then
        Last_Warping = tick()
    end
    if (tick() - Last_Warping) < (Reach_Time / 1.5) then
        return true
    end
    return Dot < (0.5 - Ping)
end

local function GetParryAnimation()
    local char = player.Character
    local currentSword = char and char:GetAttribute("CurrentlyEquippedSword")
    if not currentSword then
        return SwordAPI.Collection.Default:FindFirstChild("GrabParry")
    end
    if AnimationCache[currentSword] then
        return AnimationCache[currentSword]
    end
    local success, swordData = pcall(function()
        return ReplicatedStorage.Shared.ReplicatedInstances.Swords.GetSword:Invoke(currentSword)
    end)
    if success and type(swordData) == "table" then
        for _, obj in pairs(SwordAPI.Collection:GetChildren()) do
            if obj.Name == swordData.AnimationType then
                local anim = obj:FindFirstChild("GrabParry") or obj:FindFirstChild("Grab")
                if anim then
                    AnimationCache[currentSword] = anim
                    return anim
                end
            end
        end
    end
    return SwordAPI.Collection.Default:FindFirstChild("GrabParry")
end

local function PlayParryAnimation()
    if not cfg.animfix then
        return
    end
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not hum or not hum:FindFirstChild("Animator") then
        return
    end
    local animation = GetParryAnimation()
    if not animation then
        return
    end
    for _, track in pairs(hum.Animator:GetPlayingAnimationTracks()) do
        if track.Name:find("Grab") or track.Name:find("Parry") then
            track:Stop(0.1)
        end
    end
    local track = hum.Animator:LoadAnimation(animation)
    track:Play(0, 1, 1)
end

local function ApplyCurveToCFrame(baseCFrame)
    if not cfg.curveType or cfg.curveType == 'straight' then
        return baseCFrame
    end
    local rotation = CFrame.new()
    if cfg.curveType == 'backwards' then
        rotation = CFrame.Angles(0, math.rad(180), 0)
    elseif cfg.curveType == 'down' then
        rotation = CFrame.Angles(math.rad(-45), 0, 0)
    elseif cfg.curveType == 'up' then
        rotation = CFrame.Angles(math.rad(45), 0, 0)
    elseif cfg.curveType == 'left' then
        rotation = CFrame.Angles(0, math.rad(-90), 0)
    elseif cfg.curveType == 'right' then
        rotation = CFrame.Angles(0, math.rad(90), 0)
    elseif cfg.curveType == 'random' then
        local randomAngle = math.random() * math.pi * 2
        rotation = CFrame.Angles(0, randomAngle, 0)
    end
    return baseCFrame * rotation
end

local function GetParryData()
    local viewportSize = Camera.ViewportSize
    local centerPos = { viewportSize.X / 2, viewportSize.Y / 2 }
    local events = {}
    for _, v in pairs(workspace.Alive:GetChildren()) do
        if v ~= player.Character and v:FindFirstChild("HumanoidRootPart") then
            local screenPos, isOnScreen = Camera:WorldToScreenPoint(v.HumanoidRootPart.Position)
            if isOnScreen then
                events[tostring(v)] = screenPos
            end
        end
    end
    return Camera.CFrame, events, centerPos
end

local function SendParry()
    if not captured.remote or not captured.sessionKey then
        return false
    end
    local camCF, events, mousePos = GetParryData()
    local modifiedCF = ApplyCurveToCFrame(camCF)
    local token = makeToken()
    if not token then return false end
    local success, err = pcall(function()
        fire(
            captured.remote,
            HASH,
            captured.sessionKey,
            token,
            0.025,
            modifiedCF,
            events,
            mousePos,
            false
        )
    end)
    if success and cfg.animfix then
        task.spawn(PlayParryAnimation)
    end
    return success
end

local function ProcessAutoParry(ball)
    if not cfg.parry or spamActive then
        return
    end
    local bID = ball:GetDebugId()
    if ball:GetAttribute("target") ~= player.Name or parried_balls[bID] then
        return
    end
    if Is_Curved(ball) then
        return
    end
    local charPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not charPart then
        return
    end
    local velocity = ball.zoomies.VectorVelocity
    local ballPos = ball.Position
    local playerPos = charPart.Position
    local dist = (playerPos - ballPos).Magnitude
    local ping = GetPing()
    local threshold = (velocity.Magnitude / cfg.accuracy) + (ping / 10)
    if dist <= threshold or dist <= 20 then
        parried_balls[bID] = true
        SendParry()
        ball:GetAttributeChangedSignal("target"):Once(function()
            parried_balls[bID] = nil
        end)
    end
end

local function ProcessTriggerBot(ball)
    if not cfg.trigger or spamActive then
        return
    end
    local bID = ball:GetDebugId()
    if ball:GetAttribute("target") == player.Name and not triggered_balls[bID] then
        triggered_balls[bID] = true
        SendParry()
        ball:GetAttributeChangedSignal("target"):Once(function()
            triggered_balls[bID] = nil
        end)
    end
end

RunService.Heartbeat:Connect(function()
    if spamActive and captured.remote then
        SendParry()
    end
end)

local BindButton = nil
local StatusBtn = nil

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end
    if isWaitingForBind then
        local key = input.KeyCode.Name
        if key ~= "Unknown" then
            spamBindKey = key
            isWaitingForBind = false
            if BindButton then
                BindButton.Text = "[ " .. spamBindKey .. " ]"
                BindButton.BackgroundColor3 = WHITE
                BindButton.TextColor3 = BLACK
            end
        end
        return
    end
    if input.KeyCode.Name == spamBindKey then
        spamActive = not spamActive
        if StatusBtn then
            StatusBtn.Text = spamActive and "SPAM" or "ON"
            StatusBtn.BackgroundColor3 = WHITE
            StatusBtn.TextColor3 = BLACK
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if not captured.remote then
        return
    end
    local ball = nil
    for _, v in pairs(workspace.Balls:GetChildren()) do
        if v:GetAttribute("realBall") then
            ball = v
            break
        end
    end
    if ball then
        if spamActive then
        elseif cfg.trigger then
            ProcessTriggerBot(ball)
        elseif cfg.parry then
            ProcessAutoParry(ball)
        end
    end
end)

ReplicatedStorage.Remotes.ParrySuccess.OnClientEvent:Connect(function()
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not hum or not hum:FindFirstChild("Animator") then
        return
    end
    for _, track in pairs(hum.Animator:GetPlayingAnimationTracks()) do
        if track.Name:find("Grab") or track.Name:find("Parry") then
            track:Stop(0.1)
        end
    end
end)

local ScreenGui = Instance.new("ScreenGui", game.CoreGui)

local function MakeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local BindFrame = Instance.new("Frame", ScreenGui)
BindFrame.Size = UDim2.new(0, 100, 0, 40)
BindFrame.Position = UDim2.new(0.5, -50, 0.25, 0)
BindFrame.BackgroundColor3 = BLACK_UI
BindFrame.BackgroundTransparency = 0.1
BindFrame.Visible = false
Instance.new("UICorner", BindFrame).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", BindFrame).Color = WHITE
MakeDraggable(BindFrame)

local BindLabel = Instance.new("TextLabel", BindFrame)
BindLabel.Size = UDim2.new(1, 0, 1, 0)
BindLabel.Position = UDim2.new(0, 0, 0, 0)
BindLabel.BackgroundTransparency = 1
BindLabel.Text = "BIND"
BindLabel.TextColor3 = WHITE
BindLabel.Font = Enum.Font.GothamBold
BindLabel.TextSize = 10
BindLabel.TextXAlignment = Enum.TextXAlignment.Center

BindButton = Instance.new("TextButton", BindFrame)
BindButton.Size = UDim2.new(0, 50, 0, 25)
BindButton.Position = UDim2.new(0.5, -25, 0, 30)
BindButton.BackgroundColor3 = WHITE
BindButton.Text = "[ " .. spamBindKey .. " ]"
BindButton.TextColor3 = BLACK
BindButton.Font = Enum.Font.GothamBold
BindButton.TextSize = 12
Instance.new("UICorner", BindButton).CornerRadius = UDim.new(0, 5)

BindButton.MouseButton1Click:Connect(function()
    isWaitingForBind = true
    BindButton.Text = "[ ... ]"
    BindButton.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
end)

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 130, 0, 60)
MainFrame.Position = UDim2.new(0.5, -135, 0.15, 0)
MainFrame.BackgroundColor3 = BLACK_UI
MainFrame.BackgroundTransparency = 0.1
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", MainFrame).Color = WHITE
MakeDraggable(MainFrame)

StatusBtn = Instance.new("TextButton", MainFrame)
StatusBtn.Size = UDim2.new(1, -20, 1, -20)
StatusBtn.Position = UDim2.new(0, 10, 0, 10)
StatusBtn.BackgroundColor3 = WHITE
StatusBtn.Text = "SPAM"
StatusBtn.TextColor3 = BLACK
StatusBtn.Font = Enum.Font.GothamBold
StatusBtn.TextSize = 14
Instance.new("UICorner", StatusBtn).CornerRadius = UDim.new(0, 8)

local TBFrame = Instance.new("Frame", ScreenGui)
TBFrame.Size = UDim2.new(0, 130, 0, 60)
TBFrame.Position = UDim2.new(0.5, 5, 0.15, 0)
TBFrame.BackgroundColor3 = BLACK_UI
TBFrame.BackgroundTransparency = 0.1
Instance.new("UICorner", TBFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", TBFrame).Color = WHITE
MakeDraggable(TBFrame)

local TBBtn = Instance.new("TextButton", TBFrame)
TBBtn.Size = UDim2.new(1, -20, 1, -20)
TBBtn.Position = UDim2.new(0, 10, 0, 10)
TBBtn.BackgroundColor3 = WHITE
TBBtn.Text = "TB"
TBBtn.TextColor3 = BLACK
TBBtn.Font = Enum.Font.GothamBold
TBBtn.TextSize = 14
Instance.new("UICorner", TBBtn).CornerRadius = UDim.new(0, 8)

statsFrame = Instance.new("Frame", ScreenGui)
statsFrame.Size = UDim2.new(0, 160, 0, 40)
statsFrame.Position = UDim2.new(0.5, 145, 0.15, 0)
statsFrame.BackgroundColor3 = BLACK_UI
statsFrame.BackgroundTransparency = 0.1
Instance.new("UICorner", statsFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", statsFrame).Color = WHITE
MakeDraggable(statsFrame)

currentLabel = Instance.new("TextLabel", statsFrame)
currentLabel.Size = UDim2.new(1, -10, 1, -10)
currentLabel.Position = UDim2.new(0, 5, 0, 5)
currentLabel.BackgroundTransparency = 1
currentLabel.Text = "Velocity 0 | Peak 0"
currentLabel.TextColor3 = WHITE
currentLabel.Font = Enum.Font.GothamBold
currentLabel.TextSize = 12

StatusBtn.MouseButton1Click:Connect(function()
    if not captured.remote then
        StatusBtn.Text = "NO REMOTE!"
        task.wait(1)
        StatusBtn.Text = spamActive and "SPAM" or "ON"
        return
    end
    spamActive = not spamActive
    StatusBtn.Text = spamActive and "ON" or "SPAM"
    StatusBtn.BackgroundColor3 = spamActive and Color3.fromRGB(200, 200, 200) or WHITE
    StatusBtn.TextColor3 = BLACK
end)

TBBtn.MouseButton1Click:Connect(function()
    if not captured.remote then
        TBBtn.Text = "NO REMOTE!"
        task.wait(1)
        TBBtn.Text = cfg.trigger and "TB" or "ON"
        return
    end
    cfg.trigger = not cfg.trigger
    TBBtn.Text = cfg.trigger and "ON" or "TB"
    TBBtn.BackgroundColor3 = cfg.trigger and Color3.fromRGB(200, 200, 200) or WHITE
    TBBtn.TextColor3 = BLACK
end)

local _uiBefore={} local _uiHost=(gethui and gethui()) or game:GetService("CoreGui")
pcall(function() for _,g in ipairs(_uiHost:GetChildren()) do _uiBefore[g]=true end end)
local status, NEVERLOSE = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/AchaoticSoftworksCore/AchaoticAssets/main/UiLibrarys/NEVERLOSE-UI-Nightly.luau"))()
end)

if status and NEVERLOSE then
    task.spawn(function() for _=1,20 do pcall(function() for _,g in ipairs(_uiHost:GetChildren()) do if g:IsA("ScreenGui") and not _uiBefore[g] then _uiBefore[g]=true getgenv().C417CloakGui and getgenv().C417CloakGui(g) end end end) task.wait(.1) end end)
    NEVERLOSE:Theme("nightly")
    local Win = NEVERLOSE:AddWindow("Ruqwiri", " ")
    local Tab = Win:AddTab('AUTOPARRY', 'zap')
    local MainSec = Tab:AddSection('Main')
    MainSec:AddToggle('Auto Parry', true, function(v)
        cfg.parry = v
    end)
    MainSec:AddDropdown('Curve Type', {
        'straight',
        'backwards',
        'up',
        'down',
        'left',
        'right',
        'random'
    }, 'straight', function(v)
        cfg.curveType = v
    end)
    local VisualSec = Tab:AddSection('Visuals')
    VisualSec:AddToggle('Show Bind Window', false, function(v)
        cfg.showBindWindow = v
        BindFrame.Visible = v
    end)
    VisualSec:AddToggle('Show Spam UI', true, function(v)
        MainFrame.Visible = v
    end)
    VisualSec:AddToggle('Show TriggerBot UI', true, function(v)
        TBFrame.Visible = v
    end)
    VisualSec:AddToggle('Show Ball Stats', true, function(v)
        cfg.showStats = v
        statsFrame.Visible = v
    end)
    local SetSec = Tab:AddSection('Settings')
    SetSec:AddToggle('Anim Fix', true, function(v)
        cfg.animfix = v
    end)

    task.spawn(function()
        task.wait(1.5)
        pcall(function()
            for _, gui in ipairs(_uiHost:GetChildren()) do
                if gui:IsA("ScreenGui") and not _uiBefore[gui] then
                    for _, obj in ipairs(gui:GetDescendants()) do
                        pcall(function()
                            if obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
                                obj.BackgroundColor3 = BLACK_UI
                            end
                            if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                                obj.BackgroundColor3 = WHITE
                                obj.TextColor3 = BLACK
                            end
                            if obj:IsA("TextLabel") or obj:IsA("TextBox") then
                                obj.TextColor3 = WHITE
                            end
                            if obj:IsA("UIStroke") then
                                obj.Color = WHITE
                            end
                            if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
                                obj.ImageColor3 = WHITE
                            end
                        end)
                    end
                end
            end
        end)
        task.wait(0.5)
        pcall(function()
            for _, gui in ipairs(_uiHost:GetChildren()) do
                if gui:IsA("ScreenGui") and not _uiBefore[gui] then
                    for _, obj in ipairs(gui:GetDescendants()) do
                        pcall(function()
                            if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                                obj.Active = true
                                obj.Selectable = true
                                obj.AutoButtonColor = true
                            end
                            if obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
                                obj.Active = true
                            end
                            if obj:IsA("ScrollingFrame") then
                                obj.ScrollingEnabled = true
                            end
                        end)
                    end
                end
            end
        end)
        task.wait(0.5)
        pcall(function()
            for _, gui in ipairs(_uiHost:GetChildren()) do
                if gui:IsA("ScreenGui") and not _uiBefore[gui] then
                    gui.DisplayOrder = 999
                    gui.IgnoreGuiInset = true
                end
            end
            if ScreenGui then
                ScreenGui.DisplayOrder = 1
            end
        end)
    end)
end

statsFrame.Visible = cfg.showStats
BindFrame.Visible = false
MainFrame.Visible = true
TBFrame.Visible = true
