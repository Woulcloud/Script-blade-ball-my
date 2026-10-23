repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Stats = game:GetService("Stats")
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local cfg = {
    fullbright = false,
    speed = false, speedValue = 30,
    aimbot = false, aimKey = Enum.KeyCode.E, aimFov = 150,
    hitbox = false, hitboxSize = 10,
    fly = false, flySpeed = 50,
    noclip = false,
    espBox = false,
    showStats = false
}

local fovGui = Instance.new("ScreenGui")
fovGui.Name = "AimFOV"
fovGui.ResetOnSpawn = false
fovGui.DisplayOrder = 999999
fovGui.Parent = game:GetService("CoreGui")

local aimCircle = Instance.new("Frame")
aimCircle.AnchorPoint = Vector2.new(0.5, 0.5)
aimCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
aimCircle.BackgroundTransparency = 1
aimCircle.Visible = false
aimCircle.Parent = fovGui
Instance.new("UICorner", aimCircle).CornerRadius = UDim.new(1, 0)
local aimStroke = Instance.new("UIStroke", aimCircle)
aimStroke.Color = Color3.fromRGB(255, 255, 255)
aimStroke.Thickness = 1.5

local statsGui = Instance.new("ScreenGui")
statsGui.Name = "NotCryStats"
statsGui.ResetOnSpawn = false
statsGui.DisplayOrder = 999999
statsGui.Parent = game:GetService("CoreGui")

local statsFrame = Instance.new("TextButton")
statsFrame.Size = UDim2.new(0, 110, 0, 26)
statsFrame.Position = UDim2.new(0, 20, 0, 20)
statsFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
statsFrame.BackgroundTransparency = 0.2
statsFrame.BorderSizePixel = 0
statsFrame.Text = "FPS: 0 | Ping: 0"
statsFrame.TextColor3 = Color3.fromRGB(255, 255, 255)
statsFrame.Font = Enum.Font.GothamBold
statsFrame.TextSize = 11
statsFrame.Visible = false
statsFrame.Active = true
statsFrame.Parent = statsGui
Instance.new("UICorner", statsFrame).CornerRadius = UDim.new(0, 6)
local statsStroke = Instance.new("UIStroke", statsFrame)
statsStroke.Color = Color3.fromRGB(80, 80, 80)

local draggingStats, dragStartStats, startPosStats
statsFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingStats = true
        dragStartStats = input.Position
        startPosStats = statsFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingStats and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartStats
        statsFrame.Position = UDim2.new(startPosStats.X.Scale, startPosStats.X.Offset + delta.X, startPosStats.Y.Scale, startPosStats.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingStats = false end
end)

local fpsCounter = 0
local lastTime = tick()

RunService.RenderStepped:Connect(function()
    fpsCounter = fpsCounter + 1
    local currentTime = tick()
    if currentTime - lastTime >= 1 then
        if cfg.showStats then
            statsFrame.Visible = true
            local ping = 0
            pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
            statsFrame.Text = string.format("FPS: %d | Ping: %d", fpsCounter, ping)
        else
            statsFrame.Visible = false
        end
        fpsCounter = 0
        lastTime = currentTime
    end
end)

local originalLighting = {
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, GlobalShadows = Lighting.GlobalShadows,
    FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient
}

local function ApplyFullbright()
    Lighting.Brightness = 5
    Lighting.ClockTime = 14
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 100000
    Lighting.FogStart = 100000
    Lighting.Ambient = Color3.fromRGB(180, 180, 180)
    Lighting.OutdoorAmbient = Color3.fromRGB(180, 180, 180)
end

local function RestoreLighting()
    Lighting.Brightness = originalLighting.Brightness
    Lighting.ClockTime = originalLighting.ClockTime
    Lighting.GlobalShadows = originalLighting.GlobalShadows
    Lighting.FogEnd = originalLighting.FogEnd
    Lighting.FogStart = originalLighting.FogStart
    Lighting.Ambient = originalLighting.Ambient
    Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
end

local function ToggleFullbright(state)
    if state then ApplyFullbright() else RestoreLighting() end
end

task.spawn(function()
    while task.wait(0.5) do
        if cfg.fullbright then ApplyFullbright() end
    end
end)

local espDrawings = {}

