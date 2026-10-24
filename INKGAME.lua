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
    qteReaction = 0.05,
    glassVision = false,
    legitWalk = false,
    walkStepMin = 4,
    walkStepMax = 7,
    walkStepDelay = 0.5
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

local lastPressed = {}
local function PressKey(keyCode)
    pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(0.03)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)
end

local function CheckQTE(gui)
    if not cfg.autoQTE then return end
    local isLetter, letter = false, nil
    if gui:IsA("TextLabel") or gui:IsA("TextButton") then
        local text = gui.Text
        if #text == 1 and text:match("%a") then
            isLetter, letter = true, text:upper()
        end
    elseif gui:IsA("ImageLabel") or gui:IsA("ImageButton") then
        local name = gui.Name:upper()
        local match = name:match("([A-Z])$") or name:match("KEY([A-Z])")
        if match then isLetter, letter = true, match end
    end
    if isLetter and letter and gui.Visible then
        local now = tick()
        if not lastPressed[gui] or now - lastPressed[gui] > 0.5 then
            lastPressed[gui] = now
            task.wait(cfg.qteReaction)
            local keyCode = Enum.KeyCode[letter]
            if keyCode then PressKey(keyCode) end
        end
    end
end

local glassChecked = {}
local function ClearGlassVision()
    for obj, _ in pairs(glassChecked) do
        if obj and obj:FindFirstChildOfClass("Highlight") then
            obj:FindFirstChildOfClass("Highlight"):Destroy()
        end
    end
    glassChecked = {}
end

local function ApplyGlassVision()
    if not cfg.glassVision then return end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name:find("glass") or name:find("pane") or name:find("window") or name:find("bridge") then
                if not glassChecked[obj] then
                    glassChecked[obj] = true
                    local hl = Instance.new("Highlight")
                    hl.Parent = obj
                    hl.FillTransparency = 0.5
                    local c = obj.Color
                    if c.R > 0.6 and c.G < 0.4 and c.B < 0.4 then
                        hl.FillColor = Color3.fromRGB(255, 0, 0)
                        hl.OutlineColor = Color3.fromRGB(255, 0, 0)
                    else
                        hl.FillColor = Color3.fromRGB(0, 255, 0)
                        hl.OutlineColor = Color3.fromRGB(0, 255, 0)
                    end
                end
            end
        end
    end
end

local function GetDoll()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name:find("doll") or name:find("puppet") or name:find("redlight") or name:find("greenlight") or name:find("statue") or name:find("youngh") then
                return obj
            end
        end
    end
    return nil
end

local function IsDollRed(doll)
    if not doll then return false end
    local light = doll:FindFirstChildOfClass("PointLight") or doll:FindFirstChildOfClass("SpotLight") or doll:FindFirstChildOfClass("SurfaceLight")
    if light and light.Enabled and light.Color.R > 0.7 and light.Color.G < 0.3 then return true end
    for _, part in ipairs(doll:GetDescendants()) do
        if part:IsA("BasePart") and part.Color.R > 0.8 and part.Color.G < 0.2 then return true end
    end
    return false
end

task.spawn(function()
    while task.wait(0.5) do
        if cfg.fullbright then ApplyFullbright() end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if not cfg.legitWalk then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local doll = GetDoll()
        if not doll then continue end
        if not IsDollRed(doll) then
            local waitT = math.random(20, 40) / 10
            task.wait(waitT)
            if cfg.legitWalk and not IsDollRed(doll) then
                for i = 1, 3 do
                    if not cfg.legitWalk or IsDollRed(doll) then break end
                    local dir = hrp.CFrame.LookVector
                    local stepDist = math.random(cfg.walkStepMin, cfg.walkStepMax)
                    hrp.CFrame = CFrame.new(hrp.Position + (dir * stepDist))
                    task.wait(cfg.walkStepDelay)
                end
            end
        end
    end
end)

task.spawn(function()
    local pg = player:WaitForChild("PlayerGui")
    pg.DescendantAdded:Connect(CheckQTE)
    for _, v in ipairs(pg:GetDescendants()) do CheckQTE(v) end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "InkGameMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 200)
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
Content.CanvasSize = UDim2.new(0, 0, 0, 200)
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

CreateBtn("Fullbright", function(v) cfg.fullbright = v if v then ApplyFullbright() else RestoreLighting() end end)
CreateBtn("Auto QTE", function(v) cfg.autoQTE = v end)
CreateBtn("Glass Vision", function(v) cfg.glassVision = v if v then ApplyGlassVision() else ClearGlassVision() end end)
CreateBtn("Auto Walk (Legit)", function(v) cfg.legitWalk = v end)

ToggleBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
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
