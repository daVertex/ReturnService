

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("FallReturnRemotes")
local OfferReturn      = remotes:WaitForChild("OfferReturn")
local RequestPurchase1 = remotes:WaitForChild("RequestPurchase1")
local RequestPurchase3 = remotes:WaitForChild("RequestPurchase3")
local UseReturn        = remotes:WaitForChild("UseReturn")
local ServerMessage    = remotes:WaitForChild("ServerMessage")

--====================================================
-- CONFIG
--====================================================
local DEFAULT_TIMER = 59
local RED_AT = 10

--====================================================
-- GUI ROOT
--====================================================
local gui = Instance.new("ScreenGui")
gui.Name = "FallReturnGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Dim overlay
local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.45
overlay.Visible = false
overlay.ZIndex = 1
overlay.Parent = gui

-- Main card (cartoony big)
local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(560, 320)
card.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
card.BorderSizePixel = 0
card.Visible = false
card.ZIndex = 3
card.Parent = gui

local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(420, 260)
sizeConstraint.MaxSize = Vector2.new(680, 420)
sizeConstraint.Parent = card

local cardScale = Instance.new("UIScale")
cardScale.Scale = 1
cardScale.Parent = card

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 22)
corner.Parent = card

-- Outline (cartoon)
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Transparency = 0.15
stroke.Color = Color3.fromRGB(0, 0, 0)
stroke.Parent = card

-- Clean “fake drop shadow” via thick faint stroke
local stroke2 = Instance.new("UIStroke")
stroke2.Thickness = 8
stroke2.Transparency = 0.85
stroke2.Color = Color3.fromRGB(0, 0, 0)
stroke2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke2.LineJoinMode = Enum.LineJoinMode.Round
stroke2.Parent = card

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 14)
pad.PaddingBottom = UDim.new(0, 16)
pad.PaddingLeft = UDim.new(0, 16)
pad.PaddingRight = UDim.new(0, 16)
pad.Parent = card

--====================================================
-- TOP BAR (timer + X)
--====================================================
local topBar = Instance.new("Frame")
topBar.BackgroundTransparency = 1
topBar.Size = UDim2.new(1, 0, 0, 34)
topBar.ZIndex = 4
topBar.Parent = card

local timerLabel = Instance.new("TextLabel")
timerLabel.BackgroundTransparency = 1
timerLabel.AnchorPoint = Vector2.new(0.5, 0.5)
timerLabel.Position = UDim2.fromScale(0.5, 0.5)
timerLabel.Size = UDim2.new(0.75, 0, 1, 0)
timerLabel.Text = ""
timerLabel.Font = Enum.Font.FredokaOne
timerLabel.TextSize = 16
timerLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
timerLabel.TextXAlignment = Enum.TextXAlignment.Center
timerLabel.ZIndex = 5
timerLabel.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.Position = UDim2.fromScale(1, 0.5)
closeBtn.Size = UDim2.fromOffset(36, 36)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.FredokaOne
closeBtn.TextSize = 18
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 6
closeBtn.Parent = topBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 12)
closeCorner.Parent = closeBtn

local closeStroke = Instance.new("UIStroke")
closeStroke.Thickness = 2
closeStroke.Transparency = 0.2
closeStroke.Color = Color3.fromRGB(0, 0, 0)
closeStroke.Parent = closeBtn


local CLOSE_BG_NORMAL = Color3.fromRGB(40, 40, 45)
local CLOSE_BG_HOVER  = Color3.fromRGB(220, 60, 60)

local closeHoverIn = TweenService:Create(
	closeBtn,
	TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{BackgroundColor3 = CLOSE_BG_HOVER}
)

local closeHoverOut = TweenService:Create(
	closeBtn,
	TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{BackgroundColor3 = CLOSE_BG_NORMAL}
)

closeBtn.MouseEnter:Connect(function()
	closeHoverOut:Cancel()
	closeHoverIn:Play()
end)

closeBtn.MouseLeave:Connect(function()
	closeHoverIn:Cancel()
	closeHoverOut:Play()
end)

--====================================================
-- CONTENT
--====================================================
local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(0, 40)
title.Size = UDim2.new(1, 0, 0, 40)
title.Text = "Return to where you fell?"
title.Font = Enum.Font.FredokaOne
title.TextSize = 28
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 5
title.Parent = card

local desc = Instance.new("TextLabel")
desc.BackgroundTransparency = 1
desc.Position = UDim2.fromOffset(0, 82)
desc.Size = UDim2.new(1, 0, 0, 22)
desc.Text = "Save your run instantly."
desc.Font = Enum.Font.Gotham
desc.TextSize = 14
desc.TextColor3 = Color3.fromRGB(190, 190, 205)
desc.TextXAlignment = Enum.TextXAlignment.Left
desc.ZIndex = 5
desc.Parent = card

