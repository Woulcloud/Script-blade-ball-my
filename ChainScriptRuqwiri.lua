task.wait(2)

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HITBOX_SIZE = 500

local function addInvisibleHitbox(player)
    if player == LocalPlayer then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local old = hrp:FindFirstChild("Ruqwiri_InvisibleHitbox")
    if old then old:Destroy() end

    local hitbox = Instance.new("Part")
    hitbox.Name = "Ruqwiri_InvisibleHitbox"
    hitbox.Size = Vector3.new(HITBOX_SIZE, HITBOX_SIZE, HITBOX_SIZE)
    hitbox.Transparency = 1
    hitbox.CanCollide = false
    hitbox.CanTouch = true
    hitbox.Massless = true
    hitbox.Anchored = false
    hitbox.Parent = hrp

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hrp
    weld.Part1 = hitbox
    weld.Parent = hitbox
end

for _, p in ipairs(Players:GetPlayers()) do
    addInvisibleHitbox(p)
end

Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        addInvisibleHitbox(p)
    end)
end)

for _, p in ipairs(Players:GetPlayers()) do
    p.CharacterAdded:Connect(function()
        task.wait(0.5)
        addInvisibleHitbox(p)
    end)
end)
