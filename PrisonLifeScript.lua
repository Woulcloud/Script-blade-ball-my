repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local cfg = {
    aimbot = false, aimKey = Enum.KeyCode.E, aimFov = 150, aimSmooth = 0.3,
    killAura = false, auraRange = 50,
    autoReload = false,
    speed = false, speedValue = 28,
    espHighlight = false, espSkeleton = true,
    effectFire = false, effectWings = false, effectCubes = false,
    effectHat = false, effectWhiteAura = false,
    showFpsPing = false
}

local effectsFolder = Instance.new("Folder", Workspace)
effectsFolder.Name = "NotCryEffects"

local fireAura, wings, cubesFolder, hatModel = nil, nil, nil, nil
local whiteAuraParts = {}

local function ClearAllEffects()
    if fireAura then fireAura:Destroy() fireAura = nil end
    if wings then wings:Destroy() wings = nil end
    if cubesFolder then cubesFolder:Destroy() cubesFolder = nil end
    if hatModel then hatModel:Destroy() hatModel = nil end
    for _, part in ipairs(whiteAuraParts) do part:Destroy() end
    whiteAuraParts = {}
end

local function CreateFireAura()
    if fireAura then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local part = Instance.new("Part")
    part.Size = Vector3.new(4, 4, 4)
    part.Transparency = 1
    part.CanCollide = false
    part.Massless = true
    part.Parent = effectsFolder
    local fire = Instance.new("Fire", part)
    fire.Size = 5
    fire.Heat = 10
    fire.Color = Color3.fromRGB(255, 0, 0)
    fire.SecondaryColor = Color3.fromRGB(255, 150, 0)
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = part
    weld.Parent = part
    fireAura = part
end

local function CreateWings()
    if wings then return end
    local char = player.Character
    local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
    if not torso then return end
    local wingsFolder = Instance.new("Folder", effectsFolder)
    wingsFolder.Name = "Wings"
    for i = -1, 1, 2 do
        local wing = Instance.new("Part")
        wing.Size = Vector3.new(0.2, 3, 5)
        wing.Transparency = 0.3
        wing.Color = Color3.fromRGB(255, 255, 255)
        wing.Material = Enum.Material.Neon
        wing.CanCollide = false
        wing.Massless = true
        wing.Parent = wingsFolder
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = torso
        weld.Part1 = wing
        weld.Parent = wing
        wing.CFrame = torso.CFrame * CFrame.new(i * 2, 1, 1) * CFrame.Angles(0, math.rad(i * -20), math.rad(i * 30))
    end
    wings = wingsFolder
end

local function CreateCubes()
    if cubesFolder then return end
    cubesFolder = Instance.new("Folder", effectsFolder)
    cubesFolder.Name = "Cubes"
    for i = 1, 4 do
        local cube = Instance.new("Part")
        cube.Size = Vector3.new(1, 1, 1)
        cube.Color = Color3.fromRGB(255, 255, 255)
        cube.Material = Enum.Material.Neon
        cube.CanCollide = false
        cube.Massless = true
        cube.Parent = cubesFolder
    end
end

local function CreateHat()
    if hatModel then return end
    local char = player.Character
    local head = char and char:FindFirstChild("Head")
    if not head then return end
    hatModel = Instance.new("Model", effectsFolder)
    hatModel.Name = "RiceHat"
    local part = Instance.new("Part")
    part.Name = "Handle"
    part.Size = Vector3.new(4, 0.2, 4)
    part.Color = Color3.fromRGB(255, 255, 255)
    part.Material = Enum.Material.Neon
    part.CanCollide = false
    part.Massless = true
    part.Parent = hatModel
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.FileMesh
    mesh.MeshId = "rbxassetid://183486326" 
    mesh.Scale = Vector3.new(3, 3, 3)
    mesh.Parent = part
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = head
    weld.Part1 = part
    weld.Parent = part
    part.CFrame = head.CFrame * CFrame.new(0, 1.5, 0)
