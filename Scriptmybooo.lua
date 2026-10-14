--[[
    I See You — Blade Ball
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local StarterGui        = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats             = game:GetService("Stats")
local TweenService      = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Balls  = workspace:WaitForChild("Balls")

--== hookfunction ==--
local hook = rawget(getfenv(), "hookfunction")
    or (getgenv and getgenv().hookfunction)
    or hookfunction

assert(hook, "hookfunction недоступен — нужна эксплойт-среда")

--== Константы ==--
local HASH = "5455ef47-de02-4074-808c-8d82c2cd12ec"
local byte, char      = string.byte, string.char
local floor, bxor     = math.floor, bit32.bxor
local CLICKS_NEEDED   = 3

--== Состояние ==--
local captured, votes, key = {}, {}, nil
local parried_balls, triggered_balls = {}, {}

local autoParryEnabled  = false
local triggerBotEnabled = false
local spamEnabled       = false
local isActivated       = false
local menuOpen          = true
local clickCount        = 0
local spamUIVisible     = false

local accuracyMultiplier = 0.2

local spamCPS   = 200
local spamDelay = 1 / spamCPS

--== Утилиты ==--
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

--== XOR-обучение токена ==--
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

--== Хук RemoteEvent ==--
local fire
do
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
end

--== Воспроизведение паринга ==--
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

local function Parry()
    if not captured.remote or not captured.sessionKey then return end
    replay()
end

--== Анимация GrabParry ==--
local SwordAPI = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SwordAPI")
local AnimFix_Cache = {}
local Loaded_Tracks = {}

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
        Loaded_Tracks[currentSword] = track
        return track
    end
    return nil
end

local function PlayGrabParry()
    local track = GetOrLoadTrack()
    if not track then return end
    pcall(function()
        track:Stop(0)
        track.TimePosition = 0
        track:Play(0, 1, 1)
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
    end)
end)

Player.CharacterAdded:Connect(function()
    Loaded_Tracks = {}
    parried_balls = {}
    triggered_balls = {}
    votes = {}
    key = nil
end)

--== Активация 3 кликами ==--
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or isActivated then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        clickCount += 1
        if clickCount < CLICKS_NEEDED then
            ShowNotification("Activation", ("Click %d/%d"):format(clickCount, CLICKS_NEEDED), 1)
        else
            isActivated = true
            ShowNotification("I See You", "Активировано!", 2)
        end
    end
end)

ShowNotification("I See You", ("Сделай %d клика для активации"):format(CLICKS_NEEDED), 5)

--== Мяч ==--
local function GetRealBall()
    for _, ball in ipairs(Balls:GetChildren()) do
        if ball:GetAttribute("realBall") == true then
            return ball
        end
    end
    return nil
end

--== Кривизна мяча ==--
local Lerp_Radians = 0
local Last_Warping = tick()

local function Is_Curved(ball, charPart)
    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return false end

    local velocity = zoomies.VectorVelocity
    if not charPart then return false end

    local toPlayer = charPart.Position - ball.Position
    local distance = toPlayer.Magnitude
    if distance <= 25 then return false end

    local speed = velocity.Magnitude
    if speed < 1 then return false end

    local direction = toPlayer.Unit
    local dot = direction:Dot(velocity.Unit)

    local ping = GetPing() / 1000
    local reachTime = distance / speed - ping
    local radians = math.rad(math.asin(math.clamp(dot, -1, 1)))
    Lerp_Radians += (radians - Lerp_Radians) * 0.8

    if Lerp_Radians < 0.018 then
        Last_Warping = tick()
    end

    if (tick() - Last_Warping) < (reachTime / 1.5) then
        return true
    end
    return dot < (0.5 - ping)
end

