repeat task.wait() until game:IsLoaded()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Window = Fluent:CreateWindow({
    Title = "Ruqwiri",
    TabWidth = 160,
    Size = UDim2.fromOffset(440, 360),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Main = Window:AddTab({ Title = "Main", Icon = "home" })
local MainSection = Main:AddSection("Hitbox")

local hitboxEnabled = false
local hitboxSize = 15
local originalData = {}

local function applyHitbox(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then return end
    if not originalData[player] then
        originalData[player] = {
            Size = hrp.Size, Transparency = hrp.Transparency,
            CanCollide = hrp.CanCollide, Color = hrp.Color, Material = hrp.Material
        }
    end
    hrp.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
    hrp.Transparency = 0.5
    hrp.CanCollide = false
    hrp.Color = Color3.fromRGB(255, 0, 0)
    hrp.Material = Enum.Material.Neon
end

local function resetHitbox(player)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then return end
    local data = originalData[player]
    if data then
        hrp.Size = data.Size
        hrp.Transparency = data.Transparency
        hrp.CanCollide = data.CanCollide
        hrp.Color = data.Color
        hrp.Material = data.Material
        originalData[player] = nil
    else
        hrp.Size = Vector3.new(2, 2, 1)
        hrp.Transparency = 0
        hrp.CanCollide = true
        hrp.Color = Color3.new(1, 1, 1)
        hrp.Material = Enum.Material.Plastic
    end
end

RunService.Heartbeat:Connect(function()
    if not hitboxEnabled then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then applyHitbox(player) end
    end
end)

MainSection:AddToggle("HitboxToggle", {
    Title = "Hitbox Expander",
    Description = "Increases other players' hitbox",
    Default = false,
    Callback = function(value)
        hitboxEnabled = value
        if not value then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then resetHitbox(player) end
            end
        end
    end
})

MainSection:AddSlider("HitboxSize", {
    Title = "Hitbox Size",
    Description = "Hitbox size (studs)",
    Default = 15, Min = 5, Max = 50, Rounding = 1,
    Callback = function(value) hitboxSize = value end
})

local autoInteractEnabled = false

local function tryInteract()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local closestPrompt, closestDist = nil, 15
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            local parent = obj.Parent
            if parent and parent:IsA("BasePart") then
                local dist = (parent.Position - hrp.Position).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestPrompt = obj
                end
            end
        end
    end
    if closestPrompt then
        closestPrompt:InputHoldBegin()
        task.wait(0.1)
        closestPrompt:InputHoldEnd()
    end
end

task.spawn(function()
    while task.wait(0.3) do
        if autoInteractEnabled then tryInteract() end
    end
end)

MainSection:AddToggle("AutoInteractToggle", {
    Title = "Auto Interact (Quests)",
    Description = "Auto-activates nearby quest objects (ProximityPrompt)",
    Default = false,
    Callback = function(value)
        autoInteractEnabled = value
        if value then
            Fluent:Notify({ Title = "Auto Interact", Content = "Enabled. Walk near quest NPCs/objects.", Duration = 3 })
        end
    end
})

local SpeedSection = Main:AddSection("Speed")
local KILLER_SPEED = 30.75
local defaultSpeed = 16
local killerSpeedEnabled = false
local KillerSpeedToggle

KillerSpeedToggle = SpeedSection:AddToggle("KillerSpeedToggle", {
    Title = "Killer Speed",
    Description = "Sets your walk speed to the fastest killer speed (30.75)",
    Default = false,
    Callback = function(value)
        killerSpeedEnabled = value
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if value then
            defaultSpeed = hum.WalkSpeed
            hum.WalkSpeed = KILLER_SPEED
            Fluent:Notify({ Title = "Speed", Content = "Killer speed ON (30.75)", Duration = 2 })
        else
            hum.WalkSpeed = defaultSpeed
            Fluent:Notify({ Title = "Speed", Content = "Killer speed OFF", Duration = 2 })
        end
    end
})

SpeedSection:AddButton({
    Title = "Disable Killer Speed",
    Description = "Force-disables killer speed and restores normal speed",
    Callback = function()
        killerSpeedEnabled = false
        if KillerSpeedToggle then KillerSpeedToggle:Set(false) end
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
        Fluent:Notify({ Title = "Speed", Content = "Killer speed disabled (16)", Duration = 2 })
    end
})

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if killerSpeedEnabled then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = KILLER_SPEED end
    end
end)

local NoclipSection = Main:AddSection("Noclip")
local noclipEnabled = false
local noclipConnection = nil
local mobileNoclipButton = nil

local function setNoclip(state)
    noclipEnabled = state
    local char = LocalPlayer.Character
    if not char then return end
    if state then
        if noclipConnection then noclipConnection:Disconnect() end
        noclipConnection = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            if not c then return end
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end)
        Fluent:Notify({ Title = "Noclip", Content = "ON", Duration = 2 })
    else
        if noclipConnection then
            noclipConnection:Disconnect()
            noclipConnection = nil
        end
        local c = LocalPlayer.Character
        if c then
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
        Fluent:Notify({ Title = "Noclip", Content = "OFF", Duration = 2 })
    end
    if mobileNoclipButton then
        mobileNoclipButton.Text = noclipEnabled and "Noclip: ON" or "Noclip: OFF"
        mobileNoclipButton.BackgroundColor3 = noclipEnabled
            and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(170, 0, 0)
    end
end

local function createMobileButton()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")
    local old = playerGui:FindFirstChild("RuqwiriNoclipButton")
    if old then old:Destroy() end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RuqwiriNoclipButton"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    local button = Instance.new("TextButton")
    button.Name = "NoclipMobileBtn"
    button.Size = UDim2.new(0, 120, 0, 50)
    button.Position = UDim2.new(0, 10, 0.5, -25)
    button.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Text = "Noclip: OFF"
    button.TextScaled = true
    button.Font = Enum.Font.GothamBold
    button.BorderSizePixel = 0
    button.Active = true
    button.Draggable = false
    button.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = button

    local dragging, dragStart, startPos, moved = false, nil, nil, false

    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; moved = false
            dragStart = input.Position; startPos = button.Position
        end
    end)
    button.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then moved = true end
            if moved then
                button.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if not moved then setNoclip(not noclipEnabled) end
        end
    end)
    mobileNoclipButton = button
