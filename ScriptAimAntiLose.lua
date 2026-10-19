repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Anti Lose",
    SubTitle = "Aimbot + Trigger + Spinbot",
    TabWidth = 160,
    Size = UDim2.fromOffset(460, 400),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

task.spawn(function()
    task.wait(1.5)
    local host = (gethui and gethui()) or game:GetService("CoreGui")
    for _, gui in ipairs(host:GetDescendants()) do
        pcall(function()
            if gui:IsA("Frame") or gui:IsA("ScrollingFrame") then
                local bg = gui.BackgroundColor3
                if bg.R > 0.2 or bg.G > 0.2 or bg.B > 0.2 then
                    gui.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
                end
            elseif gui:IsA("TextButton") then
                gui.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                gui.TextColor3 = Color3.fromRGB(255, 255, 255)
            elseif gui:IsA("TextLabel") or gui:IsA("TextBox") then
                gui.TextColor3 = Color3.fromRGB(255, 255, 255)
            elseif gui:IsA("UIStroke") then
                gui.Color = Color3.fromRGB(120, 120, 120)
            end
        end)
    end
end)

local fovGui = Instance.new("ScreenGui")
fovGui.Name = "AntiLoseFOV"
fovGui.ResetOnSpawn = false
fovGui.IgnoreGuiInset = true
fovGui.DisplayOrder = 999
fovGui.Parent = game:GetService("CoreGui")

local aimFovCircle = Instance.new("Frame")
aimFovCircle.Name = "AimFOV"
aimFovCircle.BackgroundTransparency = 1
aimFovCircle.Parent = fovGui
aimFovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
aimFovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
Instance.new("UICorner", aimFovCircle).CornerRadius = UDim.new(0.5, 0)
local aimStroke = Instance.new("UIStroke", aimFovCircle)
aimStroke.Color = Color3.fromRGB(255, 255, 255)
aimStroke.Thickness = 1.5

local trigFovCircle = Instance.new("Frame")
trigFovCircle.Name = "TrigFOV"
trigFovCircle.BackgroundTransparency = 1
trigFovCircle.Parent = fovGui
trigFovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
trigFovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
Instance.new("UICorner", trigFovCircle).CornerRadius = UDim.new(0.5, 0)
local trigStroke = Instance.new("UIStroke", trigFovCircle)
trigStroke.Color = Color3.fromRGB(255, 0, 0)
trigStroke.Thickness = 1.5

local menuKey = Enum.KeyCode.RightShift

local menuBtn = Instance.new("TextButton")
menuBtn.Name = "MenuToggle"
menuBtn.Size = UDim2.new(0, 44, 0, 44)
menuBtn.Position = UDim2.new(0, 15, 0.5, -22)
menuBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
menuBtn.BorderSizePixel = 0
menuBtn.Text = "≡"
menuBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
menuBtn.TextSize = 22
menuBtn.Font = Enum.Font.GothamBold
menuBtn.ZIndex = 9999
menuBtn.Active = true
menuBtn.Parent = fovGui
Instance.new("UICorner", menuBtn).CornerRadius = UDim.new(0, 10)
local mbStroke = Instance.new("UIStroke", menuBtn)
mbStroke.Color = Color3.fromRGB(120, 120, 120)