end

local function CreateWhiteAura()
    if #whiteAuraParts > 0 then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local part = Instance.new("Part")
    part.Name = "WhiteAura"
    part.Size = Vector3.new(6, 6, 6)
    part.Transparency = 1
    part.CanCollide = false
    part.Massless = true
    part.Parent = effectsFolder
    local light = Instance.new("PointLight", part)
    light.Color = Color3.fromRGB(255, 255, 255)
    light.Range = 10
    light.Brightness = 2
    local particles = Instance.new("ParticleEmitter", part)
    particles.Texture = "rbxassetid://243660364"
    particles.Color = ColorSequence.new(Color3.fromRGB(255,255,255))
    particles.Size = NumberSequence.new(2)
    particles.Rate = 50
    particles.Speed = NumberRange.new(2, 5)
    particles.Lifetime = NumberRange.new(0.5, 1)
    particles.EmissionDirection = Enum.NormalId.Bottom
    particles.Rotation = NumberRange.new(0, 360)
    particles.RotSpeed = NumberRange.new(-90, 90)
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = root
    weld.Part1 = part
    weld.Parent = part
    table.insert(whiteAuraParts, part)
end

RunService.RenderStepped:Connect(function(dt)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if cfg.effectFire then CreateFireAura() else if fireAura then fireAura:Destroy() fireAura = nil end end
    if cfg.effectWings then CreateWings() else if wings then wings:Destroy() wings = nil end end
    if cfg.effectHat then CreateHat() else if hatModel then hatModel:Destroy() hatModel = nil end end
    if cfg.effectWhiteAura then CreateWhiteAura() else for _, part in ipairs(whiteAuraParts) do part:Destroy() end whiteAuraParts = {} end
    
    if cfg.effectCubes then
        CreateCubes()
        if cubesFolder then
            local angle = tick() * 2
            for i, cube in ipairs(cubesFolder:GetChildren()) do
                local a = angle + (i * math.pi / 2)
                cube.CFrame = root.CFrame * CFrame.new(math.cos(a) * 5, 2, math.sin(a) * 5)
                cube.CFrame = CFrame.new(cube.Position, root.Position)
            end
        end
    else
        if cubesFolder then cubesFolder:Destroy() cubesFolder = nil end
    end
end)

player.CharacterAdded:Connect(function(char)
    ClearAllEffects()
    task.wait(1)
    if cfg.effectFire then CreateFireAura() end
    if cfg.effectWings then CreateWings() end
    if cfg.effectHat then CreateHat() end
    if cfg.effectWhiteAura then CreateWhiteAura() end
end)

local statsGui = Instance.new("ScreenGui")
statsGui.Name = "NotCryStats"
statsGui.ResetOnSpawn = false
statsGui.DisplayOrder = 999999
statsGui.Parent = game:GetService("CoreGui")

local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(0, 150, 0, 30)
statsLabel.Position = UDim2.new(0, 10, 0, 10)
statsLabel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
statsLabel.BackgroundTransparency = 0.3
statsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statsLabel.Font = Enum.Font.GothamBold
statsLabel.TextSize = 12
statsLabel.Visible = false
statsLabel.Parent = statsGui
Instance.new("UICorner", statsLabel).CornerRadius = UDim.new(0, 6)

local fpsCounter = 0
local lastTime = tick()

