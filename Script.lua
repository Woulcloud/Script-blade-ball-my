local Luna = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nebula-Softworks/Luna-Interface-Suite/main/source.lua"))()

local Window = Luna:CreateWindow({
    Name = "Blade Ball",
    LoadingTitle = "Blade Ball",
    LoadingSubtitle = "by EAGLE",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "EagleHub",
        FileName = "FlickConfig"
    },
    Discord = {
        Enabled = true,
        Invite = "https://discord.gg/JtKycFr6B",
        RememberJoins = false
    },
    KeySystem = false
})

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Variables
local aimlockEnabled = false
local aimbotEnabled = false
local smoothAim = false
local aimPart = "Head"
local fovEnabled = false
local fovSize = 100
local fovCircle = nil
local smoothness = 0.4
local wallCheck = true
local targetPlayer = nil

local espEnabled = false
local ESPObjects = {}

local xrayEnabled = false
local originalTransparencies = {}

local infiniteJumpEnabled = false
local infiniteJumpConnection = nil

-- ============================================
-- AUTO CONFIG SAVE SYSTEM
-- ============================================
local ConfigFile = "EagleHub_FlickConfig.json"

local function SaveConfig()
    local config = {
        aimlockEnabled = aimlockEnabled,
        aimbotEnabled = aimbotEnabled,
        smoothAim = smoothAim,
        aimPart = aimPart,
        fovEnabled = fovEnabled,
        fovSize = fovSize,
        smoothness = smoothness,
        wallCheck = wallCheck,
        espEnabled = espEnabled,
        xrayEnabled = xrayEnabled,
        infiniteJumpEnabled = infiniteJumpEnabled
    }
    
    local success, encoded = pcall(function()
        return HttpService:JSONEncode(config)
    end)
    
    if success then
        if writefile then
            pcall(function()
                writefile(ConfigFile, encoded)
            end)
        end
    end
end

local function LoadConfig()
    if not isfile or not readfile then return end
    if not isfile(ConfigFile) then return end
    
    local success, data = pcall(function()
        return readfile(ConfigFile)
    end)
    
    if success and data then
        local decodeSuccess, config = pcall(function()
            return HttpService:JSONDecode(data)
        end)
        
        if decodeSuccess and config then
            aimlockEnabled = config.aimlockEnabled or false
            aimbotEnabled = config.aimbotEnabled or false
            smoothAim = config.smoothAim or false
            aimPart = config.aimPart or "Head"
            fovEnabled = config.fovEnabled or false
            fovSize = config.fovSize or 100
            smoothness = config.smoothness or 0.4
            wallCheck = config.wallCheck ~= nil and config.wallCheck or true
            espEnabled = config.espEnabled or false
            xrayEnabled = config.xrayEnabled or false
            infiniteJumpEnabled = config.infiniteJumpEnabled or false
        end
    end
end

LoadConfig()

local function createFOVCircle()
    if fovCircle then fovCircle:Remove() end
    fovCircle = Drawing.new("Circle")
    fovCircle.Thickness = 2
    fovCircle.NumSides = 50
    fovCircle.Radius = fovSize
    fovCircle.Filled = false
    fovCircle.Transparency = 1
    fovCircle.Color = Color3.fromRGB(255, 255, 255)
    fovCircle.Visible = false
    fovCircle.ZIndex = 2
end

local function updateFOVCircle()
    if fovCircle then
        local centerX = Camera.ViewportSize.X / 2
        local centerY = Camera.ViewportSize.Y / 2
        fovCircle.Position = Vector2.new(centerX, centerY)
        fovCircle.Radius = fovSize
        fovCircle.Visible = fovEnabled and (aimlockEnabled or aimbotEnabled)
    end
end

local function getClosestPlayerToCursor()
    local closestPlayer = nil
    local shortestDistance = fovEnabled and fovSize or math.huge
    local mousePos = UserInputService:GetMouseLocation()
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local targetPart = player.Character:FindFirstChild(aimPart)
                if targetPart then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    
                    if onScreen then
                        local distance = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        
                        if wallCheck then
                            local ray = Ray.new(Camera.CFrame.Position, (targetPart.Position - Camera.CFrame.Position).Unit * 1000)
                            local hit, position = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character})
                            
                            if hit and hit:IsDescendantOf(player.Character) then
                                if distance < shortestDistance then
                                    closestPlayer = player
                                    shortestDistance = distance
                                end
                            end
                        else
                            if distance < shortestDistance then
                                closestPlayer = player
                                shortestDistance = distance
                            end
                        end
                    end
                end
            end
        end
    end
    
    return closestPlayer