local dragging, dragStart, startPos, moved = false, nil, nil, false
menuBtn.MouseButton1Down:Connect(function()
    dragging = true
    moved = false
    dragStart = UserInputService:GetMouseLocation()
    startPos = menuBtn.Position
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = UserInputService:GetMouseLocation() - dragStart
        if delta.Magnitude > 5 then moved = true end
        if moved then
            menuBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

local function ToggleMenu()
    pcall(function() Fluent:Toggle() end)
end

menuBtn.MouseButton1Click:Connect(function()
    if not moved then ToggleMenu() end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == menuKey then ToggleMenu() end
end)

local Tabs = {
    Aimbot = Window:AddTab({ Title = "Aimbot", Icon = "crosshair" }),
    Trigger = Window:AddTab({ Title = "Trigger Bot", Icon = "target" }),
    Spinbot = Window:AddTab({ Title = "Spinbot", Icon = "rotate-cw" }),
    Exploits = Window:AddTab({ Title = "Exploits", Icon = "zap" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "eye" })
}

local cfg = {
    aimbot = false, aimKey = Enum.KeyCode.E, fov = 150, showAimFov = true,
    smoothness = 0.25, criticalAim = true, teamCheck = true, prediction = true, ping = 50,
    triggerBot = false, triggerKey = Enum.KeyCode.C, triggerDelay = 0.05, trigFov = 150, showTrigFov = true,
    spinbot = false, spinSpeed = 20, spinMode = "Camera", spinAim = true, spinFov = 300,
    speed = false, speedValue = 16, jumpPower = false, jumpValue = 50, bhop = false,
    detachCam = false, fullbright = false, savedCFrame = nil
}

local function GetTarget(fovOverride)
    local fov = fovOverride or cfg.fov
    local screenCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local head = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("HumanoidRootPart")
            if hum and head and hum.Health > 0 then
                if cfg.teamCheck and player.Team and p.Team == player.Team then continue end
                local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if dist <= fov and dist < bestDist then
                        bestDist = dist
                        best = head
                    end
                end
            end
        end
    end
    return best
end

local aimActive = false

RunService.RenderStepped:Connect(function()
    aimFovCircle.Visible = cfg.showAimFov
    if cfg.showAimFov then
        aimFovCircle.Size = UDim2.new(0, cfg.fov * 2, 0, cfg.fov * 2)
    end
    if not cfg.aimbot or not aimActive then return end
    local target = GetTarget()
    if not target then return end
    local targetPos = target.Position
    if cfg.prediction and target.Parent then
        local hum = target.Parent:FindFirstChildOfClass("Humanoid")
        if hum and hum.RootPart then
            targetPos = targetPos + (hum.RootPart.AssemblyLinearVelocity * (cfg.ping / 1000))
        end
    end
    local lookCF = CFrame.new(camera.CFrame.Position, targetPos)
    camera.CFrame = camera.CFrame:Lerp(lookCF, cfg.smoothness)
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == cfg.aimKey then aimActive = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == cfg.aimKey then aimActive = false end
end)

local triggerActive = false
local lastShot = 0
local function Click()
    local vim = game:GetService("VirtualInputManager")
    vim:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(0.01)
    vim:SendMouseButtonEvent(0, 0, 0, false, game, 1)
end

RunService.RenderStepped:Connect(function()
    trigFovCircle.Visible = cfg.showTrigFov
    if cfg.showTrigFov then
        trigFovCircle.Size = UDim2.new(0, cfg.trigFov * 2, 0, cfg.trigFov * 2)
    end
    if not cfg.triggerBot or not triggerActive then return end
    local target = GetTarget(cfg.trigFov)
    if not target then return end
    local now = tick()
    local pingDelay = math.clamp(cfg.ping, 10, 400) / 1000
    if now - lastShot >= (cfg.triggerDelay + pingDelay) then
        lastShot = now
        Click()
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == cfg.triggerKey then triggerActive = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == cfg.triggerKey then triggerActive = false end
end)

local spinAngle = 0
RunService.RenderStepped:Connect(function(dt)
    if not cfg.spinbot then return end
    spinAngle = spinAngle + (cfg.spinSpeed * dt)
    local orbitOffset = Vector3.new(math.cos(spinAngle) * 10, math.sin(spinAngle) * 10, 0)
    if cfg.spinAim then
        local target = GetTarget(cfg.spinFov)
        if target then
            camera.CFrame = CFrame.new(camera.CFrame.Position + orbitOffset, target.Position)
            return
        end
    end
    if cfg.spinMode == "Camera" then
        local rotated = (CFrame.Angles(0, math.rad(cfg.spinSpeed * dt * 60), 0) * CFrame.new(camera.CFrame.LookVector * 0)).LookVector
        camera.CFrame = CFrame.new(camera.CFrame.Position, camera.CFrame.Position + rotated)
    elseif cfg.spinMode == "Character" then
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(cfg.spinSpeed * dt * 60), 0) end
    end
end)

RunService.Heartbeat:Connect(function()
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.WalkSpeed = cfg.speed and cfg.speedValue or 16
    if cfg.jumpPower then hum.JumpPower = cfg.jumpValue hum.UseJumpPower = true end
    if cfg.bhop and (hum:GetState() == Enum.HumanoidStateType.Landed or hum:GetState() == Enum.HumanoidStateType.Running) then
        hum.Jump = true
    end
end)

RunService.RenderStepped:Connect(function()
    if cfg.detachCam then
        if not cfg.savedCFrame then
            cfg.savedCFrame = camera.CFrame
            camera.CameraType = Enum.CameraType.Scriptable
        end
    else
        if cfg.savedCFrame then
            camera.CameraType = Enum.CameraType.Custom
            cfg.savedCFrame = nil
        end
    end
end)

local function SetFullbright(v)
    if v then
        Lighting.Brightness = 5
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        Lighting.Ambient = Color3.fromRGB(180, 180, 180)
    else
        Lighting.Brightness = 2
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 1000
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
    end
end

