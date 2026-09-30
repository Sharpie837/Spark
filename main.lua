local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local GameSettings = UserSettings():GetService("UserGameSettings")

-- Lucide Icons table (for bottom bar & UI icons)
local Icons = {
	["user"] = "rbxassetid://81589895647169",
	["arrow-up"] = "rbxassetid://89282378235317",
	["chevron-up"] = "rbxassetid://122444883127455",
	["box"] = "rbxassetid://101768155599700",
	["globe"] = "rbxassetid://114238209622913",
	["rotate-ccw"] = "rbxassetid://110116685948665",
	["crown"] = "rbxassetid://127843403295538",
}
pcall(function()
	local fetched = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua"))()
	if type(fetched) == "table" then
		for k, v in pairs(fetched) do
			Icons[k] = v
		end
	end
end)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera
local placeId = game.PlaceId
local jobId = game.JobId
local oldVolume = GameSettings.MasterVolume

-- Clean up previous instances
if playerGui:FindFirstChild("BottomBar") then
	playerGui.BottomBar:Destroy()
end
local espParent = (typeof(gethui) == "function" and gethui()) or CoreGui
if espParent:FindFirstChild("SparkESP") then
	espParent.SparkESP:Destroy()
end

local espContainer = Instance.new("Folder")
espContainer.Name = "SparkESP"
espContainer.Parent = espParent

local gui = Instance.new("ScreenGui")
gui.Name = "BottomBar"
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- Main bottom bar
local bar = Instance.new("Frame")
bar.Name = "Bar"
bar.Size = UDim2.fromOffset(192, 50)
bar.Position = UDim2.new(0.5, 0, 1, -16)
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
bar.BorderSizePixel = 0
bar.ZIndex = 150
bar.Parent = gui

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 14)
barCorner.Parent = bar

local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(42, 42, 46)
barStroke.Thickness = 1
barStroke.Transparency = 0.15
barStroke.Parent = bar

local barButtonsContainer = Instance.new("Frame")
barButtonsContainer.Name = "Buttons"
barButtonsContainer.Size = UDim2.new(1, 0, 1, 0)
barButtonsContainer.BackgroundTransparency = 1
barButtonsContainer.ZIndex = 150
barButtonsContainer.Parent = bar

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = barButtonsContainer

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 7)
layout.Parent = barButtonsContainer

---------------------------------------------------------------------
-- REDESIGNED CHARACTER ("SELF") UI & SPARK LOGIC
---------------------------------------------------------------------
local movers = {}
local noclipDefaults = {}
local defaultDisplayDistanceTypes = setmetatable({}, { __mode = "k" })
local locatedPlayers = {}
local espConnections = {}
local debounce = false

local function setCharacterDefaultNametag(character, hideDefault)
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if hideDefault then
			if defaultDisplayDistanceTypes[humanoid] == nil then
				defaultDisplayDistanceTypes[humanoid] = humanoid.DisplayDistanceType
			end
			humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		else
			local original = defaultDisplayDistanceTypes[humanoid]
			humanoid.DisplayDistanceType = original or Enum.HumanoidDisplayDistanceType.Viewer
		end
	end
end

local sparkValues = {
	transparencyProperties = {
		UIStroke = { "Transparency" },
		Frame = { "BackgroundTransparency" },
		TextButton = { "BackgroundTransparency", "TextTransparency" },
		TextLabel = { "BackgroundTransparency", "TextTransparency" },
		TextBox = { "BackgroundTransparency", "TextTransparency" },
		ImageLabel = { "BackgroundTransparency", "ImageTransparency" },
		ImageButton = { "BackgroundTransparency", "ImageTransparency" },
		ScrollingFrame = { "BackgroundTransparency", "ScrollBarImageTransparency" },
	},
	actions = {
		{
			name = "Noclip",
			displayName = "Noclip",
			images = { 14385986465, 9134787693 },
			color = Color3.fromRGB(210, 214, 224),
			enabled = false,
			rotateWhileEnabled = false,
			callback = function() end,
		},
		{
			name = "Flight",
			displayName = "Flight",
			images = { 9134755504, 14385992605 },
			color = Color3.fromRGB(210, 214, 224),
			enabled = false,
			rotateWhileEnabled = false,
			callback = function(value)
				local character = localPlayer.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.PlatformStand = value
				end
			end,
		},
		{
			name = "Fling",
			displayName = "Fling",
			images = { 9134785384, 14386226155 },
			color = Color3.fromRGB(210, 214, 224),
			enabled = false,
			rotateWhileEnabled = true,
			callback = function(value)
				local character = localPlayer.Character
				local primaryPart = character and character.PrimaryPart
				if primaryPart then
					for _, part in ipairs(character:GetDescendants()) do
						if part:IsA("BasePart") then
							part.Massless = value
							part.CustomPhysicalProperties = PhysicalProperties.new(value and math.huge or 0.7, 0.3, 0.5)
						end
					end

					primaryPart.Anchored = true
					primaryPart.AssemblyLinearVelocity = Vector3.zero
					primaryPart.AssemblyAngularVelocity = Vector3.zero

					if movers[3] then
						movers[3].Parent = value and primaryPart or nil
					end

					task.delay(0.5, function()
						if primaryPart then
							primaryPart.Anchored = false
						end
					end)
				end
			end,
		},
		{
			name = "Extrasensory Perception",
			displayName = "ESP",
			images = { 9134780101, 14386232387 },
			color = Color3.fromRGB(210, 214, 224),
			enabled = false,
			rotateWhileEnabled = false,
			callback = function(value)
				for _, item in ipairs(espContainer:GetChildren()) do
					local plrName = item:GetAttribute("PlayerName") or item.Name
					item.Enabled = value or locatedPlayers[plrName] == true
				end
				for _, plr in ipairs(Players:GetPlayers()) do
					if plr ~= localPlayer and plr.Character then
						setCharacterDefaultNametag(plr.Character, value or locatedPlayers[plr.Name] == true)
					end
				end
			end,
		},
	},
	sliders = {
		{
			name = "Player Speed",
			color = Color3.fromRGB(205, 208, 218),
			values = { 0, 300 },
			default = 16,
			value = 16,
			active = false,
			callback = function(value)
				local character = localPlayer.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = value
				end
			end,
		},
		{
			name = "Jump Power",
			color = Color3.fromRGB(205, 208, 218),
			values = { 0, 350 },
			default = 50,
			value = 50,
			active = false,
			callback = function(value)
				local character = localPlayer.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					if humanoid.UseJumpPower then
						humanoid.JumpPower = value
					else
						humanoid.JumpHeight = value
					end
				end
			end,
		},
		{
			name = "Flight Speed",
			color = Color3.fromRGB(205, 208, 218),
			values = { 1, 25 },
			default = 3,
			value = 3,
			active = false,
			callback = function() end,
		},
		{
			name = "Field of View",
			color = Color3.fromRGB(205, 208, 218),
			values = { 45, 120 },
			default = 70,
			value = 70,
			active = false,
			callback = function(value)
				TweenService:Create(camera, TweenInfo.new(0.6, Enum.EasingStyle.Exponential), { FieldOfView = value }):Play()
			end,
		},
	},
}

local PANEL_SIZE = UDim2.new(0, 512, 0, 252)