local bankLabel = Instance.new("TextLabel")
bankLabel.BackgroundTransparency = 1
bankLabel.Position = UDim2.fromOffset(0, 108)
bankLabel.Size = UDim2.new(1, 0, 0, 22)
bankLabel.Text = ""
bankLabel.Font = Enum.Font.GothamBold
bankLabel.TextSize = 14
bankLabel.TextColor3 = Color3.fromRGB(120, 255, 170)
bankLabel.TextXAlignment = Enum.TextXAlignment.Left
bankLabel.ZIndex = 5
bankLabel.Parent = card

local msg = Instance.new("TextLabel")
msg.BackgroundTransparency = 1
msg.Position = UDim2.fromOffset(0, 132)
msg.Size = UDim2.new(1, 0, 0, 18)
msg.Text = ""
msg.Font = Enum.Font.Gotham
msg.TextSize = 12
msg.TextColor3 = Color3.fromRGB(255, 210, 120)
msg.TextXAlignment = Enum.TextXAlignment.Left
msg.ZIndex = 5
msg.Parent = card

local divider = Instance.new("Frame")
divider.Position = UDim2.fromOffset(0, 158)
divider.Size = UDim2.new(1, 0, 0, 2)
divider.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
divider.BackgroundTransparency = 0.55
divider.BorderSizePixel = 0
divider.ZIndex = 5
divider.Parent = card

--====================================================
-- BUTTONS
--====================================================
local function makeCartoonButton(parent, text, fillColor)
	local btn = Instance.new("TextButton")
	btn.AutoButtonColor = true
	btn.BackgroundColor3 = fillColor
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 18
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.ZIndex = 8
	btn.Parent = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 16)
	c.Parent = btn

	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Transparency = 0.15
	s.Color = Color3.fromRGB(0, 0, 0)
	s.Parent = btn

	return btn
end

local function addRobuxBadge(btn)
	local badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 12, 0.5, 0)
	badge.Size = UDim2.fromOffset(38, 28)
	badge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	badge.BorderSizePixel = 0
	badge.ZIndex = btn.ZIndex + 1
	badge.Parent = btn

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 999)
	c.Parent = badge

	local s = Instance.new("UIStroke")
	s.Thickness = 2
	s.Transparency = 0.2
	s.Color = Color3.fromRGB(0, 0, 0)
	s.Parent = badge

	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = "R$"
	t.Font = Enum.Font.FredokaOne
	t.TextSize = 14
	t.TextColor3 = Color3.fromRGB(0, 0, 0)
	t.ZIndex = badge.ZIndex + 1
	t.Parent = badge
end


local useRow = Instance.new("Frame")
useRow.BackgroundTransparency = 1
useRow.Position = UDim2.fromOffset(0, 170)
useRow.Size = UDim2.new(1, 0, 0, 60)
useRow.ZIndex = 6
useRow.Parent = card

local useBtn = makeCartoonButton(useRow, "USE 1 RETURN", Color3.fromRGB(70, 120, 255))
useBtn.AnchorPoint = Vector2.new(0.5, 0.5)
useBtn.Position = UDim2.fromScale(0.5, 0.5)
useBtn.Size = UDim2.new(0.70, 0, 0, 52)


local buyRow = Instance.new("Frame")
buyRow.BackgroundTransparency = 1
buyRow.Position = UDim2.fromOffset(0, 232)
buyRow.Size = UDim2.new(1, 0, 0, 62)
buyRow.ZIndex = 6
buyRow.Parent = card

local buyLayout = Instance.new("UIListLayout")
buyLayout.FillDirection = Enum.FillDirection.Horizontal
buyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buyLayout.VerticalAlignment = Enum.VerticalAlignment.Center
buyLayout.Padding = UDim.new(0, 14)
buyLayout.Parent = buyRow

local buy1Btn = makeCartoonButton(buyRow, "BUY 1  (10)", Color3.fromRGB(55, 200, 95))
buy1Btn.Size = UDim2.fromOffset(210, 54)
addRobuxBadge(buy1Btn)

local buy3Btn = makeCartoonButton(buyRow, "BUY 3  (25)", Color3.fromRGB(40, 180, 85))
buy3Btn.Size = UDim2.fromOffset(210, 54)
addRobuxBadge(buy3Btn)

-- Pulse scale for Buy 3
local buy3Scale = Instance.new("UIScale")
buy3Scale.Scale = 1
buy3Scale.Parent = buy3Btn

-- BEST VALUE tag 
local tag = Instance.new("Frame")
tag.AnchorPoint = Vector2.new(0.5, 0)
tag.Position = UDim2.new(1, -9, 0, -14)
tag.Size = UDim2.fromOffset(120, 30)
tag.BackgroundColor3 = Color3.fromRGB(255, 220, 70)
tag.BorderSizePixel = 0
tag.Rotation = -10
tag.ZIndex = buy3Btn.ZIndex + 2
tag.Parent = buy3Btn

local tagC = Instance.new("UICorner")
tagC.CornerRadius = UDim.new(0, 10)
tagC.Parent = tag

local tagS = Instance.new("UIStroke")
tagS.Thickness = 2
tagS.Transparency = 0.15
tagS.Color = Color3.fromRGB(0, 0, 0)
tagS.Parent = tag

