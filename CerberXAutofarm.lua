-- Cerber X Autofarm Version
-- GUI reworked from Cerber X style.
-- Functions: Hit Aura + Auto farm
-- Hide GUI Keybind: C | Cerber X

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CERBER_ICON_IMAGE = "rbxassetid://98605939008332"
local PREFS_FILE = "nyhito_cerberx_autofarm_prefs.json"
local HIDE_KEY = Enum.KeyCode.C

local MAIN_SIZE = UDim2.new(0, 315, 0, 220)
local MINI_SIZE = UDim2.new(0, 134, 0, 38)

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Workspace = workspace

local GLOBAL_TOKEN_NAME = "__nyhito_cerberx_autofarm_active_token"
local ACTIVE_TOKEN = tostring(os.clock()) .. "_" .. tostring(math.random(100000, 999999))

pcall(function()
	if getgenv then
		getgenv()[GLOBAL_TOKEN_NAME] = ACTIVE_TOKEN
	else
		_G[GLOBAL_TOKEN_NAME] = ACTIVE_TOKEN
	end
end)

local function isThisScriptActive()
	local ok, value = pcall(function()
		if getgenv then
			return getgenv()[GLOBAL_TOKEN_NAME]
		end
		return _G[GLOBAL_TOKEN_NAME]
	end)
	return (not ok) or value == ACTIVE_TOKEN
end

local ScreenGui
local MainFrame
local MiniButton
local Notice
local NoticeStroke
local NoticeBar
local NoticeGlow
local HitAuraRow
local AutoFarmRow
local HitAuraSwitch
local HitAuraKnob
local AutoFarmSwitch
local AutoFarmKnob

local guiVisible = true
local guiMinimized = false
local hitAuraEnabled = false
local autoFarmEnabled = false

local autofarmToken = 0
local hitAuraToken = 0
local character = LocalPlayer.Character

local shadowRegistry = {}
local dragConnections = {}

LocalPlayer.CharacterAdded:Connect(function(char)
	character = char
end)

local function getChar(player)
	player = player or LocalPlayer
	if player == LocalPlayer then
		character = LocalPlayer.Character or character
		return character
	end
	return player.Character
end

local function getHRP(player)
	local char = getChar(player)
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid(player)
	local char = getChar(player)
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function noTextStroke(obj)
	obj.TextStrokeTransparency = 1
end

local function setTargetTransparency(obj, bg, text)
	if bg ~= nil then
		obj:SetAttribute("TargetBGTransparency", bg)
	end
	if text ~= nil then
		obj:SetAttribute("TargetTextTransparency", text)
	end
end

local function getTargetBG(obj)
	local v = obj:GetAttribute("TargetBGTransparency")
	if typeof(v) == "number" then
		return v
	end
	return obj.BackgroundTransparency
end

local function getTargetText(obj)
	local v = obj:GetAttribute("TargetTextTransparency")
	if typeof(v) == "number" then
		return v
	end
	return obj.TextTransparency
end

local function registerShadow(host, shadow)
	shadowRegistry[host] = shadowRegistry[host] or {}
	table.insert(shadowRegistry[host], shadow)
end

local function setHostShadowVisible(host, visible)
	local list = shadowRegistry[host]
	if not list then return end
	for _, shadow in ipairs(list) do
		shadow.Visible = visible
		shadow.BackgroundTransparency = visible and shadow:GetAttribute("BaseTransparency") or 1
	end
end

local function addTrueRoundedShadow(parent, cornerRadius, strength, shadowColor)
	strength = strength or 1
	shadowColor = shadowColor or Color3.fromRGB(0, 0, 0)

	local layers = {
		{grow = math.floor(8 * strength), transparency = 0.82, y = 2},
		{grow = math.floor(16 * strength), transparency = 0.90, y = 4},
		{grow = math.floor(24 * strength), transparency = 0.95, y = 6},
	}

	for _, cfg in ipairs(layers) do
		local shadow = Instance.new("Frame")
		shadow.Name = "TrueShadow"
		shadow.AnchorPoint = Vector2.new(0.5, 0.5)
		shadow.Position = UDim2.new(0.5, 0, 0.5, cfg.y)
		shadow.Size = UDim2.new(1, cfg.grow, 1, cfg.grow)
		shadow.BackgroundColor3 = shadowColor
		shadow.BackgroundTransparency = cfg.transparency
		shadow.BorderSizePixel = 0
		shadow.ZIndex = math.max(parent.ZIndex - 1, 0)
		shadow.Parent = parent
		shadow:SetAttribute("BaseTransparency", cfg.transparency)

		Instance.new("UICorner", shadow).CornerRadius =
			UDim.new(0, cornerRadius + math.floor(cfg.grow / 2.1))

		registerShadow(parent, shadow)
	end
