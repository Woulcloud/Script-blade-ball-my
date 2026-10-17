repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StatsService = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Ruqwiri",
    SubTitle = "Auto Parry + Avatar Clone",
    TabWidth = 160,
    Size = UDim2.fromOffset(440, 320),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Combat = Window:AddTab({ Title = "Combat", Icon = "sword" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "eye" })
}

local cfg = { autoParry = false }

local hook = hookfunction or (getgenv and getgenv().hookfunction)
local HASH = "5455ef47-de02-4074-808c-8d82c2cd12ec"
local byte, char = string.byte, string.char
local floor, bxor = math.floor, bit32.bxor
local captured, votes, key = {}, {}, nil

local function timestamp() return tostring(floor(workspace:GetServerTimeNow() * 100)) end
local function learn(token, stamp)
    if #token ~= #stamp then return false end
    for i = 1, #token do
        local value = bxor(byte(token, i), (byte(stamp, i) + i) % 256)
        local counts = votes[i] or {}
        votes[i] = counts
        counts[value] = (counts[value] or 0) + 1
    end
    local nextKey = {}
    for i = 1, #token do
        local best, highest = 0, -1
        for value, count in pairs(votes[i]) do
            if count > highest then best, highest = value, count end
        end
        nextKey[i] = best
    end
    key = nextKey
    return true
