local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local Player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Balls = workspace:WaitForChild("Balls")

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

local CLICKS_NEEDED = 3
local clickCount = 0
local isActivated = false
local autoParryEnabled = false
local lastParry = 0
local COOLDOWN = 0.02

-- === ANIMATION FIX ===
local animFixEnabled = true
local animationFixConnection = nil

local function AttachAnimationFix()
    if animationFixConnection then return end
    animationFixConnection = RunService.Heartbeat:Connect(function()
        if not spamEnabled then return end
        if not animFixEnabled then return end
        local char = Player.Character
        if not char then return end
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then return end
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            pcall(function()
                track:AdjustSpeed(1)
            end)
        end
    end)
end

-- === SPAM ===
local spamEnabled = false
local SPAM_CPS = 100
local spamThread = nil

local function startSpam()
    if spamThread then return end
    spamEnabled = true
    spamThread = task.spawn(function()
        while spamEnabled do
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
            task.wait(1 / SPAM_CPS)
        end
        spamThread = nil
    end)
end

local function stopSpam()
    spamEnabled = false
end

local function ShowNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

local function IsClickingUI()
    local gui = Player:FindFirstChild("PlayerGui")
    if not gui then return false end
    local bb = gui:FindFirstChild("BladeBallMenu")
    if not bb then return false end
    local mouse = UserInputService:GetMouseLocation()
    for _, obj in ipairs(bb:GetDescendants()) do
        if obj:IsA("GuiButton") and obj.Visible then
            local pos = obj.AbsolutePosition
            local size = obj.AbsoluteSize
            if mouse.X >= pos.X and mouse.X <= pos.X + size.X
            and mouse.Y >= pos.Y and mouse.Y <= pos.Y + size.Y then
                return true
            end
        end
    end
    return false
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if isActivated then return end
    if IsClickingUI() then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then

        clickCount = clickCount + 1

        if clickCount < CLICKS_NEEDED then
            ShowNotification("Активация", "Клик " .. clickCount .. "/" .. CLICKS_NEEDED, 1)
        else
            isActivated = true
            ShowNotification("Auto Parry", "АКТИВИРОВАН!", 2)
        end
    end
end)

ShowNotification("Blade Ball", "Сделай " .. CLICKS_NEEDED .. " клика для активации", 5)

local function GetRealBall()
    for _, ball in ipairs(Balls:GetChildren()) do
        if ball:GetAttribute("realBall") == true then
            return ball
        end
    end
    return nil
end

local function Parry()
    if not captured.remote or not captured.sessionKey then return end
    local token = makeToken()
    if not token then return end
    replay()
end

-- === АВТОПОДБОР ПОРОГА ПОД ПИНГ ===
-- Чем выше пинг, тем раньше надо парировать (мяч уже на сервере, а ты его видишь позже).
-- Формула: threshold = baseTime + pingCompensation
-- baseTime = 0.15 сек (базовое окно реакции)
-- pingCompensation = пинг в секундах (макс ограничение 0.45)
local function GetParryThreshold()
    local ping = 0
    pcall(function()
        ping = Player:GetNetworkPing() -- возвращает в секундах (например 0.05 для 50 пинга)
    end)
    -- Если ping не получился — считаем через stats
    if ping <= 0 then
        pcall(function()
            local stats = game:GetService("Stats")
            ping = stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        end)
    end
    if ping <= 0 then ping = 0.1 end -- на всякий случай

    -- Ограничиваем пинг, чтобы не парировать слишком рано
    local pingClamped = math.clamp(ping, 0.02, 0.30)

    -- Итоговый порог: базовое время + пинг
    local threshold = 0.12 + pingClamped

    -- Ограничение сверху (не парировать сверхранно)
    return math.min(threshold, 0.45)
end

