local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer

local function protectGui(gui)
	if gui and syn and syn.protect_gui then
		pcall(syn.protect_gui, gui)
	end
	if gui and gethui then
		gui.Parent = gethui()
		return
	end
	if gui and get_hidden_gui then
		gui.Parent = get_hidden_gui()
		return
	end
	local ok = pcall(function()
		gui.Parent = CoreGui
	end)
	if not ok then
		gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end
end

local function safeDestroy(obj)
	if obj and obj.Destroy then
		pcall(function()
			obj:Destroy()
		end)
	end
end

local function round(num, places)
	local mult = 10 ^ (places or 0)
	return math.floor(num * mult + 0.5) / mult
end

local function deepCopy(tbl)
	if type(tbl) ~= "table" then
		return tbl
	end
	local copy = {}
	for k, v in pairs(tbl) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local Library = {
	Version = "1.2.0-compat",
	Flags = {},
	Options = {},
	Toggles = {},
	Labels = {},
	Theme = {
		Background = Color3.fromRGB(20, 20, 24),
		Surface = Color3.fromRGB(28, 28, 34),
		SurfaceAlt = Color3.fromRGB(34, 34, 42),
		Outline = Color3.fromRGB(52, 52, 64),
		Accent = Color3.fromRGB(120, 160, 255),
		AccentDark = Color3.fromRGB(86, 118, 196),
		Text = Color3.fromRGB(235, 235, 240),
		SubText = Color3.fromRGB(170, 170, 182),
		Danger = Color3.fromRGB(220, 90, 90),
		Success = Color3.fromRGB(90, 200, 120),
		Font = Enum.Font.Gotham,
		CornerRadius = 6,
	},
	Registry = {},
	Connections = {},
	UnloadCallbacks = {},
	Unloaded = false,
	ForceCheckbox = false,
	NotifySide = "Right",
}

local env = (getgenv and getgenv()) or _G
env.Toggles = env.Toggles or Library.Toggles
env.Options = env.Options or Library.Options
env.Library = env.Library or Library

function Library:SafeCallback(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[UI Library Callback Error]: " .. tostring(err))
	end
end

function Library:Connect(signal, fn)
	local conn = signal:Connect(fn)
	table.insert(self.Connections, conn)
	return conn
end

function Library:OnUnload(callback)
	if type(callback) == "function" then
		table.insert(self.UnloadCallbacks, callback)
	end
end

function Library:Unload()
	if self.Unloaded then
		return
	end
	self.Unloaded = true
	for _, cb in ipairs(self.UnloadCallbacks) do
		self:SafeCallback(cb)
	end
	for _, conn in ipairs(self.Connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	table.clear(self.Connections)
	if self.ScreenGui then
		safeDestroy(self.ScreenGui)
	end
end

function Library:Toggle(value)
	if self.ActiveWindow and self.ActiveWindow.Toggle then
		return self.ActiveWindow:Toggle(value)
	end
end

function Library:ToggleUI(value)
	return self:Toggle(value)
end

function Library:SetWatermark(_) end
function Library:SetWatermarkVisibility(_) end

local function create(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function addCorner(parent, radius)
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius or Library.Theme.CornerRadius),
		Parent = parent,
	})
end