end

local function aimlock()
    if not aimlockEnabled then return end
    
    local target = getClosestPlayerToCursor()
    if target and target.Character then
        local targetPart = target.Character:FindFirstChild(aimPart)
        if targetPart then
            local aimPosition = targetPart.Position
            local cameraPosition = Camera.CFrame.Position
            local direction = (aimPosition - cameraPosition).Unit
            
            if smoothAim then
                local targetCFrame = CFrame.new(cameraPosition, cameraPosition + direction)
                Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothness)
            else
                Camera.CFrame = CFrame.new(cameraPosition, cameraPosition + direction)
            end
        end
    end
end

local function aimbot()
    if not aimbotEnabled then return end
    
    local target = getClosestPlayerToCursor()
    if target then
        targetPlayer = target
    else
        targetPlayer = nil
    end
end

local function createESP(Player)
    if ESPObjects[Player] or Player == LocalPlayer then return end
    
    local ESPHolder = {
        Box = Drawing.new("Square"),
        BoxOutline = Drawing.new("Square"),
        CornerTL = Drawing.new("Line"),
        CornerTR = Drawing.new("Line"),
        CornerBL = Drawing.new("Line"),
        CornerBR = Drawing.new("Line"),
        Tracer = Drawing.new("Line"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Health = Drawing.new("Text"),
        HealthBar = Drawing.new("Line"),
        HealthBarOutline = Drawing.new("Line")
    }
    
    ESPHolder.Box.Thickness = 2
    ESPHolder.Box.Filled = false
    ESPHolder.Box.Color = Color3.fromRGB(255, 0, 0)
    ESPHolder.Box.Visible = false
    ESPHolder.Box.ZIndex = 2
    ESPHolder.Box.Transparency = 1
    
    ESPHolder.BoxOutline.Thickness = 4
    ESPHolder.BoxOutline.Filled = false
    ESPHolder.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    ESPHolder.BoxOutline.Visible = false
    ESPHolder.BoxOutline.ZIndex = 1
    ESPHolder.BoxOutline.Transparency = 0.8
    
    for _, corner in pairs({ESPHolder.CornerTL, ESPHolder.CornerTR, ESPHolder.CornerBL, ESPHolder.CornerBR}) do
        corner.Thickness = 3
        corner.Color = Color3.fromRGB(255, 255, 255)
        corner.Visible = false
        corner.ZIndex = 3
        corner.Transparency = 1
    end
    
    ESPHolder.Tracer.Thickness = 2
    ESPHolder.Tracer.Color = Color3.fromRGB(255, 0, 0)
    ESPHolder.Tracer.Visible = false
    ESPHolder.Tracer.ZIndex = 1
    ESPHolder.Tracer.Transparency = 0.5
    
    ESPHolder.Name.Size = 16
    ESPHolder.Name.Center = true
    ESPHolder.Name.Outline = true
    ESPHolder.Name.Font = 3
    ESPHolder.Name.Color = Color3.fromRGB(255, 255, 255)
    ESPHolder.Name.Visible = false
    ESPHolder.Name.ZIndex = 3
    ESPHolder.Name.Transparency = 1
    
    ESPHolder.Distance.Size = 13
    ESPHolder.Distance.Center = true
    ESPHolder.Distance.Outline = true
    ESPHolder.Distance.Font = 2
    ESPHolder.Distance.Color = Color3.fromRGB(200, 200, 255)
    ESPHolder.Distance.Visible = false
    ESPHolder.Distance.ZIndex = 3
    ESPHolder.Distance.Transparency = 1
    
    ESPHolder.Health.Size = 13
    ESPHolder.Health.Center = true
    ESPHolder.Health.Outline = true
    ESPHolder.Health.Font = 2
    ESPHolder.Health.Color = Color3.fromRGB(0, 255, 0)
    ESPHolder.Health.Visible = false
    ESPHolder.Health.ZIndex = 3
    ESPHolder.Health.Transparency = 1
    
    ESPHolder.HealthBar.Thickness = 3
    ESPHolder.HealthBar.Color = Color3.fromRGB(0, 255, 0)
    ESPHolder.HealthBar.Visible = false
    ESPHolder.HealthBar.ZIndex = 3
    ESPHolder.HealthBar.Transparency = 1
    
    ESPHolder.HealthBarOutline.Thickness = 5
    ESPHolder.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
    ESPHolder.HealthBarOutline.Visible = false
    ESPHolder.HealthBarOutline.ZIndex = 2
    ESPHolder.HealthBarOutline.Transparency = 0.8
    
    ESPObjects[Player] = ESPHolder
end

local function removeESP(Player)
    if ESPObjects[Player] then
        for _, Drawing in pairs(ESPObjects[Player]) do
            Drawing:Remove()
        end
        ESPObjects[Player] = nil
    end
end

local function updateESP()
    for Player, ESP in pairs(ESPObjects) do
        pcall(function()
            if Player and Player.Character and Player ~= LocalPlayer then
                local Character = Player.Character
                local Humanoid = Character:FindFirstChildOfClass("Humanoid")
                local RootPart = Character:FindFirstChild("HumanoidRootPart")
                local Head = Character:FindFirstChild("Head")
                
                if Humanoid and RootPart and Head and Humanoid.Health > 0 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local Distance = (LocalPlayer.Character.HumanoidRootPart.Position - RootPart.Position).Magnitude
                    
                    if Distance > 5000 then
                        ESP.Box.Visible = false
                        ESP.BoxOutline.Visible = false
                        ESP.CornerTL.Visible = false
                        ESP.CornerTR.Visible = false
                        ESP.CornerBL.Visible = false
                        ESP.CornerBR.Visible = false
                        ESP.Tracer.Visible = false
                        ESP.Name.Visible = false
                        ESP.Distance.Visible = false
                        ESP.Health.Visible = false
                        ESP.HealthBar.Visible = false
                        ESP.HealthBarOutline.Visible = false
                        return
                    end
                    
                    local Vector, OnScreen = Camera:WorldToViewportPoint(RootPart.Position)
                    
                    if OnScreen and espEnabled then
                        local HeadPos = Camera:WorldToViewportPoint(Head.Position + Vector3.new(0, 0.5, 0))
                        local LegPos = Camera:WorldToViewportPoint(RootPart.Position - Vector3.new(0, 3, 0))
                        
                        local Height = math.abs(HeadPos.Y - LegPos.Y)
                        local Width = Height / 2
                        
                        local IsTarget = (targetPlayer == Player)
                        local BoxColor = IsTarget and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 50, 50)
                        
                        if IsTarget then
                            local pulse = math.abs(math.sin(tick() * 3)) * 0.3 + 0.7
                            BoxColor = Color3.fromRGB(0, 255 * pulse, 100)
                        end
                        
                        ESP.Box.Size = Vector2.new(Width, Height)
                        ESP.Box.Position = Vector2.new(Vector.X - Width / 2, Vector.Y - Height / 2)
                        ESP.Box.Color = BoxColor
                        ESP.Box.Visible = true
                        
                        ESP.BoxOutline.Size = Vector2.new(Width, Height)
                        ESP.BoxOutline.Position = Vector2.new(Vector.X - Width / 2, Vector.Y - Height / 2)
                        ESP.BoxOutline.Visible = true
                        
                        local cornerLength = math.min(Width, Height) / 4
                        
                        ESP.CornerTL.From = Vector2.new(Vector.X - Width / 2, Vector.Y - Height / 2)
                        ESP.CornerTL.To = Vector2.new(Vector.X - Width / 2 + cornerLength, Vector.Y - Height / 2)
                        ESP.CornerTL.Color = BoxColor
                        ESP.CornerTL.Visible = true
                        
                        ESP.CornerTR.From = Vector2.new(Vector.X + Width / 2, Vector.Y - Height / 2)
                        ESP.CornerTR.To = Vector2.new(Vector.X + Width / 2 - cornerLength, Vector.Y - Height / 2)
                        ESP.CornerTR.Color = BoxColor
                        ESP.CornerTR.Visible = true
                        
                        ESP.CornerBL.From = Vector2.new(Vector.X - Width / 2, Vector.Y + Height / 2)
                        ESP.CornerBL.To = Vector2.new(Vector.X - Width / 2 + cornerLength, Vector.Y + Height / 2)
                        ESP.CornerBL.Color = BoxColor
                        ESP.CornerBL.Visible = true
                        
                        ESP.CornerBR.From = Vector2.new(Vector.X + Width / 2, Vector.Y + Height / 2)
                        ESP.CornerBR.To = Vector2.new(Vector.X + Width / 2 - cornerLength, Vector.Y + Height / 2)
                        ESP.CornerBR.Color = BoxColor
                        ESP.CornerBR.Visible = true
                        
                        ESP.Tracer.Visible = false
                        
                        ESP.Name.Text = Player.Name .. (IsTarget and " ⚡ [LOCKED]" or "")
                        ESP.Name.Position = Vector2.new(Vector.X, HeadPos.Y - 25)
                        ESP.Name.Color = IsTarget and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(255, 255, 255)
                        ESP.Name.Visible = true
                        
                        local distColor = Distance < 100 and Color3.fromRGB(255, 100, 100) or 
                                         Distance < 300 and Color3.fromRGB(255, 255, 100) or 
                                         Color3.fromRGB(100, 200, 255)
                        ESP.Distance.Text = math.floor(Distance) .. "m"
                        ESP.Distance.Position = Vector2.new(Vector.X, LegPos.Y + 5)
                        ESP.Distance.Color = distColor
                        ESP.Distance.Visible = true
                        
                        local HealthPercent = math.floor((Humanoid.Health / Humanoid.MaxHealth) * 100)
                        ESP.Health.Text = HealthPercent .. "❤"
                        ESP.Health.Position = Vector2.new(Vector.X, LegPos.Y + 20)
                        
                        if HealthPercent > 75 then
                            ESP.Health.Color = Color3.fromRGB(0, 255, 100)
                        elseif HealthPercent > 50 then
                            ESP.Health.Color = Color3.fromRGB(255, 255, 0)
                        elseif HealthPercent > 25 then
                            ESP.Health.Color = Color3.fromRGB(255, 150, 0)
                        else
                            ESP.Health.Color = Color3.fromRGB(255, 0, 0)
                        end
                        ESP.Health.Visible = true
                        
                        local healthBarHeight = Height * (Humanoid.Health / Humanoid.MaxHealth)
                        local healthBarX = Vector.X - Width / 2 - 7
                        
                        ESP.HealthBarOutline.From = Vector2.new(healthBarX, Vector.Y - Height / 2)
                        ESP.HealthBarOutline.To = Vector2.new(healthBarX, Vector.Y + Height / 2)
                        ESP.HealthBarOutline.Visible = true
                        
                        ESP.HealthBar.From = Vector2.new(healthBarX, Vector.Y + Height / 2)
                        ESP.HealthBar.To = Vector2.new(healthBarX, Vector.Y + Height / 2 - healthBarHeight)
                        ESP.HealthBar.Color = ESP.Health.Color
                        ESP.HealthBar.Visible = true
                    else
                        ESP.Box.Visible = false
                        ESP.BoxOutline.Visible = false
                        ESP.CornerTL.Visible = false
                        ESP.CornerTR.Visible = false
                        ESP.CornerBL.Visible = false
                        ESP.CornerBR.Visible = false
                        ESP.Tracer.Visible = false
                        ESP.Name.Visible = false
                        ESP.Distance.Visible = false
                        ESP.Health.Visible = false
                        ESP.HealthBar.Visible = false
                        ESP.HealthBarOutline.Visible = false
                    end
                else
                    ESP.Box.Visible = false
                    ESP.BoxOutline.Visible = false
                    ESP.CornerTL.Visible = false
                    ESP.CornerTR.Visible = false
                    ESP.CornerBL.Visible = false
                    ESP.CornerBR.Visible = false
                    ESP.Tracer.Visible = false
                    ESP.Name.Visible = false
                    ESP.Distance.Visible = false
                    ESP.Health.Visible = false
                    ESP.HealthBar.Visible = false
                    ESP.HealthBarOutline.Visible = false
                end
            end
        end)
    end
