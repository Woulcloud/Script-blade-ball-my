repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local cfg = {
    aimbot = false, aimKey = Enum.KeyCode.E,
    esp = false, espBox = true, espSkeleton = true, espName = true,
    thirdPerson = false,
    spinbot = false,
    speed = false, bhop = false,
    hitbox = false,
    freecam = false
}

local originalSizes = {}
local function SaveOriginalSizes(char)
    local head = char:FindFirstChild("Head")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if head and hrp then
        originalSizes[char] = {
            headSize = head.Size, headTrans = head.Transparency, headCollide = head.CanCollide,
            hrpSize = hrp.Size, hrpTrans = hrp.Transparency, hrpCollide = hrp.CanCollide
        }
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    if p.Character then SaveOriginalSizes(p.Character) end
    p.CharacterAdded:Connect(SaveOriginalSizes)
end
Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(SaveOriginalSizes) end)

local fovGui = Instance.new("ScreenGui")
fovGui.Name = "AntiFollsFOV"
fovGui.ResetOnSpawn = false
fovGui.Parent = game:GetService("CoreGui")

local aimCircle = Instance.new("Frame")
aimCircle.AnchorPoint = Vector2.new(0.5, 0.5)
aimCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
aimCircle.BackgroundTransparency = 1
aimCircle.Size = UDim2.new(0, 300, 0, 300)
aimCircle.Parent = fovGui
Instance.new("UICorner", aimCircle).CornerRadius = UDim.new(1, 0)
local aimStroke = Instance.new("UIStroke", aimCircle)
aimStroke.Color = Color3.fromRGB(255, 255, 255)
aimStroke.Thickness = 1

