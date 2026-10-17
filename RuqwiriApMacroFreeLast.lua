local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")

local Player = Players.LocalPlayer
local Balls = workspace:WaitForChild("Balls")

local hook = hookfunction or (getgenv and getgenv().hookfunction)
local HASH = "5455ef47-de02-4074-808c-8d82c2cd12ec"
local byte, char = string.byte, string.char
local floor, bxor = math.floor, bit32.bxor
local captured, votes, key = {}, {}, nil

local WHITE = Color3.fromRGB(255, 255, 255)
local BLACK = Color3.fromRGB(0, 0, 0)
local DARK = Color3.fromRGB(15, 15, 15)

local boostEnabled = false
local disabledEffects = {}
local targetCPS = 1500
local spamRunning = false
local spamHeartbeat = nil

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

local function Parry()
    if not captured.remote or not captured.sessionKey then return end
    local token = makeToken()
    if not token then return end
    replay()
end

local accuracyMultiplier = 0.1

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
    if not ok or not swordData or type(swordData) ~= "table" or not swordData.AnimationType then
        AnimFix_Cache[swordName] = SwordAPI.Collection.Default:FindFirstChild("GrabParry")
        return AnimFix_Cache[swordName]
    end
    for _, obj in pairs(SwordAPI.Collection:GetChildren()) do
        if obj.Name == swordData.AnimationType then
            local anim = obj:FindFirstChild("GrabParry") or obj:FindFirstChild("Grab")
            if anim then AnimFix_Cache[swordName] = anim; return anim end
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
end)

local isActivated = false
local menuOpen = true
local autoParryEnabled = false
local spamEnabled = false
local parried_balls = {}

local function ShowNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

local function EnableBoost()
    if boostEnabled then return end
    boostEnabled = true
    pcall(function()
        Lighting.GlobalShadows = false
        Lighting.Brightness = 0
        Lighting.Ambient = Color3.fromRGB(128, 128, 128)
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
        Lighting.EnvironmentDiffuseScale = 0
        Lighting.EnvironmentSpecularScale = 0
    end)
    for _, effect in ipairs(Lighting:GetChildren()) do
        if effect:IsA("PostEffect") or effect:IsA("BlurEffect") or effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("DepthOfFieldEffect") or effect:IsA("Atmosphere") then
            pcall(function()
                disabledEffects[effect] = effect.Enabled
                effect.Enabled = false
            end)
        end
    end
    task.spawn(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if not boostEnabled then break end
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                    disabledEffects[obj] = obj.Enabled
                    obj.Enabled = false
                end
            end)
        end
    end)
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
end

local function DisableBoost()
    if not boostEnabled then return end
    boostEnabled = false
    for obj, origState in pairs(disabledEffects) do
        pcall(function() if obj and obj.Parent then obj.Enabled = origState end end)
    end
    disabledEffects = {}
    pcall(function()
        Lighting.GlobalShadows = true
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        Lighting.FogEnd = 1000
        Lighting.FogStart = 0
    end)
    pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic end)
end

local function StartSpam()
    if spamRunning then return end
    spamRunning = true
    local delay = 1 / targetCPS
    
    spamHeartbeat = RunService.Heartbeat:Connect(function()
        if not spamRunning then return end
        Parry()
        task.spawn(PlayGrabParry)
        if targetCPS > 60 then
            task.wait(delay)
        end
    end)
end

local function StopSpam()
    spamRunning = false
    if spamHeartbeat then
        spamHeartbeat:Disconnect()
        spamHeartbeat = nil
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if isActivated then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isActivated = true
        ShowNotification("Ruqwiri", "Ap Macro Activated", 2)
    end
end)

ShowNotification("Ruqwiri", "1 click to activate", 5)

local function GetRealBall()
    for _, ball in ipairs(Balls:GetChildren()) do
        if ball:GetAttribute("realBall") == true then return ball end
    end
    return nil
end

local function GetPing()
    local success, result = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return success and result or 100
end

local Lerp_Radians = 0
local Last_Warping = tick()

local function Is_Curved(ball)
    local Zoomies = ball:FindFirstChild("zoomies")
    if not Zoomies then return false end
    local Velocity = Zoomies.VectorVelocity
    local Character = Player.Character
    if not Character or not Character.PrimaryPart then return false end
    local distanceToBall = (Character.PrimaryPart.Position - ball.Position).Magnitude
    if distanceToBall <= 25 then return false end
    local Speed = Velocity.Magnitude
    local Direction = (Character.PrimaryPart.Position - ball.Position).Unit
    local Dot = Direction:Dot(Velocity.Unit)
    local Ping = GetPing() / 1000
    local Distance = (Character.PrimaryPart.Position - ball.Position).Magnitude
    local Reach_Time = Distance / Speed - Ping
    local Radians = math.rad(math.asin(math.clamp(Dot, -1, 1)))
    Lerp_Radians = Lerp_Radians + (Radians - Lerp_Radians) * 0.8
    if Lerp_Radians < 0.018 then Last_Warping = tick() end
    if (tick() - Last_Warping) < (Reach_Time / 1.5) then return true end
    return Dot < (0.5 - Ping)
end

