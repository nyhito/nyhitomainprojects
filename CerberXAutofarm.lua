local lib = loadstring(game:HttpGet"https://raw.githubusercontent.com/dawid-scripts/UI-Libs/main/Vape.txt")()

local obf_stringchar = string.char;
local obf_stringbyte = string.byte;
local obf_stringsub = string.sub;
local obf_bitlib = bit32 or bit;
local obf_XOR = obf_bitlib.bxor;
local obf_tableconcat = table.concat;
local obf_tableinsert = table.insert;
local function __(LUAOBFUSACTOR_STR, LUAOBFUSACTOR_KEY)
	local result = {};
	for i = 1, #LUAOBFUSACTOR_STR do
		obf_tableinsert(result, obf_stringchar(obf_XOR(obf_stringbyte(obf_stringsub(LUAOBFUSACTOR_STR, i, i + 1)), obf_stringbyte(obf_stringsub(LUAOBFUSACTOR_KEY, 1 + (i % #LUAOBFUSACTOR_KEY), 1 + (i % #LUAOBFUSACTOR_KEY) + 1))) % 256));
	end
	return obf_tableconcat(result);
end
local GAME = game;
local PLAYERS = GAME.Players;
local LOCALPLAYER = PLAYERS.LocalPlayer;
local CHARACTER = LOCALPLAYER.Character;
LOCALPLAYER.CharacterAdded:Connect(function(char)
	CHARACTER = char;
end);
local REPLICATEDSTORAGE = GAME:GetService(__("\227\198\203\41\239\184\198\10\212\199\232\49\233\169\198\25\212", "\126\177\163\187\69\134\219\167"));
local RUNSERVICE = GAME:GetService(__("\17\216\36\246\249\49\219\35\198\249", "\156\67\173\74\165"));
local VIRTUALINPUT = GAME:GetService(__("\2\190\91\2\169\39\74\29\185\89\3\168\11\71\58\182\78\19\174", "\38\84\215\41\118\220\70"));
local WORKSPACE = GAME.Workspace;
local ENUM = Enum;
local TextChatService = GAME:GetService(__("\100\19\58\6\221\88\23\54\33\251\66\0\43\17\251", "\158\48\118\66\114"));
local SOUNDSERVICE = GAME:GetService(__("\152\43\5\56\119\150\254\185\50\25\53\118", "\155\203\68\112\86\19\197"));
local CAMERA = WORKSPACE.CurrentCamera;
local USERINPUT = GAME:GetService(__("\115\206\51\238\105\118\245\237\82\238\51\238\86\113\230\253", "\152\38\189\86\156\32\24\133"));
local CF = CFrame;
local function GetCharacter()
	CHARACTER = LOCALPLAYER.Character or CHARACTER;
	if CHARACTER and CHARACTER.Parent then
		return CHARACTER;
	end
	CHARACTER = LOCALPLAYER.CharacterAdded:Wait();
	return CHARACTER;
end
local function GetHammer()
	local character = GetCharacter();
	if character then
		return character:FindFirstChild(__("\212\86\170\75\249\69", "\38\156\55\199"));
	end
	return nil;
end
local function enableKillAura()
	task.spawn(function()
		while getgenv().killaura do
			task.wait(0.1);
			for _, player in ipairs(PLAYERS:GetPlayers()) do
				if not getgenv().killaura then
					return;
				end
				if ((player ~= LOCALPLAYER) and player.Character) then
					local torso = player.Character:FindFirstChild(__("\156\114\110\59\28", "\35\200\29\28\72\115\20\154"));
					local myChar = GetCharacter();
					local myTorso = myChar and myChar:FindFirstChild(__("\45\176\195\204\130", "\84\121\223\177\191\237\76"));
					if (torso and myTorso) then
						local distance = (torso.Position - myTorso.Position).Magnitude;
						if (distance <= (getgenv().KillAuraRadius or 10)) then
							local hammer = GetHammer();
							if (hammer and hammer:FindFirstChild(__("\147\87\196\173\63\66\21\215\190\88\221", "\161\219\54\169\192\90\48\80"))) then
								hammer.HammerEvent:FireServer(__("\97\67\13\40\76\80\40\44\93", "\69\41\34\96"), torso);
							end
						end
					end
				end
			end
		end
	end);
end

local win = lib:Window("PREVIEW",Color3.fromRGB(44, 120, 224), Enum.KeyCode.RightControl)

local tab = win:Tab("Main")

tab:Toggle("Hit Aura",false, function(Value)
	getgenv().killaura = Value;
		if Value then
			enableKillAura()
		end
end)

tab:Toggle("Autofarm",false, function(Value)
	getgenv().AutofarmFTFEnabled = Value and true or false
	getgenv().Collid = Value and true or false
	getgenv().X = Value and true or false
	getgenv().BeastFF = false

	getgenv().AutofarmFTFToken = (getgenv().AutofarmFTFToken or 0) + 1
	local token = getgenv().AutofarmFTFToken

	local function isTokenActive()
		return getgenv().AutofarmFTFEnabled == true and getgenv().AutofarmFTFToken == token
	end

	local function safeWait(t)
		local started = tick()
		while isTokenActive() and tick() - started < (t or 0) do
			task.wait(math.min(0.05, t or 0.05))
		end
	end

	local function getChar(player)
		player = player or LOCALPLAYER
		local char = player.Character
		if player == LOCALPLAYER then
			CHARACTER = char or CHARACTER
			return CHARACTER
		end
		return char
	end

	local function getHRP(player)
		local char = getChar(player)
		return char and char:FindFirstChild("HumanoidRootPart")
	end

	local function getHumanoid(player)
		local char = getChar(player)
		return char and char:FindFirstChildOfClass("Humanoid")
	end

	local function isGameActive()
		local active = REPLICATEDSTORAGE:FindFirstChild("IsGameActive")
		return active and active.Value == true
	end

	local function isLocalBeast()
		local stats = LOCALPLAYER:FindFirstChild("TempPlayerStatsModule")
		local beast = stats and stats:FindFirstChild("IsBeast")
		return beast and beast.Value == true
	end

	local function getPlayerCaptured(player)
		local stats = player and player:FindFirstChild("TempPlayerStatsModule")
		local captured = stats and stats:FindFirstChild("Captured")
		return captured and captured.Value == true
	end

	local function getCurrentMap()
		local currentMap = REPLICATEDSTORAGE:FindFirstChild("CurrentMap")
		if not currentMap then
			return nil
		end

		local mapName = tostring(currentMap.Value or "")
		if mapName == "" or mapName == "nil" then
			return nil
		end

		return WORKSPACE:FindFirstChild(mapName)
	end

	local function spamUseKey(times, delay)
		times = times or 5
		delay = delay or 0.03

		for i = 1, times do
			if not isTokenActive() then
				return
			end

			pcall(function()
				VIRTUALINPUT:SendKeyEvent(true, "E", false, LOCALPLAYER)
				VIRTUALINPUT:SendKeyEvent(false, "E", false, LOCALPLAYER)
			end)

			if delay > 0 then
				safeWait(delay)
			end
		end
	end

	local function getHammerEvent()
		local char = getChar(LOCALPLAYER)
		local hammer = char and char:FindFirstChild("Hammer")
		return hammer and hammer:FindFirstChild("HammerEvent")
	end

	local function getPods()
		local pods = {}
		local map = getCurrentMap()

		if map then
			for _, pod in pairs(map:GetChildren()) do
				if pod.Name == "FreezePod"
					and pod:FindFirstChild("PodTrigger")
					and pod.PodTrigger:FindFirstChild("CapturedTorso") then
					table.insert(pods, pod)
				end
			end
		end

		return pods
	end

	local function getEmptyPods()
		local empty = {}

		for _, pod in pairs(getPods()) do
			if pod.PodTrigger.CapturedTorso.Value == nil then
				table.insert(empty, pod)
			end
		end

		return empty
	end

	local function isPlayerInsideAnyPod(player)
		local char = player and player.Character
		local torso = char and (char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso") or char:FindFirstChild("HumanoidRootPart"))
		if not torso then
			return false
		end

		for _, pod in pairs(getPods()) do
			local trigger = pod:FindFirstChild("PodTrigger")
			local capturedTorso = trigger and trigger:FindFirstChild("CapturedTorso")
			if capturedTorso and capturedTorso.Value == torso then
				return true
			end
		end

		return false
	end

	local function isPlayerStuckOrBadCaptured(player)
		if not player or player == LOCALPLAYER then
			return false
		end

		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not char or not hrp or not hum or hum.Health <= 0 then
			return false
		end

		-- Principal correção: se Captured ficar true mas o player não estiver realmente em nenhum pod,
		-- ele não pode ser ignorado para sempre.
		if getPlayerCaptured(player) and not isPlayerInsideAnyPod(player) then
			return true
		end

		-- Se o mapa sumiu/removido, qualquer player congelado/ancorado/plataformado vira alvo de recuperação.
		if not getCurrentMap() then
			if hrp.Anchored or hum.PlatformStand or hum.Sit then
				return true
			end
		end

		return false
	end

	local function getBestTarget()
		local myHrp = getHRP(LOCALPLAYER)
		if not myHrp then
			return nil
		end

		local bestPlayer = nil
		local bestDistance = math.huge

		-- Prioriza players bugados/capturados fora do pod.
		for _, player in pairs(PLAYERS:GetPlayers()) do
			if player ~= LOCALPLAYER and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local hrp = player.Character.HumanoidRootPart
				local distance = (hrp.Position - myHrp.Position).Magnitude

				if distance <= 1200 and isPlayerStuckOrBadCaptured(player) and distance < bestDistance then
					bestPlayer = player
					bestDistance = distance
				end
			end
		end

		if bestPlayer then
			return bestPlayer
		end

		-- Depois pega alvos normais. Captured só é ignorado se estiver realmente dentro de um pod válido.
		for _, player in pairs(PLAYERS:GetPlayers()) do
			if player ~= LOCALPLAYER and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local hrp = player.Character.HumanoidRootPart
				local hum = player.Character:FindFirstChildOfClass("Humanoid")
				local distance = (hrp.Position - myHrp.Position).Magnitude

				if hum and hum.Health > 0 and distance <= 800 then
					local captured = getPlayerCaptured(player)
					if not captured or not isPlayerInsideAnyPod(player) then
						return player
					end
				end
			end
		end

		return nil
	end

	local function tiePlayer(player)
		local hammerEvent = getHammerEvent()
		if not hammerEvent or not player or not player.Character then
			return
		end

		local torso = player.Character:FindFirstChild("Torso") or player.Character:FindFirstChild("UpperTorso")
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if torso and hrp then
			for i = 1, 5 do
				if not isTokenActive() then
					return
				end
				pcall(function()
					hammerEvent:FireServer("HammerTieUp", torso, hrp.Position)
				end)
				safeWait(0.10)
			end
		end
	end

	local function hitPlayer(player)
		local hammerEvent = getHammerEvent()
		if not hammerEvent or not player or not player.Character then
			return
		end

		local targetLimb = player.Character:FindFirstChild("Left Arm")
			or player.Character:FindFirstChild("Right Arm")
			or player.Character:FindFirstChild("Torso")
			or player.Character:FindFirstChild("UpperTorso")
			or player.Character:FindFirstChild("HumanoidRootPart")

		if targetLimb then
			for i = 1, 3 do
				if not isTokenActive() then
					return
				end
				pcall(function()
					hammerEvent:FireServer("HammerHit", targetLimb)
				end)
				safeWait(0.08)
			end
		end
	end

	local function teleportToPlayer(player)
		local myHrp = getHRP(LOCALPLAYER)
		local targetHrp = getHRP(player)
		if not myHrp or not targetHrp then
			return false
		end

		pcall(function()
			myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 3)
		end)

		safeWait(0.08)
		hitPlayer(player)
		tiePlayer(player)

		return true
	end

	local function teleportToEmptyPod()
		local myHrp = getHRP(LOCALPLAYER)
		if not myHrp then
			return false
		end

		local pods = getEmptyPods()
		if #pods <= 0 then
			return false
		end

		local pod = pods[math.random(1, #pods)]
		local part = pod:FindFirstChild("Part") or pod:FindFirstChildWhichIsA("BasePart", true)
		if not part then
			return false
		end

		pcall(function()
			myHrp.CFrame = part.CFrame * CFrame.new(0, 2, 0)
		end)

		return true
	end

	local function recoverLocalCharacterIfStuck()
		local char = getChar(LOCALPLAYER)
		local hrp = getHRP(LOCALPLAYER)
		local hum = getHumanoid(LOCALPLAYER)
		if not char or not hrp or not hum then
			return
		end

		pcall(function()
			hrp.Anchored = false
			hum.PlatformStand = false
			hum.Sit = false
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)

		-- Se o round acabou/mapa sumiu e a conta ficou capturada/congelada, tenta resetar para forçar respawn/lobby.
		if not isGameActive() and (getPlayerCaptured(LOCALPLAYER) or hrp.Anchored or hum.PlatformStand) then
			pcall(function()
				hum.Health = 0
			end)
		end
	end

	if not Value then
		getgenv().BeastFF = false
		return
	end

	task.spawn(function()
		while isTokenActive() do
			getgenv().BeastFF = isLocalBeast() and isGameActive()
			recoverLocalCharacterIfStuck()
			safeWait(0.15)
		end
	end)

	task.spawn(function()
		while isTokenActive() do
			if getgenv().BeastFF then
				local target = getBestTarget()

				if target then
					teleportToPlayer(target)
					safeWait(0.20)

					if teleportToEmptyPod() then
						safeWait(0.18)
						spamUseKey(10, 0.01)
					else
						-- Sem pod/mapa: não fica preso tentando eternamente no mesmo estado.
						safeWait(0.35)
					end
				else
					safeWait(0.25)
				end
			else
				safeWait(0.45)
			end
		end
	end)
end)

