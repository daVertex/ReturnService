--// FallReturn.server.lua - use as name
-- Put in ServerScriptService (Script)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")

--====================================================
-- CONFIG
--====================================================
local DEBUG = false

local FALL_THRESHOLD_STUDS = 60
local UI_TIMER_SECONDS = 59

-- Anti-spam / polish
local OFFER_COOLDOWN_SECONDS = 6
local OFFER_WINDOW_SECONDS = 30
local MAX_OFFERS_PER_WINDOW = 3
local SUPPRESS_AFTER_SPAM_SECONDS = 25

-- Dev Products (YOUR IDS)
local RETURN_1_PRODUCT_ID = 3534185122 -- 10 Robux -> +1 return
local RETURN_3_PRODUCT_ID = 3534200267 -- 25 Robux -> +3 returns

-- DataStore
local RETURNS_STORE_NAME = "BankedReturns_v1"
local returnsStore = DataStoreService:GetDataStore(RETURNS_STORE_NAME)

local function dprint(...)
	if DEBUG then
		print("[FallReturn]", ...)
	end
end

local function now()
	return os.clock()
end

--====================================================
-- REMOTES
--====================================================
local remoteFolder = ReplicatedStorage:FindFirstChild("FallReturnRemotes")
if not remoteFolder then
	remoteFolder = Instance.new("Folder")
	remoteFolder.Name = "FallReturnRemotes"
	remoteFolder.Parent = ReplicatedStorage
end

local function ensureRemote(name: string)
	local r = remoteFolder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = remoteFolder
	end
	return r
end

local OfferReturn      = ensureRemote("OfferReturn")
local RequestPurchase1 = ensureRemote("RequestPurchase1")
local RequestPurchase3 = ensureRemote("RequestPurchase3")
local UseReturn        = ensureRemote("UseReturn")
local ServerMessage    = ensureRemote("ServerMessage")

--====================================================
-- STATE
--====================================================
local savedReturnCFrameByUserId: {[number]: CFrame} = {}
local pendingReturnByUserId: {[number]: boolean} = {}

local returnsByUserId: {[number]: number} = {}

local lastOfferTimeByUserId: {[number]: number} = {}
local offerTimestampsByUserId: {[number]: {number}} = {}
local suppressedUntilByUserId: {[number]: number} = {}

--====================================================
-- DATASTORE
--====================================================
local function getReturns(userId: number): number
	return returnsByUserId[userId] or 0
end

local function setReturns(userId: number, amount: number)
	returnsByUserId[userId] = math.max(0, math.floor(amount))
end

local function loadReturns(userId: number)
	local ok, data = pcall(function()
		return returnsStore:GetAsync(tostring(userId))
	end)

	if ok and typeof(data) == "number" then
		setReturns(userId, data)
	else
		setReturns(userId, 0)
	end
end

local function saveReturns(userId: number)
	local amount = getReturns(userId)
	local ok, err = pcall(function()
		return returnsStore:SetAsync(tostring(userId), amount)
	end)
	if not ok then
		warn("[FallReturn] Failed to save returns:", userId, err)
	end
end

--====================================================
-- ANTI-SPAM OFFER GATING
--====================================================
local function isSuppressed(userId: number): boolean
	local untilT = suppressedUntilByUserId[userId]
	return untilT ~= nil and now() < untilT
end

local function recordOffer(userId: number)
	local t = now()
	local list = offerTimestampsByUserId[userId]
	if not list then
		list = {}
		offerTimestampsByUserId[userId] = list
	end

	table.insert(list, t)

	local cutoff = t - OFFER_WINDOW_SECONDS
	local i = 1
	while i <= #list do
		if list[i] < cutoff then
			table.remove(list, i)
		else
			i += 1
		end
	end

	if #list > MAX_OFFERS_PER_WINDOW then
		suppressedUntilByUserId[userId] = t + SUPPRESS_AFTER_SPAM_SECONDS
	end
end

local function canOffer(userId: number): boolean
	if isSuppressed(userId) then
		return false
	end

	local t = now()
	local last = lastOfferTimeByUserId[userId] or -math.huge
	if (t - last) < OFFER_COOLDOWN_SECONDS then
		return false
	end

	return true
end

--====================================================
-- TELEPORT RETURN
--====================================================
local function safePivotTo(player: Player, cf: CFrame): boolean
	local character = player.Character
	if not character or not character.Parent then return false end
	character:PivotTo(cf)
	return true
end

local function completeReturn(player: Player): boolean
	local userId = player.UserId
	local cf = savedReturnCFrameByUserId[userId]
	if not (pendingReturnByUserId[userId] and cf) then
		return false
	end

	local ok = safePivotTo(player, cf + Vector3.new(0, 3, 0))

	pendingReturnByUserId[userId] = nil
	savedReturnCFrameByUserId[userId] = nil

	return ok
end

local function fireOffer(player: Player)
	local userId = player.UserId
	if not pendingReturnByUserId[userId] then return end
	if not savedReturnCFrameByUserId[userId] then return end
	if not canOffer(userId) then return end

	lastOfferTimeByUserId[userId] = now()
	recordOffer(userId)

	OfferReturn:FireClient(player, {
		timerSeconds = UI_TIMER_SECONDS,
		returns = getReturns(userId),
	})

	dprint("Offer fired ->", player.Name, "banked:", getReturns(userId))