local function ProcessAutoParry(ball)
    if not autoParryEnabled then return end
    local bID = ball:GetDebugId()
    if ball:GetAttribute("target") ~= Player.Name or parried_balls[bID] then return end
    if Is_Curved(ball) then return end
    local charPart = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
    if not charPart then return end
    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return end
    local velocity = zoomies.VectorVelocity
    local dist = (charPart.Position - ball.Position).Magnitude
    local ping = GetPing()
    local pingBase = math.clamp(ping / 100, 5, 17)
    local rawSpeed = velocity.Magnitude
    local speedAdjusted = math.min(math.max(rawSpeed - 9.5, 0), 650)
    local speedCoefficient = 2.4 + speedAdjusted * 0.002
    local scaledAg = speedCoefficient * accuracyMultiplier
    local targetDistance = pingBase + math.max(rawSpeed / scaledAg, 9.5)
    if dist <= targetDistance then
        parried_balls[bID] = true
        Parry()
        task.spawn(PlayGrabParry)
        ball:GetAttributeChangedSignal("target"):Once(function()
            parried_balls[bID] = nil
        end)
    end
end

RunService.Heartbeat:Connect(function()
    if not captured.remote then return end
    if not isActivated then return end
    local ball = GetRealBall()
    if not ball then return end
    if autoParryEnabled then ProcessAutoParry(ball) end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RuqwiriMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 240, 0, 300)
MainFrame.Position = UDim2.new(0, 20, 0, 80)
MainFrame.BackgroundColor3 = BLACK
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(40, 40, 40)
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundColor3 = DARK
Title.BorderSizePixel = 0
Title.Text = "  Ruqwiri"
Title.TextColor3 = WHITE
Title.TextSize = 14
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = Title

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 35, 0, 25)
ToggleBtn.Position = UDim2.new(1, -45, 0, 5)
ToggleBtn.BackgroundColor3 = WHITE
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "—"
ToggleBtn.TextColor3 = BLACK
ToggleBtn.TextSize = 18
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = Title

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleBtn

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "Content"
ContentFrame.Size = UDim2.new(1, -20, 1, -50)
ContentFrame.Position = UDim2.new(0, 10, 0, 42)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local function CreateButton(name, yPos)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Btn"
    btn.Size = UDim2.new(1, 0, 0, 38)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = WHITE
    btn.BorderSizePixel = 0
    btn.Text = name .. ": OFF"
    btn.TextColor3 = BLACK
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.Parent = ContentFrame
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    return btn
end

local AutoParryBtn = CreateButton("Auto Parry", 0)
local SpamBtn = CreateButton("Spam", 45)
local BoostFPSBtn = CreateButton("Boost FPS", 90)

local CPSLabel = Instance.new("TextLabel")
CPSLabel.Size = UDim2.new(1, 0, 0, 20)
CPSLabel.Position = UDim2.new(0, 0, 0, 140)
CPSLabel.BackgroundTransparency = 1
CPSLabel.Text = ("Target CPS: %d"):format(targetCPS)
CPSLabel.TextColor3 = WHITE
CPSLabel.TextSize = 12
CPSLabel.Font = Enum.Font.GothamBold
CPSLabel.Parent = ContentFrame

local CPSSlider = Instance.new("TextButton")
CPSSlider.Size = UDim2.new(1, 0, 0, 20)
CPSSlider.Position = UDim2.new(0, 0, 0, 165)
CPSSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
CPSSlider.BorderSizePixel = 0
CPSSlider.Text = ""
CPSSlider.Parent = ContentFrame

local CPSSliderCorner = Instance.new("UICorner")
CPSSliderCorner.CornerRadius = UDim.new(0, 5)
CPSSliderCorner.Parent = CPSSlider

local CPSFill = Instance.new("Frame")
CPSFill.Size = UDim2.new(1, 0, 1, 0)
CPSFill.BackgroundColor3 = WHITE
CPSFill.BorderSizePixel = 0
CPSFill.Parent = CPSSlider

local CPSFillCorner = Instance.new("UICorner")
CPSFillCorner.CornerRadius = UDim.new(0, 5)
CPSFillCorner.Parent = CPSFill

local CPS_MIN, CPS_MAX = 50, 1500

local function SetCPSFromX(x)
    local rel = math.clamp((x - CPSSlider.AbsolutePosition.X) / CPSSlider.AbsoluteSize.X, 0, 1)
    targetCPS = math.floor(CPS_MIN + rel * (CPS_MAX - CPS_MIN) + 0.5)
    CPSFill.Size = UDim2.new(rel, 0, 1, 0)
    CPSLabel.Text = ("Target CPS: %d"):format(targetCPS)
    if spamRunning then
        StopSpam()
        StartSpam()
    end
end

CPSSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        SetCPSFromX(input.Position.X)
    end
end)

CPSSlider.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        SetCPSFromX(input.Position.X)
    end
end)

local FULL_SIZE = UDim2.new(0, 240, 0, 300)
local MIN_SIZE = UDim2.new(0, 240, 0, 35)

ToggleBtn.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    if menuOpen then
        MainFrame.Size = FULL_SIZE
        ContentFrame.Visible = true
        ToggleBtn.Text = "—"
    else
        MainFrame.Size = MIN_SIZE
        ContentFrame.Visible = false
        ToggleBtn.Text = "□"
    end
end)

AutoParryBtn.MouseButton1Click:Connect(function()
    autoParryEnabled = not autoParryEnabled
    AutoParryBtn.Text = "Auto Parry: " .. (autoParryEnabled and "ON" or "OFF")
end)

SpamBtn.MouseButton1Click:Connect(function()
    spamEnabled = not spamEnabled
    SpamBtn.Text = "Spam: " .. (spamEnabled and "ON" or "OFF")
    if spamEnabled then
        StartSpam()
    else
        StopSpam()
    end
end)

BoostFPSBtn.MouseButton1Click:Connect(function()
    if boostEnabled then
        DisableBoost()
        BoostFPSBtn.Text = "Boost FPS: OFF"
    else
        EnableBoost()
        BoostFPSBtn.Text = "Boost FPS: ON"
    end
end)
