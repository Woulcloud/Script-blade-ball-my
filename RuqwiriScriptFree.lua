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
    SubTitle = "Auto Parry",
    TabWidth = 160,
    Size = UDim2.fromOffset(440, 260),
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
    accuracy = 1.5
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

local function SendParry()
    if not captured.remote or not captured.sessionKey then return false end
    local token = makeToken()
    if not token then return false end
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
        ball:GetAttributeChangedSignal("target"):Once(function()
            parried[bID] = nil
        end)
    end
end

RunService.Heartbeat:Connect(function()
    if not captured.remote then return end
    local ball = GetRealBall()
    if not ball then return end
    ProcessAutoParry(ball)
end)

local Combat = Tabs.Combat:AddSection("Parry")

Combat:AddToggle("AutoParry", {
    Title = "Auto Parry",
    Default = false,
    Callback = function(v)
        cfg.autoParry = v
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

Fluent:Notify({
    Title = "Ruqwiri",
    Content = "Loaded. Auto Parry ready.",
    Duration = 4
})