end

createMobileButton()

NoclipSection:AddToggle("NoclipToggle", {
    Title = "Noclip",
    Description = "Walk through walls (disables collision)",
    Default = false,
    Callback = function(value) setNoclip(value) end
})

NoclipSection:AddButton({
    Title = "Show Noclip (OFF/ON)",
    Description = "Shows current Noclip state",
    Callback = function()
        Fluent:Notify({
            Title = "Noclip",
            Content = "Current: " .. (noclipEnabled and "ON" or "OFF"),
            Duration = 3
        })
    end
})

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if noclipEnabled then setNoclip(true) end
end)

local TeleportSection = Main:AddSection("Teleport")

local function getPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    return names
end

local TeleportDropdown = TeleportSection:AddDropdown("TeleportTarget", {
    Title = "Select Player",
    Description = "Select a player to teleport to",
    Values = getPlayerNames(),
    Default = 1, Multi = false,
    Callback = function(value) end
})

Players.PlayerAdded:Connect(function()
    task.wait(0.5); TeleportDropdown:SetValues(getPlayerNames())
end)
Players.PlayerRemoving:Connect(function()
    task.wait(0.5); TeleportDropdown:SetValues(getPlayerNames())
end)

TeleportSection:AddButton({
    Title = "Teleport to Player",
    Description = "Teleports you to the selected player",
    Callback = function()
        local targetName = Fluent.Options.TeleportTarget.Value
        if not targetName or targetName == "" then
            Fluent:Notify({ Title = "Teleport", Content = "No player selected", Duration = 3 }); return
        end
        local target = Players:FindFirstChild(targetName)
        if not target then
            Fluent:Notify({ Title = "Teleport", Content = "Player not found", Duration = 3 }); return
        end
        local targetHrp = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetHrp or not myHrp then
            Fluent:Notify({ Title = "Teleport", Content = "Character not found", Duration = 3 }); return
        end
        myHrp.CFrame = targetHrp.CFrame
        Fluent:Notify({ Title = "Teleport", Content = "Teleported to " .. targetName, Duration = 3 })
    end
})

local Visual = Window:AddTab({ Title = "Visual", Icon = "eye" })
local VisualSection = Visual:AddSection("ESP")
local espEnabled = false
local espObjects = {}

local function removeESP(player)
    local char = player.Character
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj.Name == "Ruqwiri_ESP_Highlight" or obj.Name == "Ruqwiri_ESP_Billboard" then
            obj:Destroy()
        end
    end
end

local function applyESP(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not head or not hrp then return end
    removeESP(player)

    local highlight = Instance.new("Highlight")
    highlight.Name = "Ruqwiri_ESP_Highlight"
    highlight.Adornee = char
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.6
    highlight.OutlineTransparency = 0
    highlight.Parent = char
    table.insert(espObjects, highlight)

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "Ruqwiri_ESP_Billboard"
    billboard.Adornee = head
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = head

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextScaled = true
    label.Text = player.Name .. " | --"
    label.Parent = billboard
    table.insert(espObjects, billboard)

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not espEnabled or not label.Parent then
            if conn then conn:Disconnect() end
            return
        end
        local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myHrp and hrp.Parent then
            local dist = (hrp.Position - myHrp.Position).Magnitude
            label.Text = player.Name .. " | " .. math.floor(dist) .. " studs"
        end
    end)
    table.insert(espObjects, {conn = conn})
end

local function refreshAllESP()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then applyESP(player) end
    end
end

local function clearAllESP()
    for _, obj in ipairs(espObjects) do
        if type(obj) == "table" and obj.conn then
            obj.conn:Disconnect()
        elseif obj and obj.Destroy then
            obj:Destroy()
        end
    end
    espObjects = {}
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        if espEnabled then applyESP(player) end
    end)
end)

VisualSection:AddToggle("ESPToggle", {
    Title = "Player ESP",
    Description = "Highlights players, shows name and distance",
    Default = false,
    Callback = function(value)
        espEnabled = value
        if value then refreshAllESP() else clearAllESP() end
    end
})

Fluent:Notify({ Title = "Ruqwiri", Content = "Menu loaded", Duration = 3 })
