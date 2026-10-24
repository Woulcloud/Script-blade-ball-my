repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

local cfg = {
    fullbright = false,
    autoQTE = false,
    qteReaction = 0.05
}

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

local lastPressed = {}

local function PressKey(keyCode)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.03)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

task.spawn(function()
    while task.wait(0.02) do
        if not cfg.autoQTE then continue end
        
        local playerGui = player:FindFirstChild("PlayerGui")
        if not playerGui then continue end
        
        for _, gui in ipairs(playerGui:GetDescendants()) do
            local isLetter = false
            local letter = nil
            
            if gui:IsA("TextLabel") or gui:IsA("TextButton") then
                local text = gui.Text
                if #text == 1 and text:match("%a") then
                    isLetter = true
                    letter = text:upper()
                end
            elseif gui:IsA("ImageLabel") or gui:IsA("ImageButton") then
                local name = gui.Name:upper()
                local match = name:match("([A-Z])$") or name:match("KEY([A-Z])")
                if match then
                    isLetter = true
                    letter = match
                end
            end
            
            if isLetter and letter and gui.Visible then
                local now = tick()
                if not lastPressed[gui] or now - lastPressed[gui] > 0.5 then
                    lastPressed[gui] = now
                    task.wait(cfg.qteReaction)
                    local keyCode = Enum.KeyCode[letter]
                    if keyCode then
                        PressKey(keyCode)
                    end
                end
            end
        end
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "InkGameMenu"
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
Title.Text = "  INK GAME"
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
Content.CanvasSize = UDim2.new(0, 0, 0, 150)
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

CreateBtn("Fullbright", function(v) cfg.fullbright = v ToggleFullbright(v) end)
CreateBtn("Auto QTE (Legit)", function(v) cfg.autoQTE = v end)

MainFrame.Size = UDim2.new(0, 220, 0, 150)
local isOpen = true
ToggleBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    Content.Visible = isOpen
    MainFrame.Size = isOpen and UDim2.new(0, 220, 0, 150) or UDim2.new(0, 220, 0, 35)
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
ToggleGui.Name = "InkGameToggle"
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