end

local function toggleXRay(enabled)
    if enabled then
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj:IsDescendantOf(LocalPlayer.Character) then
                originalTransparencies[obj] = obj.Transparency
                obj.Transparency = 0.7
            end
        end
    else
        for obj, transparency in pairs(originalTransparencies) do
            if obj and obj.Parent then
                obj.Transparency = transparency
            end
        end
        originalTransparencies = {}
    end
end

local function toggleInfiniteJump(enabled)
    if enabled then
        infiniteJumpConnection = UserInputService.JumpRequest:Connect(function()
            if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    else
        if infiniteJumpConnection then
            infiniteJumpConnection:Disconnect()
            infiniteJumpConnection = nil
        end
    end
end

Window:CreateHomeTab({
    SupportedExecutors = {
        "Synapse X", "Krnl", "Fluxus", "Script-Ware", 
        "Electron", "Wave", "Delta",
    },
    DiscordInvite = "https://discord.gg/JtKycFr6B",
    Icon = 1
})

local CombatTab = Window:CreateTab({
    Name = "Combat",
    Icon = "gps_fixed",
    ImageSource = "Material",
    ShowTitle = true
})

local VisualsTab = Window:CreateTab({
    Name = "Visuals",
    Icon = "visibility",
    ImageSource = "Material",
    ShowTitle = true
})

local MiscTab = Window:CreateTab({
    Name = "Misc",
    Icon = "more_horiz",
    ImageSource = "Material",
    ShowTitle = true
})

local SettingsTab = Window:CreateTab({
    Name = "Settings",
    Icon = "settings",
    ImageSource = "Material",
    ShowTitle = true
})

local AimlockSection = CombatTab:CreateSection("Aimlock")

local AimlockToggle = CombatTab:CreateToggle({
    Name = "Blatant Aimlock",
    CurrentValue = aimlockEnabled,
    Flag = "AimlockToggle",
    Callback = function(Value)
        aimlockEnabled = Value
        SaveConfig()
        createFOVCircle()
    end,
})

local SmoothAimToggle = CombatTab:CreateToggle({
    Name = "Legit Aimbot",
    CurrentValue = smoothAim,
    Flag = "SmoothAimToggle",
    Callback = function(Value)
        smoothAim = Value
        SaveConfig()
    end,
})

local SmoothnessSlider = CombatTab:CreateSlider({
    Name = "Smoothness",
    Range = {0.1, 1},
    Increment = 0.05,
    CurrentValue = smoothness,
    Flag = "SmoothnessSlider",
    Callback = function(Value)
        smoothness = Value
        SaveConfig()
    end,
})

local WallCheckToggle = CombatTab:CreateToggle({
    Name = "Wall Check",
    CurrentValue = wallCheck,
    Flag = "WallCheckToggle",
    Callback = function(Value)
        wallCheck = Value
        SaveConfig()
    end,
})

local AimPartDropdown = CombatTab:CreateDropdown({
    Name = "Target Body Part",
    Options = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"},
    CurrentOption = {aimPart},
    MultipleOptions = false,
    Flag = "AimPartDropdown",
    Callback = function(Option)
        if type(Option) == "table" then
            aimPart = Option[1]
        else
            aimPart = Option
        end
        SaveConfig()
    end,
})

local FOVSection = CombatTab:CreateSection("FOV Circle")

local FOVToggle = CombatTab:CreateToggle({
    Name = "Enable FOV",
    CurrentValue = fovEnabled,
    Flag = "FOVToggle",
    Callback = function(Value)
        fovEnabled = Value
        SaveConfig()
        createFOVCircle()
    end,
})

local FOVSlider = CombatTab:CreateSlider({
    Name = "FOV Size",
    Range = {50, 500},
    Increment = 10,
    CurrentValue = fovSize,
    Flag = "FOVSlider",
    Callback = function(Value)
        fovSize = Value
        SaveConfig()
        if fovCircle then
            fovCircle.Radius = Value
        end
    end,
})

local FOVColorPicker = CombatTab:CreateColorPicker({
    Name = "FOV Color",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "FOVColor",
    Callback = function(Value)
        if fovCircle then
            fovCircle.Color = Value
        end
    end
})

local AimbotSection = CombatTab:CreateSection("Aimbot (Silent)")

local AimbotToggle = CombatTab:CreateToggle({
    Name = "Enable Aimbot",
    CurrentValue = aimbotEnabled,
    Flag = "AimbotToggle",
    Callback = function(Value)
        aimbotEnabled = Value
        SaveConfig()
    end,
})

local ESPSection = VisualsTab:CreateSection("ESP")

local ESPToggle = VisualsTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = espEnabled,
    Flag = "ESPToggle",
    Callback = function(Value)
        espEnabled = Value
        SaveConfig()
        
        if Value then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    createESP(player)
                end
            end
            
            RunService:BindToRenderStep("UpdateESP", Enum.RenderPriority.Camera.Value + 1, updateESP)
        else
            RunService:UnbindFromRenderStep("UpdateESP")
            
            for player, _ in pairs(ESPObjects) do
                removeESP(player)
            end
        end
    end,
})

