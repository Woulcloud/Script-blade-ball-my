-- ============================================
-- I See You — Violence District (Horizontal Menu)
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
menuFrame.Size = UDim2.new(0, 420, 0, 240)
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

local colWidth = 95
local colGap = 5
local colStartX = 5
local colStartY = 50

local function createColumn(name, index)
    local col = Instance.new("Frame")
    col.Name = name
    col.Size = UDim2.new(0, colWidth, 1, -55)
    col.Position = UDim2.new(0, colStartX + (colWidth + colGap) * index, 0, colStartY)
    col.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    col.BorderSizePixel = 1
    col.BorderColor3 = Color3.fromRGB(60, 60, 60)
    col.Parent = menuFrame

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, 0, 0, 18)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.Text = name
    header.Font = Enum.Font.SourceSansBold
    header.TextSize = 10
    header.TextColor3 = Color3.new(1, 1, 1)
    header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    header.BorderSizePixel = 0
    header.Parent = col

    return col
end

local mainCol = createColumn("Main", 0)
local killerCol = createColumn("Killer", 1)
local teleportCol = createColumn("Teleport", 2)
local optimCol = createColumn("Optimization", 3)

local function createColBtn(parent, text, yPos, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 22)
    btn.Position = UDim2.new(0, 5, 0, yPos)
    btn.Text = text
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 10
    btn.TextColor3 = Color3.new(0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.TextWrapped = true
    btn.Parent = parent

    local state = false
    btn.MouseButton1Click:Connect(function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(180, 180, 180) or Color3.fromRGB(255, 255, 255)
        callback(state)
    end)
    return btn
end

-- ESP
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

-- FLY
local flyEnabled = false
local flySpeed = 50
local flyBodyVelocity = nil
local flyBodyGyro = nil

local function toggleFly(enabled)
    flyEnabled = enabled
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if enabled then
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        flyBodyVelocity.Parent = hrp

        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
        flyBodyGyro.P = 1000
        flyBodyGyro.Parent = hrp

        task.spawn(function()
            while flyEnabled and flyBodyVelocity and flyBodyVelocity.Parent do
                RunService.RenderStepped:Wait()
                local cam = workspace.CurrentCamera
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                local moveDir = Vector3.new()

                if humanoid then
                    moveDir = humanoid.MoveDirection
                end

                if moveDir.Magnitude > 0 then
                    flyBodyVelocity.Velocity = moveDir * flySpeed
                else
                    flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
                end
                flyBodyGyro.CFrame = cam.CFrame
            end
        end)
    else
        if flyBodyVelocity then flyBodyVelocity:Destroy() end
        if flyBodyGyro then flyBodyGyro:Destroy() end
        flyBodyVelocity = nil
        flyBodyGyro = nil
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    wait(1)
    if flyEnabled then
        flyEnabled = false
        toggleFly(true)
    end
end)

-- AUTO SPRINT
local autoSprintEnabled = false
local autoSprintSpeed = 24

local function toggleAutoSprint(enabled)
    autoSprintEnabled = enabled
end

RunService.Heartbeat:Connect(function()
    if not autoSprintEnabled then return end
    local char = LocalPlayer.Character
    if not char then return end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.MoveDirection.Magnitude > 0 then
        humanoid.WalkSpeed = math.max(humanoid.WalkSpeed, autoSprintSpeed)
    end
end)

-- STEALTH
local transparencyEnabled = false

local function setCharacterTransparency(enabled)
    transparencyEnabled = enabled
    local char = LocalPlayer.Character
    if not char then return end

    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.LocalTransparencyModifier = enabled and 1 or 0
        end
    end
end

local function toggleTransparency(enabled)
    setCharacterTransparency(enabled)
end

LocalPlayer.CharacterAdded:Connect(function(char)
    wait(1)
    if transparencyEnabled then setCharacterTransparency(true) end
end)

-- GENERATOR ESP
local genEspEnabled = false
local genEspFolder = Instance.new("Folder")
genEspFolder.Name = "VD_GenESP"
genEspFolder.Parent = game.CoreGui