RunService.RenderStepped:Connect(function()
    fpsCounter = fpsCounter + 1
    local currentTime = tick()
    if currentTime - lastTime >= 1 then
        if cfg.showFpsPing then
            local ping = 0
            pcall(function()
                ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            statsLabel.Visible = true
            statsLabel.Text = string.format("FPS: %d | Ping: %d ms", fpsCounter, ping)
        else
            statsLabel.Visible = false
        end
        fpsCounter = 0
        lastTime = currentTime
    end
end)

local espData = {}
local function CreateESP(p)
    if espData[p] then return end
    local highlight = Instance.new("Highlight")
    highlight.Name = "NotCryESP"
    highlight.FillColor = Color3.fromRGB(255, 50, 50)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.5
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Enabled = false
    highlight.Parent = p.Character
    espData[p] = {highlight = highlight}
end
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= player and p.Character then CreateESP(p) end
    p.CharacterAdded:Connect(function() task.wait(1) CreateESP(p) end)
end

local function GetTarget(fov)
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local best, bestDist = nil, fov
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local head = p.Character:FindFirstChild("Head")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 and (not player.Team or p.Team ~= player.Team) then
                local pos, onScreen = camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - center).Magnitude
                    if dist < bestDist then bestDist = dist; best = head end
                end
            end
        end
    end
    return best
end

local function GetClosestEnemy()
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local best, bestDist = nil, cfg.auraRange
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local head = p.Character:FindFirstChild("Head")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if head and hum and hum.Health > 0 and (not player.Team or p.Team ~= player.Team) then
                local dist = (root.Position - head.Position).Magnitude
                if dist < bestDist then bestDist = dist; best = head end
            end
        end
    end
    return best
end

local aimActive = false
RunService.RenderStepped:Connect(function()
    if cfg.aimbot and aimActive then
        local t = GetTarget(cfg.aimFov)
        if t then camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.Position, t.Position), cfg.aimSmooth) end
    end
    for p, data in pairs(espData) do
        if data.highlight then
            data.highlight.Enabled = cfg.espHighlight
            if cfg.espHighlight and p.Team == player.Team and player.Team then
                data.highlight.FillColor = Color3.fromRGB(0, 255, 0)
            elseif cfg.espHighlight then
                data.highlight.FillColor = Color3.fromRGB(255, 0, 0)
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe) if not gpe and input.KeyCode == cfg.aimKey then aimActive = true end end)
UserInputService.InputEnded:Connect(function(input) if input.KeyCode == cfg.aimKey then aimActive = false end end)

task.spawn(function()
    while task.wait(0.05) do
        if not cfg.killAura then continue end
        local char = player.Character
        local weapon = nil
        for _, v in ipairs(char:GetChildren()) do if v:IsA("Tool") then weapon = v break end end
        if not weapon then continue end
        local target = GetClosestEnemy()
        if not target then continue end
        local orig = camera.CFrame
        pcall(function() camera.CFrame = CFrame.new(camera.CFrame.Position, target.Position); weapon:Activate() end)
        task.wait(0.02)
        camera.CFrame = orig
    end
end)

RunService.Heartbeat:Connect(function()
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = cfg.speed and math.min(cfg.speedValue, 35) or 16 end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NotCryMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 280, 0, 35)
MainFrame.Position = UDim2.new(0.5, -140, 0.5, -150)
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
Title.TextSize = 14
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

local TabFrame = Instance.new("Frame")
TabFrame.Size = UDim2.new(1, -10, 0, 30)
TabFrame.Position = UDim2.new(0, 5, 0, 40)
TabFrame.BackgroundTransparency = 1
TabFrame.Parent = MainFrame
Instance.new("UIListLayout", TabFrame).FillDirection = Enum.FillDirection.Horizontal
Instance.new("UIListLayout", TabFrame).Padding = UDim.new(0, 5)

local TabCombat = Instance.new("TextButton")
TabCombat.Size = UDim2.new(0.24, -3, 1, 0)
TabCombat.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TabCombat.Text = "Combat"
TabCombat.TextColor3 = Color3.fromRGB(0, 0, 0)
TabCombat.Font = Enum.Font.GothamBold
TabCombat.TextSize = 11
TabCombat.Parent = TabFrame
Instance.new("UICorner", TabCombat).CornerRadius = UDim.new(0, 5)