local ESPColorPicker = VisualsTab:CreateColorPicker({
    Name = "ESP Color",
    Color = Color3.fromRGB(255, 0, 0),
    Flag = "ESPColor",
    Callback = function(Value)
        for _, ESP in pairs(ESPObjects) do
            ESP.Box.Color = Value
            ESP.Tracer.Color = Value
        end
    end
})

local XRaySection = VisualsTab:CreateSection("X-Ray")

local XRayToggle = VisualsTab:CreateToggle({
    Name = "Enable X-Ray",
    CurrentValue = xrayEnabled,
    Flag = "XRayToggle",
    Callback = function(Value)
        xrayEnabled = Value
        SaveConfig()
        toggleXRay(Value)
    end,
})

local XRaySlider = VisualsTab:CreateSlider({
    Name = "X-Ray Transparency",
    Range = {0, 1},
    Increment = 0.1,
    CurrentValue = 0.7,
    Flag = "XRayTransparency",
    Callback = function(Value)
        if xrayEnabled then
            for obj, _ in pairs(originalTransparencies) do
                if obj and obj.Parent then
                    obj.Transparency = Value
                end
            end
        end
    end,
})

local MovementSection = MiscTab:CreateSection("Movement")

local InfiniteJumpToggle = MiscTab:CreateToggle({
    Name = "Infinite Jump",
    CurrentValue = infiniteJumpEnabled,
    Flag = "InfiniteJump",
    Callback = function(Value)
        infiniteJumpEnabled = Value
        SaveConfig()
        toggleInfiniteJump(Value)
    end,
})

