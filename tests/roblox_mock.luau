--[[
	Mock Roblox environment for smoke-testing AnnouncementPanel outside Studio.
	Provides: virtual clock + task scheduler, Instance tree, signals, services,
	datatypes (Color3/UDim2/UDim/Vector2/Vector3/CFrame/TweenInfo/sequences/Font),
	Enum with dynamic members, and the services the panel touches.

	Everything is intentionally permissive EXCEPT that unknown members return nil,
	so real bugs (typos, wrong names, nil indexing) still blow up loudly.
--]]

--============================================================================
-- virtual clock
--============================================================================
local VirtualClock = 0
local VirtualUnix = 1700000000
local realFloor = math.floor
local realDate = os.date

-- The CLI sandbox marks stdlib tables readonly, so the panel receives a mock
-- "os" through local shadowing instead of mutation.
local mockOs = {
	clock = function() return VirtualClock end,
	time = function(t) return VirtualUnix + realFloor(VirtualClock) end,
	date = function(fmt, t)
		return realDate(fmt or "%H:%M:%S", t or (VirtualUnix + realFloor(VirtualClock)))
	end,
	difftime = os.difftime,
}

--============================================================================
-- scheduler
--============================================================================
local scheduled = {} -- { {time=, co=} }
local stepCount = 0
local MAX_STEPS = 400000
local RuntimeErrors = {}
local TraceLog = {}

local function recordError(where, err)
	table.insert(RuntimeErrors, where .. ": " .. tostring(err))
	print("[MOCK ERROR] " .. where .. " -> " .. tostring(err))
end

local function scheduleCo(co, atTime)
	table.insert(scheduled, { Time = math.max(VirtualClock, atTime or VirtualClock), Co = co })
end

local function resumeCo(co, where)
	if coroutine.status(co) ~= "suspended" then
		return
	end
	stepCount += 1
	local ok, a, b = coroutine.resume(co)
	if not ok then
		recordError(where or "coroutine", a)
		return
	end
	if coroutine.status(co) == "suspended" then
		if a == "wait" then
			scheduleCo(co, VirtualClock + (tonumber(b) or 0))
		elseif a == "yield" then
			scheduleCo(co, VirtualClock)
		else
			-- plain yield: reschedule immediately
			scheduleCo(co, VirtualClock)
		end
	end
end

-- pump(seconds) advances the virtual clock by `seconds` and runs everything
-- scheduled inside that window.
local function pump(seconds, label)
	local untilTime = VirtualClock + (tonumber(seconds) or 0)
	local guard = 0
	while guard < MAX_STEPS do
		guard += 1
		-- find the earliest ready coroutine
		local bestIndex = nil
		local bestTime = math.huge
		for index, entry in ipairs(scheduled) do
			if entry.Time <= untilTime and entry.Time < bestTime then
				bestTime = entry.Time
				bestIndex = index
			end
		end
		if bestIndex == nil then
			-- advance to the next scheduled time if it is inside our window
			local nextIndex = nil
			local nextTime = math.huge
			for index, entry in ipairs(scheduled) do
				if entry.Time < nextTime then
					nextTime = entry.Time
					nextIndex = index
				end
			end
			if nextIndex == nil or nextTime > untilTime then
				break
			end
			VirtualClock = nextTime
		else
			VirtualClock = math.max(VirtualClock, bestTime)
			local entry = table.remove(scheduled, bestIndex)
			resumeCo(entry.Co, label or "pump")
		end
		if stepCount > MAX_STEPS then
			recordError("scheduler", "step limit exceeded")
			break
		end
	end
	-- Always land on the requested time, even when nothing was scheduled in the
	-- window (otherwise cooldowns and delays would never expire).
	VirtualClock = math.max(VirtualClock, untilTime)
end

local task = {}
task.spawn = function(fn, ...)
	local args = { ... }
	local co = coroutine.create(function()
		local ok, err = pcall(fn, table.unpack(args))
		if not ok then
			recordError("task.spawn", err)
		end
	end)
	scheduleCo(co, VirtualClock)
	resumeCo(co, "task.spawn")
	return co
end
task.defer = task.spawn
task.delay = function(seconds, fn, ...)
	local args = { ... }
	local co = coroutine.create(function()
		local ok, err = pcall(fn, table.unpack(args))
		if not ok then
			recordError("task.delay", err)
		end
	end)
	scheduleCo(co, VirtualClock + (tonumber(seconds) or 0))
	return co
