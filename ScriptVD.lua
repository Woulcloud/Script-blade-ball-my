-- ============================================
-- I See You — Violence District
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VD_CustomMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Кнопка открытия
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ToggleBtn"
toggleBtn.Size = UDim2.new(0, 50, 0, 50)
toggleBtn.Position = UDim2.new(0, 10, 0, 100)
toggleBtn.Text = "I"
toggleBtn.Font = Enum.Font.SourceSansBold
toggleBtn.TextSize = 18
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
toggleBtn.BorderSizePixel = 1
toggleBtn.BorderColor3 = Color3.fromRGB(255, 255, 255)
toggleBtn.Parent = screenGui

-- Главное меню
local menuFrame = Instance.new("Frame")
menuFrame.Name = "MenuFrame"
menuFrame.Size = UDim2.new(0, 180, 0, 480)
menuFrame.Position = UDim2.new(0, 70, 0, 80)
menuFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
menuFrame.BorderSizePixel = 1
menuFrame.BorderColor3 = Color3.fromRGB(255, 255, 255)
menuFrame.Visible = false
menuFrame.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 25)
title.Position = UDim2.new(0, 0, 0, 0)
title.Text = "I See You"
title.Font = Enum.Font.SourceSansBold
title.TextSize = 14
title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
title.BorderSizePixel = 0
title.Parent = menuFrame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0, 15)
subtitle.Position = UDim2.new(0, 0, 0, 25)
subtitle.Text = "Violence District"
subtitle.Font = Enum.Font.SourceSans
subtitle.TextSize = 10
subtitle.TextColor3 = Color3.fromRGB(180, 180, 180)
subtitle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
subtitle.BorderSizePixel = 0
subtitle.Parent = menuFrame

local line = Instance.new("Frame")
line.Size = UDim2.new(1, -10, 0, 1)
line.Position = UDim2.new(0, 5, 0, 42)
line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
line.BorderSizePixel = 0
line.Parent = menuFrame

-- Разделитель категории
local function createSection(text, yPos)
    local section = Instance.new("TextLabel")
    section.Size = UDim2.new(1, -20, 0, 18)
    section.Position = UDim2.new(0, 10, 0, yPos)
    section.Text = "— " .. text .. " —"
    section.Font = Enum.Font.SourceSansBold
    section.TextSize = 10
    section.TextColor3 = Color3.fromRGB(255, 255, 255)
    section.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    section.BorderSizePixel = 0
    section.Parent = menuFrame
end

-- Кнопка
local function createBtn(text, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 22)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.Text = text
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 10
    btn.TextColor3 = Color3.new(0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.Parent = menuFrame

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(180, 180, 180) or Color3.fromRGB(255, 255, 255)
        callback(state)
    end)
    return btn
end

-- ============================================
-- MAIN: ESP
-- ============================================

local espEnabled = false
local espFolder = Instance.new("Folder")
espFolder.Name = "VD_ESP"
espFolder.Parent = game.CoreGui

local function createESP(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    if espFolder:FindFirstChild(player.Name) then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = player.Name
    box.Adornee = hrp
    box.Size = Vector3.new(2, 5, 2)
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Transparency = 0.5
    box.Color3 = Color3.fromRGB(255, 0, 0)
    box.Parent = espFolder
end

local function toggleESP(enabled)
    espEnabled = enabled
    if enabled then
        for _, p in ipairs(Players:GetPlayers()) do
            createESP(p)
        end
    else
        espFolder:ClearAllChildren()
    end
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        wait(1)
        if espEnabled then createESP(p) end
    end)
end)

Players.PlayerRemoving:Connect(function(p)
    local h = espFolder:FindFirstChild(p.Name)
    if h then h:Destroy() end
end)

-- ============================================
-- MAIN: SPEED BOOST (СЛАЙДЕР 16-30)
-- ============================================

local speedValue = 16
local speedEnabled = false

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -20, 0, 15)
speedLabel.Position = UDim2.new(0, 10, 0, 142)
speedLabel.Text = "Speed Boost: 16"
speedLabel.Font = Enum.Font.SourceSans
speedLabel.TextSize = 10
speedLabel.TextColor3 = Color3.new(1, 1, 1)
speedLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
speedLabel.BorderSizePixel = 0
speedLabel.Parent = menuFrame

local speedBar = Instance.new("Frame")
speedBar.Size = UDim2.new(1, -20, 0, 8)
speedBar.Position = UDim2.new(0, 10, 0, 160)
speedBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
speedBar.BorderSizePixel = 0
speedBar.Parent = menuFrame

local speedFill = Instance.new("Frame")
speedFill.Size = UDim2.new(0, 0, 1, 0)
speedFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
speedFill.BorderSizePixel = 0
speedFill.Parent = speedBar