end

local function savePrefs()
	if not writefile then return end

	local payload = {
		hitAuraEnabled = hitAuraEnabled,
		autoFarmEnabled = autoFarmEnabled,
		guiVisible = guiVisible,
		guiMinimized = guiMinimized,
		mainX = MainFrame and MainFrame.Position.X.Offset or nil,
		mainY = MainFrame and MainFrame.Position.Y.Offset or nil,
		miniX = MiniButton and MiniButton.Position.X.Offset or nil,
		miniY = MiniButton and MiniButton.Position.Y.Offset or nil
	}

	pcall(function()
		writefile(PREFS_FILE, HttpService:JSONEncode(payload))
	end)
end

local function loadPrefs()
	if not readfile or not isfile or not isfile(PREFS_FILE) then return end

	pcall(function()
		local decoded = HttpService:JSONDecode(readfile(PREFS_FILE))

		if type(decoded.hitAuraEnabled) == "boolean" then
			hitAuraEnabled = decoded.hitAuraEnabled
		end
		if type(decoded.autoFarmEnabled) == "boolean" then
			autoFarmEnabled = decoded.autoFarmEnabled
		end
		if type(decoded.guiVisible) == "boolean" then
			guiVisible = decoded.guiVisible
		end
		if type(decoded.guiMinimized) == "boolean" then
			guiMinimized = decoded.guiMinimized
		end
	end)
end

local function getSavedPosition(which, fallback)
	if not readfile or not isfile or not isfile(PREFS_FILE) then
		return fallback
	end

	local result = fallback
	pcall(function()
		local decoded = HttpService:JSONDecode(readfile(PREFS_FILE))
		if which == "main" and type(decoded.mainX) == "number" and type(decoded.mainY) == "number" then
			result = UDim2.new(0, decoded.mainX, 0, decoded.mainY)
		elseif which == "mini" and type(decoded.miniX) == "number" and type(decoded.miniY) == "number" then
			result = UDim2.new(0, decoded.miniX, 0, decoded.miniY)
		end
	end)
	return result
end

local function elegantShow(root, finalSize, finalPosition, finalBgTransparency)
	if not root then return end

	root.Visible = true
	local targetSize = finalSize or root.Size
	local targetPos = finalPosition or root.Position
	local targetBg = finalBgTransparency
	if targetBg == nil then
		targetBg = getTargetBG(root)
	end

	root.Size = UDim2.new(
		targetSize.X.Scale * 0.72, math.floor(targetSize.X.Offset * 0.72),
		targetSize.Y.Scale * 0.72, math.floor(targetSize.Y.Offset * 0.72)
	)
	root.Position = targetPos
	root.BackgroundTransparency = 1
	setHostShadowVisible(root, false)

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("ImageLabel") then
			pcall(function()
				if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("ImageLabel") then
					obj.BackgroundTransparency = 1
				end
				if obj:IsA("TextButton") or obj:IsA("TextLabel") then
					obj.TextTransparency = 1
				elseif obj:IsA("ImageLabel") then
					obj.ImageTransparency = 1
				end
			end)
		elseif obj:IsA("UIStroke") then
			obj.Transparency = 1
		end
	end

	TweenService:Create(root, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = targetSize,
		Position = targetPos,
		BackgroundTransparency = targetBg
	}):Play()

	task.delay(0.03, function()
		setHostShadowVisible(root, true)

		for _, obj in ipairs(root:GetDescendants()) do
			if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("ImageLabel") then
				local goal = {}

				if obj:IsA("Frame") or obj:IsA("TextButton") then
					goal.BackgroundTransparency = getTargetBG(obj)
				elseif obj:IsA("ImageLabel") then
					goal.BackgroundTransparency = getTargetBG(obj)
					goal.ImageTransparency = 0
				end

				if obj:IsA("TextButton") or obj:IsA("TextLabel") then
					goal.TextTransparency = getTargetText(obj)
				end

				TweenService:Create(obj, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
			elseif obj:IsA("UIStroke") then
				TweenService:Create(obj, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Transparency = 0
				}):Play()
			end
		end
	end)
end