local tagText = Instance.new("TextLabel")
tagText.BackgroundTransparency = 1
tagText.Size = UDim2.fromScale(1, 1)
tagText.Text = "BEST VALUE"
tagText.Font = Enum.Font.FredokaOne
tagText.TextSize = 14
tagText.TextColor3 = Color3.fromRGB(0, 0, 0)
tagText.ZIndex = tag.ZIndex + 1
tagText.Parent = tag

--====================================================
-- ANIMS
--====================================================
local active = false
local timerActive = false
local labelPulseLock = false
local buy3PulseLock = false

local function pulseTimerLabel()
	if labelPulseLock then return end
	labelPulseLock = true

	local t1 = TweenService:Create(timerLabel, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0.25})
	local t2 = TweenService:Create(timerLabel, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})

	t1:Play()
	t1.Completed:Once(function()
		if not timerActive then labelPulseLock = false return end
		t2:Play()
		t2.Completed:Once(function()
			labelPulseLock = false
		end)
	end)
end

local function pulseBuy3()
	if buy3PulseLock then return end
	buy3PulseLock = true

	buy3Scale.Scale = 1
	local up = TweenService:Create(buy3Scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.06})
	local down = TweenService:Create(buy3Scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1})

	up:Play()
	up.Completed:Once(function()
		if not timerActive then buy3PulseLock = false return end
		down:Play()
		down.Completed:Once(function()
			buy3PulseLock = false
		end)
	end)
end

local function wiggleBestValue()
	local baseRot = -10
	local basePos = tag.Position

	local a = TweenService:Create(tag, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = baseRot - 12,
		Position = basePos + UDim2.fromOffset(0, -2)
	})
	local b = TweenService:Create(tag, TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = baseRot + 6,
		Position = basePos + UDim2.fromOffset(0, 1)
	})
	local c = TweenService:Create(tag, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = baseRot - 4,
		Position = basePos
	})
	local d = TweenService:Create(tag, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Rotation = baseRot,
		Position = basePos
	})

	a:Play()
	a.Completed:Once(function()
		b:Play()
		b.Completed:Once(function()
			c:Play()
			c.Completed:Once(function()
				d:Play()
			end)
		end)
	end)
end

local function popIn()
	cardScale.Scale = 0.75
	local tweenIn = TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1})
	tweenIn:Play()
end

local function stopTimer()
	timerActive = false
end

local function hideInstant()
	stopTimer()
	card.Visible = false
	overlay.Visible = false
	cardScale.Scale = 1
	timerLabel.Text = ""
	timerLabel.TextTransparency = 0
	timerLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
	msg.Text = ""
	buy3Scale.Scale = 1
	tag.Rotation = -10
	active = false
end

local function closeWithShrink()
	stopTimer()
	cardScale.Scale = 0.9
	local tweenOut = TweenService:Create(cardScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0})
	tweenOut:Play()
	tweenOut.Completed:Once(function()
		hideInstant()
	end)
end

local function setReturnsUI(count)
	count = count or 0
	if count > 0 then
		bankLabel.Text = ("Banked returns: %d"):format(count)
		useBtn.Visible = true
	else
		bankLabel.Text = "No banked returns."
		useBtn.Visible = false
	end
end

local function startTimer(seconds)
	timerActive = true
	local n = seconds or DEFAULT_TIMER

	-- Jiggle every 15 seconds while UI is open
	task.spawn(function()
		while timerActive and card.Visible do
			task.wait(15)
			if timerActive and card.Visible then
				wiggleBestValue()
			end
		end
	end)

	for i = n, 0, -1 do
		if not timerActive then return end

		timerLabel.Text = ("⏱ Offer closes in %ds"):format(i)

		if i <= RED_AT then
			timerLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
			pulseTimerLabel()
			pulseBuy3()
		else
			timerLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
			timerLabel.TextTransparency = 0
		end

		if i == 1 then
			closeWithShrink()
			return
		end

		task.wait(1)
	end

	hideInstant()
end

local function showOffer(payload)
	if active then
		setReturnsUI(payload and payload.returns or 0)
		return
	end

	active = true
	card.Visible = true
	overlay.Visible = true
	msg.Text = ""

	setReturnsUI(payload and payload.returns or 0)

	popIn()

	local seconds = (payload and payload.timerSeconds) or DEFAULT_TIMER
	task.spawn(function()
		startTimer(seconds)
	end)
end

--====================================================
-- BUTTON EVENTS
--====================================================
closeBtn.MouseButton1Click:Connect(hideInstant)

useBtn.MouseButton1Click:Connect(function()
	hideInstant()
	UseReturn:FireServer()
end)

buy1Btn.MouseButton1Click:Connect(function()
	hideInstant()
	RequestPurchase1:FireServer()
end)

buy3Btn.MouseButton1Click:Connect(function()
	hideInstant()
	RequestPurchase3:FireServer()
end)

--====================================================
-- REMOTES
--====================================================
OfferReturn.OnClientEvent:Connect(function(payload)
	showOffer(payload)
end)

ServerMessage.OnClientEvent:Connect(function(text)
	msg.Text = tostring(text or "")
	task.delay(2, function()
		if card.Visible then
			hideInstant()
		end
	end)
end)
