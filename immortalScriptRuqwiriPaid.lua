local controlValueA = 3238
local controlValueB = 1420
local controlFlagA = true
local controlFlagB = true
do
    do
        do
            do
                do
                    local secondaryValue
                    do
                        if _G.oxyFluent then
                            return 
                        end
                        _G.oxyFluent = true
                        cloneref = cloneref or function(inputValue)
                            return inputValue
                        end
                        do
                            local cloneReference = cloneref
                            createInstance = Instance.new
                            createTweenInfo = TweenInfo.new
                            createUDim = UDim.new
                            createUDim2 = UDim2.new
                            fromOffset = UDim2.fromOffset
                            createVector2 = Vector2.new
                            createVector3 = Vector3.new
                            createCFrame = CFrame.new
                            colorFromRGB = Color3.fromRGB
                            formatString = string.format
                            clampValue = math.clamp
                            floorValue = math.floor
                            maxValue = math.max
                            minValue = math.min
                            arcSin = math.asin
                            toRadians = math.rad
                            randomValue = math.random
                            bitwiseXor = bit32.bxor
                            clearTable = table.clear
                            concatTable = table.concat
                            createTable = table.create
                            findInTable = table.find
                            insertIntoTable = table.insert
                            stringByte = string.byte
                            stringChar = string.char
                            spawnTask = task.spawn
                            delayTask = task.delay
                            deferTask = task.defer
                            waitTask = task.wait
                            globalEnvironment = getgenv()
                            ReplicatedStorage = cloneReference(game:GetService("ReplicatedStorage"))
                            UserInputService = cloneReference(game:GetService("UserInputService"))
                            Players = cloneReference(game:GetService("Players"))
                            Workspace = cloneReference(game:GetService("Workspace"))
                            local runService = cloneReference(game:GetService("RunService"))
                            repeat
                                waitTask()
                            until game:IsLoaded()
                            localPlayer = Players.LocalPlayer
                            name = localPlayer.Name
                            currentCamera = Workspace.CurrentCamera
                            balls = Workspace.Balls
                            alive = Workspace.Alive
                            dataPing = cloneReference(game:GetService("Stats")).Network.ServerStatsItem["Data Ping"]
                        end
                    end
                    local runtimeConnections, ballState, triggerbotState, spinState
                    do
                        local parryController, helperFunction
                        do
                            local eventCapture
                            do
                                runtimeConnections = {}
                                parryController = { count = 0, first_signal = nil }
                                helperFunction = function(inputValue, secondaryInput, tertiaryInput)
                                    return inputValue + (secondaryInput - inputValue) * tertiaryInput
                                end
                                eventCapture = { captured = {}, hooked = {}, originals = {}, token_fn = nil }
                                for _, primaryValue in getgc(true) do
                                    if type(primaryValue) ~= "function" or not debug.info(primaryValue, "s"):find("PRY", 1, true) then
                                        continue
                                    else
                                        for _, secondaryValue in debug.getupvalues(primaryValue) do
                                            if type(secondaryValue) == "function" then
                                                eventCapture.token_fn = secondaryValue
                                                break
                                            end
                                        end
                                        if not eventCapture.token_fn then
                                            continue
                                        end
                                    end
                                    break
                                end
                                eventCapture.tokenize = function(inputValue)
                                    local secondaryValue = tostring(floorValue(Workspace:GetServerTimeNow() * 100))
                                    local tertiaryValue = eventCapture.token_fn(inputValue, "TIME")
                                    local quaternaryValue = createTable(#secondaryValue)
                                    for i = 1, #secondaryValue do
                                        quaternaryValue[i] = stringChar(bitwiseXor((stringByte(secondaryValue, i) + i) % 256, stringByte(tertiaryValue, (i - 1) % #tertiaryValue + 1)))
                                    end
                                    return concatTable(quaternaryValue)
                                end
                                eventCapture.hook = function(inputValue)
                                    if next(eventCapture.captured) ~= nil then return end
                                    local primaryValue = getrawmetatable(inputValue)
                                    if eventCapture.hooked[primaryValue] then return end
                                    eventCapture.hooked[primaryValue] = true
                                    setreadonly(primaryValue, false)
                                    local index = primaryValue.__index
                                    eventCapture.originals[primaryValue] = index
                                    primaryValue.__index = function(secondaryInput, tertiaryInput)
                                        if tertiaryInput == "FireServer" and secondaryInput:IsA("RemoteEvent") or tertiaryInput == "InvokeServer" and secondaryInput:IsA("RemoteFunction") then
                                            return function(quaternaryInput, ...)
                                                local temporaryList = {...}
                                                if #temporaryList == 8 and type(temporaryList[2]) == "string" and type(temporaryList[3]) == "string" then
                                                    eventCapture.captured[secondaryInput] = temporaryList
                                                end
                                                return index(secondaryInput, tertiaryInput)(quaternaryInput, unpack(temporaryList))
                                            end
                                        end
                                        return index(secondaryInput, tertiaryInput)
                                    end
                                    setreadonly(primaryValue, true)
                                end
                                for _, primaryValue in ReplicatedStorage:GetDescendants() do
                                    if primaryValue:IsA("RemoteEvent") or primaryValue:IsA("RemoteFunction") then
                                        eventCapture.hook(primaryValue)
                                    end
                                end
                            end
                            ballState = { state = { Curving = tick() }, positions = {} }
                            ballState.get = function()
                                for _, primaryValue in balls:GetChildren() do
                                    if primaryValue:GetAttribute("realBall") then return primaryValue end
                                end
                            end
                            ballState.position = function(inputValue)
                                local primaryValue = inputValue or ballState.get()
                                if primaryValue then return primaryValue.Position end
                                return Vector3.zero
                            end
                            parryController.fire = function()
                                local primaryValue = currentCamera.CFrame
                                local temporaryList = { currentCamera.ViewportSize.X * 0.5, currentCamera.ViewportSize.Y * 0.5 }
                                local temporaryMap = {}
                                for _, secondaryValue in alive:GetChildren() do
                                    local primaryPart2 = secondaryValue.PrimaryPart
                                    if primaryPart2 then
                                        temporaryMap[secondaryValue.Name] = currentCamera:WorldToScreenPoint(primaryPart2.Position)
                                    end
                                end
                                if next(eventCapture.captured) ~= nil then
                                    for k, secondaryValue in eventCapture.captured, nil, nil do
                                        local parryArguments = {
                                            secondaryValue[1], secondaryValue[2], 
                                            eventCapture.tokenize(secondaryValue[2]), 
                                            0.5, primaryValue, temporaryMap, temporaryList, false
                                        }
                                        if k:IsA("RemoteEvent") then k:FireServer(unpack(parryArguments)) end
                                    end
                                end
                            end
                        end
                        triggerbotState = { on = false, busy = false, key = Enum.KeyCode.T }
                        spinState = { on = false, speed = 50, angle = 0 }
                        local spamController = { manual_on = false, manual_key = Enum.KeyCode.E }
                        
                        local parryState = { debounce = false, until_at = 0, accuracy = 1.5 }
                        parryState.check = function()
                            local character = localPlayer.Character and localPlayer.Character.PrimaryPart
                            if not character or parryState.debounce then return end
                            local primaryValue = tick()
                            local position = character.Position
                            local secondaryValue = clampValue(dataPing:GetValue() / 10 / 10, 5, 17)
                            local attribute = ballState.get()
                            attribute = attribute and attribute:GetAttribute("target")
                            for _, tertiaryValue in ballState.get_all() do
                                local quaternaryValue = tertiaryValue:FindFirstChild("zoomies")
                                if not quaternaryValue then continue end
                                local magnitude = quaternaryValue.VectorVelocity.Magnitude
                                local magnitude2 = (position - ballState.position(tertiaryValue)).Magnitude
                                local calculationA = (2.4 + minValue(maxValue(magnitude - 9.5, 0), 650) * 0.002) * parryState.accuracy
                                if tertiaryValue:GetAttribute("target") == name and magnitude2 <= secondaryValue + maxValue(magnitude / calculationA, 9.5) then
                                    parryController.fire()
                                    parryState.debounce = true
                                    parryState.until_at = primaryValue + 1
                                end
                            end
                        end
                        
                        local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
                        local oxy = Fluent:CreateWindow({ Title = "Ruqwiri Paid Script", TabWidth = 145, Size = UDim2.fromOffset(440, 315), Theme = "Dark" })
                        local combat = oxy:AddTab({ Title = "Combat", Icon = "swords" })
                        local main = oxy:AddTab({ Title = "Main", Icon = "shield" })
                        
                        local parrySection = combat:AddSection("Parry")
                        parrySection:AddToggle("AutoParry", { Title = "Auto Parry", Default = false, Callback = function(v)
                            if v then runtimeConnections.auto_parry = runService.PostSimulation:Connect(parryState.check)
                            elseif runtimeConnections.auto_parry then runtimeConnections.auto_parry:Disconnect() end
                        end })
                        parrySection:AddSlider("Accuracy", { Title = "Accuracy", Min = 1, Max = 100, Default = 100, Rounding = 1, Callback = function(accuracy) parryState.accuracy = (accuracy - 1) * 0.015151515151515152 end })
                        
                        local mainSection = main:AddSection("Protection")
                        mainSection:AddToggle("SpinImmortal", { Title = "Immortal", Default = false, Callback = function(v) spinState.on = v end })
                        mainSection:AddSlider("SpinSpeed", { Title = "Speed", Min = 10, Max = 200, Default = 50, Rounding = 1, Callback = function(v) spinState.speed = v end })
                        
                        runService.Heartbeat:Connect(function(dt)
                            if spinState.on then
                                local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
                                if root then
                                    spinState.angle = spinState.angle + (spinState.speed * dt)
                                    root.CFrame = root.CFrame + createVector3(math.cos(spinState.angle) * 15, math.sin(spinState.angle) * 15, 0)
                                end
                            end
                        end)
                    end
                end
            end
        end
    end
end