local speedBtn = Instance.new("TextButton")
speedBtn.Size = UDim2.new(1, -20, 0, 22)
speedBtn.Position = UDim2.new(0, 10, 0, 172)
speedBtn.Text = "Speed Boost Toggle"
speedBtn.Font = Enum.Font.SourceSans
speedBtn.TextSize = 10
speedBtn.TextColor3 = Color3.new(0, 0, 0)
speedBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
speedBtn.BorderSizePixel = 0
speedBtn.Parent = menuFrame

local speedState = false
speedBtn.MouseButton1Click:Connect(function()
    speedState = not speedState
    speedEnabled = speedState
    speedBtn.BackgroundColor3 = speedState and Color3.fromRGB(180, 180, 180) or Color3.fromRGB(255, 255, 255)
    applySpeed()
end)

local speedDragging = false
speedBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        speedDragging = true
    end
end)

speedBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        speedDragging = false
    end
end)

speedBar.InputChanged:Connect(function(input)
    if speedDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local relX = math.clamp(input.Position.X - speedBar.AbsolutePosition.X, 0, speedBar.AbsoluteSize.X)
        local percent = relX / speedBar.AbsoluteSize.X
        speedValue = math.floor(16 + percent * 14)
        speedLabel.Text = "Speed Boost: " .. speedValue
        speedFill.Size = UDim2.new(percent, 0, 1, 0)
        applySpeed()
    end
end)

local function applySpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = speedEnabled and speedValue or 16
    end
end

LocalPlayer.CharacterAdded:Connect(function(char)
    wait(1)
    applySpeed()
end)

-- ============================================
-- MAIN: INSTANT ESCAPE
-- ============================================

local escapeRemote = ReplicatedStorage:FindFirstChild("Escape") 
    or ReplicatedStorage:FindFirstChild("ExitGate")

local function instantEscape(enabled)
    if enabled and escapeRemote then
        escapeRemote:FireServer()
    end
end

-- ============================================
-- KILLER: ANTI FLASHLIGHT
-- ============================================

local antiFlashlightEnabled = false

local function toggleAntiFlashlight(enabled)
    antiFlashlightEnabled = enabled
    local Lighting = game:GetService("Lighting")
    if enabled then
        Lighting.Brightness = 0
        Lighting.Ambient = Color3.fromRGB(100, 100, 100)
        Lighting.OutdoorAmbient = Color3.fromRGB(100, 100, 100)
    else
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(128, 128, 128)
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    end
end

game:GetService("Lighting").ChildAdded:Connect(function(child)
    if antiFlashlightEnabled and (child:IsA("SpotLight") or child:IsA("PointLight")) then
        child.Enabled = false
        child:Destroy()
    end
end)

-- ============================================
-- KILLER: RAGE (AUTO KILL)
-- ============================================

local rageEnabled = false
local rageCooldown = 0

local function rageLoop()
    while rageEnabled do
        RunService.Heartbeat:Wait()
        if tick() - rageCooldown < 0.3 then continue end
        
        local char = LocalPlayer.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        
        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end
            local targetChar = player.Character
            if not targetChar then continue end
            local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
            if not targetHrp then continue end
            
            local dist = (hrp.Position - targetHrp.Position).Magnitude
            if dist < 10 then
                print("[I See You RAGE] Attacking: " .. player.Name)
                rageCooldown = tick()
                break
            end
        end
    end
end

local function toggleRage(enabled)
    rageEnabled = enabled
    if enabled then
        task.spawn(rageLoop)
    end
end

-- ============================================
-- TELEPORT: TP TO PLAYER
-- ============================================

local tpPanel = Instance.new("Frame")
tpPanel.Name = "TPPanel"
tpPanel.Size = UDim2.new(0, 180, 0, 220)
tpPanel.Position = UDim2.new(0, 260, 0, 80)
tpPanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
tpPanel.BorderSizePixel = 1
tpPanel.BorderColor3 = Color3.fromRGB(255, 255, 255)
tpPanel.Visible = false
tpPanel.Parent = screenGui

local tpTitle = Instance.new("TextLabel")
tpTitle.Size = UDim2.new(1, 0, 0, 25)
tpTitle.Position = UDim2.new(0, 0, 0, 0)
tpTitle.Text = "TP to Player"
tpTitle.Font = Enum.Font.SourceSansBold
tpTitle.TextSize = 12
tpTitle.TextColor3 = Color3.new(1, 1, 1)
tpTitle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
tpTitle.BorderSizePixel = 0
tpTitle.Parent = tpPanel

local tpLine = Instance.new("Frame")
tpLine.Size = UDim2.new(1, -10, 0, 1)
tpLine.Position = UDim2.new(0, 5, 0, 25)
tpLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
tpLine.BorderSizePixel = 0
tpLine.Parent = tpPanel