end

--====================================================
-- FALL DETECTION (FIXED: peakY tracking so jumps don't trigger)
--====================================================
local function hookCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	local hrp = character:WaitForChild("HumanoidRootPart")

	-- Robust HRP readiness
	local tries = 0
	while (not hrp or not hrp.Parent) and character.Parent and tries < 200 do
		tries += 1
		task.wait(0.05)
		hrp = character:FindFirstChild("HumanoidRootPart")
	end
	if not character.Parent then return end
	if not humanoid or not hrp then
		warn("[FallReturn] Failed to hook character for", player.Name, "(missing Humanoid/HRP)")
		return
	end

	local inAir = false
	local peakY: number? = nil
	local returnCF: CFrame? = nil
	local triggeredThisAir = false

	local function resetAir()
		inAir = false
		peakY = nil
		returnCF = nil
		triggeredThisAir = false
	end

	humanoid.StateChanged:Connect(function(_, newState)
		-- Any "air" state: we treat freefall/jumping as airtime
		if newState == Enum.HumanoidStateType.Freefall
			or newState == Enum.HumanoidStateType.Jumping then

			if not inAir then
				inAir = true
				peakY = hrp.Position.Y
				-- Return spot is where airtime started (ledge), NOT jump apex
				returnCF = hrp.CFrame
				triggeredThisAir = false
			end
		end

		-- When we touch ground / stable movement, reset and offer if a fall was flagged
		if newState == Enum.HumanoidStateType.Landed
			or newState == Enum.HumanoidStateType.Running
			or newState == Enum.HumanoidStateType.RunningNoPhysics then

			resetAir()

			task.defer(function()
				fireOffer(player)
			end)
		end
	end)

	humanoid.Died:Connect(function()
		task.delay(0.2, function()
			fireOffer(player)
		end)
	end)

	task.spawn(function()
		while character.Parent do
			task.wait(0.08)

			if inAir and peakY and returnCF and not triggeredThisAir then
				local y = hrp.Position.Y
				if y > peakY then
					peakY = y
				end

				-- This is the important part:
				-- We measure how far they've dropped from the HIGHEST point in that airtime.
				local drop = peakY - y
				if drop >= FALL_THRESHOLD_STUDS then
					triggeredThisAir = true
					savedReturnCFrameByUserId[player.UserId] = returnCF
					pendingReturnByUserId[player.UserId] = true
				end
			end
		end
	end)
end

--====================================================
-- PLAYER LIFECYCLE
--====================================================
Players.PlayerAdded:Connect(function(player)
	loadReturns(player.UserId)

	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if character and character.Parent then
				hookCharacter(player, character)
			end
		end)
	end)

	-- Studio sometimes already has a character
	if player.Character then
		task.defer(function()
			if player.Character and player.Character.Parent then
				hookCharacter(player, player.Character)
			end
		end)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	saveReturns(userId)

	savedReturnCFrameByUserId[userId] = nil
	pendingReturnByUserId[userId] = nil
	returnsByUserId[userId] = nil
	lastOfferTimeByUserId[userId] = nil
	offerTimestampsByUserId[userId] = nil
	suppressedUntilByUserId[userId] = nil
end)

--====================================================
-- REMOTE HANDLERS
--====================================================
UseReturn.OnServerEvent:Connect(function(player)
	local userId = player.UserId
	if not pendingReturnByUserId[userId] then return end
	if not savedReturnCFrameByUserId[userId] then return end

	local current = getReturns(userId)
	if current <= 0 then
		ServerMessage:FireClient(player, "You don't have any banked returns.")
		return
	end

	setReturns(userId, current - 1)
	saveReturns(userId)

	if not completeReturn(player) then
		setReturns(userId, getReturns(userId) + 1)
		saveReturns(userId)
		ServerMessage:FireClient(player, "Couldn't return right now.")
	end
end)

RequestPurchase1.OnServerEvent:Connect(function(player)
	local userId = player.UserId
	if not pendingReturnByUserId[userId] then return end
	if not savedReturnCFrameByUserId[userId] then return end
	MarketplaceService:PromptProductPurchase(player, RETURN_1_PRODUCT_ID)
end)

RequestPurchase3.OnServerEvent:Connect(function(player)
	local userId = player.UserId
	if not pendingReturnByUserId[userId] then return end
	if not savedReturnCFrameByUserId[userId] then return end
	MarketplaceService:PromptProductPurchase(player, RETURN_3_PRODUCT_ID)
end)

--====================================================
-- PROCESS RECEIPT
--====================================================
MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local userId = player.UserId
	local productId = receiptInfo.ProductId

	if productId == RETURN_1_PRODUCT_ID then
		setReturns(userId, getReturns(userId) + 1)
		saveReturns(userId)

		setReturns(userId, getReturns(userId) - 1)
		saveReturns(userId)

		completeReturn(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if productId == RETURN_3_PRODUCT_ID then
		setReturns(userId, getReturns(userId) + 3)
		saveReturns(userId)

		setReturns(userId, getReturns(userId) - 1)
		saveReturns(userId)

		completeReturn(player)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end
