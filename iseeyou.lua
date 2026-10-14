local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")

local Settings = {
    Aimlock = false,
    FOV = 50,
    ESP = false,
    TeamCheck = true,
    WallCheck = false,
    AimKey = Enum.KeyCode.E,
    Smoothness = 0.2,
}

local aiming = false
local espObjects = {}

local function GetClosestTarget()
    local closest = nil
    local shortestDist = Settings.FOV * 5

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not player.Character then continue end
        if not player.Character:FindFirstChild("HumanoidRootPart") then continue end
        if not player.Character:FindFirstChild("Humanoid") then continue end
        if player.Character.Humanoid.Health <= 0 then continue end
        if Settings.TeamCheck and player.Team == LocalPlayer.Team then continue end

        local hrp = player.Character.HumanoidRootPart
        local screenPoint, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        if not onScreen then continue end

        if Settings.WallCheck then
            local ray = Ray.new(Camera.CFrame.Position, (hrp.Position - Camera.CFrame.Position).Unit * 500)
            local hit = workspace:FindPartOnRay(ray, LocalPlayer.Character)
            if hit and not hit:IsDescendantOf(player.Character) then continue end
        end

        local mousePos = UserInputService:GetMouseLocation()
        local dist = (Vector2.new(screenPoint.X, screenPoint.Y) - mousePos).Magnitude

        if dist < shortestDist then
            shortestDist = dist
            closest = player
        end
    end

    return closest
end

local function CreateESP(player)
    if espObjects[player] then return end
    local char = player.Character
    if not char then return end
    if not char:FindFirstChild("HumanoidRootPart") then return end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "ISeeYou_ESP"
    box.Size = Vector3.new(2, 5, 2)
    box.Adornee = char.HumanoidRootPart
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Transparency = 0.7
    box.Color3 = Color3.fromRGB(255, 255, 255)
    box.Parent = char.HumanoidRootPart

    espObjects[player] = box
end

local function RemoveESP(player)
    if espObjects[player] then
        espObjects[player]:Destroy()
        espObjects[player] = nil
    end
end

RunService.RenderStepped:Connect(function()
    if Settings.Aimlock and aiming then
        local target = GetClosestTarget()
        if target then
            local hrp = target.Character.HumanoidRootPart
            local targetPos = hrp.Position
            local currentCFrame = Camera.CFrame
            local goalCFrame = CFrame.new(currentCFrame.Position, targetPos)
            Camera.CFrame = currentCFrame:Lerp(goalCFrame, Settings.Smoothness)
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not player.Character then continue end
        if not player.Character:FindFirstChild("HumanoidRootPart") then continue end
        if player.Character.Humanoid.Health <= 0 then
            RemoveESP(player)
            continue
        end

        if Settings.ESP then
            if Settings.TeamCheck and player.Team == LocalPlayer.Team then
                RemoveESP(player)
            else
                CreateESP(player)
            end
        else
            RemoveESP(player)
        end
    end
end)

Players.PlayerRemoving:Connect(function(player)
    RemoveESP(player)
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Settings.AimKey then
        aiming = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Settings.AimKey then
        aiming = false
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ISeeYouMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 230, 0, 260)
MainFrame.Position = UDim2.new(0, 20, 0, 100)
MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
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
Title.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
Title.BorderSizePixel = 0
Title.Text = "  I See You"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 35, 0, 25)
ToggleBtn.Position = UDim2.new(1, -45, 0, 5)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = "-"
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
ContentFrame.Position = UDim2.new(0, 10, 0, 45)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local menuOpen = true

local function CreateButton(name, yPos)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Btn"
    btn.Size = UDim2.new(1, 0, 0, 35)
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

local AimlockBtn = CreateButton("Aimlock", 0)
local EspBtn = CreateButton("ESP", 40)
local TeamCheckBtn = CreateButton("Teamcheck", 80)
local WallCheckBtn = CreateButton("Wallcheck", 120)

local FOVFrame = Instance.new("Frame")
FOVFrame.Name = "FOVFrame"
FOVFrame.Size = UDim2.new(1, 0, 0, 45)
FOVFrame.Position = UDim2.new(0, 0, 0, 165)
FOVFrame.BackgroundTransparency = 1
FOVFrame.Parent = ContentFrame