--== AutoParry ==--
local function ProcessAutoParry(ball, charPart)
    if not autoParryEnabled then return end

    local bID = ball:GetDebugId()
    if ball:GetAttribute("target") ~= Player.Name or parried_balls[bID] then return end
    if Is_Curved(ball, charPart) then return end

    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return end

    local velocity = zoomies.VectorVelocity
    local dist = (charPart.Position - ball.Position).Magnitude
    local ping = GetPing()

    local pingBase = math.clamp(ping / 100, 3, 10)
    local rawSpeed = velocity.Magnitude
    local speedAdjusted = math.clamp(rawSpeed - 9.5, 0, 650)
    local speedCoefficient = 3.4 + speedAdjusted * 0.0025
    local scaledAg = speedCoefficient * accuracyMultiplier
    local targetDistance = pingBase + math.max(rawSpeed / scaledAg, 9.5) + 2.5

    if dist <= targetDistance then
        parried_balls[bID] = true
        Parry()
        task.spawn(PlayGrabParry)
        ball:GetAttributeChangedSignal("target"):Once(function()
            parried_balls[bID] = nil
        end)
    end
end

--== TriggerBot ==--
local triggerConnections = {}

local function BindTriggerBot(ball)
    if triggerConnections[ball] then return end
    triggerConnections[ball] = ball:GetAttributeChangedSignal("target"):Connect(function()
        if not triggerBotEnabled then return end
        if ball:GetAttribute("target") ~= Player.Name then return end

        local bID = ball:GetDebugId()
        if triggered_balls[bID] then return end
        triggered_balls[bID] = true

        Parry()
        task.spawn(PlayGrabParry)

        task.defer(function()
            local conn
            conn = ball:GetAttributeChangedSignal("target"):Connect(function()
                if ball:GetAttribute("target") ~= Player.Name then
                    triggered_balls[bID] = nil
                    if conn then conn:Disconnect() end
                end
            end)
        end)
    end)
end

for _, ball in ipairs(Balls:GetChildren()) do
    BindTriggerBot(ball)
end
Balls.ChildAdded:Connect(BindTriggerBot)

--== Spam ==--
local spamThread = nil

local function StartSpam()
    if spamThread then return end
    spamThread = task.spawn(function()
        while spamEnabled do
            if captured.remote then
                Parry()
                task.spawn(PlayGrabParry)
            end
            task.wait(spamDelay)
        end
        spamThread = nil
    end)
end

local function StopSpam()
    spamEnabled = false
    if spamThread then
        pcall(function() task.cancel(spamThread) end)
        spamThread = nil
    end
end

--== Главный цикл ==--
RunService.Heartbeat:Connect(function()
    if not isActivated or not captured.remote then return end

    local char = Player.Character
    local charPart = char and char:FindFirstChild("HumanoidRootPart")
    if not charPart then return end

    if autoParryEnabled then
        local ball = GetRealBall()
        if ball then
            ProcessAutoParry(ball, charPart)
        end
    end
end)

--== UI ==--
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ISeeYouMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

--== Основное меню 300×420 ==--
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 300, 0, 420)
MainFrame.Position = UDim2.new(0, 20, 0, 80)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(60, 60, 60)
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

--== Заголовок ==--
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.BorderSizePixel = 0
Title.Text = "  I See You"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = Title

--== Toggle ==--
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 40, 0, 28)
ToggleBtn.Position = UDim2.new(1, -50, 0, 6)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "—"
ToggleBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
ToggleBtn.TextSize = 20
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = Title

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 8)
ToggleCorner.Parent = ToggleBtn

--== Контент ==--
local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "Content"
ContentFrame.Size = UDim2.new(1, -24, 1, -58)
ContentFrame.Position = UDim2.new(0, 12, 0, 48)
ContentFrame.BackgroundTransparency = 1
ContentFrame.ClipsDescendants = true
ContentFrame.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 8)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = ContentFrame

local FULL_SIZE = UDim2.new(0, 300, 0, 420)
local MIN_SIZE  = UDim2.new(0, 300, 0, 40)

local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

local function SetMenuOpen(open)
    menuOpen = open
    local targetSize = open and FULL_SIZE or MIN_SIZE
    TweenService:Create(MainFrame, tweenInfo, {Size = targetSize}):Play()
    if open then
        ContentFrame.Visible = true
        ToggleBtn.Text = "—"
    else
        task.delay(0.35, function()
            if not menuOpen then
                ContentFrame.Visible = false
            end
        end)
        ToggleBtn.Text = "□"
    end
end

ToggleBtn.MouseButton1Click:Connect(function()
    SetMenuOpen(not menuOpen)
end)

