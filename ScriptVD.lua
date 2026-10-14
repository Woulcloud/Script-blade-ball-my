-- ============================================
-- I See You — Violence District
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VD_CustomMenu"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

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

local menuFrame = Instance.new("Frame")
menuFrame.Name = "MenuFrame"
menuFrame.Size = UDim2.new(0, 180, 0, 370)
menuFrame.Position = UDim2.new(0, 70, 0, 100)
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

local function createBtn(text, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 25)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.Text = text
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 11
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

local skillCheckRemote = ReplicatedStorage:FindFirstChild("SkillCheck") 
    or ReplicatedStorage:FindFirstChild("GeneratorRemote")

local escapeRemote = ReplicatedStorage:FindFirstChild("Escape") 
    or ReplicatedStorage:FindFirstChild("ExitGate")

local autoGenEnabled = false
local autoSkillCheckEnabled = false
local instantEscapeEnabled = false

if skillCheckRemote then
    skillCheckRemote.OnClientEvent:Connect(function(...)
        if autoSkillCheckEnabled then
            skillCheckRemote:FireServer(true)
            print("[I See You] Auto Skill Check")
        end
    end)
else
    warn("[I See You] Ремоут скиллчека не найден")
end

local function autoGenerator(enabled)
    autoGenEnabled = enabled
    print("[I See You] Auto Generator: " .. (enabled and "ON" or "OFF"))
end

local function autoSkillCheck(enabled)
    autoSkillCheckEnabled = enabled
    print("[I See You] Auto Skill Check: " .. (enabled and "ON" or "OFF"))
end

local function instantEscape(enabled)
    instantEscapeEnabled = enabled
    if enabled then
        if escapeRemote then
            escapeRemote:FireServer()
            print("[I See You] Instant Escape")
        else
            warn("[I See You] Ремоут побега не найден")
        end
    end
    print("[I See You] Instant Escape: " .. (enabled and "ON" or "OFF"))
end

local antiFlashlightEnabled = false
local originalBrightness = nil
local originalAmbient = nil

local function toggleAntiFlashlight(enabled)
    antiFlashlightEnabled = enabled
    local Lighting = game:GetService("Lighting")
    
    if enabled then
        originalBrightness = Lighting.Brightness
        originalAmbient = Lighting.Ambient
        
        Lighting.Brightness = 0
        Lighting.Ambient = Color3.fromRGB(100, 100, 100)
        Lighting.OutdoorAmbient = Color3.fromRGB(100, 100, 100)
        
        print("[I See You] Anti Flashlight: ON")
    else
        if originalBrightness then Lighting.Brightness = originalBrightness end
        if originalAmbient then Lighting.Ambient = originalAmbient end
        Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
        
        print("[I See You] Anti Flashlight: OFF")
    end
end

game:GetService("Lighting").ChildAdded:Connect(function(child)
    if antiFlashlightEnabled and (child:IsA("SpotLight") or child:IsA("PointLight")) then
        child.Enabled = false
        child:Destroy()
    end
end)

local espEnabled = false
local espFolder = Instance.new("Folder")
espFolder.Name = "VD_ESP"
espFolder.Parent = game.CoreGui

local function createESP(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    if espFolder:FindFirstChild(player.Name) then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = player.Name
    highlight.Adornee = char
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = espFolder
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
    print("[I See You] ESP: " .. (enabled and "ON" or "OFF"))
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

local speedEnabled = false
local originalSpeed = 16

local function applySpeed(char)
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = speedEnabled and 30 or originalSpeed
    end
end

local function toggleSpeed(enabled)
    speedEnabled = enabled
    applySpeed(LocalPlayer.Character)
    print("[I See You] Speed 30: " .. (enabled and "ON" or "OFF"))
end

LocalPlayer.CharacterAdded:Connect(function(char)
    wait(1)
    applySpeed(char)
end)

local rageEnabled = false

local function rageLoop()
    while rageEnabled do
        RunService.Heartbeat:Wait()
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
    print("[I See You] Rage: " .. (enabled and "ON" or "OFF"))
end

createBtn("Auto Generator", 52, autoGenerator)
createBtn("Auto Skill Check", 82, autoSkillCheck)
createBtn("ESP Players", 112, toggleESP)
createBtn("Speed 30", 142, toggleSpeed)
createBtn("Rage (Auto Kill)", 172, toggleRage)
createBtn("Instant Escape", 202, instantEscape)
createBtn("Anti Flashlight", 232, toggleAntiFlashlight)

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

print("[I See You] Menu loaded. Press 'I' button to open.")