local FOVLabel = Instance.new("TextLabel")
FOVLabel.Size = UDim2.new(1, 0, 0, 20)
FOVLabel.BackgroundTransparency = 1
FOVLabel.Text = "Aimlock FOV: " .. Settings.FOV
FOVLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
FOVLabel.TextSize = 12
FOVLabel.Font = Enum.Font.Gotham
FOVLabel.Parent = FOVFrame

local FOVBg = Instance.new("Frame")
FOVBg.Name = "FOVBg"
FOVBg.Size = UDim2.new(1, 0, 0, 8)
FOVBg.Position = UDim2.new(0, 0, 0, 25)
FOVBg.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
FOVBg.BorderSizePixel = 0
FOVBg.Parent = FOVFrame

local FOVBgCorner = Instance.new("UICorner")
FOVBgCorner.CornerRadius = UDim.new(0, 4)
FOVBgCorner.Parent = FOVBg

local FOVFill = Instance.new("Frame")
FOVFill.Name = "FOVFill"
FOVFill.Size = UDim2.new((Settings.FOV - 10) / 90, 0, 1, 0)
FOVFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
FOVFill.BorderSizePixel = 0
FOVFill.Parent = FOVBg

local FOVFillCorner = Instance.new("UICorner")
FOVFillCorner.CornerRadius = UDim.new(0, 4)
FOVFillCorner.Parent = FOVFill

local FOVBtn = Instance.new("TextButton")
FOVBtn.Name = "FOVBtn"
FOVBtn.Size = UDim2.new(0, 20, 0, 20)
FOVBtn.Position = UDim2.new((Settings.FOV - 10) / 90, -10, 0, 19)
FOVBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
FOVBtn.BorderSizePixel = 0
FOVBtn.Text = ""
FOVBtn.Parent = FOVFrame

local FOVBtnCorner = Instance.new("UICorner")
FOVBtnCorner.CornerRadius = UDim.new(0, 10)
FOVBtnCorner.Parent = FOVBtn

ToggleBtn.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    if menuOpen then
        MainFrame:TweenSize(UDim2.new(0, 230, 0, 260), "Out", "Quad", 0.2, true)
        ToggleBtn.Text = "-"
    else
        MainFrame:TweenSize(UDim2.new(0, 230, 0, 35), "Out", "Quad", 0.2, true)
        ToggleBtn.Text = "[]"
    end
end)

AimlockBtn.MouseButton1Click:Connect(function()
    Settings.Aimlock = not Settings.Aimlock
    AimlockBtn.Text = "Aimlock: " .. (Settings.Aimlock and "ON" or "OFF")
    AimlockBtn.BackgroundColor3 = Settings.Aimlock and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
end)

EspBtn.MouseButton1Click:Connect(function()
    Settings.ESP = not Settings.ESP
    EspBtn.Text = "ESP: " .. (Settings.ESP and "ON" or "OFF")
    EspBtn.BackgroundColor3 = Settings.ESP and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
end)

TeamCheckBtn.MouseButton1Click:Connect(function()
    Settings.TeamCheck = not Settings.TeamCheck
    TeamCheckBtn.Text = "Teamcheck: " .. (Settings.TeamCheck and "ON" or "OFF")
    TeamCheckBtn.BackgroundColor3 = Settings.TeamCheck and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
end)

WallCheckBtn.MouseButton1Click:Connect(function()
    Settings.WallCheck = not Settings.WallCheck
    WallCheckBtn.Text = "Wallcheck: " .. (Settings.WallCheck and "ON" or "OFF")
    WallCheckBtn.BackgroundColor3 = Settings.WallCheck and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
end)

local dragging = false

FOVBtn.InputBegan:Connect(function(input)
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
    local sliderX = FOVBg.AbsolutePosition.X
    local sliderW = FOVBg.AbsoluteSize.X

    local percent = math.clamp((mouseX - sliderX) / sliderW, 0, 1)
    Settings.FOV = math.floor(percent * 90) + 10

    FOVFill.Size = UDim2.new(percent, 0, 1, 0)
    FOVBtn.Position = UDim2.new(percent, -10, 0, 19)
    FOVLabel.Text = "Aimlock FOV: " .. Settings.FOV
end)

pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "I See You",
        Text = "Menu loaded. Hold " .. Settings.AimKey.Name .. " to aim.",
        Duration = 5
    })
end)