end
task.wait = function(seconds)
	coroutine.yield("wait", tonumber(seconds) or 0)
	return tonumber(seconds) or 0
end

-- legacy
local wait = task.wait
local spawn = task.spawn
local delay = task.delay

--============================================================================
-- datatypes
--============================================================================
local function mkVec3(x, y, z)
	return { X = x or 0, Y = y or 0, Z = z or 0, Type = "Vector3" }
end
local Vector3 = {
	new = function(x, y, z) return mkVec3(x, y, z) end,
	zero = function() return mkVec3(0, 0, 0) end,
	one = function() return mkVec3(1, 1, 1) end,
}
local function mkVec2(x, y)
	local v = { X = x or 0, Y = y or 0, Type = "Vector2" }
	return v
end
local Vector2 = {
	new = function(x, y) return mkVec2(x, y) end,
	zero = function() return mkVec2(0, 0) end,
}
local Color3 = {
	new = function(r, g, b) return { R = r or 0, G = g or 0, B = b or 0, Type = "Color3" } end,
	fromRGB = function(r, g, b) return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255, Type = "Color3" } end,
	fromHSV = function(h, s, v) return { R = v, G = v, B = v, Type = "Color3" } end,
}
local UDim = {
	new = function(s, o) return { Scale = s or 0, Offset = o or 0, Type = "UDim" } end,
	fromScale = function(s) return { Scale = s or 0, Offset = 0, Type = "UDim" } end,
	fromOffset = function(o) return { Scale = 0, Offset = o or 0, Type = "UDim" } end,
}
local UDim2 = {}
UDim2.new = function(xs, xo, ys, yo)
	return {
		X = UDim.new(xs, xo), Y = UDim.new(ys, yo),
		Scale = { X = xs or 0, Y = ys or 0 }, Offset = { X = xo or 0, Y = yo or 0 },
		Type = "UDim2",
	}
end
UDim2.fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end
UDim2.fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end
local CFrame = {
	new = function(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0, Type = "CFrame" } end,
	Angles = function() return { Type = "CFrame" } end,
	identity = { Type = "CFrame" },
}
local TweenInfo = {
	new = function(time, style, dir, rep, rev, delay)
		return { Time = time, EasingStyle = style, EasingDirection = dir, RepeatCount = rep, Reverses = rev, DelayTime = delay, Type = "TweenInfo" }
	end,
}
local NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
local ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
local NumberSequence = { new = function(a, b) return { Keypoints = a, Type = "NumberSequence" } end }
local ColorSequence = { new = function(a, b) return { Keypoints = a, Type = "ColorSequence" } end }
local Rect = { new = function() return { Type = "Rect" } end }
local Font = {
	new = function(family, weight, style) return { Family = family, Weight = weight, Style = style, Type = "Font" } end,
	fromEnum = function(e) return { Enum = e, Type = "Font" } end,
	fromName = function(n) return { Name = n, Type = "Font" } end,
}
local Random = { new = function() return { NextNumber = function() return 0.5 end } end }

--============================================================================
-- Enum (dynamic: any Enum.X.Y resolves to an item)
--============================================================================
local enumItemMeta = {}
local Enum = {}
local enumCache = {}
setmetatable(Enum, {
	__index = function(_, enumTypeName)
		if enumCache[enumTypeName] then
			return enumCache[enumTypeName]
		end
		local itemCache = {}
		local enumType = setmetatable({ Name = enumTypeName }, {
			__index = function(_, itemName)
				if itemCache[itemName] then
					return itemCache[itemName]
				end
				local item = { Name = itemName, Value = 1, EnumType = enumTypeName }
				itemCache[itemName] = item
				return item
			end,
		})
		enumCache[enumTypeName] = enumType
		return enumType
	end,
})

local function typeofImpl(value)
	if type(value) == "table" then
		if value.Type then
			return value.Type
		end
		if value.__isInstance then
			return "Instance"
		end
		if value.__isSignal then
			return "RBXScriptSignal"
		end
		if value.__isConnection then
			return "RBXScriptConnection"
		end
		if value.__isEnumItem then
			return "EnumItem"
		end
		if value.__isTween then
			return "Tween"
		end
		return "table"
	end
	return type(value)
end
local typeof = typeofImpl