local function elegantHide(root, onDone)
	if not root then
		if onDone then onDone() end
		return
	end

	local currentSize = root.Size
	local currentPos = root.Position
	local shrinkSize = UDim2.new(
		currentSize.X.Scale * 0.965, math.floor(currentSize.X.Offset * 0.965),
		currentSize.Y.Scale * 0.965, math.floor(currentSize.Y.Offset * 0.965)
	)
	local liftPos = UDim2.new(currentPos.X.Scale, currentPos.X.Offset, currentPos.Y.Scale, currentPos.Y.Offset + 4)

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("Frame") or obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("ImageLabel") then
			local goal = {}
			if obj:IsA("Frame") or obj:IsA("TextButton") then
				goal.BackgroundTransparency = 1
			elseif obj:IsA("ImageLabel") then
				goal.BackgroundTransparency = 1
				goal.ImageTransparency = 1
			end
			if obj:IsA("TextButton") or obj:IsA("TextLabel") then
				goal.TextTransparency = 1
			end
			TweenService:Create(obj, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), goal):Play()
		elseif obj:IsA("UIStroke") then
			TweenService:Create(obj, TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Transparency = 1}):Play()
		end
	end

	setHostShadowVisible(root, false)

	local tween = TweenService:Create(root, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
		Size = shrinkSize,
		Position = liftPos,
		BackgroundTransparency = 1
	})

	tween:Play()
	tween.Completed:Connect(function()
		root.Visible = false
		root.Size = currentSize
		root.Position = currentPos
		if onDone then onDone() end
	end)
end

local activeNoticeId = 0
local function showNotice(text)
	if not Notice or not NoticeStroke or not NoticeBar then
		return
	end

	activeNoticeId = activeNoticeId + 1
	local myId = activeNoticeId
	local msg = tostring(text or "")
	local noticeWidth = math.clamp(78 + (#msg * 6), 120, 260)

	Notice.Size = UDim2.new(0, noticeWidth, 0, 26)
	if NoticeGlow then
		NoticeGlow.Size = UDim2.new(0, noticeWidth + 8, 0, 34)
		NoticeGlow.Position = UDim2.new(1, -10, 0, 10)
	end
	Notice.Text = msg
	Notice.Visible = true
	Notice.Position = UDim2.new(1, noticeWidth + 20, 0, 14)
	Notice.BackgroundTransparency = 1
	Notice.TextTransparency = 1
	NoticeStroke.Transparency = 1
	if NoticeGlow then
		NoticeGlow.Visible = true
		NoticeGlow.BackgroundTransparency = 1
	end
	NoticeBar.BackgroundTransparency = 0
	NoticeBar.Size = UDim2.new(1, -10, 0, 2)
	NoticeBar.Position = UDim2.new(0, 5, 1, -4)

	TweenService:Create(Notice, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.08,
		TextTransparency = 0,
		Position = UDim2.new(1, -14, 0, 14)
	}):Play()

	TweenService:Create(NoticeStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 0.45
	}):Play()

	if NoticeGlow then
		TweenService:Create(NoticeGlow, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.78
		}):Play()
	end

	TweenService:Create(NoticeBar, TweenInfo.new(0.8, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 0, 0, 2),
		Position = UDim2.new(1, -6, 1, -4)
	}):Play()

	task.delay(0.8, function()
		if myId ~= activeNoticeId then
			return
		end

		TweenService:Create(Notice, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
			Position = UDim2.new(1, noticeWidth + 20, 0, 14)
		}):Play()

		TweenService:Create(NoticeStroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1
		}):Play()

		if NoticeGlow then
			TweenService:Create(NoticeGlow, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1
			}):Play()
		end

		TweenService:Create(NoticeBar, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1
		}):Play()

		task.delay(0.25, function()
			if myId == activeNoticeId then
				Notice.Visible = false
				if NoticeGlow then
					NoticeGlow.Visible = false
				end
			end
		end)
	end)
end

local function playMiniClickAnimation()
	if not MiniButton then return end

	local originalSize = MiniButton.Size
	local originalPos = MiniButton.Position
	local pressSize = UDim2.new(
		originalSize.X.Scale, math.floor(originalSize.X.Offset * 0.94),
		originalSize.Y.Scale, math.floor(originalSize.Y.Offset * 0.94)
	)
	local pressPos = UDim2.new(
		originalPos.X.Scale, originalPos.X.Offset + math.floor((originalSize.X.Offset - pressSize.X.Offset) / 2),
		originalPos.Y.Scale, originalPos.Y.Offset + math.floor((originalSize.Y.Offset - pressSize.Y.Offset) / 2)
	)

	local down = TweenService:Create(MiniButton, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = pressSize,
		Position = pressPos,
		BackgroundColor3 = Color3.fromRGB(12,12,12)
	})

	down:Play()
	down.Completed:Connect(function()
		if MiniButton and MiniButton.Parent then
			TweenService:Create(MiniButton, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = originalSize,
				Position = originalPos,
				BackgroundColor3 = Color3.fromRGB(0,0,0)
			}):Play()
		end
	end)
end

local function clearDragConnections()
	for _, c in ipairs(dragConnections) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(dragConnections)
end