local function CreateESP(p)
    if espDrawings[p] then return end
    local box = Drawing.new("Square")
    box.Thickness = 1.5
    box.Color = Color3.fromRGB(255, 255, 255)
    box.Filled = false
    box.Visible = false
    espDrawings[p] = {box = box}
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= player then
        if p.Character then CreateESP(p) end
        p.CharacterAdded:Connect(function() task.wait(1) CreateESP(p) end)
    end
end

RunService.RenderStepped:Connect(function()
    for p, data in pairs(espDrawings) do
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and p.Character:FindFirstChildOfClass("Humanoid") and p.Character.Humanoid.Health > 0 then
            local isTeammate = false
            if player.Team and p.Team and player.Team == p.Team then isTeammate = true end
            local head = p.Character:FindFirstChild("Head")
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if cfg.espBox and not isTeammate and head and root then
                local hScr, hOn = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                local rScr, rOn = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                if hOn and rOn then
                    local height = math.abs(hScr.Y - rScr.Y)
                    local width = height / 2
                    data.box.Visible = true
                    data.box.Size = Vector2.new(width, height)
                    data.box.Position = Vector2.new(hScr.X - width/2, hScr.Y)
                else
                    data.box.Visible = false
                end
            else
                data.box.Visible = false
            end
        else
            data.box.Visible = false
        end
    end
end)

RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.WalkSpeed = cfg.speed and cfg.speedValue or 16
    if cfg.noclip then
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
        end
    end
end)

local function GetTarget()
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local best, bestDist = nil, cfg.aimFov
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local head = p.Character:FindFirstChild("Head")
            if hum and head and hum.Health > 0 then
                local isTeammate = false
                if player.Team and p.Team and player.Team == p.Team then isTeammate = true end
                if not isTeammate then
                    local pos, onScreen = camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                        if dist < bestDist then 
                            bestDist = dist
                            best = head 
                        end
                    end
                end
            end
        end
    end
    return best
end

local aimActive = false
RunService.RenderStepped:Connect(function()
    if cfg.aimbot then
        aimCircle.Visible = true
        aimCircle.Size = UDim2.new(0, cfg.aimFov * 2, 0, cfg.aimFov * 2)
    else
        aimCircle.Visible = false
    end

    if cfg.aimbot and aimActive then
        local target = GetTarget()
        if target then 
            camera.CFrame = CFrame.new(camera.CFrame.Position, target.Position)
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe) if not gpe and input.KeyCode == cfg.aimKey then aimActive = true end end)
UserInputService.InputEnded:Connect(function(input) if input.KeyCode == cfg.aimKey then aimActive = false end end)

task.spawn(function()
    while task.wait(0.5) do
        if not cfg.hitbox then continue end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local head = p.Character:FindFirstChild("Head")
                if head then
                    head.Size = Vector3.new(cfg.hitboxSize, cfg.hitboxSize, cfg.hitboxSize)
                    head.Transparency = 0.5
                    head.CanCollide = false
                end
            end
        end
    end
end)

local flyVel, flyGyro = nil, nil
local function ToggleFly(state)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if state then
        flyVel = Instance.new("BodyVelocity") flyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5) flyVel.Velocity = Vector3.new(0, 0, 0) flyVel.Parent = root
        flyGyro = Instance.new("BodyGyro") flyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5) flyGyro.P = 1000 flyGyro.Parent = root
    else
        if flyVel then flyVel:Destroy() flyVel = nil end
        if flyGyro then flyGyro:Destroy() flyGyro = nil end
    end
end

RunService.Heartbeat:Connect(function()
    if cfg.fly and flyVel and flyGyro then
        local moveDir = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end
        flyVel.Velocity = moveDir * cfg.flySpeed
        flyGyro.CFrame = camera.CFrame
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NotCryMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 35)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -150)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = Color3.fromRGB(80, 80, 80)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Title.Text = "  Not Cry"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 8)

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 28, 0, 25)
ToggleBtn.Position = UDim2.new(1, -33, 0, 5)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ToggleBtn.Text = "—"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = Title
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 4)

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -10, 1, -45)
Content.Position = UDim2.new(0, 5, 0, 40)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
Content.CanvasSize = UDim2.new(0, 0, 0, 500)
Content.Parent = MainFrame
Instance.new("UIListLayout", Content).Padding = UDim.new(0, 5)

local function CreateBtn(text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.Text = text .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = Content
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.Text = text .. ": " .. (state and "ON" or "OFF")
        btn.BackgroundColor3 = state and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(30, 30, 30)
        btn.TextColor3 = state and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        callback(state)
    end)