--============================================================================
-- signals
--============================================================================
local function newSignal(name)
	local listeners = {}
	local signal = { __isSignal = true, Name = name or "signal" }
	function signal:Connect(fn)
		local conn = { __isConnection = true, Connected = true }
		function conn:Disconnect()
			conn.Connected = false
			for i, l in ipairs(listeners) do
				if l.Fn == fn then
					table.remove(listeners, i)
					break
				end
			end
		end
		table.insert(listeners, { Fn = fn, Conn = conn })
		return conn
	end
	signal.connect = signal.Connect
	function signal:Wait()
		coroutine.yield("wait", 0.01)
		return nil
	end
	function signal:Fire(...)
		local count = 0
		for _, l in ipairs(listeners) do
			if l.Conn.Connected then
				count += 1
				local ok, err = pcall(l.Fn, ...)
				if not ok then
					recordError("signal " .. tostring(signal.Name), err)
				end
			end
		end
		return count
	end
	function signal:ListenerCount()
		local n = 0
		for _, l in ipairs(listeners) do
			if l.Conn.Connected then
				n += 1
			end
		end
		return n
	end
	return signal
end

--============================================================================
-- Instance
--============================================================================
local EVENT_NAMES = {
	ChildAdded = true, ChildRemoved = true, DescendantAdded = true, Changed = true,
	AncestryChanged = true, AttributeChanged = true, MouseButton1Click = true,
	MouseButton1Down = true, MouseButton1Up = true, MouseEnter = true, MouseLeave = true,
	InputBegan = true, InputEnded = true, InputChanged = true, FocusLost = true,
	Focused = true, Activated = true, Completed = true, PlayerAdded = true,
	PlayerRemoving = true, PlayerChatted = true, Chatted = true, CharacterAdded = true,
	CharacterRemoving = true, OnServerEvent = true, OnClientEvent = true,
	MessageReceived = true, TouchTapInWorld = true, RenderStepped = true,
	Heartbeat = true, Stepped = true, TargetElapsed = true,
}

local DEFAULTS = {
	Name = "Instance", Text = "", Value = nil, Enabled = true, Visible = true,
	BackgroundTransparency = 0, BackgroundColor3 = nil, Transparency = 0,
	Size = nil, Position = nil, Parent = nil, ClassName = "Instance",
	TextSize = 14, TextColor3 = nil, Rotation = 0, ZIndex = 1, LayoutOrder = 0,
	AnchorPoint = nil, Scale = 1, Thickness = 1, Color = nil, Volume = 0.5,
	SoundId = "", PlaybackSpeed = 1, Looped = false, AutomaticSize = nil,
	TextWrapped = false, RichText = false, ClipsDescendants = false,
	CanvasSize = nil, ScrollBarThickness = 4, DisplayOrder = 0, ResetOnSpawn = true,
	IgnoreGuiInset = false, ZIndexBehavior = nil, ClipToDeviceSafeArea = true,
	TextTruncate = nil, TextXAlignment = nil, TextYAlignment = nil, BorderSizePixel = 0,
	AutoButtonColor = true, ClearTextOnFocus = true, PlaceholderText = "",
	MultiLine = false, CornerRadius = nil, Padding = nil, Offset = nil,
	Brightness = 0, Contrast = 0, Saturation = 0, TintColor = nil, Font = nil,
	FontFace = nil, CellSize = nil, CellPadding = nil, FillDirection = nil,
	HorizontalAlignment = nil, VerticalAlignment = nil, SortOrder = nil,
	MinSize = nil, MaxSize = nil, ApplyStrokeMode = nil, CameraType = nil,
	CFrame = nil, ViewportSize = nil, RollOffMode = nil, ShouldDeliver = true,
	TextTransparency = 0, AutomaticCanvasSize = nil, ScrollBarImageColor3 = nil,
	Text = "",
}

local InstanceRegistry = {}

local MockPlayers = {}

