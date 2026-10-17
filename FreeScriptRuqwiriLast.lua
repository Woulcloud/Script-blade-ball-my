repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StatsService = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Ruqwiri",
    SubTitle = "Auto Parry + Auto Spam + Avatar R6",
    TabWidth = 160,
    Size = UDim2.fromOffset(440, 320),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Combat = Window:AddTab({ Title = "Combat", Icon = "sword" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "eye" })
}

local cfg = { autoParry = false, autoSpam = false, accuracy = 1.5, spamThreshold = 3 }

local hook = hookfunction or (getgenv and getgenv().hookfunction)
local HASH = "5455ef47-de02-4074-808c-8d82c2cd12ec"
local byte, char = string.byte, string.char
local floor, bxor = math.floor, bit32.bxor
local captured, votes, key = {}, {}, nil

local function timestamp() return tostring(floor(workspace:GetServerTimeNow() * 100)) end

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

local fire
local function replay()
    local token = makeToken()
    if not captured.remote or not captured.sessionKey or not token then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local points = {}
    local alive = workspace:FindFirstChild("Alive")
    if alive then
        for _, character in ipairs(alive:GetChildren()) do
            local root = character:FindFirstChild("HumanoidRootPart")
            if root then points[character.Name] = camera:WorldToScreenPoint(root.Position) end
        end
    end
    local mouse = UserInputService:GetMouseLocation()
    fire(captured.remote, HASH, captured.sessionKey, token, 0.5, camera.CFrame, points, { mouse.X, mouse.Y }, false)
end

if hook then
    fire = hook(Instance.new("RemoteEvent").FireServer, function(self, ...)
        local args = table.pack(...)
        if args[1] ~= HASH or type(args[3]) ~= "string" then return fire(self, ...) end
        captured = { remote = self, sessionKey = args[2], token = args[3], timing = args[4], tailBool = args[8], args = args }
        learn(args[3], timestamp())
        return fire(self, ...)
    end)
end

local function SendParry()
    if not captured.remote or not captured.sessionKey then return false end
    local token = makeToken()
    if not token then return false end
    return pcall(replay)
end

