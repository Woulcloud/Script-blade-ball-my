repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Ruqwiri Paid Script",
    SubTitle = "Immortal Edition",
    TabWidth = 160,
    Size = UDim2.fromOffset(440, 360),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "shield" }),
    Combat = Window:AddTab({ Title = "Combat", Icon = "sword" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "eye" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "settings" })
}

local cfg = { 
    autoParry = false, triggerBot = false, accuracy = 1.5, curveMethod = "camera", 
    manualSpam = false, ballStats = false,
    spinImmortal = false, spinSpeed = 50,
    showImmortalBtn = true
}

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
local function replay(customCF)
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
    local cf = customCF or camera.CFrame
    fire(captured.remote, HASH, captured.sessionKey, token, 0.5, cf, points, { mouse.X, mouse.Y }, false)
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

local function GetCurveCFrame()
    local camera = workspace.CurrentCamera
    local baseCF = camera.CFrame
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return baseCF end
    local method = cfg.curveMethod
    if method == "camera" then return baseCF end
    local enemy = GetNearbyPlayer()
    if not enemy or not enemy.PrimaryPart then return baseCF end
    local pos = enemy.PrimaryPart.Position
    if method == "dot" then return CFrame.lookAt(root.Position, pos + Vector3.new(0, 1.75, 0)) end
    if method == "backwards" then return CFrame.new(root.Position, root.Position - (pos - root.Position).Unit * 1000) end
    if method == "slow" then return CFrame.new(root.Position, root.Position + Vector3.new(0, -350, 0)) end
    if method == "random" then return CFrame.new(root.Position, pos + Vector3.new(math.random(-1000,1000), math.random(-350,1000), math.random(-1000,1000))) end
    return baseCF
end

local function SendParry()
    if not captured.remote or not captured.sessionKey then return false end
    local token = makeToken()
    if not token then return false end
    return pcall(function() replay(GetCurveCFrame()) end)
end

local parried, triggered = {}, {}

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

local function ProcessTriggerBot(ball)
    if not cfg.triggerBot then return end
    local bID = ball:GetDebugId()
    if ball:GetAttribute("target") ~= player.Name then triggered[bID] = nil return end
    if triggered[bID] then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    triggered[bID] = true
    SendParry()
    task.delay(0.5, function() triggered[bID] = nil end)
end

local spinAngle = 0
RunService.Heartbeat:Connect(function(dt)
    if cfg.spinImmortal then
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        
        if root and hum then
            if hum.Health > 0 then
                spinAngle = spinAngle + (cfg.spinSpeed * dt)
                local offset = Vector3.new(math.cos(spinAngle) * 15, math.sin(spinAngle) * 15, 0)
                root.CFrame = root.CFrame + offset
                root.Velocity = Vector3.new(0, 0, 0)
            end
        end
    end
end)

local manualSpamThread = nil
local function StartManualSpam()
    if manualSpamThread then return end
    manualSpamThread = task.spawn(function()
        while cfg.manualSpam do
            SendParry()
            task.wait(1 / 60)
        end
        manualSpamThread = nil
    end)
end
local function StopManualSpam()
    cfg.manualSpam = false
    if manualSpamThread then task.cancel(manualSpamThread) manualSpamThread = nil end
end

RunService.Heartbeat:Connect(function()
    if not captured.remote then return end
    local ball = GetRealBall()
    if not ball then return end
    
    if cfg.triggerBot then
        ProcessTriggerBot(ball)
    elseif cfg.autoParry then
        ProcessAutoParry(ball)
    end
end)

local Main = Tabs.Main:AddSection("Protection")

Main:AddToggle("SpinImmortal", {
    Title = "Desync Spin (Immortal)",
    Default = false,
    Callback = function(v) cfg.spinImmortal = v end
})

Main:AddSlider("SpinSpeed", {
    Title = "Spin Speed",
    Min = 10,
    Max = 200,
    Default = 50,
    Rounding = 1,
    Callback = function(v) cfg.spinSpeed = v end
})

local Combat = Tabs.Combat:AddSection("Parry")
Combat:AddToggle("AutoParry", { Title = "Auto Parry", Default = false, Callback = function(v) cfg.autoParry = v end })
Combat:AddSlider("Accuracy", { Title = "Accuracy", Min = 1, Max = 100, Default = 50, Rounding = 1, Callback = function(v) cfg.accuracy = (v / 50) end })
Combat:AddToggle("TriggerBot", { Title = "Trigger Bot", Default = false, Callback = function(v) cfg.triggerBot = v end })

local CurveSec = Tabs.Combat:AddSection("Curve")
CurveSec:AddDropdown("CurveMethod", {
    Title = "Curve Method",
    Values = { "camera", "dot", "backwards", "slow", "random" },
    Multi = false,
    Default = "camera",
    Callback = function(v) cfg.curveMethod = v end
})

