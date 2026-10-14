local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Balls = workspace:WaitForChild("Balls")

local CLICKS_NEEDED = 3

local clickCount = 0
local isActivated = false
local menuOpen = true
local autoParryEnabled = false
local triggerBotEnabled = false
local parryThreshold = 50

local lastParry = 0
local COOLDOWN = 0.08

local function ShowNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if isActivated then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 
    or input.UserInputType == Enum.UserInputType.Touch then
        
        clickCount = clickCount + 1
        
        if clickCount < CLICKS_NEEDED then
            ShowNotification("Активация", "Клик " .. clickCount .. "/" .. CLICKS_NEEDED, 1)
        else
            isActivated = true
            ShowNotification("Auto Parry", "АКТИВИРОВАН!", 2)
        end
    end
end)

ShowNotification("Blade Ball", "Сделай " .. CLICKS_NEEDED .. " клика для активации", 5)

local function GetRealBall()
    for _, ball in ipairs(Balls:GetChildren()) do
        if ball:GetAttribute("realBall") == true then
            return ball
        end
    end
    return nil
end

local function IsTargetingMe()
    return Player.Character and Player.Character:FindFirstChild("Highlight") ~= nil
end

local function Parry()
    pcall(function()
        Remotes:WaitForChild("ParryButtonPress"):Fire()
    end)
end

local function CalculateTimeToImpact(ball, hrp)
    local speed = 0
    if ball:FindFirstChild("zoomies") then
        speed = ball.zoomies.VectorVelocity.Magnitude
    else
        speed = ball.AssemblyLinearVelocity.Magnitude
    end
    
    if speed <= 0 then return 999 end
    
    local distance = (hrp.Position - ball.Position).Magnitude
    return distance / speed
end