local function makeInstance(className)
	local self = {
		__isInstance = true,
		ClassName = className,
		_children = {},
		_properties = {},
		_attributes = {},
		_signals = {},
		_destroyed = false,
		Name = className,
	}
	table.insert(InstanceRegistry, self)

	local methods = {}

	function methods:Destroy()
		self._destroyed = true
		if self.Parent then
			local parent = self.Parent
			self.Parent = nil
			if parent and parent._children then
				for i, c in ipairs(parent._children) do
					if c == self then
						table.remove(parent._children, i)
						break
					end
				end
			end
		end
		self._children = {}
	end
	methods.destroy = methods.Destroy

	function methods:FindFirstChild(name, recursive)
		for _, child in ipairs(self._children) do
			if child.Name == name and not child._destroyed then
				return child
			end
		end
		if recursive then
			for _, child in ipairs(self._children) do
				local found = child:FindFirstChild(name, true)
				if found then
					return found
				end
			end
		end
		return nil
	end

	function methods:FindFirstChildOfClass(class)
		for _, child in ipairs(self._children) do
			if child.ClassName == class then
				return child
			end
		end
		return nil
	end
	methods.FindFirstChildWhichIsA = methods.FindFirstChildOfClass

	function methods:WaitForChild(name, timeout)
		local found = self:FindFirstChild(name)
		if found then
			return found
		end
		-- simulate a bounded wait using the virtual clock
		local deadline = VirtualClock + (tonumber(timeout) or 5)
		while VirtualClock < deadline do
			task.wait(0.05)
			found = self:FindFirstChild(name)
			if found then
				return found
			end
		end
		return nil
	end

	function methods:GetChildren()
		local result = {}
		for _, child in ipairs(self._children) do
			if not child._destroyed then
				table.insert(result, child)
			end
		end
		return result
	end

	function methods:GetDescendants()
		local result = {}
		local function walk(node)
			for _, child in ipairs(node._children or {}) do
				if not child._destroyed then
					table.insert(result, child)
					walk(child)
				end
			end
		end
		walk(self)
		return result
	end

	function methods:GetFullName()
		local parts = { self.Name }
		local node = self.Parent
		while node do
			table.insert(parts, 1, node.Name)
			node = node.Parent
		end
		return table.concat(parts, ".")
	end

	function methods:IsA(class)
		if self.ClassName == class then
			return true
		end
		-- crude inheritance for the classes the panel checks
		local hierarchy = {
			TextLabel = { "GuiObject", "GuiBase2d", "Instance" },
			TextButton = { "GuiButton", "GuiObject", "Instance" },
			TextBox = { "GuiObject", "Instance" },
			Frame = { "GuiObject", "Instance" },
			ScreenGui = { "LayerCollector", "GuiObject", "Instance" },
			ScrollingFrame = { "GuiObject", "Instance" },
			UIStroke = { "UIComponent", "Instance" },
			UIGradient = { "UIComponent", "Instance" },
			UIListLayout = { "UILayout", "UIComponent", "Instance" },
			UIGridLayout = { "UILayout", "UIComponent", "Instance" },
			UIPadding = { "UIComponent", "Instance" },
			UICorner = { "UIComponent", "Instance" },
			UIScale = { "UIComponent", "Instance" },
			UISizeConstraint = { "UIConstraint", "UIComponent", "Instance" },
			RemoteEvent = { "BaseRemoteEvent", "Instance" },
			Folder = { "Instance" },
			Sound = { "Instance" },
			TextChannel = { "Instance" },
			Player = { "Instance" },
			BlurEffect = { "Instance" },
			ColorCorrectionEffect = { "Instance" },
			Camera = { "Instance" },
			PlayerGui = { "Instance" },
		}
		for _, parent in ipairs(hierarchy[self.ClassName] or { "Instance" }) do
			if parent == class then
				return true
			end
		end
		return false
	end

	function methods:IsDescendantOf(other)
		local node = self.Parent
		while node do
			if node == other then
				return true
			end
			node = node.Parent
		end
		return false
	end

	function methods:ClearAllChildren()
		for _, child in ipairs(self:GetChildren()) do
			child:Destroy()
		end
	end

	function methods:GetAttribute(name)
		return self._attributes[name]
	end
	function methods:SetAttribute(name, value)
		self._attributes[name] = value
		local signal = self._signals["AttributeChanged_" .. tostring(name)]
		if signal then
			signal:Fire(value)
		end
	end
	function methods:GetAttributes()
		return self._attributes
	end
	function methods:GetAttributeChangedSignal(name)
		local key = "AttributeChanged_" .. tostring(name)
		if not self._signals[key] then
			self._signals[key] = newSignal(key)
		end
		return self._signals[key]
	end
	function methods:GetPropertyChangedSignal(property)
		local key = "PropertyChanged_" .. tostring(property)
		if not self._signals[key] then
			self._signals[key] = newSignal(key)
		end
		return self._signals[key]
	end
	function methods:Clone()
		return makeInstance(self.ClassName)
	end

	-- RemoteEvent
	function methods:FireClient(player, ...)
		self._firedToClient = (self._firedToClient or 0) + 1
		table.insert(TraceLog, { Kind = "FireClient", To = player and player.Name or "?", Args = { ... } })
		-- Deliver to the client side (OnClientEvent listeners).
		self.OnClientEvent:Fire(...)
		if self._clientHandler then
			local ok, err = pcall(self._clientHandler, ...)
			if not ok then
				recordError("client handler", err)
			end
		end
	end
	function methods:FireAllClients(...)
		self._firedToAll = (self._firedToAll or 0) + 1
		table.insert(TraceLog, { Kind = "FireAllClients", Args = { ... } })
		self.OnClientEvent:Fire(...)
	end
	function methods:FireServer(...)
		table.insert(TraceLog, { Kind = "FireServer", Args = { ... } })
		-- Roblox prepends the firing player on the server side.
		self.OnServerEvent:Fire(MockPlayers[1], ...)
		if self._serverHandler then
			local ok, err = pcall(self._serverHandler, MockPlayers[1], ...)
			if not ok then
				recordError("server handler", err)
			end
		end
	end

	-- Sound / Tween
	function methods:Play()
		self.IsPlaying = true
		table.insert(TraceLog, { Kind = "Sound:Play", Name = self.Name })
	end
	function methods:Stop()
		self.IsPlaying = false
	end
	function methods:Pause()
		self.IsPlaying = false
	end
	function methods:CaptureFocus()
		table.insert(TraceLog, { Kind = "CaptureFocus", Name = self.Name })
	end
	function methods:ReleaseFocus()
	end

	-- Player-specific
	function methods:Kick(reason)
		self._kicked = reason
		table.insert(TraceLog, { Kind = "Kick", Name = self.Name, Reason = reason })
	end
	function methods:GetRankInGroup(groupId)
		return self._groupRanks and self._groupRanks[groupId] or 0
	end

	local meta = {}
	meta.__index = function(t, key)
		if methods[key] then
			return methods[key]
		end
		if EVENT_NAMES[key] then
			if not t._signals[key] then
				t._signals[key] = newSignal(key)
			end
			return t._signals[key]
		end
		if t._properties[key] ~= nil then
			return t._properties[key]
		end
		if rawget(t, key) ~= nil then
			return rawget(t, key)
		end
		if key == "AbsoluteSize" then
			return Vector2.new(1440, 900)
		end
		if key == "AbsolutePosition" then
			return Vector2.new(0, 0)
		end
		if DEFAULTS[key] ~= nil then
			return DEFAULTS[key]
		end
		-- Roblox falls back to child-by-name lookup (parent.SomeChild).
		if type(key) == "string" then
			for _, child in ipairs(t._children or {}) do
				if not child._destroyed and child.Name == key then
					return child
				end
			end
		end
		return nil
	end
	meta.__newindex = function(t, key, value)
		if key == "Parent" then
			local old = t._properties.Parent
			if old and old._children then
				for i, c in ipairs(old._children) do
					if c == t then
						table.remove(old._children, i)
						break
					end
				end
				if old._signals and old._signals.ChildRemoved then
					old._signals.ChildRemoved:Fire(t)
				end
			end
			t._properties.Parent = value
			if value and value._children then
				table.insert(value._children, t)
				if value._signals and value._signals.ChildAdded then
					value._signals.ChildAdded:Fire(t)
				end
			end
			return
		end
		t._properties[key] = value
		local signal = t._signals["PropertyChanged_" .. tostring(key)]
		if signal then
			signal:Fire()
		end
	end
	meta.__tostring = function(t)
		return t.Name
	end

	setmetatable(self, meta)
	self._properties.Name = className
	self._properties.ClassName = className
	self._properties.Size = UDim2.fromScale(0, 0)
	self._properties.Position = UDim2.fromScale(0, 0)
	self._properties.AnchorPoint = Vector2.new(0, 0)
	return self