local function addStroke(parent, color, transparency)
	return create("UIStroke", {
		Color = color or Library.Theme.Outline,
		Transparency = transparency or 0,
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

local function addPadding(parent, p)
	local pad = typeof(p) == "number" and p or 8
	return create("UIPadding", {
		PaddingTop = UDim.new(0, pad),
		PaddingBottom = UDim.new(0, pad),
		PaddingLeft = UDim.new(0, pad),
		PaddingRight = UDim.new(0, pad),
		Parent = parent,
	})
end

local function tween(obj, info, props)
	local t = TweenService:Create(obj, info, props)
	t:Play()
	return t
end

local function getTextSize(text, size, font, maxWidth)
	local params = Vector2.new(maxWidth or 10000, 10000)
	local ok, result = pcall(function()
		return TextService:GetTextSize(text or "", size or 14, font or Enum.Font.Gotham, params)
	end)
	if ok and result then
		return result
	end
	return Vector2.new(#tostring(text or "") * 7, size or 14)
end

local function getMouseLocation()
	local loc = UserInputService:GetMouseLocation()
	local inset = GuiService:GetGuiInset()
	return Vector2.new(loc.X, loc.Y - inset.Y)
end

local function makeDraggable(handle, target)
	local dragging = false
	local dragStart
	local startPos

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = target.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragging then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local delta = input.Position - dragStart
		target.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end)
end

local function resolveIcon(icon)
	if type(icon) == "number" then
		return "rbxassetid://" .. tostring(icon)
	end
	if type(icon) == "string" and icon ~= "" then
		if icon:match("^rbxasset") or icon:match("^http") then
			return icon
		end
	end
	return nil
end

function Library:Notify(message, duration, title)
	if type(message) == "table" then
		local info = message
		message = info.Description or info.Text or info.Message or info.Title or ""
		duration = info.Time or info.Duration or duration
		title = info.Title or title
	end
	duration = tonumber(duration) or 3
	title = title or "Notification"

	if not self.NotificationHolder or not self.NotificationHolder.Parent then
		return
	end

	local card = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		Parent = self.NotificationHolder,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	addCorner(card, self.Theme.CornerRadius)
	addStroke(card, self.Theme.Outline)
	addPadding(card, 10)

	local titleLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = self.Theme.Font,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = self.Theme.Text,
		Text = tostring(title),
		Parent = card,
	})

	local msgLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = self.Theme.Font,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = self.Theme.SubText,
		Text = tostring(message),
		Parent = card,
	})

	card.BackgroundTransparency = 1
	titleLabel.TextTransparency = 1
	msgLabel.TextTransparency = 1
	tween(card, TweenInfo.new(0.2), { BackgroundTransparency = 0 })
	tween(titleLabel, TweenInfo.new(0.2), { TextTransparency = 0 })
	tween(msgLabel, TweenInfo.new(0.2), { TextTransparency = 0 })

	task.delay(duration, function()
		if not card or not card.Parent then
			return
		end
		tween(card, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
		tween(titleLabel, TweenInfo.new(0.2), { TextTransparency = 1 })
		tween(msgLabel, TweenInfo.new(0.2), { TextTransparency = 1 })
		task.wait(0.22)
		safeDestroy(card)
	end)
end

local function createBaseElement(container, height)
	return create("Frame", {
		Size = UDim2.new(1, 0, 0, height or 32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = container,
	})
end

local function bindHover(button, normal, hover)
	button.MouseEnter:Connect(function()
		tween(button, TweenInfo.new(0.12), { BackgroundColor3 = hover })
	end)
	button.MouseLeave:Connect(function()
		tween(button, TweenInfo.new(0.12), { BackgroundColor3 = normal })
	end)
end

local function createOptionObject(kind, id, defaults)
	local obj = {
		Type = kind,
		Idx = id,
		Value = defaults.Value,
		ChangedCallbacks = {},
	}
	function obj:OnChanged(fn)
		table.insert(self.ChangedCallbacks, fn)
		if self.Value ~= nil then
			Library:SafeCallback(fn, self.Value)
		end
		return fn
	end
	function obj:Fire(value, ...)
		self.Value = value
		Library.Flags[self.Idx] = value
		if self.Type == "Toggle" then
			Library.Toggles[self.Idx] = self
		else
			Library.Options[self.Idx] = self
		end
		for _, fn in ipairs(self.ChangedCallbacks) do
			Library:SafeCallback(fn, value, ...)
		end
		if self.Callback then
			Library:SafeCallback(self.Callback, value, ...)
		end
	end
	function obj:SetValue(value)
		if self._setter then
			self._setter(value)
		else
			self:Fire(value)
		end
	end
	function obj:Destroy()
		if self.Instance then
			safeDestroy(self.Instance)
		end
	end
	return obj
end

function Library:CreateWindow(config)
	config = config or {}
	local selfLib = self

	local windowTitle = config.Title or "UI Library"
	local footerText = config.Footer or ""
	local toggleKey = config.ToggleKeybind or config.MenuKeybind or Enum.KeyCode.RightControl
	local size = config.Size or UDim2.fromOffset(620, 420)
	local position = config.Position or UDim2.fromScale(0.5, 0.5)

	local screenGui = create("ScreenGui", {
		Name = "ObsidianCompat",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	protectGui(screenGui)
	self.ScreenGui = screenGui
	selfLib.NotifySide = config.NotifySide or selfLib.NotifySide

	local notifyHolder = create("Frame", {
		Name = "Notifications",
		AnchorPoint = selfLib.NotifySide == "Left" and Vector2.new(0, 1) or Vector2.new(1, 1),
		Position = selfLib.NotifySide == "Left" and UDim2.new(0, 20, 1, -20) or UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(260, 400),
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = selfLib.NotifySide == "Left" and Enum.HorizontalAlignment.Left or Enum.HorizontalAlignment.Right,
		}),
	})
	self.NotificationHolder = notifyHolder

	local main = create("Frame", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		BackgroundColor3 = self.Theme.Background,
		BorderSizePixel = 0,
		Parent = screenGui,
	})
	addCorner(main, self.Theme.CornerRadius)
	addStroke(main, self.Theme.Outline)

	local topbar = create("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		Parent = main,
	})
	addCorner(topbar, self.Theme.CornerRadius)
	create("Frame", {
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -6),
		Size = UDim2.new(1, 0, 0, 6),
		Parent = topbar,
	})

	local titleLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -120, 1, 0),
		Font = self.Theme.Font,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = self.Theme.Text,
		Text = windowTitle,
		Parent = topbar,
	})

	local toggleButton = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = self.Theme.SurfaceAlt,
		BorderSizePixel = 0,
		Font = self.Theme.Font,
		Text = "-",
		TextSize = 18,
		TextColor3 = self.Theme.Text,
		AutoButtonColor = false,
		Parent = topbar,
	})
	addCorner(toggleButton, self.Theme.CornerRadius)
	addStroke(toggleButton, self.Theme.Outline)
	bindHover(toggleButton, self.Theme.SurfaceAlt, self.Theme.Outline)

	makeDraggable(topbar, main)

	local body = create("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		BackgroundTransparency = 1,
		Parent = main,
	})

	local sidebar = create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 170, 1, 0),
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		Parent = body,
	})
	create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = self.Theme.Outline,
		BorderSizePixel = 0,
		Parent = sidebar,
	})

	local tabButtons = create("ScrollingFrame", {
		Name = "TabButtons",
		Size = UDim2.new(1, 0, 1, -34),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = self.Theme.Outline,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = sidebar,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabButtons,
	})
	addPadding(tabButtons, 8)

	local footer = create("TextLabel", {
		Name = "Footer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -8),
		Size = UDim2.new(1, -20, 0, 18),
		BackgroundTransparency = 1,
		Font = self.Theme.Font,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = self.Theme.SubText,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = footerText,
		Parent = sidebar,
	})

	local pages = create("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(170, 0),
		Size = UDim2.new(1, -170, 1, 0),
		BackgroundTransparency = 1,
		Parent = body,
	})

	local Window = {
		Library = selfLib,
		Main = main,
		Topbar = topbar,
		Sidebar = sidebar,
		Pages = pages,
		TitleLabel = titleLabel,
		FooterLabel = footer,
		Tabs = {},
		Visible = true,
		ToggleKeybind = toggleKey,
		Minimized = false,
	}

	function Window:ChangeTitle(text)
		self.TitleLabel.Text = tostring(text or "")
	end

	function Window:SetFooter(text)
		self.FooterLabel.Text = tostring(text or "")
	end

	function Window:SetAlwaysOnTop(state)
		screenGui.DisplayOrder = state and 999999 or 0
	end

	function Window:SetBackgroundImage(_) end
	function Window:SetCornerRadius(_) end
	function Window:SetSnapping(_) end
	function Window:ShowTabInfo(_, _) end
	function Window:HideTabInfo() end
	function Window:GetSidebarWidth()
		return self.Sidebar.AbsoluteSize.X
	end
	function Window:IsSidebarCompacted()
		return false
	end
	function Window:SetSidebarWidth(width)
		self.Sidebar.Size = UDim2.new(0, math.max(120, tonumber(width) or 170), 1, 0)
		self.Pages.Position = UDim2.fromOffset(self.Sidebar.Size.X.Offset, 0)
		self.Pages.Size = UDim2.new(1, -self.Sidebar.Size.X.Offset, 1, 0)
	end
	function Window:SetCompact(_) end
	function Window:SetAnimations() end

	function Window:Toggle(force)
		local state = force
		if state == nil then
			state = not self.Visible
		end
		self.Visible = state
		self.Main.Visible = state
		return state
	end

	local function createTabButton(name, icon, order)
		local button = create("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			LayoutOrder = order or 0,
			BackgroundColor3 = selfLib.Theme.SurfaceAlt,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Parent = tabButtons,
		})
		addCorner(button, selfLib.Theme.CornerRadius)
		addStroke(button, selfLib.Theme.Outline)

		local iconImage
		local iconAsset = resolveIcon(icon)
		if iconAsset then
			iconImage = create("ImageLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Image = iconAsset,
				Parent = button,
			})
		end

		local label = create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(iconImage and 30 or 10, 0),
			Size = UDim2.new(1, iconImage and -36 or -16, 1, 0),
			Font = selfLib.Theme.Font,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = selfLib.Theme.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = tostring(name),
			Parent = button,
		})

		return button, label
	end

	local function createPageContainer()
		local page = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = pages,
		})

		local scroll = create("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = selfLib.Theme.Outline,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = page,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = scroll,
		})
		addPadding(scroll, 10)

		local columns = create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = scroll,
		})

		local left = create("Frame", {
			Size = UDim2.new(0.5, -5, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = columns,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = left,
		})

		local right = create("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.5, -5, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = columns,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = right,
		})

		return page, left, right
	end

	local function attachGroupboxMethods(groupbox)
		function groupbox:SetVisible(state)
			if self.Container then
				self.Container.Visible = state and true or false
			end
		end
		function groupbox:Show()
			self:SetVisible(true)
		end
		function groupbox:Hide()
			self:SetVisible(false)
		end
		function groupbox:SetDescription(text)
			if self.DescriptionLabel then
				self.DescriptionLabel.Text = text or ""
				self.DescriptionLabel.Visible = text ~= nil and text ~= ""
			end
		end
		function groupbox:SetMaxHeight(_) end
		function groupbox:SetPoppedOut(_) end
		function groupbox:TogglePoppedOut() end
		function groupbox:SetMaxPopOutHeight(_) end
		function groupbox:SetPopOutWidth(_) end
		function groupbox:Resize() end
	end

	local function createGroupbox(parent, info)
		info = info or {}
		local container = create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = selfLib.Theme.Surface,
			BorderSizePixel = 0,
			Parent = parent,
		})
		addCorner(container, selfLib.Theme.CornerRadius)
		addStroke(container, selfLib.Theme.Outline)

		local bodyFrame = create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = container,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = bodyFrame,
		})
		addPadding(bodyFrame, 10)

		local title = create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Font = selfLib.Theme.Font,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = selfLib.Theme.Text,
			Text = tostring(info.Name or "Groupbox"),
			Parent = bodyFrame,
		})

		local desc = create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = selfLib.Theme.Font,
			TextSize = 12,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = selfLib.Theme.SubText,
			Text = tostring(info.Description or ""),
			Visible = info.Description ~= nil and info.Description ~= "",
			Parent = bodyFrame,
		})

		local elementsHolder = create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = bodyFrame,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = elementsHolder,
		})

		local groupbox = {
			Container = container,
			Holder = elementsHolder,
			DescriptionLabel = desc,
			Elements = {},
		}
		attachGroupboxMethods(groupbox)

		function groupbox:AddDivider()
			local div = create("Frame", {
				Size = UDim2.new(1, 0, 0, 1),
				BackgroundColor3 = selfLib.Theme.Outline,
				BorderSizePixel = 0,
				Parent = self.Holder,
			})
			return div
		end

		function groupbox:AddLabel(arg1, arg2, arg3)
			local text, doesWrap, idx
			local info
			if type(arg1) == "table" then
				info = arg1
				text = info.Text or info.Name or ""
				doesWrap = info.DoesWrap
				idx = info.Idx or info.Index
			elseif type(arg2) == "table" then
				idx = arg1
				info = arg2
				text = info.Text or info.Name or tostring(idx or "")
				doesWrap = info.DoesWrap
			else
				text = arg1
				doesWrap = arg2
				idx = arg3
			end
			if doesWrap == nil then
				doesWrap = false
			end

			local wrapper = create("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent = self.Holder,
			})

			local addons = create("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundTransparency = 1,
				Parent = wrapper,
			})
			local addonsLayout = create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = addons,
			})

			local label = create("TextLabel", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextWrapped = doesWrap and true or false,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = selfLib.Theme.SubText,
				Text = tostring(text or ""),
				Parent = wrapper,
			})

			local function updateLabelPadding()
				local pad = addonsLayout.AbsoluteContentSize.X
				if pad > 0 then
					pad += 6
				end
				label.Size = UDim2.new(1, -pad, 0, 0)
			end
			addonsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateLabelPadding)

			local obj = {
				Instance = wrapper,
				TextLabel = label,
				Addons = addons,
			}
			function obj:SetText(newText)
				label.Text = tostring(newText or "")
			end

			function obj:AddColorPicker(cid, cinfo)
				local idArg, infoArg = cid, cinfo
				if type(cid) == "table" then
					infoArg = cid
					idArg = infoArg.Flag or infoArg.Idx or infoArg.Index or ("LabelColor_" .. HttpService:GenerateGUID(false))
				end
				infoArg = infoArg or {}
				local default = infoArg.Default or Color3.new(1, 1, 1)
				local picker = createOptionObject("ColorPicker", idArg, { Value = default })
				picker.Callback = infoArg.Callback
				picker.Transparency = infoArg.Transparency or 0
				local swatch = create("TextButton", {
					Size = UDim2.fromOffset(28, 18),
					BackgroundColor3 = default,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Text = "",
					Parent = addons,
				})
				addCorner(swatch, 4)
				addStroke(swatch, selfLib.Theme.Outline)
				local palette = {
					Color3.fromRGB(255,255,255), Color3.fromRGB(255,90,90), Color3.fromRGB(255,170,70),
					Color3.fromRGB(255,230,90), Color3.fromRGB(120,220,120), Color3.fromRGB(120,180,255),
					Color3.fromRGB(180,120,255), Color3.fromRGB(0,0,0),
				}
				local index = 1
				swatch.MouseButton1Click:Connect(function()
					index += 1
					if index > #palette then index = 1 end
					picker:SetValue(palette[index])
				end)
				picker._setter = function(value)
					local color = typeof(value) == "Color3" and value or default
					swatch.BackgroundColor3 = color
					picker:Fire(color, picker.Transparency)
				end
				function picker:SetValueRGB(r,g,b) picker:SetValue(Color3.fromRGB(r,g,b)) end
				function picker:SetValueHSV(h,s,v) picker:SetValue(Color3.fromHSV(h,s,v)) end
				function picker:SetText(_) end
				function picker:AddColorPicker(cid2, cinfo2) return obj:AddColorPicker(cid2, cinfo2) end
				function picker:AddKeyPicker(kid2, kinfo2) return obj:AddKeyPicker(kid2, kinfo2) end
				picker:SetValue(default)
				selfLib.Options[idArg] = picker
				selfLib.Flags[idArg] = picker.Value
				task.defer(updateLabelPadding)
				return picker
			end

			function obj:AddKeyPicker(cid, cinfo)
				local idArg, infoArg = cid, cinfo
				if type(cid) == "table" then
					infoArg = cid
					idArg = infoArg.Flag or infoArg.Idx or infoArg.Index or ("LabelKey_" .. HttpService:GenerateGUID(false))
				end
				infoArg = infoArg or {}
				local picker = createOptionObject("KeyPicker", idArg, { Value = infoArg.Default or "None" })
				picker.Mode = infoArg.Mode or "Toggle"
				picker.Callback = infoArg.Callback
				picker.ChangedCallback = infoArg.ChangedCallback
				picker.Toggled = false
				picker.ClickCallbacks = {}
				picker.ChangedCallbacks2 = {}
				picker.Modifiers = {}
				local keyBtn = create("TextButton", {
					Size = UDim2.fromOffset(64, 18),
					BackgroundColor3 = selfLib.Theme.SurfaceAlt,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Font = selfLib.Theme.Font,
					TextSize = 12,
					TextColor3 = selfLib.Theme.Text,
					Text = tostring(picker.Value),
					Parent = addons,
				})
				addCorner(keyBtn, 4)
				addStroke(keyBtn, selfLib.Theme.Outline)

				local function keyToString(input)
					if input.UserInputType == Enum.UserInputType.Keyboard then return input.KeyCode.Name end
					if input.UserInputType == Enum.UserInputType.MouseButton1 then return "MB1" end
					if input.UserInputType == Enum.UserInputType.MouseButton2 then return "MB2" end
					if input.UserInputType == Enum.UserInputType.MouseButton3 then return "MB3" end
					return nil
				end
				local function matchesInput(input)
					local key = tostring(picker.Value)
					if key == "None" or key == "" then return false end
					if input.UserInputType == Enum.UserInputType.Keyboard then return input.KeyCode.Name == key end
					if input.UserInputType == Enum.UserInputType.MouseButton1 then return key == "MB1" end
					if input.UserInputType == Enum.UserInputType.MouseButton2 then return key == "MB2" end
					if input.UserInputType == Enum.UserInputType.MouseButton3 then return key == "MB3" end
					return false
				end
				local function fireClick(state)
					selfLib:SafeCallback(picker.Callback, state)
					for _, cb in ipairs(picker.ClickCallbacks) do selfLib:SafeCallback(cb, state) end
				end
				local function fireChanged(key, mods)
					selfLib:SafeCallback(picker.ChangedCallback, key, mods)
					for _, cb in ipairs(picker.ChangedCallbacks2) do selfLib:SafeCallback(cb, key, mods) end
				end

				local listening = false
				keyBtn.MouseButton1Click:Connect(function()
					listening = true
					keyBtn.Text = "..."
				end)
				selfLib:Connect(UserInputService.InputBegan, function(input, gpe)
					if listening then
						local keyStr = keyToString(input)
						if keyStr then
							picker:SetValue(keyStr)
							listening = false
							fireChanged(picker.Value, picker.Modifiers)
							return
						end
						if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Escape then
							picker:SetValue("None")
							listening = false
							fireChanged(picker.Value, picker.Modifiers)
						end
						return
					end
					if not matchesInput(input) then return end
					if gpe and input.UserInputType == Enum.UserInputType.Keyboard then return end
					if picker.Mode == "Toggle" then
						picker.Toggled = not picker.Toggled
						fireClick(picker.Toggled)
					elseif picker.Mode == "Always" or picker.Mode == "Press" then
						fireClick(true)
					elseif picker.Mode == "Hold" then
						picker.Toggled = true
						fireClick(true)
					end
				end)
				selfLib:Connect(UserInputService.InputEnded, function(input)
					if not matchesInput(input) then return end
					if picker.Mode == "Hold" then
						picker.Toggled = false
						fireClick(false)
					end
				end)

				picker._setter = function(value)
					if type(value) == "table" then
						if value[1] ~= nil then
							picker.Value = value[1]
						end
						if value[2] and type(value[2]) == "string" then
							picker.Mode = value[2]
						end
						if type(value.Modifiers) == "table" then
							picker.Modifiers = value.Modifiers
						end
					else
						picker.Value = value or "None"
					end
					keyBtn.Text = tostring(picker.Value)
					selfLib.Flags[idArg] = picker.Value
				end
				function picker:SetValue(v)
					local old = picker.Value
					picker._setter(v)
					if old ~= picker.Value then
						fireChanged(picker.Value, picker.Modifiers)
					end
				end
				function picker:GetState() return picker.Toggled == true end
				function picker:OnClick(cb) if type(cb) == "function" then table.insert(picker.ClickCallbacks, cb) end return cb end
				function picker:OnChanged(cb) if type(cb) == "function" then table.insert(picker.ChangedCallbacks2, cb) end return cb end
				function picker:SetText(_) end
				function picker:Update() end
				function picker:AddColorPicker(cid2, cinfo2) return obj:AddColorPicker(cid2, cinfo2) end
				function picker:AddKeyPicker(kid2, kinfo2) return obj:AddKeyPicker(kid2, kinfo2) end
				picker._setter(infoArg.Default or "None")
				selfLib.Options[idArg] = picker
				selfLib.Flags[idArg] = picker.Value
				task.defer(updateLabelPadding)
				return picker
			end

			function obj:AddDropdown(cid, cinfo)
				local idArg, infoArg = cid, cinfo
				if type(cid) == "table" then
					infoArg = cid
					idArg = infoArg.Flag or infoArg.Idx or infoArg.Index or ("LabelDropdown_" .. HttpService:GenerateGUID(false))
				end
				infoArg = infoArg or {}
				local dd = groupbox:AddDropdown(idArg, infoArg)
				if dd and dd.Instance then
					dd.Instance.Size = UDim2.new(0, 140, 0, 52)
					dd.Instance.Parent = addons
				end
				task.defer(updateLabelPadding)
				return dd
			end

			updateLabelPadding()
			if idx then
				selfLib.Registry[idx] = obj
				if selfLib.Labels == nil then
					selfLib.Labels = {}
				end
				selfLib.Labels[idx] = obj
			end
			return obj
		end

		function groupbox:AddButton(arg1, arg2)
			local info
			if type(arg1) == "table" then
				info = arg1
			else
				info = { Text = arg1, Func = arg2 }
			end
			info = info or {}
			local text = info.Text or info.Name or "Button"
			local func = info.Func or info.Callback or info.Function

			local wrapper = createBaseElement(self.Holder, 32)
			local button = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextColor3 = selfLib.Theme.Text,
				Text = tostring(text),
				Parent = wrapper,
			})
			addCorner(button, selfLib.Theme.CornerRadius)
			addStroke(button, selfLib.Theme.Outline)
			bindHover(button, selfLib.Theme.SurfaceAlt, selfLib.Theme.Outline)

			local obj = { Instance = wrapper, Button = button, Text = text }
			button.MouseButton1Click:Connect(function()
				selfLib:SafeCallback(func)
			end)

			function obj:SetText(newText)
				obj.Text = tostring(newText or "")
				button.Text = obj.Text
			end
			function obj:SetIcon(_) end
			function obj:AddButton(subInfo)
				subInfo = subInfo or {}
				local subText = subInfo.Text or subInfo.Name or "Sub Button"
				local subFunc = subInfo.Func or subInfo.Callback or subInfo.Function
				wrapper.Size = UDim2.new(1, 0, 0, 68)
				local sub = create("TextButton", {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.new(0, 0, 1, 0),
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundColor3 = selfLib.Theme.SurfaceAlt,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Font = selfLib.Theme.Font,
					TextSize = 13,
					TextColor3 = selfLib.Theme.Text,
					Text = tostring(subText),
					Parent = wrapper,
				})
				addCorner(sub, selfLib.Theme.CornerRadius)
				addStroke(sub, selfLib.Theme.Outline)
				bindHover(sub, selfLib.Theme.SurfaceAlt, selfLib.Theme.Outline)
				button.Size = UDim2.new(1, 0, 0, 32)
				sub.MouseButton1Click:Connect(function()
					selfLib:SafeCallback(subFunc)
				end)
				return sub
			end
			function obj:AddKeyPicker(idOrConfig, keyConfig)
				local pid, pcfg
				if type(idOrConfig) == "table" then
					pcfg = idOrConfig
					pid = pcfg.Flag or pcfg.Idx or pcfg.Index or ("ButtonKey_" .. HttpService:GenerateGUID(false))
				else
					pid = idOrConfig or ("ButtonKey_" .. HttpService:GenerateGUID(false))
					pcfg = keyConfig or {}
				end
				return groupbox:AddKeyPicker(pid, pcfg)
			end

			return obj
		end

		function groupbox:AddToggle(id, info)
			info = info or {}
			local text = info.Text or info.Title or info.Name or id
			local toggle = createOptionObject("Toggle", id, { Value = info.Default == true })
			toggle.Callback = info.Callback
			local wrapper = createBaseElement(self.Holder, 30)

			local button = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				Parent = wrapper,
			})

			local box = create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 0, 0.5, 0),
				Size = UDim2.fromOffset(18, 18),
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				Parent = button,
			})
			addCorner(box, 4)
			addStroke(box, selfLib.Theme.Outline)

			local fill = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = selfLib.Theme.Accent,
				BorderSizePixel = 0,
				Visible = toggle.Value,
				Parent = box,
			})
			addCorner(fill, 3)

			local label = create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(26, 0),
				Size = UDim2.new(1, -26, 1, 0),
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = selfLib.Theme.Text,
				Text = tostring(text),
				Parent = button,
			})

			local function render()
				fill.Visible = toggle.Value and true or false
				box.BackgroundColor3 = toggle.Value and selfLib.Theme.AccentDark or selfLib.Theme.SurfaceAlt
				label.TextColor3 = toggle.Disabled and selfLib.Theme.SubText or selfLib.Theme.Text
			end

			toggle.Instance = wrapper
			toggle.Disabled = info.Disabled == true
			toggle._setter = function(value)
				if toggle.Disabled then
					return
				end
				toggle:Fire(value and true or false)
				render()
			end

			button.MouseButton1Click:Connect(function()
				if toggle.Disabled then
					return
				end
				toggle:SetValue(not toggle.Value)
			end)

			function toggle:SetText(newText)
				label.Text = tostring(newText or "")
			end
			function toggle:SetDisabled(state)
				toggle.Disabled = state and true or false
				render()
			end
			function toggle:SetVisible(state)
				wrapper.Visible = state and true or false
			end
			function toggle:AddKeyPicker(kid, kinfo)
				local idArg, infoArg = kid, kinfo
				if type(kid) == "table" then
					infoArg = kid
					idArg = infoArg.Flag or infoArg.Idx or infoArg.Index or (id .. "_KeyPicker")
				end
				infoArg = infoArg or {}
				local picker = groupbox:AddKeyPicker(idArg, infoArg)
				if picker and infoArg.SyncToggleState and (picker.Mode == "Toggle" or picker.Mode == nil) and picker.OnClick then
					picker:OnClick(function(state)
						if type(state) == "boolean" then
							toggle:SetValue(state)
						end
					end)
				end
				if picker then
					function picker:AddColorPicker(cid2, cinfo2)
						return toggle:AddColorPicker(cid2, cinfo2)
					end
					function picker:AddKeyPicker(kid2, kinfo2)
						return toggle:AddKeyPicker(kid2, kinfo2)
					end
				end
				return picker
			end
			function toggle:AddColorPicker(cid, cinfo)
				local idArg, infoArg = cid, cinfo
				if type(cid) == "table" then
					infoArg = cid
					idArg = infoArg.Flag or infoArg.Idx or infoArg.Index or (id .. "_ColorPicker")
				end
				local picker = groupbox:AddColorPicker(idArg, infoArg or {})
				if picker then
					function picker:AddColorPicker(cid2, cinfo2)
						return toggle:AddColorPicker(cid2, cinfo2)
					end
					function picker:AddKeyPicker(kid2, kinfo2)
						return toggle:AddKeyPicker(kid2, kinfo2)
					end
				end
				return picker
			end

			render()
			selfLib.Toggles[id] = toggle
			selfLib.Flags[id] = toggle.Value
			return toggle
		end

		function groupbox:AddSlider(id, info)
			info = info or {}
			local minValue = tonumber(info.Min) or 0
			local maxValue = tonumber(info.Max) or 100
			local rounding = tonumber(info.Rounding) or 0
			local default = tonumber(info.Default) or minValue
			default = math.clamp(default, minValue, maxValue)
			local slider = createOptionObject("Slider", id, { Value = default })
			slider.Callback = info.Callback
			slider.Min = minValue
			slider.Max = maxValue
			slider.Rounding = rounding

			local wrapper = createBaseElement(self.Holder, 46)
			local titleRow = create("Frame", {
				Size = UDim2.new(1, 0, 0, 18),
				BackgroundTransparency = 1,
				Parent = wrapper,
			})

			local label = create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -80, 1, 0),
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = selfLib.Theme.Text,
				Text = tostring(info.Text or id),
				Parent = titleRow,
			})

			local valueLabel = create("TextLabel", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 80, 1, 0),
				Font = selfLib.Theme.Font,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = selfLib.Theme.SubText,
				Text = "",
				Parent = titleRow,
			})

			local bar = create("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 16),
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				Parent = wrapper,
			})
			addCorner(bar, 6)
			addStroke(bar, selfLib.Theme.Outline)

			local fill = create("Frame", {
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = selfLib.Theme.Accent,
				BorderSizePixel = 0,
				Parent = bar,
			})
			addCorner(fill, 6)

			local function formatValue(val)
				local shown = round(val, rounding)
				local str = tostring(shown)
				if info.Prefix then
					str = tostring(info.Prefix) .. str
				end
				if info.Suffix then
					str = str .. tostring(info.Suffix)
				end
				return str
			end

			local function setFromAlpha(alpha)
				alpha = math.clamp(alpha, 0, 1)
				local raw = slider.Min + (slider.Max - slider.Min) * alpha
				local stepped = round(raw, rounding)
				stepped = math.clamp(stepped, slider.Min, slider.Max)
				slider:Fire(stepped)
				local ratio = 0
				if slider.Max ~= slider.Min then
					ratio = (stepped - slider.Min) / (slider.Max - slider.Min)
				end
				fill.Size = UDim2.fromScale(ratio, 1)
				valueLabel.Text = formatValue(stepped)
			end

			local dragging = false
			local function updateFromInput(input)
				local absPos = bar.AbsolutePosition.X
				local absSize = bar.AbsoluteSize.X
				if absSize <= 0 then
					return
				end
				local alpha = (input.Position.X - absPos) / absSize
				setFromAlpha(alpha)
			end

			bar.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					updateFromInput(input)
				end
			end)

			bar.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end)

			selfLib:Connect(UserInputService.InputChanged, function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
					updateFromInput(input)
				end
			end)

			slider.Instance = wrapper
			slider._setter = function(value)
				local num = tonumber(value)
				if num == nil then
					return
				end
				num = math.clamp(round(num, slider.Rounding), slider.Min, slider.Max)
				slider:Fire(num)
				local ratio = 0
				if slider.Max ~= slider.Min then
					ratio = (num - slider.Min) / (slider.Max - slider.Min)
				end
				fill.Size = UDim2.fromScale(ratio, 1)
				valueLabel.Text = formatValue(num)
			end

			function slider:SetText(text)
				label.Text = tostring(text or "")
			end
			function slider:SetMin(v)
				slider.Min = tonumber(v) or slider.Min
				slider:SetValue(slider.Value)
			end
			function slider:SetMax(v)
				slider.Max = tonumber(v) or slider.Max
				slider:SetValue(slider.Value)
			end
			function slider:SetDisabled(state)
				slider.Disabled = state and true or false
				wrapper.Active = not slider.Disabled
			end
			function slider:SetVisible(state)
				wrapper.Visible = state and true or false
			end
			function slider:SetPrefix(v)
				info.Prefix = v
				slider:SetValue(slider.Value)
			end
			function slider:SetSuffix(v)
				info.Suffix = v
				slider:SetValue(slider.Value)
			end

			slider:SetValue(default)
			selfLib.Options[id] = slider
			selfLib.Flags[id] = slider.Value
			return slider
		end

		function groupbox:AddInput(id, info)
			info = info or {}
			local default = info.Default
			if default == nil then
				default = ""
			end
			local inputObj = createOptionObject("Input", id, { Value = info.Numeric and tonumber(default) or tostring(default) })
			inputObj.Callback = info.Callback
			local wrapper = createBaseElement(self.Holder, 52)

			local label = create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 18),
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = selfLib.Theme.Text,
				Text = tostring(info.Text or info.Title or id),
				Parent = wrapper,
			})

			local box = create("TextBox", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				ClearTextOnFocus = info.ClearTextOnFocus == true,
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextColor3 = selfLib.Theme.Text,
				PlaceholderText = tostring(info.Placeholder or ""),
				PlaceholderColor3 = selfLib.Theme.SubText,
				Text = tostring(default),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = wrapper,
			})
			addCorner(box, selfLib.Theme.CornerRadius)
			addStroke(box, selfLib.Theme.Outline)
			addPadding(box, 6)

			local function commit(text)
				local value = text
				if info.Numeric then
					local n = tonumber(text)
					if n == nil then
						box.Text = tostring(inputObj.Value or "")
						return
					end
					value = n
				end
				if info.Finished then
					inputObj:Fire(value)
				else
					inputObj:Fire(value)
				end
			end

			box.FocusLost:Connect(function(enterPressed)
				if info.Finished and not enterPressed then
					return
				end
				commit(box.Text)
			end)

			if not info.Finished then
				box:GetPropertyChangedSignal("Text"):Connect(function()
					commit(box.Text)
				end)
			end

			inputObj.Instance = wrapper
			inputObj._setter = function(value)
				local text = tostring(value == nil and "" or value)
				box.Text = text
				inputObj:Fire(info.Numeric and tonumber(text) or text)
			end
			function inputObj:SetText(text)
				label.Text = tostring(text or "")
			end
			function inputObj:SetDisabled(state)
				box.TextEditable = not state
			end
			function inputObj:SetVisible(state)
				wrapper.Visible = state and true or false
			end

			selfLib.Options[id] = inputObj
			selfLib.Flags[id] = inputObj.Value
			return inputObj
		end

		function groupbox:AddTextbox(id, info)
			return self:AddInput(id, info)
		end

		function groupbox:AddDropdown(id, info)
			info = info or {}
			local values = deepCopy(info.Values or {})
			local multi = info.Multi == true
			local isArray = (#values > 0)

			local function normalizeMultiDefault(v)
				if type(v) ~= "table" then
					return {}
				end
				local out = {}
				local count = 0
				for _, _ in pairs(v) do
					count += 1
				end
				if count == #v and #v > 0 then
					for _, item in ipairs(v) do
						out[item] = true
					end
					return out
				end
				for k, val in pairs(v) do
					if val == true then
						out[k] = true
					elseif type(k) == "number" and val ~= nil and val ~= false then
						out[val] = true
					end
				end
				return out
			end

			local default = info.Default
			if multi then
				default = normalizeMultiDefault(default)
			else
				if default == nil and isArray then
					default = values[1]
				elseif type(default) == "number" and isArray and values[default] ~= nil then
					local foundLiteral = false
					for _, v in ipairs(values) do
						if v == default then
							foundLiteral = true
							break
						end
					end
					if not foundLiteral then
						default = values[default]
					end
				end
			end

			local dropdown = createOptionObject("Dropdown", id, { Value = default })
			dropdown.Callback = info.Callback
			dropdown.Values = values
			dropdown.Multi = multi
			dropdown.DisabledValues = {}
			dropdown._normalizeMultiDefault = normalizeMultiDefault

			local wrapper = createBaseElement(self.Holder, 52)
			local label = create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 18),
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = selfLib.Theme.Text,
				Text = tostring(info.Text or info.Title or id),
				Parent = wrapper,
			})

			local button = create("TextButton", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = selfLib.Theme.Text,
				Text = "",
				Parent = wrapper,
			})
			addCorner(button, selfLib.Theme.CornerRadius)
			addStroke(button, selfLib.Theme.Outline)
			addPadding(button, 6)

			local listFrame = create("Frame", {
				Visible = false,
				ClipsDescendants = true,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Position = UDim2.new(0, 0, 1, 4),
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				ZIndex = 20,
				Parent = wrapper,
			})
			addCorner(listFrame, selfLib.Theme.CornerRadius)
			addStroke(listFrame, selfLib.Theme.Outline)
			local listLayout = create("UIListLayout", {
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = listFrame,
			})
			addPadding(listFrame, 6)

			local function isSelected(value)
				if multi then
					return dropdown.Value and dropdown.Value[value] == true
				end
				return dropdown.Value == value
			end

			local function setSelected(value)
				if multi then
					dropdown.Value = dropdown.Value or {}
					if dropdown.Value[value] then
						dropdown.Value[value] = nil
					else
						dropdown.Value[value] = true
					end
					dropdown:Fire(deepCopy(dropdown.Value))
				else
					dropdown:Fire(value)
					listFrame.Visible = false
					wrapper.Size = UDim2.new(1, 0, 0, 52)
				end
				dropdown:Refresh()
			end

			function dropdown:DisplayText()
				if multi then
					local picked = {}
					for _, v in ipairs(dropdown.Values) do
						if dropdown.Value and dropdown.Value[v] then
							table.insert(picked, tostring(v))
						end
					end
					if #picked == 0 then
						return "None"
					end
					return table.concat(picked, ", ")
				end
				return dropdown.Value == nil and "None" or tostring(dropdown.Value)
			end

			function dropdown:Refresh()
				button.Text = self:DisplayText()
				for _, child in ipairs(listFrame:GetChildren()) do
					if child:IsA("TextButton") then
						child:Destroy()
					end
				end
				for _, value in ipairs(dropdown.Values) do
					local optionButton = create("TextButton", {
						Size = UDim2.new(1, 0, 0, 24),
						BackgroundColor3 = isSelected(value) and selfLib.Theme.AccentDark or selfLib.Theme.Surface,
						BorderSizePixel = 0,
						AutoButtonColor = false,
						Font = selfLib.Theme.Font,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextColor3 = selfLib.Theme.Text,
						Text = tostring(value),
						ZIndex = 21,
						Parent = listFrame,
					})
					addCorner(optionButton, 4)
					addPadding(optionButton, 6)
					optionButton.MouseButton1Click:Connect(function()
						setSelected(value)
					end)
				end
			end

			function dropdown:SetValues(newValues)
				dropdown.Values = deepCopy(newValues or {})
				if not multi and dropdown.Value ~= nil then
					local found = false
					for _, v in ipairs(dropdown.Values) do
						if v == dropdown.Value then
							found = true
							break
						end
					end
					if not found then
						dropdown.Value = dropdown.Values[1]
					end
				end
				dropdown:Refresh()
			end
			function dropdown:AddValues(newValues)
				if type(newValues) == "table" then
					for _, v in ipairs(newValues) do
						table.insert(dropdown.Values, v)
					end
				elseif newValues ~= nil then
					table.insert(dropdown.Values, newValues)
				end
				dropdown:Refresh()
			end
			function dropdown:SetDisabledValues(vals)
				dropdown.DisabledValues = deepCopy(vals or {})
				dropdown:Refresh()
			end
			function dropdown:AddDisabledValues(vals)
				dropdown.DisabledValues = dropdown.DisabledValues or {}
				if type(vals) == "table" then
					for _, v in ipairs(vals) do
						table.insert(dropdown.DisabledValues, v)
					end
				elseif vals ~= nil then
					table.insert(dropdown.DisabledValues, vals)
				end
				dropdown:Refresh()
			end
			function dropdown:SetValueImages(_) end
			function dropdown:AddValueImages(_) end
			function dropdown:SetDragSelect(_) end
			function dropdown:SetText(text)
				label.Text = tostring(text or "")
			end
			function dropdown:SetDisabled(state)
				dropdown.Disabled = state and true or false
			end
			function dropdown:SetVisible(state)
				wrapper.Visible = state and true or false
			end
			function dropdown:GetActiveValues(asCount)
				if asCount and multi then
					local n = 0
					for _ in pairs(dropdown.Value or {}) do
						n += 1
					end
					return n
				end
				return deepCopy(dropdown.Value)
			end

			dropdown.Instance = wrapper
			dropdown._setter = function(value)
				if multi then
					dropdown.Value = dropdown._normalizeMultiDefault(value)
				else
					if type(value) == "number" and #dropdown.Values > 0 and dropdown.Values[value] ~= nil then
						local foundLiteral = false
						for _, v in ipairs(dropdown.Values) do
							if v == value then
								foundLiteral = true
								break
							end
						end
						dropdown.Value = foundLiteral and value or dropdown.Values[value]
					else
						dropdown.Value = value
					end
				end
				dropdown:Fire(deepCopy(dropdown.Value))
				dropdown:Refresh()
			end

			button.MouseButton1Click:Connect(function()
				if dropdown.Disabled then
					return
				end
				listFrame.Visible = not listFrame.Visible
				wrapper.Size = UDim2.new(1, 0, 0, listFrame.Visible and math.min(52 + listLayout.AbsoluteContentSize.Y + 12, 220) or 52)
			end)

			listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				if listFrame.Visible then
					wrapper.Size = UDim2.new(1, 0, 0, math.min(52 + listLayout.AbsoluteContentSize.Y + 12, 220))
				end
			end)

			dropdown:Refresh()
			selfLib.Options[id] = dropdown
			selfLib.Flags[id] = dropdown.Value
			return dropdown
		end

		function groupbox:AddKeyPicker(id, info)
			info = info or {}
			local defaultKey = info.Default or "None"
			local picker = createOptionObject("KeyPicker", id, { Value = defaultKey })
			picker.Mode = info.Mode or "Toggle"
			picker.Callback = info.Callback
			picker.Toggled = false
			picker.ClickCallbacks = {}
			picker.SyncToggleState = info.SyncToggleState == true
			picker.NoUI = info.NoUI == true

			local wrapper = createBaseElement(self.Holder, picker.NoUI and 0 or 30)
			if picker.NoUI then
				wrapper.Visible = false
			end

			local label = create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -90, 1, 0),
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = selfLib.Theme.Text,
				Text = tostring(info.Text or info.Title or id),
				Parent = wrapper,
			})

			local button = create("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(84, 24),
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = selfLib.Theme.Font,
				TextSize = 12,
				TextColor3 = selfLib.Theme.Text,
				Text = tostring(picker.Value),
				Parent = wrapper,
			})
			addCorner(button, 4)
			addStroke(button, selfLib.Theme.Outline)

			local function keyToString(input)
				if input.UserInputType == Enum.UserInputType.Keyboard then
					return input.KeyCode.Name
				elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
					return "MB1"
				elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
					return "MB2"
				elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
					return "MB3"
				end
				return nil
			end

			local function matchesInput(input)
				local key = tostring(picker.Value)
				if key == "None" or key == "" then
					return false
				end
				if input.UserInputType == Enum.UserInputType.Keyboard then
					return input.KeyCode.Name == key
				elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
					return key == "MB1"
				elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
					return key == "MB2"
				elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
					return key == "MB3"
				end
				return false
			end

			local function fireClick(state)
				selfLib:SafeCallback(picker.Callback, state)
				for _, cb in ipairs(picker.ClickCallbacks) do
					selfLib:SafeCallback(cb, state)
				end
			end

			local listening = false
			button.MouseButton1Click:Connect(function()
				listening = true
				button.Text = "..."
			end)

			selfLib:Connect(UserInputService.InputBegan, function(input, gpe)
				if listening then
					local keyStr = keyToString(input)
					if keyStr then
						picker:SetValue(keyStr)
						listening = false
						button.Text = tostring(picker.Value)
						return
					end
					if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Escape then
						picker:SetValue("None")
						listening = false
					end
					return
				end

				if not matchesInput(input) then
					return
				end
				if gpe and input.UserInputType == Enum.UserInputType.Keyboard then
					return
				end

				if picker.Mode == "Toggle" then
					picker.Toggled = not picker.Toggled
					fireClick(picker.Toggled)
				elseif picker.Mode == "Always" then
					fireClick(true)
				elseif picker.Mode == "Press" then
					fireClick(true)
				elseif picker.Mode == "Hold" then
					picker.Toggled = true
					fireClick(true)
				end
			end)

			selfLib:Connect(UserInputService.InputEnded, function(input)
				if not matchesInput(input) then
					return
				end
				if picker.Mode == "Hold" then
					picker.Toggled = false
					fireClick(false)
				end
			end)

			picker.Instance = wrapper
			picker._setter = function(value)
				picker.Value = value or "None"
				button.Text = tostring(picker.Value)
				selfLib.Flags[id] = picker.Value
			end
			function picker:SetText(text)
				label.Text = tostring(text or "")
			end
			function picker:SetValue(value)
				picker._setter(value)
			end
			function picker:GetState()
				return picker.Toggled == true
			end
			function picker:OnClick(cb)
				if type(cb) == "function" then
					table.insert(picker.ClickCallbacks, cb)
				end
				return cb
			end
			function picker:Update() end

			selfLib.Options[id] = picker
			selfLib.Flags[id] = picker.Value
			return picker
		end

		function groupbox:AddColorPicker(id, info)
			info = info or {}
			local default = info.Default or Color3.new(1, 1, 1)
			local picker = createOptionObject("ColorPicker", id, { Value = default })
			picker.Callback = info.Callback
			picker.Transparency = info.Transparency or 0

			local wrapper = createBaseElement(self.Holder, 30)
			local label = create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -60, 1, 0),
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = selfLib.Theme.Text,
				Text = tostring(info.Text or info.Title or id),
				Parent = wrapper,
			})
			local swatch = create("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(42, 22),
				BackgroundColor3 = default,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				Parent = wrapper,
			})
			addCorner(swatch, 4)
			addStroke(swatch, selfLib.Theme.Outline)

			local palette = {
				Color3.fromRGB(255, 255, 255),
				Color3.fromRGB(255, 90, 90),
				Color3.fromRGB(255, 170, 70),
				Color3.fromRGB(255, 230, 90),
				Color3.fromRGB(120, 220, 120),
				Color3.fromRGB(120, 180, 255),
				Color3.fromRGB(180, 120, 255),
				Color3.fromRGB(0, 0, 0),
			}
			local index = 1
			swatch.MouseButton1Click:Connect(function()
				index += 1
				if index > #palette then
					index = 1
				end
				picker:SetValue(palette[index])
			end)

			picker.Instance = wrapper
			picker._setter = function(value)
				local color = typeof(value) == "Color3" and value or default
				swatch.BackgroundColor3 = color
				picker:Fire(color, picker.Transparency)
			end
			function picker:SetValueRGB(r, g, b)
				picker:SetValue(Color3.fromRGB(r, g, b))
			end
			function picker:SetValueHSV(h, s, v)
				picker:SetValue(Color3.fromHSV(h, s, v))
			end
			function picker:SetText(text)
				label.Text = tostring(text or "")
			end

			picker:SetValue(default)
			selfLib.Options[id] = picker
			selfLib.Flags[id] = picker.Value
			return picker
		end

		function groupbox:AddDependencyBox()
			return self
		end
		function groupbox:AddDependencyGroupbox()
			return self
		end

		return groupbox
	end

	local function attachTabMethods(tab)
		function tab:UpdateWarningBox(info)
			info = info or {}
			if not self.WarningBox then
				self.WarningBox = create("Frame", {
					Size = UDim2.new(1, -20, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = selfLib.Theme.SurfaceAlt,
					BorderSizePixel = 0,
					LayoutOrder = -1,
					Parent = self.Scroll,
				})
				addCorner(self.WarningBox, selfLib.Theme.CornerRadius)
				addStroke(self.WarningBox, selfLib.Theme.Outline)
				addPadding(self.WarningBox, 8)
				local layout = create("UIListLayout", { Padding = UDim.new(0, 4), Parent = self.WarningBox })
				layout.SortOrder = Enum.SortOrder.LayoutOrder
				self.WarningTitle = create("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 16),
					Font = selfLib.Theme.Font,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = selfLib.Theme.Text,
					Parent = self.WarningBox,
				})
				self.WarningText = create("TextLabel", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					Font = selfLib.Theme.Font,
					TextWrapped = true,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = selfLib.Theme.SubText,
					Parent = self.WarningBox,
				})
			end
			self.WarningTitle.Text = tostring(info.Title or "Warning")
			self.WarningText.Text = tostring(info.Text or "")
			self.WarningBox.Visible = info.Visible ~= false
		end

		function tab:SetVisible(state)
			if self.Button then
				self.Button.Visible = state and true or false
			end
			if state == false and Window.ActiveTab == self then
				for _, other in ipairs(Window.Tabs) do
					if other ~= self and other.Button and other.Button.Visible then
						other:Show()
						break
					end
				end
			end
		end
		function tab:SetOrder(order)
			if self.Button then
				self.Button.LayoutOrder = tonumber(order) or 0
			end
		end
		function tab:SetName(name)
			self.Name = tostring(name or self.Name)
			if self.ButtonLabel then
				self.ButtonLabel.Text = self.Name
			end
		end
		function tab:SetDescription(desc)
			self.Description = desc
		end
		function tab:SetIcon(_) end
		function tab:SetTooltip(_) end

		function tab:Show()
			for _, key, other in pairs(Window.Tabs) do
				if type(key) == "number" and type(other) == "table" and other.Page then
					other.Page.Visible = false
					if other.Button then
						other.Button.BackgroundColor3 = selfLib.Theme.SurfaceAlt
					end
				end
			end
			self.Page.Visible = true
			if self.Button then
				self.Button.BackgroundColor3 = selfLib.Theme.AccentDark
			end
			Window.ActiveTab = self
		end

		function tab:AddGroupbox(info)
			info = info or {}
			local side = info.Side
			local target = self.LeftColumn
			if side == 2 or side == "Right" or side == "right" then
				target = self.RightColumn
			elseif side == 1 or side == "Left" or side == "left" then
				target = self.LeftColumn
			end
			local box = createGroupbox(target, info)
			table.insert(self.Groupboxes, box)
			return box
		end

		function tab:AddLeftGroupbox(name, iconName)
			return self:AddGroupbox({ Side = 1, Name = name, IconName = iconName })
		end
		function tab:AddRightGroupbox(name, iconName)
			return self:AddGroupbox({ Side = 2, Name = name, IconName = iconName })
		end
		function tab:AddLeftTabbox(name)
			return self:AddTabbox({ Side = 1, Name = name })
		end
		function tab:AddRightTabbox(name)
			return self:AddTabbox({ Side = 2, Name = name })
		end

		function tab:AddTabbox(info)
			info = info or {}
			local host = self:AddGroupbox({
				Side = info.Side or 1,
				Name = info.Name or "Tabbox",
			})
			local tabStrip = create("Frame", {
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				Parent = host.Holder,
			})
			create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = tabStrip,
			})

			local container = create("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent = host.Holder,
			})

			local tabbox = {
				Host = host,
				Tabs = {},
				Active = nil,
			}

			function tabbox:AddTab(name)
				local page = create("Frame", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Visible = false,
					Parent = container,
				})
				create("UIListLayout", {
					Padding = UDim.new(0, 6),
					SortOrder = Enum.SortOrder.LayoutOrder,
					Parent = page,
				})

				local btn = create("TextButton", {
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundColor3 = selfLib.Theme.SurfaceAlt,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Font = selfLib.Theme.Font,
					TextSize = 13,
					TextColor3 = selfLib.Theme.Text,
					Text = "  " .. tostring(name or "Tab") .. "  ",
					Parent = tabStrip,
				})
				addCorner(btn, 4)
				addStroke(btn, selfLib.Theme.Outline)

				local nested = {
					Holder = page,
					Button = btn,
				}
				attachGroupboxMethods(nested)

				function nested:AddDivider()
					return host.AddDivider({ Holder = page })
				end
				function nested:AddLabel(...)
					return host.AddLabel({ Holder = page }, ...)
				end
				function nested:AddButton(...)
					return host.AddButton({ Holder = page }, ...)
				end
				function nested:AddToggle(...)
					return host.AddToggle({ Holder = page }, ...)
				end
				function nested:AddSlider(...)
					return host.AddSlider({ Holder = page }, ...)
				end
				function nested:AddInput(...)
					return host.AddInput({ Holder = page }, ...)
				end
				function nested:AddDropdown(...)
					return host.AddDropdown({ Holder = page }, ...)
				end
				function nested:AddKeyPicker(...)
					return host.AddKeyPicker({ Holder = page }, ...)
				end
				function nested:AddColorPicker(...)
					return host.AddColorPicker({ Holder = page }, ...)
				end
				function nested:AddDependencyBox()
					return nested
				end
				function nested:AddDependencyGroupbox()
					return nested
				end

				local function showThis()
					for _, t in ipairs(tabbox.Tabs) do
						t.Page.Visible = false
						t.Button.BackgroundColor3 = selfLib.Theme.SurfaceAlt
					end
					page.Visible = true
					btn.BackgroundColor3 = selfLib.Theme.AccentDark
					tabbox.Active = nested
				end

				btn.MouseButton1Click:Connect(showThis)

				nested.Page = page
				nested.Show = showThis
				table.insert(tabbox.Tabs, nested)
				if #tabbox.Tabs == 1 then
					showThis()
				end
				return nested
			end

			return tabbox
		end
	end

	function Window:AddTab(arg1, arg2, arg3)
		local name, icon, description
		if type(arg1) == "table" then
			name = arg1.Name or "Tab"
			icon = arg1.Icon
			description = arg1.Description
		else
			name = arg1 or "Tab"
			icon = arg2
			description = arg3
		end

		local button, buttonLabel = createTabButton(name, icon, #self.Tabs + 1)
		local page, leftColumn, rightColumn = createPageContainer()

		local tab = {
			Name = name,
			Icon = icon,
			Description = description,
			Button = button,
			ButtonLabel = buttonLabel,
			Page = page,
			Scroll = page:FindFirstChildOfClass("ScrollingFrame"),
			LeftColumn = leftColumn,
			RightColumn = rightColumn,
			Groupboxes = {},
		}

		button.MouseButton1Click:Connect(function()
			tab:Show()
		end)

		attachTabMethods(tab)
		table.insert(self.Tabs, tab)
		self.Tabs[name] = tab
		if #self.Tabs == 1 then
			tab:Show()
		end
		return tab
	end

	function Window:AddKeyTab(name, icon)
		local tab = self:AddTab(name, icon)
		function tab:AddKeyBox(callback)
			local box = tab:AddLeftGroupbox("Key System")
			local input = box:AddInput("KeyInput_" .. HttpService:GenerateGUID(false), {
				Text = "Key",
				Default = "",
				Placeholder = "Enter key...",
				Finished = true,
			})
			box:AddButton("Submit", function()
				selfLib:SafeCallback(callback, input.Value)
			end)
			return input
		end
		return tab
	end

	toggleButton.MouseButton1Click:Connect(function()
		Window:Toggle()
	end)

	selfLib.KeybindFrame = selfLib.KeybindFrame or create("Frame", {
		Name = "KeybindFrame",
		Size = UDim2.fromOffset(220, 120),
		Position = UDim2.fromOffset(20, 20),
		BackgroundColor3 = selfLib.Theme.Surface,
		BorderSizePixel = 0,
		Visible = false,
		Parent = screenGui,
	}, {
		create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = selfLib.Theme.Font,
			TextSize = 14,
			TextColor3 = selfLib.Theme.SubText,
			Text = "Keybinds",
		}),
	})
	addCorner(selfLib.KeybindFrame, selfLib.Theme.CornerRadius)
	addStroke(selfLib.KeybindFrame, selfLib.Theme.Outline)
	if selfLib.ToggleKeybind == nil then
		selfLib.ToggleKeybind = toggleKey
	end

	local function getToggleKey()
		local tk = selfLib.ToggleKeybind or Window.ToggleKeybind or toggleKey
		if typeof(tk) == "EnumItem" then
			return tk
		end
		if type(tk) == "table" then
			local v = tk.Value or tk.Key or (tk.GetState and nil)
			if typeof(v) == "EnumItem" then
				return v
			end
			if type(v) == "string" and v ~= "None" and v ~= "" then
				local ok, enumVal = pcall(function()
					return Enum.KeyCode[v]
				end)
				if ok then
					return enumVal
				end
			end
		end
		if type(tk) == "string" and tk ~= "None" and tk ~= "" then
			local ok, enumVal = pcall(function()
				return Enum.KeyCode[tk]
			end)
			if ok then
				return enumVal
			end
		end
		return nil
	end

	self:Connect(UserInputService.InputBegan, function(input, gpe)
		if gpe then
			return
		end
		local tk = getToggleKey()
		if tk and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == tk then
			Window:Toggle()
		end
	end)

	if config.AutoShow == false then
		main.Visible = false
		Window.Visible = false
	end

	selfLib.ActiveWindow = Window
	return Window
end

return Library