local espDrawings = {}
local function CreateESP(p)
    if espDrawings[p] then return end
    local box = Drawing.new("Square")
    box.Thickness = 1
    box.Color = Color3.fromRGB(255, 255, 255)
    box.Filled = false
    
    local name = Drawing.new("Text")
    name.Size = 14
    name.Center = true
    name.Outline = true
    
    local bones = {}
    local boneConns = {
        {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"},
        {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"},
        {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"},
        {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"},
        {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"}
    }
    for i = 1, #boneConns do
        local line = Drawing.new("Line")
        line.Thickness = 1
        line.Color = Color3.fromRGB(255, 255, 255)
        table.insert(bones, {line = line, p1 = boneConns[i][1], p2 = boneConns[i][2]})
    end
    espDrawings[p] = {box = box, name = name, bones = bones}
end

local function RemoveESP(p)
    if espDrawings[p] then
        espDrawings[p].box:Remove()
        espDrawings[p].name:Remove()
        for _, bone in pairs(espDrawings[p].bones) do bone.line:Remove() end
        espDrawings[p] = nil
    end
end
Players.PlayerRemoving:Connect(RemoveESP)

local function GetTarget(fov)
    local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
    local best, bestDist = nil, fov
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local head = p.Character:FindFirstChild("Head")
            if hum and head and hum.Health > 0 then
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

local aimActive = false
local spinAngle = 0
local freecamPos = nil

RunService.RenderStepped:Connect(function(dt)
    aimCircle.Visible = cfg.aimbot

    if cfg.aimbot and aimActive then
        local target = GetTarget(150)
        if target then
            camera.CFrame = camera.CFrame:Lerp(CFrame.new(camera.CFrame.Position, target.Position), 0.3)
        end
    end

    if cfg.spinbot then
        spinAngle = spinAngle + math.rad(20)
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if root and hum then
            hum.AutoRotate = false
            root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(20), 0)
        end
    else
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
    end

    if cfg.esp then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                local root = p.Character:FindFirstChild("HumanoidRootPart")
                local head = p.Character:FindFirstChild("Head")
                if hum and root and head and hum.Health > 0 then
                    CreateESP(p)
                    local data = espDrawings[p]
                    local hScr, hOn = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    local rScr, rOn = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                    
                    if hOn and rOn then
                        local height = math.abs(hScr.Y - rScr.Y)
                        local width = height / 2
                        data.box.Visible = cfg.espBox
                        data.box.Size = Vector2.new(width, height)
                        data.box.Position = Vector2.new(hScr.X - width/2, hScr.Y)
                        
                        data.name.Visible = cfg.espName
                        data.name.Text = p.Name
                        data.name.Position = Vector2.new(hScr.X, hScr.Y - 20)

                        if cfg.espSkeleton then
                            for _, bone in pairs(data.bones) do
                                local p1 = p.Character:FindFirstChild(bone.p1)
                                local p2 = p.Character:FindFirstChild(bone.p2)
                                if p1 and p2 then
                                    local s1, on1 = camera:WorldToViewportPoint(p1.Position)
                                    local s2, on2 = camera:WorldToViewportPoint(p2.Position)
                                    if on1 and on2 then
                                        bone.line.From = Vector2.new(s1.X, s1.Y)
                                        bone.line.To = Vector2.new(s2.X, s2.Y)
                                        bone.line.Visible = true
                                    else bone.line.Visible = false end
                                else bone.line.Visible = false end
                            end
                        else
                            for _, bone in pairs(data.bones) do bone.line.Visible = false end
                        end
                    else
                        data.box.Visible = false
                        data.name.Visible = false
                        for _, bone in pairs(data.bones) do bone.line.Visible = false end
                    end
                else RemoveESP(p) end
            end
        end
    else
        for p, _ in pairs(espDrawings) do RemoveESP(p) end
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if cfg.thirdPerson and not cfg.freecam then
        player.CameraMode = Enum.CameraMode.Classic
        player.CameraMaxZoomDistance = 15
        player.CameraMinZoomDistance = 8
    elseif not cfg.freecam then
        player.CameraMaxZoomDistance = 0.5
        player.CameraMinZoomDistance = 0.5
    end

    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    
    hum.WalkSpeed = cfg.speed and 40 or 16
    if cfg.bhop and (hum:GetState() == Enum.HumanoidStateType.Landed or hum:GetState() == Enum.HumanoidStateType.Running) then
        hum.Jump = true
    end

    if cfg.freecam then
        if not freecamPos then
            freecamPos = camera.CFrame
            camera.CameraType = Enum.CameraType.Scriptable
        end
        local moveDir = Vector3.new()
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0, 1, 0) end
        freecamPos = freecamPos + moveDir * (20 * dt)
        camera.CFrame = freecamPos
    else
        if freecamPos then
            camera.CameraType = Enum.CameraType.Custom
            freecamPos = nil
        end
    end
end)

task.spawn(function()
    while task.wait(0.3) do
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                local head = p.Character:FindFirstChild("Head")
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if head and hrp then
                    if cfg.hitbox then
                        head.Size = Vector3.new(15, 15, 15)
                        head.Transparency = 0.5
                        head.CanCollide = false
                        hrp.Size = Vector3.new(15, 15, 15)
                        hrp.Transparency = 0.5
                        hrp.CanCollide = false
                    else
                        local orig = originalSizes[p.Character]
                        if orig then
                            head.Size = orig.headSize
                            head.Transparency = orig.headTrans
                            head.CanCollide = orig.headCollide
                            hrp.Size = orig.hrpSize
                            hrp.Transparency = orig.hrpTrans
                            hrp.CanCollide = orig.hrpCollide
                        end
                    end
                end
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == cfg.aimKey then aimActive = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == cfg.aimKey then aimActive = false end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AntiFollsMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 999999
ScreenGui.Parent = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 35)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -150)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Visible = true
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = Color3.fromRGB(80, 80, 80)

local dragging, dragInput, dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Title.Text = "  Anti-Folls"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 8)

local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(0, 30, 0, 25)
ToggleBtn.Position = UDim2.new(1, -35, 0, 5)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ToggleBtn.Text = "+"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.Parent = Title
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 4)

local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -10, 1, -45)
Content.Position = UDim2.new(0, 5, 0, 40)
Content.BackgroundTransparency = 1
Content.ScrollBarThickness = 3
Content.CanvasSize = UDim2.new(0, 0, 0, 400)
Content.Visible = false
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
    return btn
end

CreateBtn("Aimbot (E)", function(v) cfg.aimbot = v end)
CreateBtn("ESP Boxes", function(v) cfg.esp = v; cfg.espBox = v end)
CreateBtn("ESP Skeletons", function(v) cfg.espSkeleton = v end)
CreateBtn("Force Third Person", function(v) cfg.thirdPerson = v end)
CreateBtn("Spinbot", function(v) cfg.spinbot = v end)
CreateBtn("Hitbox Expander", function(v) cfg.hitbox = v end)
CreateBtn("Freecam", function(v) cfg.freecam = v end)
CreateBtn("Speed Hack", function(v) cfg.speed = v end)
CreateBtn("Auto Bhop", function(v) cfg.bhop = v end)

local isOpen = false
ToggleBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    Content.Visible = isOpen
    MainFrame.Size = isOpen and UDim2.new(0, 220, 0, 350) or UDim2.new(0, 220, 0, 35)
    ToggleBtn.Text = isOpen and "—" or "+"
end)

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        MainFrame.Visible = not MainFrame.Visible
    end
end)
