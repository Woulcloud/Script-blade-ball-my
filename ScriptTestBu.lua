repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatsService = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "I See You",
    SubTitle = "Auto Parry + Trigger Bot + Spam",
    TabWidth = 160,
    Size = UDim2.fromOffset(480, 340),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Combat = Window:AddTab({ Title = "Combat", Icon = "sword" })
}
local Options = Fluent.Options

local cfg = {
    autoParry = false,
    triggerBot = false,
    spam = false,
    accuracy = 1.5,
    cps = 140,
    safety = true
}

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

local parryCooldown = 0
local cpsWindow = {}
local MAX_CPS = 4

local function CanParry()
    local now = tick()
    if not cfg.safety then return true end
    if now - parryCooldown < 0.25 then return false end
    local recent = 0
    for i = #cpsWindow, 1, -1 do
        if now - cpsWindow[i] > 1 then
            table.remove(cpsWindow, i)
        else
            recent = recent + 1
        end
    end
    if recent >= MAX_CPS then return false end
    return true
end

local function SendParry(force)
    if not captured.remote or not captured.sessionKey then return false end
    if not force and not CanParry() then return false end
    local token = makeToken()
    if not token then return false end
    parryCooldown = tick()
    table.insert(cpsWindow, tick())
    return pcall(replay)
end

local function GetPing()
    local success, result = pcall(function()
        return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    return success and result or 100
end

local function GetRealBall()
    for _, v in pairs(workspace.Balls:GetChildren()) do
        if v:GetAttribute("realBall") then
            return v
        end
    end
    return nil
end

local parried = {}
local triggered = {}

local function ProcessAutoParry(ball)
    if not cfg.autoParry then return end
    local bID = ball:GetDebugId()
    if ball:GetAttribute("target") ~= player.Name or parried[bID] then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return end
    local velocity = zoomies.VectorVelocity
    local dist = (root.Position - ball.Position).Magnitude
    local ping = GetPing()
    local threshold = (velocity.Magnitude / cfg.accuracy) + (ping / 10)
    if cfg.safety then
        threshold = threshold * (0.9 + math.random() * 0.2)
    end
    if dist <= threshold or dist <= 20 then
        parried[bID] = true
        if SendParry() then
            if cfg.safety then
                task.wait(math.random(10, 25) / 100)
            end
        end
        ball:GetAttributeChangedSignal("target"):Once(function()
            parried[bID] = nil
        end)
    end
end

local function ProcessTriggerBot(ball)
    if not cfg.triggerBot then return end
    local bID = ball:GetDebugId()
    if ball:GetAttribute("target") ~= player.Name then
        triggered[bID] = nil
        return
    end
    if triggered[bID] then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    triggered[bID] = true
    SendParry()
    task.delay(0.5, function()
        triggered[bID] = nil
    end)
end

-- ===== SPAM =====
local spamThread = nil

local function StartSpam()
    if spamThread then return end
    spamThread = task.spawn(function()
        while cfg.spam do
            SendParry(true)
            task.wait(1 / cfg.cps)
        end
        spamThread = nil
    end)
end

local function StopSpam()
    cfg.spam = false
    if spamThread then
        task.cancel(spamThread)
        spamThread = nil
    end
end

RunService.Heartbeat:Connect(function()
    if not captured.remote then return end
    local ball = GetRealBall()
    if not ball then return end
    if cfg.spam then
        return
    end
    if cfg.triggerBot then
        ProcessTriggerBot(ball)
    elseif cfg.autoParry then
        ProcessAutoParry(ball)
    end
end)

local Combat = Tabs.Combat:AddSection("Parry")

Combat:AddToggle("AutoParry", {
    Title = "Auto Parry",
    Default = false,
    Callback = function(v)
        cfg.autoParry = v
    end
})

Combat:AddToggle("TriggerBot", {
    Title = "Trigger Bot",
    Default = false,
    Callback = function(v)
        cfg.triggerBot = v
    end
})

Combat:AddToggle("Spam", {
    Title = "Spam",
    Default = false,
    Callback = function(v)
        cfg.spam = v
        if v then
            StartSpam()
        else
            StopSpam()
        end
    end
})

Combat:AddSlider("Accuracy", {
    Title = "Accuracy",
    Min = 1,
    Max = 100,
    Default = 50,
    Rounding = 1,
    Callback = function(v)
        cfg.accuracy = (v / 50)
    end
})

Combat:AddSlider("CPS", {
    Title = "Spam CPS",
    Min = 1,
    Max = 140,
    Default = 140,
    Rounding = 1,
    Callback = function(v)
        cfg.cps = v
    end
})

Combat:AddToggle("Safety", {
    Title = "Anti-Kick Safety",
    Default = true,
    Callback = function(v)
        cfg.safety = v
    end
})

-- ===== ПЛАВАЮЩИЕ КНОПКИ =====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ISeeYouFloating"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 50
ScreenGui.Parent = player:WaitForChild("PlayerGui")

local function MakeDraggable(btn)
    local dragging, dragInput, dragStart, startPos
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = btn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    btn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function CreateFloatingBtn(name, pos, text, callback)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 140, 0, 46)
    btn.Position = pos
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.ZIndex = 2
    btn.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = btn

    MakeDraggable(btn)

    btn.MouseButton1Click:Connect(function()
        callback(btn)
    end)

    return btn
end

local triggerBtn = CreateFloatingBtn(
    "TriggerBtn",
    UDim2.new(1, -160, 0.5, -25),
    "Trigger Bot [off]",
    function(btn)
        cfg.triggerBot = not cfg.triggerBot
        Combat:GetToggle("TriggerBot"):SetValue(cfg.triggerBot)
        btn.Text = cfg.triggerBot and "Trigger Bot [on]" or "Trigger Bot [off]"
        btn.BackgroundColor3 = cfg.triggerBot and Color3.fromRGB(255, 105, 180) or Color3.fromRGB(22, 22, 22)
    end
)

local spamBtn = CreateFloatingBtn(
    "SpamBtn",
    UDim2.new(1, -160, 0.5, 25),
    "Spam [off]",
    function(btn)
        cfg.spam = not cfg.spam
        Combat:GetToggle("Spam"):SetValue(cfg.spam)
        btn.Text = cfg.spam and "Spam [on]" or "Spam [off]"
        btn.BackgroundColor3 = cfg.spam and Color3.fromRGB(255, 105, 180) or Color3.fromRGB(22, 22, 22)
        if cfg.spam then
            StartSpam()
        else
            StopSpam()
        end
    end
)

Fluent:Notify({
    Title = "I See You",
    Content = "Loaded. Auto Parry + Trigger Bot + Spam ready.",
    Duration = 4
})