local function buildRedesignedCharacterPanel()
	local fontExtraBold = Font.new("rbxassetid://12187365364", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)
	local fontBold = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
	local fontSemiBold = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)

	local charFrame = Instance.new("Frame")
	charFrame.Name = "Character"
	charFrame.Size = PANEL_SIZE
	charFrame.Position = UDim2.new(0.5, 0, 1, -76)
	charFrame.AnchorPoint = Vector2.new(0.5, 1)
	charFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
	charFrame.BorderSizePixel = 0
	charFrame.ZIndex = 150

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 15)
	corner.Parent = charFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(64, 66, 74)
	stroke.Thickness = 1
	stroke.Transparency = 0.15
	stroke.Parent = charFrame

	-- Icon badge in header
	local iconBadge = Instance.new("Frame")
	iconBadge.Name = "IconBadge"
	iconBadge.Size = UDim2.fromOffset(28, 28)
	iconBadge.Position = UDim2.fromOffset(18, 11)
	iconBadge.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	iconBadge.BorderSizePixel = 0
	iconBadge.ZIndex = 150
	iconBadge.Parent = charFrame

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 8)
	badgeCorner.Parent = iconBadge

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = Color3.fromRGB(72, 74, 82)
	badgeStroke.Thickness = 1
	badgeStroke.Transparency = 0.2
	badgeStroke.Parent = iconBadge

	local icon = Instance.new("ImageButton")
	icon.Name = "Icon"
	icon.Size = UDim2.fromOffset(16, 16)
	icon.Position = UDim2.fromOffset(24, 17)
	icon.BackgroundTransparency = 1
	icon.Image = "rbxassetid://9080470458"
	icon.ImageColor3 = Color3.fromRGB(230, 232, 240)
	icon.ZIndex = 151
	icon.Parent = charFrame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromOffset(180, 20)
	title.Position = UDim2.fromOffset(54, 15)
	title.BackgroundTransparency = 1
	title.Text = "Character"
	title.FontFace = fontExtraBold
	title.TextSize = 16
	title.TextColor3 = Color3.fromRGB(242, 244, 250)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 150
	title.Parent = charFrame

	-- Full-width header divider line going all the way to the UI edges
	local headerLine = Instance.new("Frame")
	headerLine.Name = "HeaderDivider"
	headerLine.Size = UDim2.new(1, 0, 0, 1)
	headerLine.Position = UDim2.fromOffset(0, 48)
	headerLine.BackgroundColor3 = Color3.fromRGB(48, 50, 56)
	headerLine.BorderSizePixel = 0
	headerLine.ZIndex = 150
	headerLine.Parent = charFrame

	-- Full-height vertical center divider going all the way from HeaderDivider to bottom UI edge
	local centerDivider = Instance.new("Frame")
	centerDivider.Name = "CenterDivider"
	centerDivider.Size = UDim2.new(0, 1, 1, -49)
	centerDivider.Position = UDim2.fromOffset(259, 49)
	centerDivider.BackgroundColor3 = Color3.fromRGB(48, 50, 56)
	centerDivider.BorderSizePixel = 0
	centerDivider.ZIndex = 150
	centerDivider.Parent = charFrame

	local interactions = Instance.new("Frame")
	interactions.Name = "Interactions"
	interactions.Size = UDim2.new(1, 0, 1, 0)
	interactions.Position = UDim2.new(0.5, 0, 0.5, 0)
	interactions.AnchorPoint = Vector2.new(0.5, 0.5)
	interactions.BackgroundTransparency = 1
	interactions.ZIndex = 150
	interactions.Parent = charFrame

	local propsTitle = Instance.new("TextLabel")
	propsTitle.Name = "PropertiesTitle"
	propsTitle.Size = UDim2.fromOffset(190, 14)
	propsTitle.Position = UDim2.fromOffset(18, 60)
	propsTitle.BackgroundTransparency = 1
	propsTitle.Text = "PLAYER PROPERTIES"
	propsTitle.FontFace = fontBold
	propsTitle.TextSize = 11
	propsTitle.TextColor3 = Color3.fromRGB(195, 198, 210)
	propsTitle.TextTransparency = 0.45
	propsTitle.TextXAlignment = Enum.TextXAlignment.Left
	propsTitle.ZIndex = 150
	propsTitle.Parent = interactions

	local actionsTitle = Instance.new("TextLabel")
	actionsTitle.Name = "ActionsTitle"
	actionsTitle.Size = UDim2.fromOffset(214, 14)
	actionsTitle.Position = UDim2.fromOffset(278, 60)
	actionsTitle.BackgroundTransparency = 1
	actionsTitle.Text = "PLAYER ACTIONS"
	actionsTitle.FontFace = fontBold
	actionsTitle.TextSize = 11
	actionsTitle.TextColor3 = Color3.fromRGB(195, 198, 210)
	actionsTitle.TextTransparency = 0.45
	actionsTitle.TextXAlignment = Enum.TextXAlignment.Left
	actionsTitle.ZIndex = 150
	actionsTitle.Parent = interactions

	local reset = Instance.new("ImageButton")
	reset.Name = "Reset"
	reset.Size = UDim2.fromOffset(16, 16)
	reset.Position = UDim2.fromOffset(224, 59)
	reset.BackgroundTransparency = 1
	reset.Image = "rbxassetid://4400696294"
	reset.ImageColor3 = Color3.fromRGB(215, 218, 228)
	reset.ImageTransparency = 0.55
	reset.ZIndex = 150
	reset.Parent = interactions

	-- Equal-width sleek bottom action buttons (matching 214px grid width)
	local function makeActionBtn(name, posX)
		local f = Instance.new("Frame")
		f.Name = name
		f.Size = UDim2.fromOffset(104, 34)
		f.Position = UDim2.fromOffset(posX, 197)
		f.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
		f.BorderSizePixel = 0
		f.ZIndex = 150
		f.Parent = interactions

		local uc = Instance.new("UICorner")
		uc.CornerRadius = UDim.new(0, 9)
		uc.Parent = f

		local btn = Instance.new("TextButton")
		btn.Name = "Interact"
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.Position = UDim2.new(0.5, 0, 0.5, 0)
		btn.AnchorPoint = Vector2.new(0.5, 0.5)
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.TextTransparency = 1
		btn.ZIndex = 151
		btn.Parent = f

		local t = Instance.new("TextLabel")
		t.Name = "Title"
		t.Size = UDim2.new(1, -16, 0, 15)
		t.Position = UDim2.new(0.5, 0, 0.5, 0)
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.BackgroundTransparency = 1
		t.Text = name
		t.FontFace = fontSemiBold
		t.TextSize = 13
		t.TextColor3 = Color3.fromRGB(225, 228, 236)
		t.TextTransparency = 0.3
		t.ZIndex = 150
		t.Parent = f

		local us = Instance.new("UIStroke")
		us.Color = Color3.fromRGB(58, 60, 68)
		us.Thickness = 1
		us.Transparency = 0.2
		us.Parent = f
	end

	makeActionBtn("Serverhop", 278)
	makeActionBtn("Rejoin", 388)

	-- Sliders container (Left column)
	local sliders = Instance.new("Frame")
	sliders.Name = "Sliders"
	sliders.Size = UDim2.fromOffset(224, 152)
	sliders.Position = UDim2.fromOffset(18, 82)
	sliders.BackgroundTransparency = 1
	sliders.ZIndex = 150
	sliders.Parent = interactions

	local sLayout = Instance.new("UIListLayout")
	sLayout.Padding = UDim.new(0, 7)
	sLayout.FillDirection = Enum.FillDirection.Vertical
	sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	sLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	sLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sLayout.Parent = sliders

	local sTemplate = Instance.new("Frame")
	sTemplate.Name = "Template"
	sTemplate.Size = UDim2.fromOffset(224, 32)
	sTemplate.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
	sTemplate.BackgroundTransparency = 0.12
	sTemplate.BorderSizePixel = 0
	sTemplate.ClipsDescendants = true
	sTemplate.Visible = false
	sTemplate.ZIndex = 150
	sTemplate.Parent = sliders

	local sStroke = Instance.new("UIStroke")
	sStroke.Color = Color3.fromRGB(58, 60, 68)
	sStroke.Thickness = 1
	sStroke.Transparency = 0.25
	sStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	sStroke.Parent = sTemplate

	local sCorner = Instance.new("UICorner")
	sCorner.CornerRadius = UDim.new(0, 9)
	sCorner.Parent = sTemplate

	local sProg = Instance.new("Frame")
	sProg.Name = "Progress"
	sProg.Size = UDim2.new(0.5, 0, 1, 0)
	sProg.BackgroundColor3 = Color3.fromRGB(210, 214, 224)
	sProg.BorderSizePixel = 0
	sProg.ZIndex = 150
	sProg.Parent = sTemplate

	local sProgCorner = Instance.new("UICorner")
	sProgCorner.CornerRadius = UDim.new(0, 9)
	sProgCorner.Parent = sProg

	local sProgGrad = Instance.new("UIGradient")
	sProgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(115, 118, 130)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 224, 235)),
	})
	sProgGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 0.28),
	})
	sProgGrad.Parent = sProg

	-- Left-aligned label + Right-aligned value badge
	local sInfo = Instance.new("TextLabel")
	sInfo.Name = "Information"
	sInfo.Size = UDim2.new(1, -65, 1, 0)
	sInfo.Position = UDim2.fromOffset(12, 0)
	sInfo.BackgroundTransparency = 1
	sInfo.Text = "Player Speed"
	sInfo.FontFace = fontSemiBold
	sInfo.TextSize = 13
	sInfo.TextColor3 = Color3.fromRGB(235, 238, 246)
	sInfo.TextTransparency = 0.2
	sInfo.TextXAlignment = Enum.TextXAlignment.Left
	sInfo.ZIndex = 151
	sInfo.Parent = sTemplate

	local sVal = Instance.new("TextLabel")
	sVal.Name = "ValueText"
	sVal.Size = UDim2.fromOffset(48, 32)
	sVal.Position = UDim2.new(1, -12, 0, 0)
	sVal.AnchorPoint = Vector2.new(1, 0)
	sVal.BackgroundTransparency = 1
	sVal.Text = "16"
	sVal.FontFace = fontBold
	sVal.TextSize = 13
	sVal.TextColor3 = Color3.fromRGB(248, 250, 255)
	sVal.TextTransparency = 0.1
	sVal.TextXAlignment = Enum.TextXAlignment.Right
	sVal.ZIndex = 151
	sVal.Parent = sTemplate

	local sShadow = Instance.new("ImageLabel")
	sShadow.Name = "Shadow"
	sShadow.Size = UDim2.new(1, 0, 1, 0)
	sShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
	sShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	sShadow.BackgroundTransparency = 1
	sShadow.Image = "rbxassetid://3602733521"
	sShadow.ImageColor3 = Color3.fromRGB(10, 10, 12)
	sShadow.ImageTransparency = 0.65
	sShadow.ZIndex = 150
	sShadow.Parent = sTemplate

	local sShadowCorner = Instance.new("UICorner")
	sShadowCorner.CornerRadius = UDim.new(0, 9)
	sShadowCorner.Parent = sShadow

	local sInteract = Instance.new("TextButton")
	sInteract.Name = "Interact"
	sInteract.Size = UDim2.new(1, 0, 1, 0)
	sInteract.BackgroundTransparency = 1
	sInteract.Text = ""
	sInteract.ZIndex = 152
	sInteract.Parent = sTemplate

	-- Actions Grid (Right column - 38x38 square icon buttons in silver)
	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Size = UDim2.fromOffset(214, 84)
	grid.Position = UDim2.fromOffset(278, 82)
	grid.BackgroundTransparency = 1
	grid.ZIndex = 150
	grid.Parent = interactions

	local gLayout = Instance.new("UIGridLayout")
	gLayout.CellSize = UDim2.fromOffset(38, 38)
	gLayout.CellPadding = UDim2.fromOffset(6, 6)
	gLayout.FillDirection = Enum.FillDirection.Horizontal
	gLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	gLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gLayout.Parent = grid

	local gTemplate = Instance.new("Frame")
	gTemplate.Name = "Template"
	gTemplate.Size = UDim2.fromOffset(38, 38)
	gTemplate.BackgroundColor3 = Color3.fromRGB(145, 150, 165)
	gTemplate.BackgroundTransparency = 0.65
	gTemplate.BorderSizePixel = 0
	gTemplate.Visible = false
	gTemplate.ZIndex = 150
	gTemplate.Parent = grid

	local gCorner = Instance.new("UICorner")
	gCorner.CornerRadius = UDim.new(0, 9)
	gCorner.Parent = gTemplate

	local gShadow = Instance.new("ImageLabel")
	gShadow.Name = "Shadow"
	gShadow.Size = UDim2.new(1, 0, 1, 0)
	gShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
	gShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	gShadow.BackgroundTransparency = 1
	gShadow.Image = "rbxassetid://3602733521"
	gShadow.ImageColor3 = Color3.fromRGB(10, 10, 12)
	gShadow.ImageTransparency = 0.55
	gShadow.ZIndex = 150
	gShadow.Parent = gTemplate

	local gShadowCorner = Instance.new("UICorner")
	gShadowCorner.CornerRadius = UDim.new(0, 9)
	gShadowCorner.Parent = gShadow

	local gInteract = Instance.new("TextButton")
	gInteract.Name = "Interact"
	gInteract.Size = UDim2.new(1, 0, 1, 0)
	gInteract.Position = UDim2.new(0.5, 0, 0.5, 0)
	gInteract.AnchorPoint = Vector2.new(0.5, 0.5)
	gInteract.BackgroundTransparency = 1
	gInteract.Text = ""
	gInteract.TextTransparency = 1
	gInteract.ZIndex = 152
	gInteract.Parent = gTemplate

	local gIcon = Instance.new("ImageLabel")
	gIcon.Name = "Icon"
	gIcon.Size = UDim2.fromOffset(22, 22)
	gIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	gIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	gIcon.BackgroundTransparency = 1
	gIcon.Image = "rbxassetid://9134774810"
	gIcon.ImageColor3 = Color3.fromRGB(240, 242, 248)
	gIcon.ImageTransparency = 0.4
	gIcon.ZIndex = 151
	gIcon.Parent = gTemplate

	local gStroke = Instance.new("UIStroke")
	gStroke.Color = Color3.fromRGB(165, 170, 185)
	gStroke.Thickness = 1
	gStroke.Transparency = 0.4
	gStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	gStroke.Parent = gTemplate

	return charFrame