local SpamSec = Tabs.Combat:AddSection("Manual Spam")
SpamSec:AddToggle("ManualSpam", {
    Title = "Manual Spam (E)",
    Default = false,
    Callback = function(v) cfg.manualSpam = v; if v then StartManualSpam() else StopManualSpam() end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.E then
        local toggle = Tabs.Combat:GetToggle("ManualSpam")
        toggle:SetValue(not toggle.Value)
    end
end)

local StatsSec = Tabs.Misc:AddSection("Ball Stats")
local statsLabel = nil

StatsSec:AddToggle("BallStats", {
    Title = "Ball Stats",
    Default = false,
    Callback = function(v)
        cfg.ballStats = v
        if v then
            if not statsLabel then
                local ScreenGui = Instance.new("ScreenGui")
                ScreenGui.Name = "RuqwiriStats"
                ScreenGui.ResetOnSpawn = false
                ScreenGui.Parent = player:WaitForChild("PlayerGui")
                statsLabel = Instance.new("TextLabel")
                statsLabel.Size = UDim2.new(0.3, 0, 0.05, 0)
                statsLabel.Position = UDim2.new(0.68, 0, 0.1, 0)
                statsLabel.BackgroundTransparency = 1
                statsLabel.TextColor3 = Color3.new(1, 1, 1)
                statsLabel.Font = Enum.Font.Fantasy
                statsLabel.TextSize = 22
                statsLabel.Text = "waiting..."
                statsLabel.Parent = ScreenGui
            end
        else
            if statsLabel then statsLabel.Parent:Destroy() statsLabel = nil end
        end
    end
})

task.spawn(function()
    while true do
        if cfg.ballStats and statsLabel then
            local ball = GetRealBall()
            if ball then
                local z = ball:FindFirstChild("zoomies")
                if z then statsLabel.Text = string.format("velocity: %.0f", z.VectorVelocity.Magnitude) end
            end
        end
        task.wait(0.1)
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RuqwiriMobile"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999999
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.Parent = player:WaitForChild("PlayerGui")

local function CreateMobileBtn(name, pos, text, callback)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(0, 130, 0, 44)
    btn.Position = pos
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.ZIndex = 9999
    btn.Active = true
    btn.Selectable = true
    btn.Modal = false
    btn.Parent = ScreenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = btn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(60, 60, 60)
    stroke.Thickness = 1
    stroke.Parent = btn

    local dragging, dragStart, startPos, moved = false, nil, nil, false

    local function onDown(input) dragging = true; moved = false; dragStart = input.Position; startPos = btn.Position end
    local function onMove(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 6 or math.abs(delta.Y) > 6 then moved = true end
            if moved then btn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end
        end
    end
    local function onUp() if dragging and not moved then callback(btn) end dragging = false end

    btn.MouseButton1Down:Connect(function() onDown({Position = UserInputService:GetMouseLocation(), UserInputType = Enum.UserInputType.MouseButton1}) end)
    btn.MouseButton1Up:Connect(onUp)
    btn.MouseButton1Click:Connect(function() if not moved then callback(btn) end end)
    btn.TouchTap:Connect(function() callback(btn) end)
    btn.InputChanged:Connect(onMove)
    btn.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then onUp() end end)

    return btn
end

local triggerBtn = CreateMobileBtn("TriggerBtn", UDim2.new(1, -160, 0.5, -80), "Trigger Bot [off]", function(btn)
    cfg.triggerBot = not cfg.triggerBot
    Tabs.Combat:GetToggle("TriggerBot"):SetValue(cfg.triggerBot)
    btn.Text = cfg.triggerBot and "Trigger Bot [on]" or "Trigger Bot [off]"
    btn.BackgroundColor3 = cfg.triggerBot and Color3.fromRGB(255, 105, 180) or Color3.fromRGB(22, 22, 22)
end)

local spamBtn = CreateMobileBtn("SpamBtn", UDim2.new(1, -160, 0.5, -25), "Manual Spam [off]", function(btn)
    cfg.manualSpam = not cfg.manualSpam
    Tabs.Combat:GetToggle("ManualSpam"):SetValue(cfg.manualSpam)
    btn.Text = cfg.manualSpam and "Manual Spam [on]" or "Manual Spam [off]"
    btn.BackgroundColor3 = cfg.manualSpam and Color3.fromRGB(255, 105, 180) or Color3.fromRGB(22, 22, 22)
    if cfg.manualSpam then StartManualSpam() else StopManualSpam() end
end)

local immortalBtn = CreateMobileBtn("ImmortalBtn", UDim2.new(1, -160, 0.5, 25), "Immortal [off]", function(btn)
    cfg.spinImmortal = not cfg.spinImmortal
    Tabs.Main:GetToggle("SpinImmortal"):SetValue(cfg.spinImmortal)
    btn.Text = cfg.spinImmortal and "Immortal [on]" or "Immortal [off]"
    btn.BackgroundColor3 = cfg.spinImmortal and Color3.fromRGB(255, 105, 180) or Color3.fromRGB(22, 22, 22)
end)

immortalBtn.Visible = cfg.showImmortalBtn

local VisualSec = Tabs.Visual:AddSection("UI Settings")
VisualSec:AddToggle("ShowImmortalUI", {
    Title = "Show Immortal Button",
    Default = true,
    Callback = function(v)
        cfg.showImmortalBtn = v
        if immortalBtn then immortalBtn.Visible = v end
    end
})

Fluent:Notify({ Title = "Ruqwiri Paid Script", Content = "Immortal Edition Loaded.", Duration = 4 })