local InfoSection = SettingsTab:CreateSection("Info")

SettingsTab:CreateParagraph({
    Title = "Blade Ball",
    Content = "A clean and simple FPS script for Flick.\n\nFeatures:\n- Aimlock with FOV\n- Silent Aimbot\n- ESP (Boxes, Names, Health, Distance)\n- X-Ray Vision\n- Auto Config Save\n\nCreated by EAGLE"
})

local ConfigSection = SettingsTab:CreateSection("Config")

SettingsTab:CreateButton({
    Name = "Save Config",
    Callback = function()
        SaveConfig()
        Luna:Notification({
            Title = "Config Saved",
            Content = "Your settings have been saved successfully!",
            Icon = "save",
            ImageSource = "Material"
        })
    end,
})

SettingsTab:CreateButton({
    Name = "Reset Config",
    Callback = function()
        aimlockEnabled = false
        aimbotEnabled = false
        smoothAim = false
        aimPart = "Head"
        fovEnabled = false
        fovSize = 100
        smoothness = 0.4
        wallCheck = true
        espEnabled = false
        xrayEnabled = false
        infiniteJumpEnabled = false
        
        SaveConfig()
        
        Luna:Notification({
            Title = "Config Reset",
            Content = "Settings have been reset.",
            Icon = "restart_alt",
            ImageSource = "Material"
        })
    end,
})

local ControlsSection = SettingsTab:CreateSection("Controls")

SettingsTab:CreateKeybind({
    Name = "Toggle UI",
    CurrentKeybind = "RightShift",
    HoldToInteract = false,
    Flag = "UIKeybind",
    Callback = function(Keybind)
    end,
})

SettingsTab:CreateButton({
    Name = "Destroy GUI",
    Callback = function()
        SaveConfig()
        Luna:Destroy()
    end,
})

RunService.RenderStepped:Connect(function()
    updateFOVCircle()
    aimlock()
    aimbot()
end)

Players.PlayerAdded:Connect(function(player)
    if espEnabled and player ~= LocalPlayer then
        createESP(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
end)

task.spawn(function()
    while task.wait(30) do
        SaveConfig()
    end
end)

Luna:Notification({
    Title = "Blade Ball",
    Content = "Script loaded successfully! Auto-Save is active.",
    Icon = "check_circle",
    ImageSource = "Material"
})