--== Фабрика кнопок ==--
local function CreateButton(name, order)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Btn"
    btn.Size = UDim2.new(1, 0, 0, 44)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.Text = name .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.TextSize = 15
    btn.Font = Enum.Font.GothamMedium
    btn.LayoutOrder = order
    btn.AutoButtonColor = true
    btn.Parent = ContentFrame

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn

    return btn
end

local AutoParryBtn  = CreateButton("Auto Parry", 1)
local TriggerBotBtn = CreateButton("Trigger Bot", 2)
local SpamBtn       = CreateButton("Spam", 3)

--== Слайдер точности ==--
local SliderLabel = Instance.new("TextLabel")
SliderLabel.Size = UDim2.new(1, 0, 0, 22)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Text = ("Accuracy: %.3f"):format(accuracyMultiplier)
SliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SliderLabel.TextSize = 14
SliderLabel.Font = Enum.Font.GothamMedium
SliderLabel.LayoutOrder = 4
SliderLabel.Parent = ContentFrame

local Slider = Instance.new("TextButton")
Slider.Size = UDim2.new(1, 0, 0, 24)
Slider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
Slider.BorderSizePixel = 0
Slider.Text = ""
Slider.LayoutOrder = 5
Slider.Parent = ContentFrame

local SliderCorner = Instance.new("UICorner")
SliderCorner.CornerRadius = UDim.new(0, 8)
SliderCorner.Parent = Slider

local ACC_MIN, ACC_MAX = 0.2, 2.5

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(0, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = Slider

local SliderFillCorner = Instance.new("UICorner")
SliderFillCorner.CornerRadius = UDim.new(0, 8)
SliderFillCorner.Parent = SliderFill

local function SetSliderFromX(x)
    local rel = math.clamp((x - Slider.AbsolutePosition.X) / Slider.AbsoluteSize.X, 0, 1)
    accuracyMultiplier = ACC_MIN + rel * (ACC_MAX - ACC_MIN)
    SliderFill.Size = UDim2.new(rel, 0, 1, 0)
    SliderLabel.Text = ("Accuracy: %.3f"):format(accuracyMultiplier)
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
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        or input.UserInputType == Enum.UserInputType.Touch then
            SetSliderFromX(input.Position.X)
        end
    end
end)

--== Show Spam UI ==--
local ShowSpamUIBtn = CreateButton("Show Spam UI", 6)

--== Floating Trigger ==--
local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Name = "FloatingTriggerBot"
FloatingBtn.Size = UDim2.new(0, 150, 0, 50)
FloatingBtn.Position = UDim2.new(0, 20, 0, 510)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
FloatingBtn.BorderSizePixel = 0
FloatingBtn.Text = "TRIGGER: OFF"
FloatingBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
FloatingBtn.TextSize = 15
FloatingBtn.Font = Enum.Font.GothamBold
FloatingBtn.Active = true
FloatingBtn.Draggable = true
FloatingBtn.Parent = ScreenGui

local FloatingCorner = Instance.new("UICorner")
FloatingCorner.CornerRadius = UDim.new(0, 10)
FloatingCorner.Parent = FloatingBtn

--== Floating Spam ==--
local FloatingSpamBtn = nil

local function CreateFloatingSpamBtn()
    if FloatingSpamBtn then return end
    FloatingSpamBtn = Instance.new("TextButton")
    FloatingSpamBtn.Name = "FloatingSpamBtn"
    FloatingSpamBtn.Size = UDim2.new(0, 150, 0, 50)
    FloatingSpamBtn.Position = UDim2.new(0, 20, 0, 570)
    FloatingSpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    FloatingSpamBtn.BorderSizePixel = 0
    FloatingSpamBtn.Text = "SPAM: OFF"
    FloatingSpamBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    FloatingSpamBtn.TextSize = 15
    FloatingSpamBtn.Font = Enum.Font.GothamBold
    FloatingSpamBtn.Active = true
    FloatingSpamBtn.Draggable = true
    FloatingSpamBtn.Parent = ScreenGui

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = FloatingSpamBtn

    FloatingSpamBtn.MouseButton1Click:Connect(function()
        spamEnabled = not spamEnabled
        FloatingSpamBtn.Text = "SPAM: " .. (spamEnabled and "ON" or "OFF")
        FloatingSpamBtn.BackgroundColor3 = spamEnabled and Color3.fromRGB(255, 220, 150) or Color3.fromRGB(255, 255, 255)
        SpamBtn.Text = "Spam: " .. (spamEnabled and "ON" or "OFF")
        SpamBtn.BackgroundColor3 = spamEnabled and Color3.fromRGB(255, 220, 150) or Color3.fromRGB(255, 255, 255)
        if spamEnabled then StartSpam() else StopSpam() end
    end)
