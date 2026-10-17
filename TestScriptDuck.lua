local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local espEnabled = true
local espObjects = {}

local function clearESP()
    for _, obj in ipairs(espObjects) do
        if obj and obj.Destroy then obj:Destroy() end
    end
    espObjects = {}
end

local function scanDucks()
    clearESP()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local name = obj.Name:lower()
            if name:find("duck") then
                local part = obj:IsA("BasePart") and obj or obj:FindFirstChildWhichIsA("BasePart")
                if part and not part:FindFirstChild("Ruqwiri_DuckESP") then
                    local billboard = Instance.new("BillboardGui")
                    billboard.Name = "Ruqwiri_DuckESP"
                    billboard.Adornee = part
                    billboard.Size = UDim2.new(0, 120, 0, 40)
                    billboard.StudsOffset = Vector3.new(0, 3, 0)
                    billboard.AlwaysOnTop = true
                    billboard.Parent = part

                    local label = Instance.new("TextLabel")
                    label.Size = UDim2.new(1, 0, 1, 0)
                    label.BackgroundTransparency = 0.3
                    label.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
                    label.TextColor3 = Color3.fromRGB(0, 0, 0)
                    label.Font = Enum.Font.GothamBold
                    label.TextScaled = true
                    label.Text = "DUCK"
                    label.Parent = billboard
                    table.insert(espObjects, billboard)
                end
            end
        end
    end
end

task.spawn(function()
    while task.wait(2) do
        if espEnabled then
            scanDucks()
        end
    end
end)

print("Duck ESP loaded. Look for yellow 'DUCK' labels.")