end

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(1, 0, 0, 15)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = ("Speed Value: %d"):format(cfg.speedValue)
SpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedLabel.Font = Enum.Font.GothamBold
SpeedLabel.TextSize = 11
SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedLabel.Parent = Content

local SpeedSlider = Instance.new("TextButton")
SpeedSlider.Size = UDim2.new(1, -20, 0, 8)
SpeedSlider.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
SpeedSlider.BorderSizePixel = 0
SpeedSlider.Text = ""
SpeedSlider.Parent = Content
Instance.new("UICorner", SpeedSlider).CornerRadius = UDim.new(0, 4)

local SpeedFill = Instance.new("Frame")
SpeedFill.Size = UDim2.new((cfg.speedValue - 10) / 90, 0, 1, 0)
SpeedFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SpeedFill.BorderSizePixel = 0
SpeedFill.Parent = SpeedSlider
Instance.new("UICorner", SpeedFill).CornerRadius = UDim.new(0, 4)

local SPEED_MIN, SPEED_MAX = 10, 100
local function SetSpeedFromX(x)
    local rel = math.clamp((x - SpeedSlider.AbsolutePosition.X) / SpeedSlider.AbsoluteSize.X, 0, 1)
    cfg.speedValue = math.floor(SPEED_MIN + rel * (SPEED_MAX - SPEED_MIN) + 0.5)
    SpeedFill.Size = UDim2.new(rel, 0, 1, 0)
    SpeedLabel.Text = ("Speed Value: %d"):format(cfg.speedValue)
end

SpeedSlider.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then SetSpeedFromX(input.Position.X) end
end)
SpeedSlider.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then SetSpeedFromX(input.Position.X) end
end)

CreateBtn("Show Stats (FPS+Ping)", function(v) cfg.showStats = v end)
CreateBtn("Fullbright", function(v) cfg.fullbright = v ToggleFullbright(v) end)
CreateBtn("ESP Box", function(v) cfg.espBox = v end)
CreateBtn("Aimbot (Hold E)", function(v) cfg.aimbot = v end)
CreateBtn("Hitbox Expander", function(v) cfg.hitbox = v end)
CreateBtn("Fly (WASD)", function(v) cfg.fly = v ToggleFly(v) end)
CreateBtn("Noclip", function(v) cfg.noclip = v end)
CreateBtn("Speed Hack", function(v) cfg.speed = v end)

MainFrame.Size = UDim2.new(0, 220, 0, 450)
local isOpen = true
ToggleBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    Content.Visible = isOpen
    MainFrame.Size = isOpen and UDim2.new(0, 220, 0, 450) or UDim2.new(0, 220, 0, 35)
    ToggleBtn.Text = isOpen and "—" or "+"
end)

local dragging, dragStart, startPos
Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)

local ToggleGui = Instance.new("ScreenGui")
ToggleGui.Name = "ToggleGui"
ToggleGui.ResetOnSpawn = false
ToggleGui.DisplayOrder = 999999
ToggleGui.Parent = game:GetService("CoreGui")

local ToggleFloat = Instance.new("TextButton")
ToggleFloat.Size = UDim2.new(0, 90, 0, 40)
ToggleFloat.Position = UDim2.new(0, 20, 0.5, -20)
ToggleFloat.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
ToggleFloat.BorderSizePixel = 0
ToggleFloat.Text = "Toggle"
ToggleFloat.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleFloat.Font = Enum.Font.GothamBold
ToggleFloat.TextSize = 14
ToggleFloat.Active = true
ToggleFloat.Parent = ToggleGui
Instance.new("UICorner", ToggleFloat).CornerRadius = UDim.new(0, 8)
local FloatStroke = Instance.new("UIStroke", ToggleFloat)
FloatStroke.Color = Color3.fromRGB(80, 80, 80)

local draggingToggle, dragStartToggle, startPosToggle
ToggleFloat.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingToggle = true
        dragStartToggle = input.Position
        startPosToggle = ToggleFloat.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartToggle
        ToggleFloat.Position = UDim2.new(startPosToggle.X.Scale, startPosToggle.X.Offset + delta.X, startPosToggle.Y.Scale, startPosToggle.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then draggingToggle = false end
end)

ToggleFloat.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)