end

local function DestroyFloatingSpamBtn()
    if FloatingSpamBtn then
        FloatingSpamBtn:Destroy()
        FloatingSpamBtn = nil
    end
end

--== Spam UI панель ==--
local SpamUIFrame = Instance.new("Frame")
SpamUIFrame.Name = "SpamUIFrame"
SpamUIFrame.Size = UDim2.new(0, 300, 0, 130)
SpamUIFrame.Position = UDim2.new(0, 20, 0, 630)
SpamUIFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
SpamUIFrame.BorderSizePixel = 0
SpamUIFrame.Active = true
SpamUIFrame.Draggable = true
SpamUIFrame.Visible = false
SpamUIFrame.Parent = ScreenGui

local SpamUICorner = Instance.new("UICorner")
SpamUICorner.CornerRadius = UDim.new(0, 10)
SpamUICorner.Parent = SpamUIFrame

local SpamUIStroke = Instance.new("UIStroke")
SpamUIStroke.Color = Color3.fromRGB(60, 60, 60)
SpamUIStroke.Thickness = 1
SpamUIStroke.Parent = SpamUIFrame

local SpamUITitle = Instance.new("TextLabel")
SpamUITitle.Size = UDim2.new(1, 0, 0, 35)
SpamUITitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
SpamUITitle.BorderSizePixel = 0
SpamUITitle.Text = "  Spam Settings"
SpamUITitle.TextColor3 = Color3.fromRGB(255, 255, 255)
SpamUITitle.TextSize = 15
SpamUITitle.Font = Enum.Font.GothamBold
SpamUITitle.TextXAlignment = Enum.TextXAlignment.Left
SpamUITitle.Parent = SpamUIFrame

local SpamUITitleCorner = Instance.new("UICorner")
SpamUITitleCorner.CornerRadius = UDim.new(0, 10)
SpamUITitleCorner.Parent = SpamUITitle

local CloseSpamUI = Instance.new("TextButton")
CloseSpamUI.Size = UDim2.new(0, 30, 0, 24)
CloseSpamUI.Position = UDim2.new(1, -36, 0, 6)
CloseSpamUI.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CloseSpamUI.BorderSizePixel = 0
CloseSpamUI.Text = "X"
CloseSpamUI.TextColor3 = Color3.fromRGB(0, 0, 0)
CloseSpamUI.TextSize = 15
CloseSpamUI.Font = Enum.Font.GothamBold
CloseSpamUI.Parent = SpamUITitle

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseSpamUI

local SpamCPSLabel = Instance.new("TextLabel")
SpamCPSLabel.Size = UDim2.new(1, -24, 0, 22)
SpamCPSLabel.Position = UDim2.new(0, 12, 0, 46)
SpamCPSLabel.BackgroundTransparency = 1
SpamCPSLabel.Text = ("CPS: %d"):format(spamCPS)
SpamCPSLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SpamCPSLabel.TextSize = 14
SpamCPSLabel.Font = Enum.Font.GothamMedium
SpamCPSLabel.TextXAlignment = Enum.TextXAlignment.Left
SpamCPSLabel.Parent = SpamUIFrame

local SpamCPSSlider = Instance.new("TextButton")
SpamCPSSlider.Size = UDim2.new(1, -24, 0, 24)
SpamCPSSlider.Position = UDim2.new(0, 12, 0, 82)
SpamCPSSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
SpamCPSSlider.BorderSizePixel = 0
SpamCPSSlider.Text = ""
SpamCPSSlider.Parent = SpamUIFrame

local SpamCPSCorner = Instance.new("UICorner")
SpamCPSCorner.CornerRadius = UDim.new(0, 8)
SpamCPSCorner.Parent = SpamCPSSlider