local function makeDraggable(frame, handle, longPressOnly)
	local dragging = false
	local dragInput = nil
	local dragStart = nil
	local startPos = nil
	local pressStart = 0
	local longPressReady = false
	local longPressToken = 0

	handle.Active = true
	handle.Selectable = false

	local function begin(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

		pressStart = tick()
		longPressReady = not longPressOnly
		longPressToken += 1
		local thisToken = longPressToken

		if longPressOnly then
			task.delay(0.5, function()
				if thisToken == longPressToken and input.UserInputState ~= Enum.UserInputState.End then
					longPressReady = true
				end
			end)
		end

		dragging = false
		dragInput = input
		dragStart = input.Position
		startPos = frame.Position
	end

	local function changed(input)
		if input ~= dragInput or not dragStart or not startPos then return end

		local delta = input.Position - dragStart
		if longPressReady and delta.Magnitude > 4 then
			dragging = true
		end

		if dragging then
			frame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
			frame:SetAttribute("LastDragTime", tick())
		end
	end

	local function ended(input)
		if input ~= dragInput then return end

		local wasDragging = dragging

		longPressToken += 1
		dragging = false
		dragInput = nil
		dragStart = nil
		startPos = nil
		longPressReady = false

		if wasDragging then
			savePrefs()
		end
	end

	table.insert(dragConnections, handle.InputBegan:Connect(begin))
	table.insert(dragConnections, handle.InputChanged:Connect(changed))
	table.insert(dragConnections, handle.InputEnded:Connect(ended))
end

local function updateSwitchVisual(switchFrame, knob, enabled)
	if not switchFrame or not knob then return end

	local offPos = UDim2.new(0, 3, 0.5, -12)
	local onPos = UDim2.new(1, -27, 0.5, -12)

	TweenService:Create(switchFrame, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = enabled and Color3.fromRGB(190,190,190) or Color3.fromRGB(20,20,24)
	}):Play()

	TweenService:Create(knob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = enabled and onPos or offPos,
		BackgroundColor3 = enabled and Color3.fromRGB(255,255,255) or Color3.fromRGB(0,0,0)
	}):Play()
end