local tpList = Instance.new("ScrollingFrame")
tpList.Size = UDim2.new(1, -10, 1, -35)
tpList.Position = UDim2.new(0, 5, 0, 30)
tpList.BackgroundTransparency = 1
tpList.BorderSizePixel = 0
tpList.ScrollBarThickness = 3
tpList.CanvasSize = UDim2.new(0, 0, 0, 0)
tpList.Parent = tpPanel

local function tpToPlayer(player)
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local targetChar = player.Character
    if not targetChar then return end
    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return end
    hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 3)
end

local function refreshTPList()
    for _, child in ipairs(tpList:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    
    local y = 0
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -5, 0, 22)
        btn.Position = UDim2.new(0, 0, 0, y)
        btn.Text = player.Name
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 10
        btn.TextColor3 = Color3.new(0, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        btn.BorderSizePixel = 0
        btn.Parent = tpList
        
        btn.MouseButton1Click:Connect(function()
            tpToPlayer(player)
        end)
        
        y = y + 25
    end
    
    tpList.CanvasSize = UDim2.new(0, 0, 0, y)
end

Players.PlayerAdded:Connect(refreshTPList)
Players.PlayerRemoving:Connect(function()
    wait(0.5)
    refreshTPList()
end)

-- ============================================
-- TELEPORT: CLICK TP
-- ============================================

local clickTPEnabled = false

local function toggleClickTP(enabled)
    clickTPEnabled = enabled
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not clickTPEnabled then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
    
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local mouse = LocalPlayer:GetMouse()
    if mouse.Hit then
        hrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
    end
end)

-- ============================================
-- OPTIMIZATION: BOOST FPS
-- ============================================

local boostFpsEnabled = false
local originalSettings = {}

local function toggleBoostFPS(enabled)
    boostFpsEnabled = enabled
    local Lighting = game:GetService("Lighting")
    local Terrain = workspace:FindFirstChildOfClass("Terrain")

    if enabled then
        originalSettings.GlobalShadows = Lighting.GlobalShadows
        originalSettings.FogEnd = Lighting.FogEnd
        originalSettings.Brightness = Lighting.Brightness

        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        Lighting.Brightness = 2

        if Terrain then
            Terrain.WaterWaveSize = 0
            Terrain.WaterWaveSpeed = 0
            Terrain.WaterReflectance = 0
            Terrain.WaterTransparency = 1
        end

        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
                obj.Enabled = false
            end
        end
    else
        Lighting.GlobalShadows = originalSettings.GlobalShadows or true
        Lighting.FogEnd = originalSettings.FogEnd or 100000
        Lighting.Brightness = originalSettings.Brightness or 2
    end
end

-- ============================================
-- OPTIMIZATION: ANTI LAG
-- ============================================

local antiLagEnabled = false
local savedObjects = {}

local function toggleAntiLag(enabled)
    antiLagEnabled = enabled
    
    if enabled then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj:IsDescendantOf(LocalPlayer.Character or game) then
                if obj.Material ~= Enum.Material.SmoothPlastic then
                    savedObjects[obj] = obj.Material
                    obj.Material = Enum.Material.SmoothPlastic
                end
            end
        end
        
        local Lighting = game:GetService("Lighting")
        for _, effect in ipairs(Lighting:GetChildren()) do
            if effect:IsA("PostEffect") or effect:IsA("Atmosphere") or effect:IsA("Sky") then
                effect.Enabled = false
            end
        end
        
        print("[I See You] Anti Lag: ON")
    else
        for obj, material in pairs(savedObjects) do
            if obj and obj.Parent then
                obj.Material = material
            end
        end
        savedObjects = {}
        
        print("[I See You] Anti Lag: OFF")
    end
end

-- ============================================
-- МЕНЮ: КАТЕГОРИИ И КНОПКИ
-- ============================================

-- MAIN
createSection("Main", 48)
createBtn("ESP Players", 68, toggleESP)
createBtn("Speed Boost Toggle", 92, function() end)
createBtn("Instant Escape", 116, instantEscape)

-- KILLER
createSection("Killer", 190)
createBtn("Anti Flashlight", 210, toggleAntiFlashlight)
createBtn("Rage (Auto Kill)", 234, toggleRage)

-- TELEPORT
createSection("Teleport", 262)
createBtn("TP to Player", 282, function()
    refreshTPList()
    tpPanel.Visible = not tpPanel.Visible
end)
createBtn("Click TP", 306, toggleClickTP)

-- OPTIMIZATION
createSection("Optimization", 334)
createBtn("Boost FPS", 354, toggleBoostFPS)
createBtn("Anti Lag", 378, toggleAntiLag)

-- ============================================
-- ОТКРЫТИЕ / ЗАКРЫТИЕ + ПЕРЕТАСКИВАНИЕ
-- ============================================

toggleBtn.MouseButton1Click:Connect(function()
    menuFrame.Visible = not menuFrame.Visible
end)

local dragging = false
local dragStart, startPos

menuFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = menuFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

menuFrame.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        menuFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

print("[I See You] Menu loaded.")