end

local Instance = {
	new = function(className)
		return makeInstance(className)
	end,
}

--============================================================================
-- TweenService
--============================================================================
local TweenCount = 0
local TweenService = {
	Name = "TweenService",
	Create = function(_, instance, info, goals)
		TweenCount += 1
		if typeofImpl(instance) ~= "Instance" then
			error("TweenService:Create expects an Instance, got " .. typeofImpl(instance))
		end
		if typeofImpl(info) ~= "TweenInfo" then
			error("TweenService:Create expects TweenInfo")
		end
		if type(goals) ~= "table" then
			error("TweenService:Create expects a goals table")
		end
		-- validate goal property names exist as instance properties (mock keeps
		-- them permissive, so we only validate types loosely here)
		local tween = { __isTween = true, Instance = instance, Info = info, Goals = goals, Playing = false }
		tween.Completed = newSignal("TweenCompleted")
		function tween:Play()
			self.Playing = true
			-- apply the end state immediately, like a completed tween
			for key, value in pairs(self.Goals) do
				self.Instance[key] = value
			end
			task.delay(self.Info.Time or 0, function()
				self.Playing = false
				self.Completed:Fire("Completed")
			end)
		end
		function tween:Cancel()
			self.Playing = false
			self.Completed:Fire("Cancelled")
		end
		function tween:Pause()
			self.Playing = false
		end
		return tween
	end,
}