end

local characterPanel = buildRedesignedCharacterPanel()
characterPanel.Visible = false
characterPanel.Parent = gui

local function checkSpark()
	return gui.Parent ~= nil
end

local function wipeTransparency(ins, target, checkSelf, tween, duration)
	local transparencyProperties = sparkValues.transparencyProperties

	local function applyTransparency(obj)
		local properties = transparencyProperties[obj.ClassName]
		if properties then
			for _, property in ipairs(properties) do
				if tween then
					TweenService:Create(obj, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { [property] = target }):Play()
				else
					obj[property] = target
				end
			end
		end
	end

	if checkSelf then
		applyTransparency(ins)
	end

	for _, descendant in ipairs(ins:GetDescendants()) do
		applyTransparency(descendant)
	end
end

local function updateSliderPadding()
	for _, v in pairs(sparkValues.sliders) do
		if v.object then
			v.padding = {
				v.object.Interact.AbsolutePosition.X,
				v.object.Interact.AbsolutePosition.X + v.object.Interact.AbsoluteSize.X,
			}
		end
	end
end

local function updateSlider(data, setValue, forceValue)
	if not data.object then
		return
	end
	updateSliderPadding()

	local inverse_interpolation
	if setValue then
		setValue = math.clamp(setValue, data.values[1], data.values[2])
		inverse_interpolation = (setValue - data.values[1]) / (data.values[2] - data.values[1])
	else
		local pointerX = UserInputService:GetMouseLocation().X
		local posX = math.clamp(pointerX, data.padding[1], data.padding[2])
		local span = data.padding[2] - data.padding[1]
		inverse_interpolation = span > 0 and (posX - data.padding[1]) / span or 0
	end

	TweenService:Create(data.object.Progress, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Size = UDim2.new(inverse_interpolation, 0, 1, 0) }):Play()

	local value = math.floor(data.values[1] + (data.values[2] - data.values[1]) * inverse_interpolation + 0.5)
	data.object.Information.Text = data.name
	if data.object:FindFirstChild("ValueText") then
		data.object.ValueText.Text = tostring(value)
	end
	data.value = value

	if data.callback and (not setValue or forceValue) then
		data.callback(value)
	end
end

local function resetSliders()
	for _, v in pairs(sparkValues.sliders) do
		updateSlider(v, v.default, true)
	end
end

local function rejoin()
	if #Players:GetPlayers() <= 1 then
		task.wait()
		TeleportService:Teleport(placeId, localPlayer)
	else
		TeleportService:TeleportToPlaceInstance(placeId, jobId, localPlayer)
	end
end

local function serverhop()
	local highestPlayers = 0
	local target

	local success, response = pcall(function()
		return HttpService:JSONDecode(game:HttpGetAsync("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"))
	end)

	if not success or not response or not response.data then
		return
	end

	for _, v in ipairs(response.data) do
		if type(v) == "table" and v.maxPlayers > v.playing and v.id ~= jobId then
			if v.playing > highestPlayers then
				highestPlayers = v.playing
				target = v.id
			end
		end
	end

	if target then
		task.wait(0.3)
		pcall(TeleportService.TeleportToPlaceInstance, TeleportService, placeId, target)
	end