-- === AUTO PARRY ===
RunService.PreSimulation:Connect(function()
    if not isActivated then return end
    if not autoParryEnabled then return end
    if tick() - lastParry < COOLDOWN then return end

    local ball = GetRealBall()
    if not ball then return end

    local char = Player.Character
    if not char then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local speed
    if ball:FindFirstChild("zoomies") then
        speed = ball.zoomies.VectorVelocity.Magnitude
    else
        speed = ball.AssemblyLinearVelocity.Magnitude
    end
    if not speed or speed <= 0 then return end

    local distance = (hrp.Position - ball.Position).Magnitude
    local timeToImpact = distance / speed

    local threshold = GetParryThreshold()

    if timeToImpact <= threshold then
        Parry()
        lastParry = tick()
    end
end)

-- === UI ===
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BladeBallMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local OpenBtn = Instance.new("TextButton")
OpenBtn.Name = "OpenBtn"
OpenBtn.Size = UDim2.new(0, 45, 0, 45)
OpenBtn.Position = UDim2.new(0, 20, 0, 100)
OpenBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
OpenBtn.BorderSizePixel = 0
OpenBtn.Text = "≡"
OpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenBtn.TextSize = 26
OpenBtn.Font = Enum.Font.GothamBold
OpenBtn.Visible = false
OpenBtn.Active = true
OpenBtn.Draggable = true
OpenBtn.Parent = ScreenGui

local OpenCorner = Instance.new("UICorner")
OpenCorner.CornerRadius = UDim.new(0, 10)
OpenCorner.Parent = OpenBtn

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 260, 0, 250)
MainFrame.Position = UDim2.new(0, 20, 0, 100)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.BorderSizePixel = 0
Title.Text = "  BLADE BALL"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = Title

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 40, 0, 30)
ToggleBtn.Position = UDim2.new(1, -90, 0, 5)
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

local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -45, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
CloseBtn.BorderSizePixel = 0
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 16
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Title

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 8)
CloseCorner.Parent = CloseBtn

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "Content"
ContentFrame.Size = UDim2.new(1, -20, 1, -55)
ContentFrame.Position = UDim2.new(0, 10, 0, 48)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local function CreateButton(name, yPos)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Btn"
    btn.Size = UDim2.new(1, 0, 0, 55)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.Text = name .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.TextSize = 16
    btn.Font = Enum.Font.GothamBold
    btn.Parent = ContentFrame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    return btn
end

local AutoParryBtn = CreateButton("Auto Parry", 0)
local SpamBtn = CreateButton("Spam 100 CPS", 65)
local AnimFixBtn = CreateButton("Animation Fix", 130)

local menuOpen = true

ToggleBtn.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    if menuOpen then
        MainFrame:TweenSize(UDim2.new(0, 260, 0, 250), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
        ToggleBtn.Text = "—"
    else
        MainFrame:TweenSize(UDim2.new(0, 260, 0, 40), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.2, true)
        ToggleBtn.Text = "□"
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    OpenBtn.Visible = true
    OpenBtn.Position = MainFrame.Position
end)

OpenBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    OpenBtn.Visible = false
    MainFrame.Position = OpenBtn.Position
    menuOpen = true
    MainFrame.Size = UDim2.new(0, 260, 0, 250)
    ToggleBtn.Text = "—"
end)

AutoParryBtn.MouseButton1Click:Connect(function()
    autoParryEnabled = not autoParryEnabled
    AutoParryBtn.Text = "Auto Parry: " .. (autoParryEnabled and "ON" or "OFF")
    AutoParryBtn.BackgroundColor3 = autoParryEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
end)

SpamBtn.MouseButton1Click:Connect(function()
    if spamEnabled then
        stopSpam()
        SpamBtn.Text = "Spam 100 CPS: OFF"
        SpamBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    else
        startSpam()
        SpamBtn.Text = "Spam 100 CPS: ON"
        SpamBtn.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
    end
end)

AnimFixBtn.MouseButton1Click:Connect(function()
    animFixEnabled = not animFixEnabled
    AnimFixBtn.Text = "Animation Fix: " .. (animFixEnabled and "ON" or "OFF")
    AnimFixBtn.BackgroundColor3 = animFixEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
end)

AttachAnimationFix()