local function GetPing()
    local ok, result = pcall(function() return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return ok and result or 100
end

local function GetRealBall()
    for _, v in pairs(workspace.Balls:GetChildren()) do
        if v:GetAttribute("realBall") then return v end
    end
    return nil
end

local function GetNearbyPlayer()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local alive = workspace:FindFirstChild("Alive")
    if not alive then return nil end
    local best, target = math.huge, nil
    for _, v in ipairs(alive:GetChildren()) do
        if v.Name ~= player.Name then
            local hum = v:FindFirstChildOfClass("Humanoid")
            local r = v:FindFirstChild("HumanoidRootPart")
            if hum and r and hum.Health > 0 then
                local d = (root.Position - r.Position).Magnitude
                if d < best then best = d; target = v end
            end
        end
    end
    return target
end

local parried = {}
local spamLast = 0

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
    if dist <= threshold or dist <= 20 then
        parried[bID] = true
        SendParry()
        ball:GetAttributeChangedSignal("target"):Once(function() parried[bID] = nil end)
    end
end

local function ProcessAutoSpam(ball)
    if not cfg.autoSpam then return end
    local now = tick()
    if now - spamLast < 0.05 then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local enemy = GetNearbyPlayer()
    if not enemy or not enemy.PrimaryPart then return end
    local ed = (root.Position - enemy.PrimaryPart.Position).Magnitude
    if ed > 30 then return end
    local bd = (root.Position - ball.Position).Magnitude
    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return end
    local speed = zoomies.VectorVelocity.Magnitude
    local ping = GetPing()
    local maxDist = (ping / 10) + math.min(speed / 6, 95)
    if bd > maxDist or ed > maxDist then return end
    spamLast = now
    SendParry()
end

RunService.Heartbeat:Connect(function()
    if not captured.remote then return end
    local ball = GetRealBall()
    if not ball then return end
    if cfg.autoParry then ProcessAutoParry(ball) end
    if cfg.autoSpam then ProcessAutoSpam(ball) end
end)

-- ================= COMBAT UI =================

local Combat = Tabs.Combat:AddSection("Parry")

Combat:AddToggle("AutoParry", { Title = "Auto Parry", Default = false, Callback = function(v) cfg.autoParry = v end })
Combat:AddSlider("Accuracy", { Title = "Accuracy", Min = 1, Max = 100, Default = 50, Rounding = 1, Callback = function(v) cfg.accuracy = (v / 50) end })

local SpamSec = Tabs.Combat:AddSection("Auto Spam")
SpamSec:AddToggle("AutoSpam", { Title = "Auto Spam", Default = false, Callback = function(v) cfg.autoSpam = v end })
SpamSec:AddSlider("Threshold", { Title = "Threshold", Min = 1, Max = 3, Default = 3, Rounding = 1, Callback = function(v) cfg.spamThreshold = v end })

-- ================= VISUAL UI (Avatar R6) =================

local VisualSec = Tabs.Visual:AddSection("Avatar Changer (R6)")

VisualSec:AddInput("TargetName", {
    Title = "Player Name / UserId",
    Description = "Введите ник Roblox или ID",
    Placeholder = "Username or ID",
    Default = "",
    Finished = true
})

local overlayModel = nil
local overlayConnection = nil

local function RemoveOverlay()
    if overlayConnection then overlayConnection:Disconnect() overlayConnection = nil end
    if overlayModel then
        pcall(function() overlayModel:Destroy() end)
        overlayModel = nil
    end
    local char = player.Character
    if char then
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Transparency = 0
                v.LocalTransparencyModifier = 0
            end
        end
    end
end

local function ApplyR6Avatar(userId)
    RemoveOverlay()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local ok, desc = pcall(function()
        return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
    end)
    if not ok or not desc then
        Fluent:Notify({ Title = "Avatar", Content = "Не удалось загрузить скин", Duration = 3 })
        return
    end

    local ok2, model = pcall(function()
        return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R6)
    end)

    if not ok2 or not model then
        Fluent:Notify({ Title = "Avatar", Content = "R6 недоступен, пробую R15", Duration = 2 })
        local ok3, modelR15 = pcall(function()
            return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R15)
        end)
        if not ok3 or not modelR15 then return end
        model = modelR15
    end

    model.Name = "Overlay"
    model.Parent = workspace

    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.DisplayName = ""
        hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
    end

    for _, v in ipairs(model:GetDescendants()) do
        if v:IsA("BillboardGui") or v:IsA("Highlight") or v:IsA("SelectionBox") or v:IsA("BoxHandleAdornment") or v:IsA("SpotLight") then
            v:Destroy()
        elseif v:IsA("BasePart") then
            v.CanCollide = false
            v.Massless = true
            v.Transparency = 0
        end
    end

    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Transparency = 1
        end
    end

    overlayModel = model

    overlayConnection = RunService.Heartbeat:Connect(function()
        local currentChar = player.Character
        local currentRoot = currentChar and currentChar:FindFirstChild("HumanoidRootPart")
        if not currentRoot or not overlayModel or not overlayModel.Parent then return end

        local mRootPart = overlayModel:FindFirstChild("HumanoidRootPart")
        if mRootPart then
            mRootPart.CFrame = currentRoot.CFrame
            
            if not mRootPart:FindFirstChild("OverlayWeld") then
                local weld = Instance.new("WeldConstraint")
                weld.Name = "OverlayWeld"
                weld.Part0 = currentRoot
                weld.Part1 = mRootPart
                weld.Parent = mRootPart
            end
        end

        for _, v in ipairs(currentChar:GetDescendants()) do
            if v:IsA("BasePart") and v.Transparency ~= 1 then
                v.Transparency = 1
            end
        end
    end)

    Fluent:Notify({ Title = "Avatar", Content = "R6 скин применён (локально)", Duration = 3 })
end

VisualSec:AddButton({
    Title = "Apply R6 Skin",
    Description = "Надеть R6 скин по нику/ID (видно только вам)",
    Callback = function()
        local input = Fluent.Options.TargetName.Value
        if input == "" then return end
        local userId = tonumber(input)
        if not userId then
            local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(input) end)
            if ok then userId = id end
        end
        if not userId then
            Fluent:Notify({ Title = "Avatar", Content = "Игрок не найден", Duration = 3 })
            return
        end
        ApplyR6Avatar(userId)
    end
})

VisualSec:AddButton({
    Title = "Remove Skin",
    Description = "Убрать оверлей",
    Callback = function()
        RemoveOverlay()
        Fluent:Notify({ Title = "Avatar", Content = "Скин убран", Duration = 2 })
    end
})

Fluent:Notify({
    Title = "Ruqwiri",
    Content = "Loaded. Auto Parry + Auto Spam + Avatar R6.",
    Duration = 4
})