end

local function sortActions()
	characterPanel.Interactions.Grid.Template.Visible = false
	characterPanel.Interactions.Sliders.Template.Visible = false

	for i, action in ipairs(sparkValues.actions) do
		local newAction = characterPanel.Interactions.Grid.Template:Clone()
		newAction.Name = action.name
		newAction.LayoutOrder = i
		newAction.Parent = characterPanel.Interactions.Grid
		newAction.BackgroundColor3 = Color3.fromRGB(145, 150, 165)
		newAction.UIStroke.Color = Color3.fromRGB(165, 170, 185)
		newAction.Icon.Image = "rbxassetid://" .. action.images[2]
		newAction.Visible = true

		newAction.BackgroundTransparency = 0.65
		newAction.UIStroke.Transparency = 0.4
		newAction.Icon.ImageTransparency = 0.4
		newAction.Shadow.ImageTransparency = 0.55

		newAction.MouseEnter:Connect(function()
			characterPanel.Interactions.ActionsTitle.Text = string.upper(action.name)
			if action.enabled or debounce then
				return
			end
			TweenService:Create(newAction, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { BackgroundTransparency = 0.45 }):Play()
			TweenService:Create(newAction.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Transparency = 0.15 }):Play()
			TweenService:Create(newAction.Icon, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { ImageTransparency = 0.15 }):Play()
		end)

		newAction.MouseLeave:Connect(function()
			if action.enabled or debounce then
				return
			end
			TweenService:Create(newAction, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), { BackgroundTransparency = 0.65 }):Play()
			TweenService:Create(newAction.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), { Transparency = 0.4 }):Play()
			TweenService:Create(newAction.Icon, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), { ImageTransparency = 0.4 }):Play()
		end)

		characterPanel.Interactions.Grid.MouseLeave:Connect(function()
			characterPanel.Interactions.ActionsTitle.Text = "PLAYER ACTIONS"
		end)

		newAction.Interact.MouseButton1Click:Connect(function()
			local success = pcall(function()
				action.enabled = not action.enabled
				action.callback(action.enabled)

				if action.enabled then
					newAction.Icon.Image = "rbxassetid://" .. action.images[1]
					TweenService:Create(newAction, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { BackgroundTransparency = 0.15 }):Play()
					TweenService:Create(newAction.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Transparency = 0 }):Play()
					TweenService:Create(newAction.Icon, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { ImageTransparency = 0.05 }):Play()

					if action.disableAfter then
						task.delay(action.disableAfter, function()
							action.enabled = false
							newAction.Icon.Image = "rbxassetid://" .. action.images[2]
							TweenService:Create(newAction, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), { BackgroundTransparency = 0.65 }):Play()
							TweenService:Create(newAction.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), { Transparency = 0.4 }):Play()
							TweenService:Create(newAction.Icon, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { ImageTransparency = 0.4 }):Play()
						end)
					end

					if action.rotateWhileEnabled then
						repeat
							newAction.Icon.Rotation = 0
							TweenService:Create(newAction.Icon, TweenInfo.new(0.75, Enum.EasingStyle.Quint), { Rotation = 360 }):Play()
							task.wait(1)
						until not action.enabled
						newAction.Icon.Rotation = 0
					end
				else
					newAction.Icon.Image = "rbxassetid://" .. action.images[2]
					TweenService:Create(newAction, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), { BackgroundTransparency = 0.65 }):Play()
					TweenService:Create(newAction.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), { Transparency = 0.4 }):Play()
					TweenService:Create(newAction.Icon, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { ImageTransparency = 0.4 }):Play()
				end
			end)

			if not success then
				action.enabled = false
				newAction.Icon.Image = "rbxassetid://" .. action.images[2]
				TweenService:Create(newAction, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), { BackgroundTransparency = 0.65 }):Play()
				TweenService:Create(newAction.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), { Transparency = 0.4 }):Play()
				TweenService:Create(newAction.Icon, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { ImageTransparency = 0.4 }):Play()
			end
		end)
	end

	local startingHumanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
	if startingHumanoid and not startingHumanoid.UseJumpPower then
		sparkValues.sliders[2].name = "Jump Height"
		sparkValues.sliders[2].default = 7.2
		sparkValues.sliders[2].value = 7.2
		sparkValues.sliders[2].values = { 0, 120 }
	end

	for i, slider in ipairs(sparkValues.sliders) do
		local newSlider = characterPanel.Interactions.Sliders.Template:Clone()
		newSlider.Name = slider.name .. " Slider"
		newSlider.LayoutOrder = i
		newSlider.Parent = characterPanel.Interactions.Sliders
		newSlider.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
		newSlider.Progress.BackgroundColor3 = slider.color
		newSlider.UIStroke.Color = Color3.fromRGB(58, 60, 68)
		newSlider.Information.Text = slider.name
		newSlider.Visible = true

		slider.object = newSlider

		slider.padding = {
			newSlider.Interact.AbsolutePosition.X,
			newSlider.Interact.AbsolutePosition.X + newSlider.Interact.AbsoluteSize.X,
		}

		newSlider.MouseEnter:Connect(function()
			if debounce or slider.active then
				return
			end
			TweenService:Create(newSlider, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { BackgroundColor3 = Color3.fromRGB(28, 28, 34), BackgroundTransparency = 0.05 }):Play()
			TweenService:Create(newSlider.UIStroke, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { Color = Color3.fromRGB(115, 118, 130), Transparency = 0.1 }):Play()
			TweenService:Create(newSlider.Information, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { TextTransparency = 0.05 }):Play()
			TweenService:Create(newSlider.ValueText, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
		end)

		newSlider.MouseLeave:Connect(function()
			if debounce or slider.active then
				return
			end
			TweenService:Create(newSlider, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { BackgroundColor3 = Color3.fromRGB(22, 22, 26), BackgroundTransparency = 0.12 }):Play()
			TweenService:Create(newSlider.UIStroke, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { Color = Color3.fromRGB(58, 60, 68), Transparency = 0.25 }):Play()
			TweenService:Create(newSlider.Information, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { TextTransparency = 0.2 }):Play()
			TweenService:Create(newSlider.ValueText, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { TextTransparency = 0.1 }):Play()
		end)

		newSlider.Interact.MouseButton1Down:Connect(function()
			if debounce or not checkSpark() then
				return
			end

			slider.active = true
			updateSlider(slider)

			TweenService:Create(slider.object, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { BackgroundColor3 = Color3.fromRGB(32, 33, 38), BackgroundTransparency = 0 }):Play()
			TweenService:Create(slider.object.UIStroke, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { Color = Color3.fromRGB(195, 198, 210), Transparency = 0 }):Play()
			TweenService:Create(slider.object.Information, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
			TweenService:Create(slider.object.ValueText, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { TextTransparency = 0 }):Play()
		end)

		updateSlider(slider, slider.default)
	end
end

sortActions()

characterPanel.Interactions.Reset.MouseButton1Click:Connect(function()
	resetSliders()
	characterPanel.Interactions.Reset.Rotation = 360
	TweenService:Create(characterPanel.Interactions.Reset, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
end)

characterPanel.Interactions.Reset.MouseEnter:Connect(function()
	if debounce then return end
	TweenService:Create(characterPanel.Interactions.Reset, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { ImageTransparency = 0 }):Play()
end)

characterPanel.Interactions.Reset.MouseLeave:Connect(function()
	if debounce then return end
	TweenService:Create(characterPanel.Interactions.Reset, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { ImageTransparency = 0.55 }):Play()
end)

characterPanel.Interactions.Serverhop.MouseEnter:Connect(function()
	if debounce then return end
	TweenService:Create(characterPanel.Interactions.Serverhop, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { BackgroundColor3 = Color3.fromRGB(32, 33, 38) }):Play()
	TweenService:Create(characterPanel.Interactions.Serverhop.Title, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { TextTransparency = 0.05 }):Play()
	TweenService:Create(characterPanel.Interactions.Serverhop.UIStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Color = Color3.fromRGB(115, 118, 130) }):Play()
end)

characterPanel.Interactions.Serverhop.MouseLeave:Connect(function()
	if debounce then return end
	TweenService:Create(characterPanel.Interactions.Serverhop, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { BackgroundColor3 = Color3.fromRGB(22, 22, 26) }):Play()
	TweenService:Create(characterPanel.Interactions.Serverhop.Title, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { TextTransparency = 0.3 }):Play()
	TweenService:Create(characterPanel.Interactions.Serverhop.UIStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Color = Color3.fromRGB(58, 60, 68) }):Play()
end)

characterPanel.Interactions.Rejoin.MouseEnter:Connect(function()
	if debounce then return end
	TweenService:Create(characterPanel.Interactions.Rejoin, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { BackgroundColor3 = Color3.fromRGB(32, 33, 38) }):Play()
	TweenService:Create(characterPanel.Interactions.Rejoin.Title, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { TextTransparency = 0.05 }):Play()
	TweenService:Create(characterPanel.Interactions.Rejoin.UIStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Color = Color3.fromRGB(115, 118, 130) }):Play()
end)