local SpamCPSFill = Instance.new("Frame")
SpamCPSFill.Size = UDim2.new(1.0, 0, 1, 0)
SpamCPSFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SpamCPSFill.BorderSizePixel = 0
SpamCPSFill.Parent = SpamCPSSlider

local SpamCPSFillCorner = Instance.new("UICorner")
SpamCPSFillCorner.CornerRadius = UDim.new(0, 8)
SpamCPSFillCorner.Parent = SpamCPSFill

local CPS_MIN, CPS_MAX = 50, 200

local function SetCPSFromX(x)
    local rel = math.clamp((x - SpamCPSSlider.AbsolutePosition.X) / SpamCPSSlider.AbsoluteSize.X, 0, 1)
    spamCPS = math.floor(CPS_MIN + rel * (CPS_MAX - CPS_MIN) + 0.5)
    spamDelay = 1 / spamCPS
    SpamCPSFill.Size = UDim2.new(rel, 0, 1, 0)
    SpamCPSLabel.Text = ("CPS: %d"):format(spamCPS)
end

SpamCPSSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        SetCPSFromX(input.Position.X)
    end
end)

SpamCPSSlider.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
    or input.UserInputType == Enum.UserInputType.Touch then
        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        or input.UserInputType == Enum.UserInputType.Touch then
            SetCPSFromX(input.Position.X)
        end
    end
end)

CloseSpamUI.MouseButton1Click:Connect(function()
    spamUIVisible = false
    SpamUIFrame.Visible = false
    DestroyFloatingSpamBtn()
    ShowSpamUIBtn.Text = "Show Spam UI: OFF"
    ShowSpamUIBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
end)

ShowSpamUIBtn.MouseButton1Click:Connect(function()
    spamUIVisible = not spamUIVisible
    SpamUIFrame.Visible = spamUIVisible
    if spamUIVisible then
        CreateFloatingSpamBtn()
    else
        DestroyFloatingSpamBtn()
    end
    ShowSpamUIBtn.Text = "Show Spam UI: " .. (spamUIVisible and "ON" or "OFF")
    ShowSpamUIBtn.BackgroundColor3 = spamUIVisible and Color3.fromRGB(180, 255, 180) or Color3.fromRGB(255, 255, 255)
end)

--== UpdateTriggerUI ==--
local function UpdateTriggerUI()
    local state = triggerBotEnabled and "ON" or "OFF"
    TriggerBotBtn.Text = "Trigger Bot: " .. state
    TriggerBotBtn.BackgroundColor3 = triggerBotEnabled and Color3.fromRGB(180, 255, 180) or Color3.fromRGB(255, 255, 255)
    FloatingBtn.Text = "TRIGGER: " .. state
    FloatingBtn.BackgroundColor3 = triggerBotEnabled and Color3.fromRGB(180, 255, 180) or Color3.fromRGB(255, 255, 255)
end

--== Обработчики кнопок ==--
AutoParryBtn.MouseButton1Click:Connect(function()
    autoParryEnabled = not autoParryEnabled
    AutoParryBtn.Text = "Auto Parry: " .. (autoParryEnabled and "ON" or "OFF")
    AutoParryBtn.BackgroundColor3 = autoParryEnabled and Color3.fromRGB(180, 255, 180) or Color3.fromRGB(255, 255, 255)
end)

TriggerBotBtn.MouseButton1Click:Connect(function()
    triggerBotEnabled = not triggerBotEnabled
    UpdateTriggerUI()
end)

SpamBtn.MouseButton1Click:Connect(function()
    spamEnabled = not spamEnabled
    SpamBtn.Text = "Spam: " .. (spamEnabled and "ON" or "OFF")
    SpamBtn.BackgroundColor3 = spamEnabled and Color3.fromRGB(255, 220, 150) or Color3.fromRGB(255, 255, 255)
    if FloatingSpamBtn then
        FloatingSpamBtn.Text = "SPAM: " .. (spamEnabled and "ON" or "OFF")
        FloatingSpamBtn.BackgroundColor3 = spamEnabled and Color3.fromRGB(255, 220, 150) or Color3.fromRGB(255, 255, 255)
    end
    if spamEnabled then StartSpam() else StopSpam() end
end)

FloatingBtn.MouseButton1Click:Connect(function()
    triggerBotEnabled = not triggerBotEnabled
    UpdateTriggerUI()