local TabVisual = Instance.new("TextButton")
TabVisual.Size = UDim2.new(0.24, -3, 1, 0)
TabVisual.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TabVisual.Text = "Visual"
TabVisual.TextColor3 = Color3.fromRGB(255, 255, 255)
TabVisual.Font = Enum.Font.GothamBold
TabVisual.TextSize = 11
TabVisual.Parent = TabFrame
Instance.new("UICorner", TabVisual).CornerRadius = UDim.new(0, 5)

local TabEffects = Instance.new("TextButton")
TabEffects.Size = UDim2.new(0.24, -3, 1, 0)
TabEffects.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TabEffects.Text = "Effects"
TabEffects.TextColor3 = Color3.fromRGB(255, 255, 255)
TabEffects.Font = Enum.Font.GothamBold
TabEffects.TextSize = 11
TabEffects.Parent = TabFrame
Instance.new("UICorner", TabEffects).CornerRadius = UDim.new(0, 5)

local TabTP = Instance.new("TextButton")
TabTP.Size = UDim2.new(0.24, -3, 1, 0)
TabTP.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TabTP.Text = "TP"
TabTP.TextColor3 = Color3.fromRGB(255, 255, 255)
TabTP.Font = Enum.Font.GothamBold
TabTP.TextSize = 11
TabTP.Parent = TabFrame
Instance.new("UICorner", TabTP).CornerRadius = UDim.new(0, 5)

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -10, 1, -80)
Content.Position = UDim2.new(0, 5, 0, 75)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
Content.CanvasSize = UDim2.new(0, 0, 0, 400)
Content.Parent = MainFrame
Instance.new("UIListLayout", Content).Padding = UDim.new(0, 5)

local function ClearContent()
    for _, v in ipairs(Content:GetChildren()) do if v:IsA("TextButton") then v:Destroy() end end
end

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

local function LoadCombat()
    ClearContent()
    CreateBtn("Aimbot (Hold E)", function(v) cfg.aimbot = v end)
    CreateBtn("Kill Aura", function(v) cfg.killAura = v end)
    CreateBtn("Auto Reload", function(v) cfg.autoReload = v end)
    CreateBtn("Speed Hack", function(v) cfg.speed = v end)
end

local function LoadVisual()
    ClearContent()
    CreateBtn("ESP Highlight (Skin)", function(v) cfg.espHighlight = v end)
    CreateBtn("ESP Skeleton", function(v) cfg.espSkeleton = v end)
    CreateBtn("Show FPS + Ping", function(v) cfg.showFpsPing = v end)
end

local function LoadEffects()
    ClearContent()
    CreateBtn("Fire Aura", function(v) cfg.effectFire = v end)
    CreateBtn("Neon Wings", function(v) cfg.effectWings = v end)
    CreateBtn("Orbiting Cubes", function(v) cfg.effectCubes = v end)
    CreateBtn("Glowing Rice Hat", function(v) cfg.effectHat = v end)
    CreateBtn("White Bottom Aura", function(v) cfg.effectWhiteAura = v end)
end

local function TPWalk(targetPlayer, btn)
    local myChar = player.Character
    local targetChar = targetPlayer.Character
    if not myChar or not targetChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then return end

    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)

    local startPos = myRoot.Position
    local endPos = targetRoot.Position + (targetRoot.CFrame.LookVector * -3)
    local distance = (endPos - startPos).Magnitude
    local steps = math.floor(distance / 5)
    if steps < 1 then steps = 1 end

    for i = 1, steps do
        if not myRoot or not myRoot.Parent then break end
        local currentPos = myRoot.Position
        local dir = (endPos - currentPos).Unit
        myRoot.CFrame = CFrame.new(currentPos + (dir * 5), myRoot.CFrame.LookVector)
        task.wait(0.01)
    end

    if myRoot and myRoot.Parent then
        myRoot.CFrame = CFrame.new(endPos, myRoot.CFrame.LookVector)
    end

    task.wait(0.2)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
end