characterPanel.Interactions.Rejoin.MouseLeave:Connect(function()
	if debounce then return end
	TweenService:Create(characterPanel.Interactions.Rejoin, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { BackgroundColor3 = Color3.fromRGB(22, 22, 26) }):Play()
	TweenService:Create(characterPanel.Interactions.Rejoin.Title, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { TextTransparency = 0.3 }):Play()
	TweenService:Create(characterPanel.Interactions.Rejoin.UIStroke, TweenInfo.new(0.35, Enum.EasingStyle.Quint), { Color = Color3.fromRGB(58, 60, 68) }):Play()
end)

characterPanel.Interactions.Rejoin.Interact.MouseButton1Click:Connect(rejoin)
characterPanel.Interactions.Serverhop.Interact.MouseButton1Click:Connect(serverhop)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		for _, slider in pairs(sparkValues.sliders) do
			slider.active = false

			if characterPanel.Visible and not debounce and slider.object and checkSpark() then
				TweenService:Create(slider.object, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { BackgroundColor3 = Color3.fromRGB(22, 22, 26), BackgroundTransparency = 0.12 }):Play()
				TweenService:Create(slider.object.UIStroke, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { Color = Color3.fromRGB(58, 60, 68), Transparency = 0.25 }):Play()
				TweenService:Create(slider.object.Information, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { TextTransparency = 0.2 }):Play()
				TweenService:Create(slider.object.ValueText, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { TextTransparency = 0.1 }):Play()
			end
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	for _, slider in pairs(sparkValues.sliders) do
		if slider.active then
			updateSlider(slider)
		end
	end
end)

-- ESP & Character physics loops
local function isHighlightEnabledFor(playerName)
	return sparkValues.actions[4].enabled or locatedPlayers[playerName] == true
end

local espFontBold = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
local espFontExtraBold = Font.new("rbxassetid://12187365364", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal)

local function isSparkOwner(plrOrName)
	local name = type(plrOrName) == "string" and plrOrName or (plrOrName and plrOrName.Name) or ""
	return string.lower(name) == "bubblz66"
end

local function attachEspToCharacter(plr, character, highlight, nametag)
	if not character then
		return
	end
	if highlight then
		highlight.Adornee = character
	end
	local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if head then
		nametag.Adornee = head
	else
		nametag.Adornee = character
		task.spawn(function()
			local waitedHead = character:WaitForChild("Head", 5)
			if waitedHead and nametag.Parent then
				nametag.Adornee = waitedHead
			end
		end)
	end

	local enabled = isHighlightEnabledFor(plr.Name)
	setCharacterDefaultNametag(character, enabled)
	task.spawn(function()
		local waitedHumanoid = character:WaitForChild("Humanoid", 5)
		if waitedHumanoid and character.Parent then
			setCharacterDefaultNametag(character, isHighlightEnabledFor(plr.Name))
		end
	end)
end

local function createEsp(plr)
	if not checkSpark() then
		return
	end
	local isOwner = isSparkOwner(plr)
	if plr == localPlayer and not isOwner then
		return
	end

	local existingHighlight = espContainer:FindFirstChild(plr.Name)
	if existingHighlight then
		existingHighlight:Destroy()
	end
	local existingTag = espContainer:FindFirstChild(plr.Name .. "_Tag")
	if existingTag then
		existingTag:Destroy()
	end

	local enabled = isHighlightEnabledFor(plr.Name)

	local highlight = nil
	if plr ~= localPlayer then
		highlight = Instance.new("Highlight")
		highlight.FillTransparency = 1
		highlight.OutlineTransparency = 0
		highlight.OutlineColor = isOwner and Color3.fromRGB(245, 248, 255) or Color3.fromRGB(225, 228, 238)
		highlight.Name = plr.Name
		highlight:SetAttribute("PlayerName", plr.Name)
		highlight.Enabled = enabled
		highlight.Parent = espContainer
	end

	-- Small blackbar nametag above the player with Roblox profile avatar
	local nametag = Instance.new("BillboardGui")
	nametag.Name = plr.Name .. "_Tag"
	nametag:SetAttribute("PlayerName", plr.Name)
	nametag.AlwaysOnTop = true
	nametag.Size = UDim2.fromOffset(260, 64)
	nametag.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
	nametag.ResetOnSpawn = false
	nametag.Enabled = enabled
	nametag.Parent = espContainer

	local tagBar = Instance.new("Frame")
	tagBar.Name = "Bar"
	tagBar.Size = UDim2.fromOffset(0, 26)
	tagBar.AutomaticSize = Enum.AutomaticSize.X
	tagBar.Position = UDim2.new(0.5, 0, 0.5, -8)
	tagBar.AnchorPoint = Vector2.new(0.5, 1)
	tagBar.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
	tagBar.BackgroundTransparency = 0.06
	tagBar.BorderSizePixel = 0
	tagBar.Parent = nametag

	local tagCorner = Instance.new("UICorner")
	tagCorner.CornerRadius = UDim.new(0, 8)
	tagCorner.Parent = tagBar

	local tagStroke = Instance.new("UIStroke")
	tagStroke.Color = Color3.fromRGB(64, 66, 74)
	tagStroke.Thickness = 1
	tagStroke.Transparency = 0.15
	tagStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tagStroke.Parent = tagBar

	local tagPadding = Instance.new("UIPadding")
	tagPadding.PaddingLeft = UDim.new(0, 5)
	tagPadding.PaddingRight = UDim.new(0, isOwner and 6 or 8)
	tagPadding.Parent = tagBar

	local tagLayout = Instance.new("UIListLayout")
	tagLayout.FillDirection = Enum.FillDirection.Horizontal
	tagLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tagLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tagLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tagLayout.Padding = UDim.new(0, 6)
	tagLayout.Parent = tagBar

	local badge = Instance.new("Frame")
	badge.Name = "AvatarBadge"
	badge.LayoutOrder = 1
	badge.Size = UDim2.fromOffset(18, 18)
	badge.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
	badge.BorderSizePixel = 0
	badge.ClipsDescendants = true
	badge.Parent = tagBar

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 6)
	badgeCorner.Parent = badge

	local badgeStroke = Instance.new("UIStroke")
	badgeStroke.Color = isOwner and Color3.fromRGB(225, 180, 55) or Color3.fromRGB(82, 85, 95)
	badgeStroke.Thickness = 1
	badgeStroke.Transparency = isOwner and 0.25 or 0.2
	badgeStroke.Parent = badge

	local badgeIcon = Instance.new("ImageLabel")
	badgeIcon.Name = "Avatar"
	badgeIcon.Size = UDim2.fromScale(1, 1)
	badgeIcon.Position = UDim2.fromScale(0.5, 0.5)
	badgeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	badgeIcon.BackgroundTransparency = 1
	badgeIcon.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(plr.UserId) .. "&w=150&h=150"
	badgeIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
	badgeIcon.Parent = badge

	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(0, 6)
	avatarCorner.Parent = badgeIcon

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.LayoutOrder = 2
	nameLabel.Size = UDim2.fromOffset(0, 26)
	nameLabel.AutomaticSize = Enum.AutomaticSize.X
	nameLabel.BackgroundTransparency = 1
	nameLabel.FontFace = espFontBold
	nameLabel.Text = plr.Name
	nameLabel.TextSize = 12
	nameLabel.TextColor3 = Color3.fromRGB(242, 244, 250)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = tagBar

	-- Integrated metallic gold-crown Owner badge inside the sleek blackbar for Bubblz66
	if isOwner then
		local ownerBadge = Instance.new("Frame")
		ownerBadge.Name = "OwnerBadge"
		ownerBadge.LayoutOrder = 3
		ownerBadge.Size = UDim2.fromOffset(0, 18)
		ownerBadge.AutomaticSize = Enum.AutomaticSize.X
		ownerBadge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		ownerBadge.BackgroundTransparency = 0.08
		ownerBadge.BorderSizePixel = 0
		ownerBadge.Parent = tagBar

		local ownerBgGrad = Instance.new("UIGradient")
		ownerBgGrad.Rotation = 90
		ownerBgGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(52, 42, 18)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 23, 11)),
		})
		ownerBgGrad.Parent = ownerBadge

		local ownerCorner = Instance.new("UICorner")
		ownerCorner.CornerRadius = UDim.new(0, 6)
		ownerCorner.Parent = ownerBadge

		local ownerStroke = Instance.new("UIStroke")
		ownerStroke.Color = Color3.fromRGB(255, 255, 255)
		ownerStroke.Thickness = 1
		ownerStroke.Transparency = 0.2
		ownerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ownerStroke.Parent = ownerBadge

		local ownerStrokeGrad = Instance.new("UIGradient")
		ownerStrokeGrad.Rotation = 90
		ownerStrokeGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 228, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(195, 140, 28)),
		})
		ownerStrokeGrad.Parent = ownerStroke

		local ownerPad = Instance.new("UIPadding")
		ownerPad.PaddingLeft = UDim.new(0, 5)
		ownerPad.PaddingRight = UDim.new(0, 6)
		ownerPad.Parent = ownerBadge

		local ownerLayout = Instance.new("UIListLayout")
		ownerLayout.FillDirection = Enum.FillDirection.Horizontal
		ownerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		ownerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		ownerLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ownerLayout.Padding = UDim.new(0, 3)
		ownerLayout.Parent = ownerBadge

		local crownWrap = Instance.new("Frame")
		crownWrap.Name = "CrownWrap"
		crownWrap.LayoutOrder = 1
		crownWrap.Size = UDim2.fromOffset(14, 14)
		crownWrap.BackgroundTransparency = 1
		crownWrap.Parent = ownerBadge

		local crownIcon = Instance.new("ImageLabel")
		crownIcon.Name = "Crown"
		crownIcon.Size = UDim2.fromOffset(20, 20)
		crownIcon.Position = UDim2.fromScale(0.5, 0.5)
		crownIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		crownIcon.BackgroundTransparency = 1
		crownIcon.Image = "rbxassetid://109620668715957"
		crownIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
		crownIcon.ScaleType = Enum.ScaleType.Fit
		crownIcon.Parent = crownWrap

		local crownGrad = Instance.new("UIGradient")
		crownGrad.Rotation = 90
		crownGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 242, 155)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 210, 65)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 155, 20)),
		})
		crownGrad.Parent = crownIcon

		local ownerLabel = Instance.new("TextLabel")
		ownerLabel.Name = "OwnerLabel"
		ownerLabel.LayoutOrder = 2
		ownerLabel.Size = UDim2.fromOffset(0, 18)
		ownerLabel.AutomaticSize = Enum.AutomaticSize.X
		ownerLabel.BackgroundTransparency = 1
		ownerLabel.FontFace = espFontExtraBold
		ownerLabel.Text = "OWNER"
		ownerLabel.TextSize = 10
		ownerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		ownerLabel.TextXAlignment = Enum.TextXAlignment.Left
		ownerLabel.Parent = ownerBadge

		local ownerTextGrad = Instance.new("UIGradient")
		ownerTextGrad.Rotation = 90
		ownerTextGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 242, 155)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 215, 75)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 165, 25)),
		})
		ownerTextGrad.Parent = ownerLabel
	end

	if plr.Character then
		attachEspToCharacter(plr, plr.Character, highlight, nametag)
	end

	if espConnections[plr] then
		espConnections[plr]:Disconnect()
	end
	espConnections[plr] = plr.CharacterAdded:Connect(function(character)
		if not checkSpark() then
			return
		end
		task.wait()
		attachEspToCharacter(plr, character, highlight, nametag)
	end)