end
local function makeToken()
    if not key then return end
    local stamp = timestamp()
    local token = {}
    for i = 1, #stamp do
        local value = key[i] or key[#key]
        if not value then return end
        token[i] = char(bxor((byte(stamp, i) + i) % 256, value))
    end
    return table.concat(token)
end
local fire
local function replay()
    local token = makeToken()
    if not captured.remote or not captured.sessionKey or not token then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local points = {}
    local alive = workspace:FindFirstChild("Alive")
    if alive then
        for _, character in ipairs(alive:GetChildren()) do
            local root = character:FindFirstChild("HumanoidRootPart")
            if root then points[character.Name] = camera:WorldToScreenPoint(root.Position) end
        end
    end
    local mouse = UserInputService:GetMouseLocation()
    fire(captured.remote, HASH, captured.sessionKey, token, 0.5, camera.CFrame, points, { mouse.X, mouse.Y }, false)
end
if hook then
    fire = hook(Instance.new("RemoteEvent").FireServer, function(self, ...)
        local args = table.pack(...)
        if args[1] ~= HASH or type(args[3]) ~= "string" then return fire(self, ...) end
        captured = { remote = self, sessionKey = args[2], token = args[3], timing = args[4], tailBool = args[8], args = args }
        learn(args[3], timestamp())
        return fire(self, ...)
    end)
end
local function SendParry()
    if not captured.remote or not captured.sessionKey then return false end
    local token = makeToken()
    if not token then return false end
    return pcall(replay)
end
local function GetPing()
    local ok, result = pcall(function() return StatsService.Network.ServerStatsItem["Data Ping"]:GetValue() end)
    return ok and result or 100
end
local function GetRealBall()
    for _, v in pairs(workspace.Balls:GetChildren()) do
        if v:GetAttribute("realBall") then return v end
    end
    return nil
end
local parried = {}
local function ProcessAutoParry(ball)
    if not cfg.autoParry then return end
    local bID = ball:GetDebugId()
    if ball:GetAttribute("target") ~= player.Name or parried[bID] then return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return end
    local velocity = zoomies.VectorVelocity
    local dist = (root.Position - ball.Position).Magnitude
    local ping = GetPing()
    local threshold = (velocity.Magnitude / 1.5) + (ping / 10)
    if dist <= threshold or dist <= 20 then
        parried[bID] = true
        SendParry()
        ball:GetAttributeChangedSignal("target"):Once(function() parried[bID] = nil end)
    end
end
RunService.Heartbeat:Connect(function()
    if not captured.remote then return end
    local ball = GetRealBall()
    if ball and cfg.autoParry then ProcessAutoParry(ball) end
end)

local VisualSec = Tabs.Visual:AddSection("Avatar Cloner")

VisualSec:AddInput("TargetName", {
    Title = "Player Name / UserId",
    Description = "Введите ник Roblox или ID",
    Placeholder = "Username or ID",
    Default = "",
    Finished = true
})

local overlayModel = nil
local copiedTracks = {}

local function RemoveOverlay()
    copiedTracks = {}
    if overlayModel then
        pcall(function() overlayModel:Destroy() end)
        overlayModel = nil
    end
    local char = player.Character
    if char then
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Transparency = 0
                v.LocalTransparencyModifier = 0
            elseif v:IsA("Decal") then
                v.Transparency = 0
            end
        end
    end
end

local function ApplyAvatar(userId)
    RemoveOverlay()
    
    local char = player.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    local myHum = char and char:FindFirstChildOfClass("Humanoid")
    local myAnimator = myHum and myHum:FindFirstChildOfClass("Animator")
    
    if not myRoot or not myHum or not myAnimator then return end

    local ok, desc = pcall(function()
        return Players:GetHumanoidDescriptionFromUserIdAsync(userId)
    end)
    if not ok or not desc then
        Fluent:Notify({ Title = "Avatar", Content = "Не удалось загрузить скин", Duration = 3 })
        return
    end

    local ok2, model = pcall(function()
        return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R6)
    end)

    if not ok2 or not model then
        Fluent:Notify({ Title = "Avatar", Content = "Ошибка создания R6", Duration = 3 })
        return
    end

    model.Name = "RuqwiriOverlay"
    model.Parent = workspace

    local modelHum = model:FindFirstChildOfClass("Humanoid")
    local modelRoot = model:FindFirstChild("HumanoidRootPart")
    
    if modelHum and modelRoot then
        modelHum.DisplayName = ""
        modelHum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        modelHum.PlatformStand = true
    end

    for _, v in ipairs(model:GetDescendants()) do
        if v:IsA("BasePart") then
            v.CanCollide = false
            v.Massless = true
        elseif v:IsA("BillboardGui") or v:IsA("Highlight") or v:IsA("SelectionBox") then
            v:Destroy()
        end
    end

    for _, v in ipairs(char:GetDescendants()) do
        if v:IsA("BasePart") then v.Transparency = 1 end
        if v:IsA("Decal") then v.Transparency = 1 end
    end

    if modelRoot then
        local att1 = Instance.new("Attachment", myRoot)
        local att2 = Instance.new("Attachment", modelRoot)
        
        local alignPos = Instance.new("AlignPosition", modelRoot)
        alignPos.Attachment0 = att2
        alignPos.Attachment1 = att1
        alignPos.MaxForce = 100000
        alignPos.Responsiveness = 50
        alignPos.RigidityEnabled = false
        
        local alignOri = Instance.new("AlignOrientation", modelRoot)
        alignOri.Attachment0 = att2
        alignOri.Attachment1 = att1
        alignOri.MaxTorque = 100000
        alignOri.Responsiveness = 50
        alignOri.RigidityEnabled = false
    end

    local modelAnimator = modelHum and modelHum:FindFirstChildOfClass("Animator")
    if modelAnimator then
        local function syncAnim(track)
            local newTrack = modelAnimator:LoadAnimation(track.Animation)
            newTrack.Priority = track.Priority
            newTrack:Play(0, track.Weight, track.Speed)
            table.insert(copiedTracks, newTrack)
        end

        myAnimator.AnimationPlayed:Connect(function(track)
            if overlayModel == model then syncAnim(track) end
        end)
        
        for _, track in ipairs(myAnimator:GetPlayingAnimationTracks()) do
            syncAnim(track)
        end
        
        myAnimator.AnimationPlayed:Connect(function(track)
            track.Stopped:Connect(function()
                for _, ct in ipairs(copiedTracks) do
                    if ct.Animation == track.Animation then
                        ct:Stop(0.1)
                    end
                end
            end)
        end)
    end

    overlayModel = model
    Fluent:Notify({ Title = "Avatar", Content = "Скин скопирован", Duration = 3 })
end

VisualSec:AddButton({
    Title = "Apply Skin",
    Description = "Надеть скин по нику/ID",
    Callback = function()
        local input = Fluent.Options.TargetName.Value
        if input == "" then return end
        local userId = tonumber(input)
        if not userId then
            local ok, id = pcall(function() return Players:GetUserIdFromNameAsync(input) end)
            if ok then userId = id end
        end
        if not userId then
            Fluent:Notify({ Title = "Avatar", Content = "Игрок не найден", Duration = 3 })
            return
        end
        ApplyAvatar(userId)
    end
})

VisualSec:AddButton({
    Title = "Remove Skin",
    Description = "Убрать скин",
    Callback = function()
        RemoveOverlay()
        Fluent:Notify({ Title = "Avatar", Content = "Скин убран", Duration = 2 })
    end
})