local function createGenESP(obj)
    if not obj:IsA("Model") and not obj:IsA("BasePart") then return end
    if genEspFolder:FindFirstChild(obj.Name) then return end

    local target = obj:IsA("Model") and obj:FindFirstChildWhichIsA("BasePart") or obj
    if not target then return end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = obj.Name
    box.Adornee = target
    box.Size = Vector3.new(4, 4, 4)
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Transparency = 0.5
    box.Color3 = Color3.fromRGB(0, 255, 0)
    box.Parent = genEspFolder
end

local function toggleGeneratorESP(enabled)
    genEspEnabled = enabled
    if enabled then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name:lower():find("generator") or obj.Name:lower():find("gen") then
                createGenESP(obj)
            end
        end
    else
        genEspFolder:ClearAllChildren()
    end
end

-- ANTI FLASHLIGHT
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

-- ANTI STUN
local antiStunEnabled = false
local stunRemoteBlocked = {}

local function toggleAntiStun(enabled)
    antiStunEnabled = enabled
end

local function tryBlockStunRemote(remote)
    if not antiStunEnabled then return end
    if stunRemoteBlocked[remote] then return end

    local name = remote.Name:lower()
    if name:find("stun") or name:find("pallet") or name:find("blind") then
        stunRemoteBlocked[remote] = true

        local mt = getrawmetatable(game)
        if mt then
            local oldNamecall = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if antiStunEnabled and self == remote and (method == "FireServer" or method == "InvokeServer") then
                    return nil
                end
                return oldNamecall(self, ...)
            end)
            setreadonly(mt, true)
        end
    end
end

for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        tryBlockStunRemote(obj)
    end
end

ReplicatedStorage.DescendantAdded:Connect(function(obj)
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        tryBlockStunRemote(obj)
    end
end)

-- TP TO PLAYER
local tpPanel = Instance.new("Frame")
tpPanel.Name = "TPPanel"
tpPanel.Size = UDim2.new(0, 180, 0, 220)
tpPanel.Position = UDim2.new(0, 500, 0, 80)
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

-- CLICK TP
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

-- BOOST FPS
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

-- ANTI LAG
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
    else
        for obj, material in pairs(savedObjects) do
            if obj and obj.Parent then
                obj.Material = material
            end
        end
        savedObjects = {}
    end
end

-- ANTI AFK
local antiAfkEnabled = false
local VirtualUser = game:GetService("VirtualUser")

local function toggleAntiAfk(enabled)
    antiAfkEnabled = enabled
end

LocalPlayer.Idled:Connect(function()
    if antiAfkEnabled then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end
end)

-- FULLBRIGHT
local fullbrightEnabled = false

local function toggleFullbright(enabled)
    fullbrightEnabled = enabled
    local Lighting = game:GetService("Lighting")
    if enabled then
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
    else
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 100000
    end
end

-- NO FOG
local noFogEnabled = false

local function toggleNoFog(enabled)
    noFogEnabled = enabled
    local Lighting = game:GetService("Lighting")
    if enabled then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    else
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    end
end

-- FOV CHANGER
local fovEnabled = false
local fovValue = 70
local originalFOV = workspace.CurrentCamera.FieldOfView

local function applyFOV()
    workspace.CurrentCamera.FieldOfView = fovEnabled and fovValue or originalFOV
end

local function toggleFOV(enabled)
    fovEnabled = enabled
    applyFOV()
end

workspace.CurrentCamera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
    if fovEnabled then
        workspace.CurrentCamera.FieldOfView = fovValue
    end
end)

-- MAIN КНОПКИ
createColBtn(mainCol, "ESP", 25, toggleESP)
createColBtn(mainCol, "Fly", 50, toggleFly)
createColBtn(mainCol, "Auto Sprint", 75, toggleAutoSprint)
createColBtn(mainCol, "Stealth", 100, toggleTransparency)
createColBtn(mainCol, "Generator ESP", 125, toggleGeneratorESP)