end

for _, plr in ipairs(Players:GetPlayers()) do
	createEsp(plr)
end
Players.PlayerAdded:Connect(createEsp)
Players.PlayerRemoving:Connect(function(plr)
	if espConnections[plr] then
		espConnections[plr]:Disconnect()
		espConnections[plr] = nil
	end
	local h = espContainer:FindFirstChild(plr.Name)
	if h then h:Destroy() end
	local t = espContainer:FindFirstChild(plr.Name .. "_Tag")
	if t then t:Destroy() end
end)

local characterParts = {}
local characterPartConnections = {}

local function clearCharacterPartTracking()
	for _, connection in ipairs(characterPartConnections) do
		connection:Disconnect()
	end
	table.clear(characterPartConnections)
	table.clear(characterParts)
	table.clear(noclipDefaults)
end

local function trackCharacterParts(character)
	clearCharacterPartTracking()
	if not character then
		return
	end

	local function add(part)
		if part:IsA("BasePart") then
			characterParts[part] = true
			if noclipDefaults[part] == nil then
				noclipDefaults[part] = part.CanCollide
			end
		end
	end

	for _, descendant in ipairs(character:GetDescendants()) do
		add(descendant)
	end

	table.insert(characterPartConnections, character.DescendantAdded:Connect(add))
	table.insert(
		characterPartConnections,
		character.DescendantRemoving:Connect(function(part)
			characterParts[part] = nil
			noclipDefaults[part] = nil
		end)
	)
end

trackCharacterParts(localPlayer.Character)
localPlayer.CharacterAdded:Connect(trackCharacterParts)
localPlayer.CharacterRemoving:Connect(clearCharacterPartTracking)

local noclipWasActive = false
RunService.Stepped:Connect(function()
	if not checkSpark() then
		return
	end

	local noclipActive = sparkValues.actions[1].enabled or sparkValues.actions[3].enabled
	if not noclipActive and not noclipWasActive then
		return
	end

	for part in pairs(characterParts) do
		if part.Parent then
			if noclipActive then
				part.CanCollide = false
			else
				local default = noclipDefaults[part]
				part.CanCollide = if default == nil then true else default
			end
		end
	end

	noclipWasActive = noclipActive
end)