RunService.PreSimulation:Connect(function()
    if not isActivated then return end
    if tick() - lastParry < COOLDOWN then return end
    
    local ball = GetRealBall()
    local char = Player.Character
    if not ball or not char then return end
    
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not IsTargetingMe() then return end
    
    if triggerBotEnabled then
        Parry()
        lastParry = tick()
        return
    end
    
    if autoParryEnabled then
        local timeToImpact = CalculateTimeToImpact(ball, hrp)
        local threshold = parryThreshold / 125
        
        if timeToImpact <= threshold then
            Parry()
            lastParry = tick()
        end
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BladeBallMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 220, 0, 280)
MainFrame.Position = UDim2.new(0, 20, 0, 100)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 8)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.BorderSizePixel = 0
Title.Text = "  BLADE BALL"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
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
ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "—"
ToggleBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
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
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.Position = UDim2.new(0, 0, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.Text = name .. ": OFF"
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamMedium
    btn.Parent = ContentFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    return btn
end

local AutoParryBtn = CreateButton("Auto Parry", 0)

local SliderFrame = Instance.new("Frame")
SliderFrame.Name = "SliderFrame"
SliderFrame.Size = UDim2.new(1, 0, 0, 60)
SliderFrame.Position = UDim2.new(0, 0, 0, 48)
SliderFrame.BackgroundTransparency = 1
SliderFrame.Parent = ContentFrame

local SliderLabel = Instance.new("TextLabel")
SliderLabel.Size = UDim2.new(1, 0, 0, 20)
SliderLabel.Position = UDim2.new(0, 0, 0, 0)
SliderLabel.BackgroundTransparency = 1
SliderLabel.Text = "Threshold: 50"
SliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SliderLabel.TextSize = 12
SliderLabel.Font = Enum.Font.Gotham
SliderLabel.Parent = SliderFrame

local SliderBg = Instance.new("Frame")
SliderBg.Name = "SliderBg"
SliderBg.Size = UDim2.new(1, 0, 0, 8)
SliderBg.Position = UDim2.new(0, 0, 0, 30)
SliderBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
SliderBg.BorderSizePixel = 0
SliderBg.Parent = SliderFrame

local SliderBgCorner = Instance.new("UICorner")
SliderBgCorner.CornerRadius = UDim.new(0, 4)
SliderBgCorner.Parent = SliderBg

local SliderFill = Instance.new("Frame")
SliderFill.Name = "SliderFill"
SliderFill.Size = UDim2.new(0.5, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = SliderBg

local SliderFillCorner = Instance.new("UICorner")
SliderFillCorner.CornerRadius = UDim.new(0, 4)
SliderFillCorner.Parent = SliderFill

local SliderBtn = Instance.new("TextButton")
SliderBtn.Name = "SliderBtn"
SliderBtn.Size = UDim2.new(0, 20, 0, 20)
SliderBtn.Position = UDim2.new(0.5, -10, 0, 24)
SliderBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SliderBtn.BorderSizePixel = 0
SliderBtn.Text = ""
SliderBtn.Parent = SliderFrame

local SliderBtnCorner = Instance.new("UICorner")
SliderBtnCorner.CornerRadius = UDim.new(0, 10)
SliderBtnCorner.Parent = SliderBtn

local TriggerBotBtn = CreateButton("Trigger Bot", 115)

local FloatingBtn = Instance.new("TextButton")
FloatingBtn.Name = "FloatingTriggerBot"
FloatingBtn.Size = UDim2.new(0, 130, 0, 45)
FloatingBtn.Position = UDim2.new(0, 20, 0, 400)
FloatingBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
FloatingBtn.BorderSizePixel = 0
FloatingBtn.Text = "TRIGGER: OFF"
FloatingBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
FloatingBtn.TextSize = 14
FloatingBtn.Font = Enum.Font.GothamBold
FloatingBtn.Active = true
FloatingBtn.Draggable = true
FloatingBtn.Parent = ScreenGui

local FloatingCorner = Instance.new("UICorner")
FloatingCorner.CornerRadius = UDim.new(0, 8)
FloatingCorner.Parent = FloatingBtn

local function UpdateTriggerUI()
    local state = triggerBotEnabled and "ON" or "OFF"
    TriggerBotBtn.Text = "Trigger Bot: " .. state
    TriggerBotBtn.BackgroundColor3 = triggerBotEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
    
    FloatingBtn.Text = "TRIGGER: " .. state
    FloatingBtn.BackgroundColor3 = triggerBotEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
end

ToggleBtn.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    if menuOpen then
        MainFrame:TweenSize(UDim2.new(0, 220, 0, 280), "Out", "Quad", 0.2, true)
        ToggleBtn.Text = "—"
    else
        MainFrame:TweenSize(UDim2.new(0, 220, 0, 35), "Out", "Quad", 0.2, true)
        ToggleBtn.Text = "□"
    end
end)

AutoParryBtn.MouseButton1Click:Connect(function()
    autoParryEnabled = not autoParryEnabled
    AutoParryBtn.Text = "Auto Parry: " .. (autoParryEnabled and "ON" or "OFF")
    AutoParryBtn.BackgroundColor3 = autoParryEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
end)

TriggerBotBtn.MouseButton1Click:Connect(function()
    triggerBotEnabled = not triggerBotEnabled
    UpdateTriggerUI()
end)

FloatingBtn.MouseButton1Click:Connect(function()
    triggerBotEnabled = not triggerBotEnabled
    UpdateTriggerUI()
end)

local dragging = false

SliderBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 
    or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement 
    and input.UserInputType ~= Enum.UserInputType.Touch then return end
    
    local mouseX = input.Position.X
    local sliderX = SliderBg.AbsolutePosition.X
    local sliderW = SliderBg.AbsoluteSize.X
    
    local percent = math.clamp((mouseX - sliderX) / sliderW, 0, 1)
    parryThreshold = math.floor(percent * 100) + 1
    
    SliderFill.Size = UDim2.new(percent, 0, 1, 0)
    SliderBtn.Position = UDim2.new(percent, -10, 0, 24)
    SliderLabel.Text = "Threshold: " .. parryThreshold
end)