--============================================================================
-- services
--============================================================================
local serviceRegistry = {}

local function makePlayer(name, userId, groupRanks)
	local player = makeInstance("Player")
	player.Name = name
	player.DisplayName = name
	player.UserId = userId
	player._groupRanks = groupRanks or {}
	local playerGui = makeInstance("PlayerGui")
	playerGui.Name = "PlayerGui"
	playerGui.Parent = player
	local character = makeInstance("Model")
	character.Name = name
	character.Parent = player
	player.Character = character
	return player
end

local Players = {
	Name = "Players",
	LocalPlayer = nil,
	PlayerAdded = newSignal("PlayerAdded"),
	PlayerRemoving = newSignal("PlayerRemoving"),
	PlayerChatted = newSignal("PlayerChatted"),
	GetPlayers = function()
		local list = {}
		for _, p in ipairs(MockPlayers) do
			table.insert(list, p)
		end
		return list
	end,
	GetPlayerByUserId = function(_, userId)
		for _, p in ipairs(MockPlayers) do
			if p.UserId == userId then
				return p
			end
		end
		return nil
	end,
	GetPlayerByName = function(_, name)
		for _, p in ipairs(MockPlayers) do
			if p.Name == name then
				return p
			end
		end
		return nil
	end,
}
-- Real Roblox always parents players to the Players service, and the panel
-- uses `player.Parent == nil` to detect players who have left, so mirror that.
local rawMakePlayer = makePlayer
makePlayer = function(name, userId, groupRanks)
	local player = rawMakePlayer(name, userId, groupRanks)
	player.Parent = Players
	return player
end

local ReplicatedStorage = makeInstance("Folder")
ReplicatedStorage.Name = "ReplicatedStorage"
local ServerScriptService = makeInstance("Folder")
ServerScriptService.Name = "ServerScriptService"
local StarterGui = makeInstance("Folder")
StarterGui.Name = "StarterGui"
StarterGui.SetCore = function(_, key, value)
	table.insert(TraceLog, { Kind = "SetCore", Key = key })
	return true
end
StarterGui.GetCore = function(_, key)
	return true
end

local Lighting = makeInstance("Folder")
Lighting.Name = "Lighting"

local camera = makeInstance("Camera")
camera.Name = "Camera"
camera.ViewportSize = Vector2.new(1440, 900)
camera.CameraType = Enum.CameraType.Custom
camera.CFrame = CFrame.new(0, 0, 0)

local workspace = makeInstance("Folder")
workspace.Name = "Workspace"
workspace.CurrentCamera = camera
workspace._properties.CurrentCamera = camera

local RunService = {
	Name = "RunService",
	_server = true,
	_client = false,
	_studio = true,
	Heartbeat = newSignal("Heartbeat"),
	RenderStepped = newSignal("RenderStepped"),
	Stepped = newSignal("Stepped"),
	IsServer = function(self) return self._server end,
	IsClient = function(self) return self._client end,
	IsStudio = function(self) return self._studio end,
	IsRunning = function(self) return true end,
}

local SoundService = makeInstance("Folder")
SoundService.Name = "SoundService"
SoundService.PlayLocalSound = function(_, sound)
	table.insert(TraceLog, { Kind = "PlayLocalSound", Name = sound.Name })
	return true
end