RunService.Heartbeat:Connect(function()
	if not checkSpark() then
		return
	end

	local character = localPlayer.Character
	local primaryPart = character and character.PrimaryPart
	if primaryPart then
		local bodyVelocity, bodyGyro = unpack(movers)

		if bodyVelocity then
			local alive = pcall(function()
				bodyVelocity.Parent = bodyVelocity.Parent
			end)
			if not alive then
				movers = {}
				bodyVelocity, bodyGyro = nil, nil
			end
		end

		if not bodyVelocity then
			bodyVelocity = Instance.new("BodyVelocity")
			bodyVelocity.MaxForce = Vector3.one * 9e9

			bodyGyro = Instance.new("BodyGyro")
			bodyGyro.MaxTorque = Vector3.one * 9e9
			bodyGyro.P = 9e4

			local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
			bodyAngularVelocity.AngularVelocity = Vector3.yAxis * 9e9
			bodyAngularVelocity.MaxTorque = Vector3.yAxis * 9e9
			bodyAngularVelocity.P = 9e9

			movers = { bodyVelocity, bodyGyro, bodyAngularVelocity }
		end

		if sparkValues.actions[2].enabled then
			local camCFrame = camera.CFrame
			local velocity = Vector3.zero
			local rotation = camCFrame.Rotation

			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				velocity += camCFrame.LookVector
				rotation *= CFrame.Angles(math.rad(-40), 0, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				velocity -= camCFrame.LookVector
				rotation *= CFrame.Angles(math.rad(40), 0, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				velocity += camCFrame.RightVector
				rotation *= CFrame.Angles(0, 0, math.rad(-40))
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				velocity -= camCFrame.RightVector
				rotation *= CFrame.Angles(0, 0, math.rad(40))
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				velocity += Vector3.yAxis
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				velocity -= Vector3.yAxis
			end

			local tweenInfo = TweenInfo.new(0.5)
			TweenService:Create(bodyVelocity, tweenInfo, { Velocity = velocity * sparkValues.sliders[3].value * 45 }):Play()
			bodyVelocity.Parent = primaryPart

			if not sparkValues.actions[3].enabled then
				TweenService:Create(bodyGyro, tweenInfo, { CFrame = rotation }):Play()
				bodyGyro.Parent = primaryPart
			end
		else
			bodyVelocity.Parent = nil
			bodyGyro.Parent = nil
		end
	end
end)

---------------------------------------------------------------------
-- COLLAPSE ARROW & BAR BUTTONS
---------------------------------------------------------------------
local arrowButton = Instance.new("ImageButton")
arrowButton.Name = "CollapseButton"
arrowButton.Size = UDim2.fromOffset(26, 20)
arrowButton.Position = UDim2.new(0.5, 0, 1, -74)
arrowButton.AnchorPoint = Vector2.new(0.5, 1)
arrowButton.BackgroundTransparency = 1
arrowButton.BorderSizePixel = 0
arrowButton.Image = Icons["chevron-up"] or Icons["arrow-up"]
arrowButton.ImageColor3 = Color3.fromRGB(235, 235, 235)
arrowButton.ImageTransparency = 0.35
arrowButton.ScaleType = Enum.ScaleType.Fit
arrowButton.Rotation = 0
arrowButton.ZIndex = 200
arrowButton.Parent = gui

local arrowScale = Instance.new("UIScale")
arrowScale.Scale = 1
arrowScale.Parent = arrowButton

local collapsed = false
local animating = false
local windowOpen = false

local function openCharacterPanel(btn)
	if debounce then return end
	debounce = true
	windowOpen = true

	characterPanel.Size = btn and btn.Size or UDim2.fromOffset(36, 36)
	characterPanel.Position = UDim2.new(0.5, -20, 1, -29)

	wipeTransparency(characterPanel, 1, true)
	characterPanel.Visible = true

	TweenService:Create(arrowButton, TweenInfo.new(0.65, Enum.EasingStyle.Quint), { Position = UDim2.new(0.5, 0, 1, -(PANEL_SIZE.Y.Offset + 84)) }):Play()

	TweenService:Create(characterPanel, TweenInfo.new(0.1, Enum.EasingStyle.Quint), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(characterPanel, TweenInfo.new(0.75, Enum.EasingStyle.Exponential), { Size = PANEL_SIZE }):Play()
	TweenService:Create(characterPanel, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Position = UDim2.new(0.5, 0, 1, -76) }):Play()
	task.wait(0.1)
	TweenService:Create(characterPanel.IconBadge, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(characterPanel.IconBadge.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { Transparency = 0.2 }):Play()
	TweenService:Create(characterPanel.Icon, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { ImageTransparency = 0 }):Play()
	TweenService:Create(characterPanel.HeaderDivider, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(characterPanel.CenterDivider, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { BackgroundTransparency = 0 }):Play()
	task.wait(0.05)
	TweenService:Create(characterPanel.Title, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { TextTransparency = 0 }):Play()
	TweenService:Create(characterPanel.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { Transparency = 0.15 }):Play()
	task.wait(0.05)

	TweenService:Create(characterPanel.Interactions.PropertiesTitle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { TextTransparency = 0.45 }):Play()

	local sliderInfo = {}
	for _, slider in ipairs(characterPanel.Interactions.Sliders:GetChildren()) do
		if slider.ClassName == "Frame" and slider.Name ~= "Template" then
			table.insert(sliderInfo, { slider.Name, slider.Progress.Size })
			slider.Progress.Size = UDim2.new(0, 0, 1, 0)
			slider.Progress.BackgroundTransparency = 0

			TweenService:Create(slider, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { BackgroundTransparency = 0.12 }):Play()
			TweenService:Create(slider.UIStroke, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { Transparency = 0.25 }):Play()
			TweenService:Create(slider.Shadow, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { ImageTransparency = 0.65 }):Play()
			TweenService:Create(slider.Information, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { TextTransparency = 0.2 }):Play()
			TweenService:Create(slider.ValueText, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { TextTransparency = 0.1 }):Play()
		end
	end

	for _, sliderV in pairs(sliderInfo) do
		local slider = characterPanel.Interactions.Sliders:FindFirstChild(sliderV[1])
		if slider then
			local tweenValue = Instance.new("IntValue", gui)
			local tweenTo

			for _, sliderFound in ipairs(sparkValues.sliders) do
				if sliderFound.name .. " Slider" == slider.Name then
					tweenTo = sliderFound.value
					break
				end
			end

			TweenService:Create(slider.Progress, TweenInfo.new(0.75, Enum.EasingStyle.Quint), { Size = sliderV[2] }):Play()

			if tweenTo then
				tweenValue:GetPropertyChangedSignal("Value"):Connect(function()
					slider.ValueText.Text = tostring(tweenValue.Value)
				end)
				TweenService:Create(tweenValue, TweenInfo.new(0.35, Enum.EasingStyle.Exponential), { Value = tweenTo }):Play()
				task.delay(0.4, tweenValue.Destroy, tweenValue)
			end
		end
	end

	TweenService:Create(characterPanel.Interactions.Reset, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { ImageTransparency = 0.55 }):Play()
	TweenService:Create(characterPanel.Interactions.ActionsTitle, TweenInfo.new(0.7, Enum.EasingStyle.Quint), { TextTransparency = 0.45 }):Play()

	for _, gridButton in ipairs(characterPanel.Interactions.Grid:GetChildren()) do
		if gridButton.ClassName == "Frame" and gridButton.Name ~= "Template" then
			for _, action in ipairs(sparkValues.actions) do
				if action.name == gridButton.Name then
					if action.enabled then
						TweenService:Create(gridButton, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { BackgroundTransparency = 0.15 }):Play()
						TweenService:Create(gridButton.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { Transparency = 0 }):Play()
						TweenService:Create(gridButton.Icon, TweenInfo.new(0.4, Enum.EasingStyle.Quint), { ImageTransparency = 0.05 }):Play()
					else
						TweenService:Create(gridButton, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), { BackgroundTransparency = 0.65 }):Play()
						TweenService:Create(gridButton.UIStroke, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), { Transparency = 0.4 }):Play()
						TweenService:Create(gridButton.Icon, TweenInfo.new(0.25, Enum.EasingStyle.Quint), { ImageTransparency = 0.4 }):Play()
					end
					break
				end
			end

			TweenService:Create(gridButton.Shadow, TweenInfo.new(0.5, Enum.EasingStyle.Quint), { ImageTransparency = 0.55 }):Play()
		end
	end

	TweenService:Create(characterPanel.Interactions.Serverhop, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(characterPanel.Interactions.Serverhop.Title, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { TextTransparency = 0.3 }):Play()
	TweenService:Create(characterPanel.Interactions.Serverhop.UIStroke, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Transparency = 0.2 }):Play()

	TweenService:Create(characterPanel.Interactions.Rejoin, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(characterPanel.Interactions.Rejoin.Title, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { TextTransparency = 0.3 }):Play()
	TweenService:Create(characterPanel.Interactions.Rejoin.UIStroke, TweenInfo.new(0.45, Enum.EasingStyle.Quint), { Transparency = 0.2 }):Play()

	task.wait(0.55)
	updateSliderPadding()
	debounce = false
end

local function closeCharacterPanel(btn)
	if debounce then return end
	debounce = true
	windowOpen = false

	TweenService:Create(characterPanel.Interactions.PropertiesTitle, TweenInfo.new(0.2, Enum.EasingStyle.Quint), { TextTransparency = 1 }):Play()
	TweenService:Create(characterPanel.HeaderDivider, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(characterPanel.CenterDivider, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(characterPanel.IconBadge, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(characterPanel.IconBadge.UIStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { Transparency = 1 }):Play()

	for _, slider in ipairs(characterPanel.Interactions.Sliders:GetChildren()) do
		if slider.ClassName == "Frame" and slider.Name ~= "Template" then
			TweenService:Create(slider, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(slider.Progress, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(slider.UIStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { Transparency = 1 }):Play()
			TweenService:Create(slider.Shadow, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { ImageTransparency = 1 }):Play()
			TweenService:Create(slider.Information, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { TextTransparency = 1 }):Play()
			TweenService:Create(slider.ValueText, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { TextTransparency = 1 }):Play()
		end
	end

	TweenService:Create(characterPanel.Interactions.Reset, TweenInfo.new(0.2, Enum.EasingStyle.Quint), { ImageTransparency = 1 }):Play()
	TweenService:Create(characterPanel.Interactions.ActionsTitle, TweenInfo.new(0.2, Enum.EasingStyle.Quint), { TextTransparency = 1 }):Play()

	for _, gridButton in ipairs(characterPanel.Interactions.Grid:GetChildren()) do
		if gridButton.ClassName == "Frame" and gridButton.Name ~= "Template" then
			TweenService:Create(gridButton, TweenInfo.new(0.18, Enum.EasingStyle.Exponential), { BackgroundTransparency = 1 }):Play()
			TweenService:Create(gridButton.UIStroke, TweenInfo.new(0.1, Enum.EasingStyle.Exponential), { Transparency = 1 }):Play()
			TweenService:Create(gridButton.Icon, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { ImageTransparency = 1 }):Play()
			TweenService:Create(gridButton.Shadow, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { ImageTransparency = 1 }):Play()
		end
	end

	TweenService:Create(characterPanel.Interactions.Serverhop, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(characterPanel.Interactions.Serverhop.Title, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { TextTransparency = 1 }):Play()
	TweenService:Create(characterPanel.Interactions.Serverhop.UIStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { Transparency = 1 }):Play()

	TweenService:Create(characterPanel.Interactions.Rejoin, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(characterPanel.Interactions.Rejoin.Title, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { TextTransparency = 1 }):Play()
	TweenService:Create(characterPanel.Interactions.Rejoin.UIStroke, TweenInfo.new(0.15, Enum.EasingStyle.Quint), { Transparency = 1 }):Play()

	TweenService:Create(characterPanel.Icon, TweenInfo.new(0.2, Enum.EasingStyle.Quint), { ImageTransparency = 1 }):Play()
	TweenService:Create(characterPanel.Title, TweenInfo.new(0.2, Enum.EasingStyle.Quint), { TextTransparency = 1 }):Play()
	TweenService:Create(characterPanel.UIStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quint), { Transparency = 1 }):Play()
	task.wait(0.03)

	TweenService:Create(characterPanel, TweenInfo.new(0.65, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(characterPanel, TweenInfo.new(0.9, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Size = btn and btn.Size or UDim2.fromOffset(36, 36) }):Play()
	TweenService:Create(characterPanel, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), { Position = UDim2.new(0.5, -20, 1, -29) }):Play()
	if not collapsed then
		TweenService:Create(arrowButton, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), { Position = UDim2.new(0.5, 0, 1, -74) }):Play()
	end

	task.wait(0.45)
	characterPanel.Size = PANEL_SIZE
	characterPanel.Visible = false
	debounce = false
end

arrowButton.MouseButton1Click:Connect(function()
	if animating or debounce then
		return
	end

	animating = true
	collapsed = not collapsed

	if collapsed then
		local rotate = TweenService:Create(
			arrowButton,
			TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Rotation = 180 }
		)

		local hideBar = TweenService:Create(
			bar,
			TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
			{ Position = UDim2.new(0.5, 0, 1, 85) }
		)

		if windowOpen then
			task.spawn(closeCharacterPanel)
		end

		local moveArrow = TweenService:Create(
			arrowButton,
			TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
			{ Position = UDim2.new(0.5, 0, 1, -8) }
		)

		rotate:Play()
		hideBar:Play()
		moveArrow:Play()

		hideBar.Completed:Once(function()
			animating = false
		end)
	else
		local rotate = TweenService:Create(
			arrowButton,
			TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{ Rotation = 0 }
		)

		local showBar = TweenService:Create(
			bar,
			TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
			{ Position = UDim2.new(0.5, 0, 1, -16) }
		)

		local moveArrow = TweenService:Create(
			arrowButton,
			TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut),
			{ Position = UDim2.new(0.5, 0, 1, -74) }
		)

		rotate:Play()
		showBar:Play()
		moveArrow:Play()

		showBar.Completed:Once(function()
			animating = false
		end)
	end
end)

-- Bar buttons creation
local function createButton(index)
	local button = Instance.new("ImageButton")
	button.Name = "Button" .. index
	button.Size = UDim2.fromOffset(36, 36)
	button.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
	button.BorderSizePixel = 0
	button.Image = ""
	button.AutoButtonColor = false
	button.ZIndex = 151
	button.Parent = barButtonsContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(48, 48, 54)
	stroke.Thickness = 1
	stroke.Transparency = 0.2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = button

	local innerShadow = Instance.new("ImageLabel")
	innerShadow.Name = "Shadow"
	innerShadow.Size = UDim2.new(1, 0, 1, 0)
	innerShadow.Position = UDim2.new(0.5, 0, 0.5, 0)
	innerShadow.AnchorPoint = Vector2.new(0.5, 0.5)
	innerShadow.BackgroundTransparency = 1
	innerShadow.Image = "rbxassetid://3602733521"
	innerShadow.ImageColor3 = Color3.fromRGB(16, 16, 18)
	innerShadow.ImageTransparency = 0.55
	innerShadow.ZIndex = 151
	innerShadow.Parent = button

	local innerShadowCorner = Instance.new("UICorner")
	innerShadowCorner.CornerRadius = UDim.new(0, 9)
	innerShadowCorner.Parent = innerShadow

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromOffset(20, 20)
	icon.Position = UDim2.new(0.5, 0, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1

	if index == 1 then
		icon.Image = "rbxassetid://98755624629571"
	elseif index == 2 then
		icon.Image = "rbxassetid://9080470458"
	else
		icon.Image = Icons["box"]
	end

	icon.ImageColor3 = Color3.fromRGB(240, 240, 245)
	icon.ImageTransparency = 0.25
	icon.ScaleType = Enum.ScaleType.Fit
	icon.ZIndex = 152
	icon.Parent = button

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	local function updateVisualState(hovered)
		local isActive = (index == 2 and windowOpen)
		TweenService:Create(
			button,
			TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{
				BackgroundColor3 = isActive and Color3.fromRGB(42, 42, 48)
					or (hovered and Color3.fromRGB(36, 36, 42) or Color3.fromRGB(28, 28, 32)),
			}
		):Play()
		TweenService:Create(
			stroke,
			TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{
				Color = isActive and Color3.fromRGB(82, 82, 92)
					or (hovered and Color3.fromRGB(65, 65, 74) or Color3.fromRGB(48, 48, 54)),
				Transparency = isActive and 0 or 0.2,
			}
		):Play()
		TweenService:Create(
			icon,
			TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{
				ImageTransparency = (isActive or hovered) and 0.05 or 0.25,
			}
		):Play()
	end

	button.MouseEnter:Connect(function()
		updateVisualState(true)
	end)

	button.MouseLeave:Connect(function()
		updateVisualState(false)
	end)

	button.MouseButton1Click:Connect(function()
		local down = TweenService:Create(
			scale,
			TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 0.82 }
		)

		local up = TweenService:Create(
			scale,
			TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)

		down:Play()
		down.Completed:Once(function()
			up:Play()
		end)

		if index == 2 and not collapsed and not debounce then
			if not windowOpen then
				task.spawn(function()
					openCharacterPanel(button)
					updateVisualState(false)
				end)
				updateVisualState(true)
			else
				task.spawn(function()
					closeCharacterPanel(button)
					updateVisualState(false)
				end)
			end
		end
	end)

	return button
end

for i = 1, 4 do
	createButton(i)
end

-- Arrow hover
arrowButton.MouseEnter:Connect(function()
	TweenService:Create(
		arrowButton,
		TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ ImageTransparency = 0 }
	):Play()

	TweenService:Create(
		arrowScale,
		TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Scale = 1.1 }
	):Play()
end)

arrowButton.MouseLeave:Connect(function()
	TweenService:Create(
		arrowButton,
		TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ ImageTransparency = 0.35 }
	):Play()

	TweenService:Create(
		arrowScale,
		TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end)

arrowButton.MouseButton1Down:Connect(function()
	if animating then return end
	TweenService:Create(
		arrowScale,
		TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 0.85 }
	):Play()
end)

arrowButton.MouseButton1Up:Connect(function()
	if animating then return end
	TweenService:Create(
		arrowScale,
		TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = collapsed and 1.1 or 1 }
	):Play()
end)