local AimSec = Tabs.Aimbot:AddSection("Aimbot Settings")
AimSec:AddToggle("Aimbot", { Title = "Aimbot (hold key)", Default = false, Callback = function(v) cfg.aimbot = v end })
AimSec:AddKeybind("AimKey", { Title = "Aim Key", Default = "E", Mode = "Hold", ChangedCallback = function(k) cfg.aimKey = k end })
AimSec:AddSlider("FOV", { Title = "Aimbot FOV", Min = 20, Max = 400, Default = 150, Rounding = 0, Callback = function(v) cfg.fov = v end })
AimSec:AddToggle("ShowAimFov", { Title = "Show Aimbot FOV", Default = true, Callback = function(v) cfg.showAimFov = v end })
AimSec:AddSlider("Smooth", { Title = "Smoothness", Min = 0.05, Max = 1, Default = 0.25, Rounding = 2, Callback = function(v) cfg.smoothness = v end })
AimSec:AddToggle("Critical", { Title = "Critical Aim (Headshot)", Default = true, Callback = function(v) cfg.criticalAim = v end })
AimSec:AddToggle("Prediction", { Title = "Velocity Prediction", Default = true, Callback = function(v) cfg.prediction = v end })
AimSec:AddToggle("TeamCheck", { Title = "Ignore Teammates", Default = true, Callback = function(v) cfg.teamCheck = v end })
AimSec:AddSlider("PingComp", { Title = "Ping Compensation (ms)", Min = 10, Max = 400, Default = 50, Rounding = 0, Callback = function(v) cfg.ping = v end })

local TrigSec = Tabs.Trigger:AddSection("Trigger Bot")
TrigSec:AddToggle("TriggerBot", { Title = "Trigger Bot (hold key)", Default = false, Callback = function(v) cfg.triggerBot = v end })
TrigSec:AddKeybind("TrigKey", { Title = "Trigger Key", Default = "C", Mode = "Hold", ChangedCallback = function(k) cfg.triggerKey = k end })
TrigSec:AddSlider("TrigFovSlider", { Title = "Trigger FOV", Min = 20, Max = 400, Default = 150, Rounding = 0, Callback = function(v) cfg.trigFov = v end })
TrigSec:AddToggle("ShowTrigFov", { Title = "Show Trigger FOV", Default = true, Callback = function(v) cfg.showTrigFov = v end })
TrigSec:AddSlider("TrigDelay", { Title = "Extra Delay (sec)", Min = 0, Max = 0.5, Default = 0.05, Rounding = 2, Callback = function(v) cfg.triggerDelay = v end })

local SpinSec = Tabs.Spinbot:AddSection("Spinbot")
SpinSec:AddToggle("Spinbot", { Title = "Enable Spinbot", Default = false, Callback = function(v) cfg.spinbot = v end })
SpinSec:AddSlider("SpinSpeed", { Title = "Spin Speed", Min = 5, Max = 100, Default = 20, Rounding = 0, Callback = function(v) cfg.spinSpeed = v end })
SpinSec:AddDropdown("SpinMode", { Title = "Rotate", Values = { "Camera", "Character" }, Default = "Camera", Callback = function(v) cfg.spinMode = v end })
SpinSec:AddToggle("SpinAim", { Title = "Aim while spinning", Default = true, Callback = function(v) cfg.spinAim = v end })
SpinSec:AddSlider("SpinFov", { Title = "Spin FOV", Min = 50, Max = 800, Default = 300, Rounding = 0, Callback = function(v) cfg.spinFov = v end })

local ExplSec = Tabs.Exploits:AddSection("Movement")
ExplSec:AddToggle("Speed", { Title = "Speed Hack", Default = false, Callback = function(v) cfg.speed = v end })
ExplSec:AddSlider("SpeedVal", { Title = "Speed", Min = 16, Max = 200, Default = 40, Rounding = 0, Callback = function(v) cfg.speedValue = v end })
ExplSec:AddToggle("JumpPower", { Title = "JumpPower Hack", Default = false, Callback = function(v) cfg.jumpPower = v end })
ExplSec:AddSlider("JumpVal", { Title = "JumpPower", Min = 50, Max = 500, Default = 100, Rounding = 0, Callback = function(v) cfg.jumpValue = v end })
ExplSec:AddToggle("Bhop", { Title = "Auto Bunnyhop", Default = false, Callback = function(v) cfg.bhop = v end })

local VisSec = Tabs.Visual:AddSection("Camera / World")
VisSec:AddToggle("DetachCam", { Title = "Detach Camera (Free Look)", Default = false, Callback = function(v) cfg.detachCam = v end })
VisSec:AddToggle("Fullbright", { Title = "Fullbright", Default = false, Callback = function(v) SetFullbright(v) end })

local MenuSec = Tabs.Visual:AddSection("Menu Toggle")
MenuSec:AddKeybind("MenuKey", {
    Title = "Toggle Menu Key",
    Default = "RightShift",
    Mode = "Toggle",
    ChangedCallback = function(k) menuKey = k end
})
MenuSec:AddButton({
    Title = "Toggle Menu Now",
    Callback = function() ToggleMenu() end
})

Fluent:Notify({ Title = "Anti Lose", Content = "Loaded. RightShift or ≡ to toggle menu.", Duration = 4 })