local TextService = {
	Name = "TextService",
	FilterStringAsync = function(_, text, userId, context)
		return {
			GetNonChatStringForBroadcastAsync = function() return text end,
			GetNonChatStringForUserAsync = function() return text end,
		}
	end,
	GetTextSize = function(_, text, size, font, bounds)
		return Vector2.new(#tostring(text) * (size or 14) * 0.55, size or 14)
	end,
}

local HttpService = {
	Name = "HttpService",
	GenerateGUID = function() return "mock-guid-1234" end,
	JSONEncode = function(_, t) return "{}" end,
	JSONDecode = function(_, s) return {} end,
}

local Debris = {
	Name = "Debris",
	AddItem = function(_, instance, lifetime)
		task.delay(lifetime or 5, function()
			if instance and instance.Destroy then
				pcall(function() instance:Destroy() end)
			end
		end)
	end,
}

local TextChatService = {
	Name = "TextChatService",
	MessageReceived = newSignal("MessageReceived"),
}
local textChannels = makeInstance("Folder")
textChannels.Name = "TextChannels"
textChannels.Parent = TextChatService
local generalChannel = makeInstance("TextChannel")
generalChannel.Name = "RBXGeneral"
generalChannel.Parent = textChannels
generalChannel.DisplaySystemMessage = function(_, text)
	table.insert(TraceLog, { Kind = "SystemMessage", Text = text })
	return makeInstance("TextChatMessage")
end
generalChannel.SendAsync = function(_, text) return nil end
TextChatService.TextChannels = textChannels
TextChatService.WaitForChild = function(_, name, timeout)
	if name == "TextChannels" then
		return textChannels
	end
	return nil
end
TextChatService.FindFirstChild = function(_, name)
	if name == "TextChannels" then
		return textChannels
	end
	return nil
end

local UserInputService = {
	Name = "UserInputService",
	TouchEnabled = false,
	KeyboardEnabled = true,
	GamepadEnabled = false,
	InputBegan = newSignal("InputBegan"),
	InputEnded = newSignal("InputEnded"),
	InputChanged = newSignal("InputChanged"),
	TouchTapInWorld = newSignal("TouchTapInWorld"),
}

local ContextActionService = {
	Name = "ContextActionService",
	_bound = {},
	BindAction = function(self, name, fn, sink, ...)
		self._bound[name] = fn
	end,
	BindActionAtPriority = function(self, name, fn, sink, priority, ...)
		self._bound[name] = fn
	end,
	UnbindAction = function(self, name)
		self._bound[name] = nil
	end,
	GetBoundActions = function(self)
		local names = {}
		for actionName in pairs(self._bound) do
			table.insert(names, actionName)
		end
		return names
	end,
}

local GuiService = {
	Name = "GuiService",
	GetGuiInset = function() return 0, 58 end,
	MenuIsOpen = false,
}

local dataStoreBacking = {}
local DataStoreService = {
	Name = "DataStoreService",
	_store = dataStoreBacking,
	GetDataStore = function(_, name)
		local fullName = tostring(name)
		local store = {
			Name = fullName,
			GetAsync = function(_, key) return dataStoreBacking[fullName .. "/" .. tostring(key)] end,
			SetAsync = function(_, key, value) dataStoreBacking[fullName .. "/" .. tostring(key)] = value end,
			UpdateAsync = function(_, key, fn)
				local slot = fullName .. "/" .. tostring(key)
				dataStoreBacking[slot] = fn(dataStoreBacking[slot])
			end,
			RemoveAsync = function(_, key) dataStoreBacking[fullName .. "/" .. tostring(key)] = nil end,
			IncrementAsync = function(_, key, amount)
				local slot = fullName .. "/" .. tostring(key)
				dataStoreBacking[slot] = (tonumber(dataStoreBacking[slot]) or 0) + (tonumber(amount) or 1)
				return dataStoreBacking[slot]
			end,
		}
		return store
	end,
}

local MarketplaceService = {
	Name = "MarketplaceService",
	UserOwnsGamePassAsync = function(_, userId, passId) return false end,
	GetProductInfo = function(_, id) return { Name = "Mock Game" } end,
}

local CollectionService = {
	Name = "CollectionService",
	GetTagged = function() return {} end,
	AddTag = function() end,
}

local game = {
	Name = "Game",
	PlaceId = 123456789,
	JobId = "mock-job-id-abc",
	CreatorId = 11111,
	CreatorType = Enum.CreatorType.User,
	Genre = "Adventure",
	_services = {
		Players = Players,
		ReplicatedStorage = ReplicatedStorage,
		ServerScriptService = ServerScriptService,
		StarterGui = StarterGui,
		Lighting = Lighting,
		Workspace = workspace,
		RunService = RunService,
		SoundService = SoundService,
		TextService = TextService,
		HttpService = HttpService,
		Debris = Debris,
		TextChatService = TextChatService,
		UserInputService = UserInputService,
		ContextActionService = ContextActionService,
		GuiService = GuiService,
		DataStoreService = DataStoreService,
		MarketplaceService = MarketplaceService,
		CollectionService = CollectionService,
		TweenService = TweenService,
		ServerStorage = makeInstance("Folder"),
		StarterPlayer = makeInstance("Folder"),
		CoreGui = makeInstance("Folder"),
		TeleportService = { Name = "TeleportService" },
	},
	GetService = function(self, name)
		local svc = self._services[name]
		if svc == nil then
			svc = { Name = name }
			self._services[name] = svc
		end
		return svc
	end,
	FindFirstChild = function(self, name)
		return self._services[name]
	end,
	BindToClose = function(self, fn)
		self._closeHandler = fn
		table.insert(TraceLog, { Kind = "BindToClose" })
	end,
	GetObjects = function() return {} end,
}
game._services.Workspace = workspace

-- workspace as a global
local workspaceGlobal = workspace

local shared = {}

--============================================================================
-- export everything as globals for the panel script
--============================================================================
-- The Luau CLI keeps _G readonly, so instead of installing globals we export
-- the mocks under Mock* names. The driver re-declares locals with exactly the
-- Roblox global names, which shadows them for the panel source.
local mockWarnMessages = {}
local mockWarn = function(...)
	local parts = {}
	for index = 1, select("#", ...) do
		table.insert(parts, tostring((select(index, ...))))
	end
	table.insert(mockWarnMessages, table.concat(parts, " "))
	print(table.concat(parts, " "))
end
local mockTick = function() return VirtualClock end
local MockGame = game
local MockInstance = Instance
local MockEnum = Enum
local MockColor3 = Color3
local MockUDim = UDim
local MockUDim2 = UDim2
local MockVector2 = Vector2
local MockVector3 = Vector3
local MockCFrame = CFrame
local MockTweenInfo = TweenInfo
local MockNumberSequence = NumberSequence
local MockColorSequence = ColorSequence
local MockNumberSequenceKeypoint = NumberSequenceKeypoint
local MockColorSequenceKeypoint = ColorSequenceKeypoint
local MockRect = Rect
local MockFont = Font
local MockRandom = Random
local MockTypeof = typeofImpl
local MockTask = task
local MockOs = mockOs
local MockWarn = mockWarn
local MockTick = mockTick
local MockShared = shared
local MockWorkspace = workspaceGlobal
local MockPlayersService = Players
local MockReplicatedStorage = ReplicatedStorage
local MockStarterGuiService = StarterGui
local MockLighting = Lighting
local MockSoundService = SoundService
local MockTextChatService = TextChatService
local MockGeneralChannel = generalChannel
local MockRunService = RunService
local MockPlayerList = MockPlayers
local MockMakePlayer = makePlayer
local MockRuntimeErrors = RuntimeErrors
local MockTraceLog = TraceLog
local MockWarnMessages = mockWarnMessages
local MockCamera = camera

local Mock = {
	WarnMessages = mockWarnMessages,
	Camera = camera,
	RunService = RunService,
	Players = MockPlayers,
	makePlayer = makePlayer,
	pump = pump,
	clock = function() return VirtualClock end,
	errors = RuntimeErrors,
	trace = TraceLog,
	setMode = function(server, client, studio)
		RunService._server = server
		RunService._client = client
		RunService._studio = studio
		Players.LocalPlayer = server and nil or MockPlayers[1]
	end,
	tweenCount = function() return TweenCount end,
	instanceCount = function() return #InstanceRegistry end,
	signals = newSignal,
	findInstances = function(className)
		local result = {}
		for _, instance in ipairs(InstanceRegistry) do
			if instance.ClassName == className and not instance._destroyed then
				table.insert(result, instance)
			end
		end
		return result
	end,
	resetTrace = function()
		for i = #TraceLog, 1, -1 do
			table.remove(TraceLog, i)
		end
	end,
}