local flyLabel = Instance.new("TextLabel")
flyLabel.Size = UDim2.new(1, -10, 0, 15)
flyLabel.Position = UDim2.new(0, 5, 0, 152)
flyLabel.Text = "Fly Speed: 50"
flyLabel.Font = Enum.Font.SourceSans
flyLabel.TextSize = 10
flyLabel.TextColor3 = Color3.new(1, 1, 1)
flyLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
flyLabel.BorderSizePixel = 0
flyLabel.Parent = mainCol

local flyBar = Instance.new("Frame")
flyBar.Size = UDim2.new(1, -10, 0, 8)
flyBar.Position = UDim2.new(0, 5, 0, 170)
flyBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
flyBar.BorderSizePixel = 0
flyBar.Parent = mainCol

local flyFill = Instance.new("Frame")
flyFill.Size = UDim2.new(0, 0, 1, 0)
flyFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
flyFill.BorderSizePixel = 0
flyFill.Parent = flyBar

local flyDragging = false
flyBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        flyDragging = true
    end
end)

flyBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        flyDragging = false
    end
end)

flyBar.InputChanged:Connect(function(input)
    if flyDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local relX = math.clamp(input.Position.X - flyBar.AbsolutePosition.X, 0, flyBar.AbsoluteSize.X)
        local percent = relX / flyBar.AbsoluteSize.X
        flySpeed = math.floor(10 + percent * 190)
        flyLabel.Text = "Fly Speed: " .. flySpeed
        flyFill.Size = UDim2.new(percent, 0, 1, 0)
    end
end)

-- KILLER КНОПКИ
createColBtn(killerCol, "Anti Flashlight", 25, toggleAntiFlashlight)
createColBtn(killerCol, "Anti Stun", 50, toggleAntiStun)

-- TELEPORT КНОПКИ
createColBtn(teleportCol, "TP to Player", 25, function()
    refreshTPList()
    tpPanel.Visible = not tpPanel.Visible
end)
createColBtn(teleportCol, "Click TP", 50, toggleClickTP)

-- OPTIMIZATION КНОПКИ
createColBtn(optimCol, "Boost FPS", 25, toggleBoostFPS)
createColBtn(optimCol, "Anti Lag", 50, toggleAntiLag)
createColBtn(optimCol, "Anti AFK", 75, toggleAntiAfk)
createColBtn(optimCol, "Fullbright", 100, toggleFullbright)
createColBtn(optimCol, "No Fog", 125, toggleNoFog)

local fovLabel = Instance.new("TextLabel")
fovLabel.Size = UDim2.new(1, -10, 0, 15)
fovLabel.Position = UDim2.new(0, 5, 0, 152)
fovLabel.Text = "FOV: 70"
fovLabel.Font = Enum.Font.SourceSans
fovLabel.TextSize = 10
fovLabel.TextColor3 = Color3.new(1, 1, 1)
fovLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
fovLabel.BorderSizePixel = 0
fovLabel.Parent = optimCol

local fovBar = Instance.new("Frame")
fovBar.Size = UDim2.new(1, -10, 0, 8)
fovBar.Position = UDim2.new(0, 5, 0, 170)
fovBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
fovBar.BorderSizePixel = 0
fovBar.Parent = optimCol

local fovFill = Instance.new("Frame")
fovFill.Size = UDim2.new(0, 0, 1, 0)
fovFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
fovFill.BorderSizePixel = 0
fovFill.Parent = fovBar

local fovDragging = false
fovBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        fovDragging = true
    end
end)

fovBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        fovDragging = false
    end
end)

fovBar.InputChanged:Connect(function(input)
    if fovDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local relX = math.clamp(input.Position.X - fovBar.AbsolutePosition.X, 0, fovBar.AbsoluteSize.X)
        local percent = relX / fovBar.AbsoluteSize.X
        fovValue = math.floor(70 + percent * 50)
        fovLabel.Text = "FOV: " .. fovValue
        fovFill.Size = UDim2.new(percent, 0, 1, 0)
        applyFOV()
    end
end)

-- ОТКРЫТИЕ / ЗАКРЫТИЕ
toggleBtn.MouseButton1Click:Connect(function()
    menuFrame.Visible = not menuFrame.Visible
end)

print("[I See You] Menu loaded.")