local function LoadTeleport()
    ClearContent()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 35)
            btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
            btn.Text = "TP to: " .. p.Name
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = 12
            btn.Parent = Content
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            
            btn.MouseButton1Click:Connect(function()
                TPWalk(p, btn)
            end)
        end
    end
end

TabCombat.MouseButton1Click:Connect(function()
    TabCombat.BackgroundColor3 = Color3.fromRGB(255, 255, 255) TabCombat.TextColor3 = Color3.fromRGB(0, 0, 0)
    TabVisual.BackgroundColor3 = Color3.fromRGB(30, 30, 30) TabVisual.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabEffects.BackgroundColor3 = Color3.fromRGB(30, 30, 30) TabEffects.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabTP.BackgroundColor3 = Color3.fromRGB(30, 30, 30) TabTP.TextColor3 = Color3.fromRGB(255, 255, 255)
    LoadCombat()
end)

TabVisual.MouseButton1Click:Connect(function()
    TabCombat.BackgroundColor3 = Color3.fromRGB(30, 30, 30) TabCombat.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabVisual.BackgroundColor3 = Color3.fromRGB(255, 255, 255) TabVisual.TextColor3 = Color3.fromRGB(0, 0, 0)
    TabEffects.BackgroundColor3 = Color3.fromRGB(30, 30, 30) TabEffects.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabTP.BackgroundColor3 = Color3.fromRGB(30, 30, 30) TabTP.TextColor3 = Color3.fromRGB(255, 255, 255)
    LoadVisual()
end)

TabEffects.MouseButton1Click:Connect(function()
    TabCombat.BackgroundColor3 = Color3.fromRGB(30, 30, 30) TabCombat.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabVisual.BackgroundColor3 = Color3.fromRGB(30, 30, 30) TabVisual.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabEffects.BackgroundColor3 = Color3.fromRGB(255, 255, 255) TabEffects.TextColor3 = Color3.fromRGB(0, 0, 0)
    TabTP.BackgroundColor3 = Color3.fromRGB(30, 30, 30) TabTP.TextColor3 = Color3.fromRGB(255, 255, 255)
    LoadEffects()
end)

TabTP.MouseButton1Click:Connect(function()
    TabCombat.BackgroundColor3 = Color3.fromRGB(30, 30, 30) TabCombat.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabVisual.BackgroundColor3 = Color3.fromRGB(30, 30, 30) TabVisual.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabEffects.BackgroundColor3 = Color3.fromRGB(30, 30, 30) TabEffects.TextColor3 = Color3.fromRGB(255, 255, 255)
    TabTP.BackgroundColor3 = Color3.fromRGB(255, 255, 255) TabTP.TextColor3 = Color3.fromRGB(0, 0, 0)
    LoadTeleport()
end)

LoadCombat()

MainFrame.Size = UDim2.new(0, 280, 0, 260)
ToggleBtn.Text = "—"
local isOpen = true
ToggleBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    TabFrame.Visible = isOpen
    Content.Visible = isOpen
    MainFrame.Size = isOpen and UDim2.new(0, 280, 0, 260) or UDim2.new(0, 280, 0, 35)
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
ToggleGui.Name = "NotCryToggle"
ToggleGui.ResetOnSpawn = false
ToggleGui.DisplayOrder = 999999
ToggleGui.Parent = game:GetService("CoreGui")

local ToggleFloat = Instance.new("TextButton")
ToggleFloat.Size = UDim2.new(0, 40, 0, 40)
ToggleFloat.Position = UDim2.new(0, 15, 0.5, -20)
ToggleFloat.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
ToggleFloat.Text = "≡"
ToggleFloat.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleFloat.Font = Enum.Font.GothamBold
ToggleFloat.TextSize = 20
ToggleFloat.Parent = ToggleGui
Instance.new("UICorner", ToggleFloat).CornerRadius = UDim.new(0, 8)

ToggleFloat.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)