local function createSwitchRow(parent, yOffset, labelText)
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -28, 0, 40)
	row.Position = UDim2.new(0, 14, 0, yOffset)
	row.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	row.AutoButtonColor = false
	row.Text = ""
	row.BorderSizePixel = 0
	row.Parent = parent
	row.ZIndex = 5
	row.Active = true
	row.Selectable = false
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 12)
	setTargetTransparency(row, 0, 1)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -120, 1, 0)
	label.Position = UDim2.new(0, 14, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(255,255,255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row
	label.ZIndex = 6
	label.Active = false
	noTextStroke(label)
	setTargetTransparency(label, 1, 0)

	local switch = Instance.new("Frame")
	switch.Size = UDim2.new(0, 50, 0, 26)
	switch.Position = UDim2.new(1, -68, 0.5, -13)
	switch.BackgroundColor3 = Color3.fromRGB(20,20,24)
	switch.BorderSizePixel = 0
	switch.Parent = row
	switch.ZIndex = 6
	switch.Active = false
	Instance.new("UICorner", switch).CornerRadius = UDim.new(1, 0)
	setTargetTransparency(switch, 0, nil)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 24, 0, 24)
	knob.Position = UDim2.new(0, 3, 0.5, -12)
	knob.BackgroundColor3 = Color3.fromRGB(0,0,0)
	knob.BorderSizePixel = 0
	knob.Parent = switch
	knob.ZIndex = 7
	knob.Active = false
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
	setTargetTransparency(knob, 0, nil)

	return row, switch, knob
end

local function updateButtons()
	updateSwitchVisual(HitAuraSwitch, HitAuraKnob, hitAuraEnabled)
	updateSwitchVisual(AutoFarmSwitch, AutoFarmKnob, autoFarmEnabled)
end

local function safeWait(t, enabledGetter)
	local started = tick()
	while isThisScriptActive() and enabledGetter() and tick() - started < (t or 0) do
		task.wait(math.min(0.05, t or 0.05))
	end
end

local function isGameActive()
	local active = ReplicatedStorage:FindFirstChild("IsGameActive")
	return active and active.Value == true
end

local function isLocalBeast()
	local stats = LocalPlayer:FindFirstChild("TempPlayerStatsModule")
	local beast = stats and stats:FindFirstChild("IsBeast")
	return beast and beast.Value == true
end

local function getCaptured(player)
	local stats = player and player:FindFirstChild("TempPlayerStatsModule")
	local captured = stats and stats:FindFirstChild("Captured")
	return captured and captured.Value == true
end

local function getCurrentMap()
	local currentMap = ReplicatedStorage:FindFirstChild("CurrentMap")
	if not currentMap then return nil end

	local mapName = tostring(currentMap.Value or "")
	if mapName == "" or mapName == "nil" then return nil end

	return Workspace:FindFirstChild(mapName)
end

local function getHammerEvent()
	local char = getChar(LocalPlayer)
	local hammer = char and char:FindFirstChild("Hammer")
	return hammer and hammer:FindFirstChild("HammerEvent")
end

local function hitTarget(player)
	local event = getHammerEvent()
	local char = player and player.Character
	if not event or not char then return false end

	local limb = char:FindFirstChild("Left Arm")
		or char:FindFirstChild("Right Arm")
		or char:FindFirstChild("Torso")
		or char:FindFirstChild("UpperTorso")
		or char:FindFirstChild("HumanoidRootPart")

	if not limb then return false end

	pcall(function()
		event:FireServer("HammerHit", limb)
	end)

	return true
end

local function tieTarget(player)
	local event = getHammerEvent()
	local char = player and player.Character
	if not event or not char then return false end

	local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not torso or not hrp then return false end

	pcall(function()
		event:FireServer("HammerTieUp", torso, hrp.Position)
	end)

	return true
end

local function getPods()
	local pods = {}
	local map = getCurrentMap()

	if map then
		for _, obj in ipairs(map:GetDescendants()) do
			if obj.Name == "FreezePod"
				and obj:FindFirstChild("PodTrigger")
				and obj.PodTrigger:FindFirstChild("CapturedTorso") then
				table.insert(pods, obj)
			end
		end
	end

	return pods
end

local function getEmptyPod()
	for _, pod in ipairs(getPods()) do
		if pod.PodTrigger.CapturedTorso.Value == nil then
			return pod
		end
	end
	return nil
end

local function isPlayerInsideAnyPod(player)
	local char = player and player.Character
	local torso = char and (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart"))
	if not torso then return false end

	for _, pod in ipairs(getPods()) do
		local trigger = pod:FindFirstChild("PodTrigger")
		local capturedTorso = trigger and trigger:FindFirstChild("CapturedTorso")
		if capturedTorso and capturedTorso.Value == torso then
			return true
		end
	end

	return false
end

local function isBadCaptured(player)
	if not player or player == LocalPlayer then return false end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hrp or not hum or hum.Health <= 0 then return false end

	if getCaptured(player) and not isPlayerInsideAnyPod(player) then
		return true
	end

	if not getCurrentMap() and (hrp.Anchored or hum.PlatformStand or hum.Sit) then
		return true
	end

	return false
end

local function getBestTarget(maxDistance)
	local myHrp = getHRP(LocalPlayer)
	if not myHrp then return nil end

	local bestPlayer = nil
	local bestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local hrp = player.Character.HumanoidRootPart
			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			local distance = (hrp.Position - myHrp.Position).Magnitude

			if hum and hum.Health > 0 and distance <= (maxDistance or 800) then
				if isBadCaptured(player) and distance < bestDistance then
					bestPlayer = player
					bestDistance = distance
				end
			end
		end
	end

	if bestPlayer then return bestPlayer end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local hrp = player.Character.HumanoidRootPart
			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			local distance = (hrp.Position - myHrp.Position).Magnitude

			if hum and hum.Health > 0 and distance <= (maxDistance or 800) then
				local captured = getCaptured(player)
				if not captured or not isPlayerInsideAnyPod(player) then
					return player
				end
			end
		end
	end

	return nil
end

local function teleportToTarget(player)
	local myHrp = getHRP(LocalPlayer)
	local targetHrp = getHRP(player)
	if not myHrp or not targetHrp then return false end

	pcall(function()
		myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 3)
	end)

	return true
end

local function teleportToEmptyPod()
	local myHrp = getHRP(LocalPlayer)
	local pod = getEmptyPod()
	if not myHrp or not pod then return false end

	local part = pod:FindFirstChild("Part") or pod:FindFirstChildWhichIsA("BasePart", true)
	if not part then return false end

	pcall(function()
		myHrp.CFrame = part.CFrame * CFrame.new(0, 2, 0)
	end)

	return true
end

local function spamUseKey(times, delayTime, enabledGetter)
	times = times or 8
	delayTime = delayTime or 0.01

	for _ = 1, times do
		if not isThisScriptActive() or not enabledGetter() then return end

		pcall(function()
			VirtualInputManager:SendKeyEvent(true, "E", false, LocalPlayer)
			VirtualInputManager:SendKeyEvent(false, "E", false, LocalPlayer)
		end)

		safeWait(delayTime, enabledGetter)
	end
end

local function recoverLocalCharacterIfStuck()
	local char = getChar(LocalPlayer)
	local hrp = getHRP(LocalPlayer)
	local hum = getHumanoid(LocalPlayer)
	if not char or not hrp or not hum then return end

	pcall(function()
		hrp.Anchored = false
		hum.PlatformStand = false
		hum.Sit = false
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end)

	if not isGameActive() and (getCaptured(LocalPlayer) or hrp.Anchored or hum.PlatformStand) then
		pcall(function()
			hum.Health = 0
		end)
	end
end

local function startHitAura()
	hitAuraToken += 1
	local token = hitAuraToken

	task.spawn(function()
		while isThisScriptActive() and token == hitAuraToken and hitAuraEnabled do
			if isLocalBeast() and isGameActive() then
				local target = getBestTarget(18)
				if target then
					hitTarget(target)
					tieTarget(target)
				end
			end
			task.wait(0.08)
		end
	end)
end

local function setHitAuraEnabled(state)
	hitAuraEnabled = state and true or false
	hitAuraToken += 1

	if hitAuraEnabled then
		startHitAura()
		showNotice("Hit Aura enabled")
	else
		showNotice("Hit Aura disabled")
	end

	updateButtons()
	savePrefs()
end

local function startAutoFarm()
	autofarmToken += 1
	local token = autofarmToken

	task.spawn(function()
		while isThisScriptActive() and token == autofarmToken and autoFarmEnabled do
			recoverLocalCharacterIfStuck()

			if isLocalBeast() and isGameActive() then
				local target = getBestTarget(1200)

				if target then
					teleportToTarget(target)
					safeWait(0.12, function() return autoFarmEnabled and token == autofarmToken end)

					for _ = 1, 4 do
						if not autoFarmEnabled or token ~= autofarmToken then break end
						hitTarget(target)
						tieTarget(target)
						safeWait(0.08, function() return autoFarmEnabled and token == autofarmToken end)
					end

					if teleportToEmptyPod() then
						safeWait(0.18, function() return autoFarmEnabled and token == autofarmToken end)
						spamUseKey(10, 0.01, function() return autoFarmEnabled and token == autofarmToken end)
					else
						safeWait(0.30, function() return autoFarmEnabled and token == autofarmToken end)
					end
				else
					safeWait(0.25, function() return autoFarmEnabled and token == autofarmToken end)
				end
			else
				safeWait(0.45, function() return autoFarmEnabled and token == autofarmToken end)
			end
		end
	end)
end

local function setAutoFarmEnabled(state)
	autoFarmEnabled = state and true or false
	autofarmToken += 1

	if autoFarmEnabled then
		startAutoFarm()
		showNotice("Auto farm enabled")
	else
		showNotice("Auto farm disabled")
	end

	updateButtons()
	savePrefs()
end

local function applyVisibility()
	if not MainFrame or not MiniButton then return end

	if guiVisible then
		MiniButton.Visible = false
		elegantShow(MainFrame, MAIN_SIZE, MainFrame.Position, 0)
	else
		elegantHide(MainFrame, function()
			MiniButton.Visible = true
			elegantShow(MiniButton, MINI_SIZE, MiniButton.Position, 0)
		end)
	end

	savePrefs()
end

local function setGuiVisible(state)
	guiVisible = state and true or false
	applyVisibility()
	showNotice(guiVisible and "GUI shown" or "GUI hidden")
end

local function destroyOld()
	for _, name in ipairs({"CerberXAutofarmGui", "AutoWallHopGui", "AutoWallHopGuiMobile", "WallhopModeSelector"}) do
		local old = PlayerGui:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
end

local function buildGui()
	destroyOld()
	clearDragConnections()
	loadPrefs()

	ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "CerberXAutofarmGui"
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ScreenGui.Parent = PlayerGui

	MainFrame = Instance.new("Frame")
	MainFrame.Name = "MainFrame"
	MainFrame.Size = MAIN_SIZE
	MainFrame.Position = getSavedPosition("main", UDim2.new(0, 24, 0, 76))
	MainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MainFrame.BorderSizePixel = 0
	MainFrame.Parent = ScreenGui
	MainFrame.ZIndex = 1
	MainFrame.Active = true
	Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 18)
	setTargetTransparency(MainFrame, 0, nil)
	addTrueRoundedShadow(MainFrame, 18, 1.0)

	local dragArea = Instance.new("Frame")
	dragArea.Name = "DragArea"
	dragArea.Size = UDim2.new(1, -50, 0, 70)
	dragArea.Position = UDim2.new(0, 0, 0, 0)
	dragArea.BackgroundTransparency = 1
	dragArea.Parent = MainFrame
	dragArea.ZIndex = 20
	setTargetTransparency(dragArea, 1, nil)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(0, 150, 0, 38)
	title.Position = UDim2.new(0, 14, 0, 8)
	title.BackgroundTransparency = 1
	title.Text = "Cerber X"
	title.TextColor3 = Color3.fromRGB(255,255,255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 27
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = MainFrame
	title.ZIndex = 4
	noTextStroke(title)
	setTargetTransparency(title, 1, 0)

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 50, 0, 50)
	icon.Position = UDim2.new(0, 116, 0, 3)
	icon.BackgroundTransparency = 1
	icon.Image = CERBER_ICON_IMAGE
	icon.Parent = MainFrame
	icon.ZIndex = 4
	setTargetTransparency(icon, 1, nil)

	local version = Instance.new("TextLabel")
	version.Size = UDim2.new(0, 190, 0, 22)
	version.Position = UDim2.new(0, 15, 0, 44)
	version.BackgroundTransparency = 1
	version.Text = "Autofarm Version"
	version.TextColor3 = Color3.fromRGB(110,110,110)
	version.Font = Enum.Font.Gotham
	version.TextSize = 16
	version.TextXAlignment = Enum.TextXAlignment.Left
	version.Parent = MainFrame
	version.ZIndex = 4
	noTextStroke(version)
	setTargetTransparency(version, 1, 0)

	local minimize = Instance.new("TextButton")
	minimize.Size = UDim2.new(0, 38, 0, 38)
	minimize.Position = UDim2.new(1, -48, 0, 14)
	minimize.BackgroundColor3 = Color3.fromRGB(8,8,8)
	minimize.Text = "—"
	minimize.TextColor3 = Color3.fromRGB(255,255,255)
	minimize.Font = Enum.Font.GothamBold
	minimize.TextSize = 23
	minimize.AutoButtonColor = false
	minimize.Parent = MainFrame
	minimize.ZIndex = 6
	Instance.new("UICorner", minimize).CornerRadius = UDim.new(1, 0)
	noTextStroke(minimize)
	setTargetTransparency(minimize, 0, 0)

	local functionsTitle = Instance.new("TextLabel")
	functionsTitle.Size = UDim2.new(1, -32, 0, 32)
	functionsTitle.Position = UDim2.new(0, 14, 0, 72)
	functionsTitle.BackgroundTransparency = 1
	functionsTitle.Text = "Functions"
	functionsTitle.TextColor3 = Color3.fromRGB(255,255,255)
	functionsTitle.Font = Enum.Font.GothamBold
	functionsTitle.TextSize = 22
	functionsTitle.TextXAlignment = Enum.TextXAlignment.Left
	functionsTitle.Parent = MainFrame
	functionsTitle.ZIndex = 4
	noTextStroke(functionsTitle)
	setTargetTransparency(functionsTitle, 1, 0)

	HitAuraRow, HitAuraSwitch, HitAuraKnob = createSwitchRow(MainFrame, 108, "Hit Aura")
	AutoFarmRow, AutoFarmSwitch, AutoFarmKnob = createSwitchRow(MainFrame, 154, "Auto farm")

	local footer = Instance.new("TextLabel")
	footer.Size = UDim2.new(1, -32, 0, 24)
	footer.Position = UDim2.new(0, 14, 1, -28)
	footer.BackgroundTransparency = 1
	footer.Text = "Hide GUI Keybind: C | Cerber X"
	footer.TextColor3 = Color3.fromRGB(110,110,110)
	footer.Font = Enum.Font.Gotham
	footer.TextSize = 13
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.Parent = MainFrame
	footer.ZIndex = 4
	noTextStroke(footer)
	setTargetTransparency(footer, 1, 0)

	NoticeGlow = Instance.new("Frame")
	NoticeGlow.Name = "NoticeGlow"
	NoticeGlow.AnchorPoint = Vector2.new(1, 0)
	NoticeGlow.Size = UDim2.new(0, 128, 0, 34)
	NoticeGlow.Position = UDim2.new(1, -10, 0, 10)
	NoticeGlow.BackgroundColor3 = Color3.fromRGB(255,255,255)
	NoticeGlow.BackgroundTransparency = 1
	NoticeGlow.BorderSizePixel = 0
	NoticeGlow.Visible = false
	NoticeGlow.ZIndex = 88
	NoticeGlow.Parent = ScreenGui
	Instance.new("UICorner", NoticeGlow).CornerRadius = UDim.new(0, 12)

	Notice = Instance.new("TextLabel")
	Notice.Size = UDim2.new(0, 120, 0, 26)
	Notice.Position = UDim2.new(1, -14, 0, 14)
	Notice.AnchorPoint = Vector2.new(1, 0)
	Notice.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	Notice.BackgroundTransparency = 1
	Notice.TextColor3 = Color3.fromRGB(255,255,255)
	Notice.TextTransparency = 1
	Notice.Font = Enum.Font.GothamBold
	Notice.TextSize = 10
	Notice.TextWrapped = false
	Notice.TextXAlignment = Enum.TextXAlignment.Left
	Notice.TextYAlignment = Enum.TextYAlignment.Center
	Notice.ClipsDescendants = true
	Notice.ZIndex = 90
	Notice.Visible = false
	Notice.Parent = ScreenGui
	Instance.new("UICorner", Notice).CornerRadius = UDim.new(0, 10)
	local noticePadding = Instance.new("UIPadding")
	noticePadding.PaddingLeft = UDim.new(0, 7)
	noticePadding.PaddingRight = UDim.new(0, 7)
	noticePadding.PaddingTop = UDim.new(0, 2)
	noticePadding.Parent = Notice
	noTextStroke(Notice)
	setTargetTransparency(Notice, 0.08, 0)

	NoticeBar = Instance.new("Frame")
	NoticeBar.Size = UDim2.new(1, -10, 0, 2)
	NoticeBar.Position = UDim2.new(0, 5, 1, -4)
	NoticeBar.BackgroundColor3 = Color3.fromRGB(255,255,255)
	NoticeBar.BackgroundTransparency = 0
	NoticeBar.BorderSizePixel = 0
	NoticeBar.ZIndex = 91
	NoticeBar.Parent = Notice
	Instance.new("UICorner", NoticeBar).CornerRadius = UDim.new(1, 0)

	NoticeStroke = Instance.new("UIStroke")
	NoticeStroke.Color = Color3.fromRGB(255,255,255)
	NoticeStroke.Thickness = 1
	NoticeStroke.Transparency = 1
	NoticeStroke.Parent = Notice

	MiniButton = Instance.new("TextButton")
	MiniButton.Name = "MiniButton"
	MiniButton.Size = MINI_SIZE
	MiniButton.Position = getSavedPosition("mini", UDim2.new(0, 220, 0, 160))
	MiniButton.BackgroundColor3 = Color3.fromRGB(0,0,0)
	MiniButton.Text = "Cerber X"
	MiniButton.TextColor3 = Color3.fromRGB(190,190,190)
	MiniButton.Font = Enum.Font.GothamBold
	MiniButton.TextSize = 16
	MiniButton.AutoButtonColor = false
	MiniButton.Visible = false
	MiniButton.Parent = ScreenGui
	MiniButton.ZIndex = 50
	MiniButton.Active = true
	Instance.new("UICorner", MiniButton).CornerRadius = UDim.new(0, 14)
	noTextStroke(MiniButton)
	setTargetTransparency(MiniButton, 0, 0)
	addTrueRoundedShadow(MiniButton, 14, 1)

	makeDraggable(MainFrame, dragArea, false)
	makeDraggable(MiniButton, MiniButton, true)

	local function bindSwitch(row, callback)
		local activeInput = nil
		local startPos = nil
		local moved = false
		local lastTap = 0

		row.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				activeInput = input
				startPos = input.Position
				moved = false
			end
		end)

		row.InputChanged:Connect(function(input)
			if input == activeInput and startPos then
				if (input.Position - startPos).Magnitude > 8 then
					moved = true
				end
			end
		end)

		row.InputEnded:Connect(function(input)
			if input == activeInput then
				local wasMoved = moved
				activeInput = nil
				startPos = nil
				moved = false

				if not wasMoved and tick() - lastTap > 0.08 then
					lastTap = tick()
					callback()
				end
			end
		end)

		row.Activated:Connect(function()
			if tick() - lastTap > 0.08 then
				lastTap = tick()
				callback()
			end
		end)
	end

	bindSwitch(HitAuraRow, function()
		setHitAuraEnabled(not hitAuraEnabled)
	end)

	bindSwitch(AutoFarmRow, function()
		setAutoFarmEnabled(not autoFarmEnabled)
	end)

	minimize.Activated:Connect(function()
		setGuiVisible(false)
	end)

	MiniButton.Activated:Connect(function()
		local lastDragTime = MiniButton:GetAttribute("LastDragTime")
		if typeof(lastDragTime) == "number" and tick() - lastDragTime < 0.15 then
			return
		end

		playMiniClickAnimation()
		task.delay(0.08, function()
			setGuiVisible(true)
		end)
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == HIDE_KEY then
			setGuiVisible(not guiVisible)
		end
	end)

	updateButtons()

	if hitAuraEnabled then
		startHitAura()
	end
	if autoFarmEnabled then
		startAutoFarm()
	end

	if guiVisible then
		MiniButton.Visible = false
		MainFrame.Visible = true
		elegantShow(MainFrame, MAIN_SIZE, MainFrame.Position, 0)
	else
		MainFrame.Visible = false
		MiniButton.Visible = true
		elegantShow(MiniButton, MINI_SIZE, MiniButton.Position, 0)
	end
end

buildGui()
showNotice("Cerber X loadeeed")
