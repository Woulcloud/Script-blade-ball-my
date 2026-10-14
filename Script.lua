local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/main/source.lua"))()

local Window = Luna:CreateWindow({
    Name = "Blade Ball",
    LoadingTitle = "Blade Ball",
    LoadingSubtitle = "by EAGLE",
    ConfigurationSaving = {
        Enabled = false
    },
    Discord = {
        Enabled = false
    },
    KeySystem = false
})

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
local parryThreshold = 50

local triggerBotEnabled = false
local triggerBotUIEnabled = false
local spamUIEnabled = false

local spamEnabled = false
local SPAM_CPS = 100
local spamThread = nil

local animFixEnabled = true

local lastParry = 0
local COOLDOWN = 0.02
local TRIGGER_COOLDOWN = 0.015

-- === SPAM ===
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

-- === ANIMATION FIX ===
local animationFixConnection = RunService.Heartbeat:Connect(function()
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
            ShowNotification("Blade Ball", "АКТИВИРОВАН!", 2)
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

local function GetParryThreshold()
    local ping = 0
    pcall(function()
        ping = Player:GetNetworkPing()
    end)
    if ping <= 0 then
        pcall(function()
            local stats = game:GetService("Stats")
            ping = stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
        end)
    end
    if ping <= 0 then ping = 0.1 end
    local pingClamped = math.clamp(ping, 0.02, 0.30)
    local base = parryThreshold / 100 * 0.3
    return math.min(base + pingClamped, 0.45)
end

RunService.PreSimulation:Connect(function()
    if not isActivated then return end

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

    if triggerBotEnabled then
        if tick() - lastParry < TRIGGER_COOLDOWN then return end
        local ballSize = ball:GetAttribute("Size") or 1
        local hitZone = ballSize + 3.5
        if distance <= hitZone + (speed * 0.02) then
            Parry()
            lastParry = tick()
        end
        return
    end

    if autoParryEnabled then
        if tick() - lastParry < COOLDOWN then return end
        local threshold = GetParryThreshold()
        if timeToImpact <= threshold then
            Parry()
            lastParry = tick()
        end
    end
end)

-- === LUNA UI ===
local MainTab = Window:CreateTab({
    Name = "Main",
    Icon = "shield",
    ImageSource = "Material",
    ShowTitle = true
})

local ParrySection = MainTab:CreateSection("Auto Parry")

MainTab:CreateToggle({
    Name = "Auto Parry",
    CurrentValue = false,
    Flag = "AutoParryToggle",
    Callback = function(Value)
        autoParryEnabled = Value
    end,
})

MainTab:CreateSlider({
    Name = "Parry Threshold (1-100)",
    Range = {1, 100},
    Increment = 1,
    CurrentValue = 50,
    Flag = "ParryThresholdSlider",
    Callback = function(Value)
        parryThreshold = Value
    end,
})

local TriggerSection = MainTab:CreateSection("Trigger Bot")

MainTab:CreateToggle({
    Name = "Trigger Bot",
    CurrentValue = false,
    Flag = "TriggerBotToggle",
    Callback = function(Value)
        triggerBotEnabled = Value
    end,
})

MainTab:CreateToggle({
    Name = "Show Trigger Bot UI",
    CurrentValue = false,
    Flag = "TriggerBotUIToggle",
    Callback = function(Value)
        triggerBotUIEnabled = Value
    end,
})

local SpamSection = MainTab:CreateSection("Spam")

MainTab:CreateToggle({
    Name = "Show Spam UI",
    CurrentValue = false,
    Flag = "SpamUIToggle",
    Callback = function(Value)
        spamUIEnabled = Value
        if Value then
            startSpam()
        else
            stopSpam()
        end
    end,
})

local AnimSection = MainTab:CreateSection("Animation")

MainTab:CreateToggle({
    Name = "Animation Fix",
    CurrentValue = true,
    Flag = "AnimFixToggle",
    Callback = function(Value)
        animFixEnabled = Value
    end,
})

Window:CreateHomeTab({
    SupportedExecutors = {"Delta", "Wave", "Solara", "Codex"},
    DiscordInvite = "",
    Icon = 1
})

Luna:Notification({
    Title = "Blade Ball",
    Content = "Loaded! Сделай 3 клика для активации.",
    Icon = "check_circle",
    ImageSource = "Material"
})
