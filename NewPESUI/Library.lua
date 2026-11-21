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
-- Always point the globals at the *current* Library so re-executing the
-- script never leaves Toggles/Options pointing at a stale table.
if env.Library and env.Library ~= Library and type(env.Library.Unload) == "function" then
	pcall(function()
		env.Library:Unload()
	end)
end
env.Toggles = Library.Toggles
env.Options = Library.Options
env.Library = Library

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
	self._ListeningKey = nil
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
	table.clear(self.Toggles)
	table.clear(self.Options)
	table.clear(self.Flags)
	table.clear(self.Labels)
	table.clear(self.Registry)
	if self.KeyPickers then
		table.clear(self.KeyPickers)
	end
	if env.Library == self then
		env.Library = nil
		env.Toggles = nil
		env.Options = nil
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

-- ThemeManager only recolors instances registered with the library. Register
-- every theme-colored property at creation time by matching the value we were
-- handed against the current palette; the registry stores the palette key, so
-- later theme changes still apply.
local function themeKeyForColor(value)
	if typeof(value) ~= "Color3" then
		return nil
	end
	for key, color in pairs(Library.Theme) do
		if typeof(color) == "Color3"
			and color.R == value.R and color.G == value.G and color.B == value.B then
			return key
		end
	end
	return nil
end

local function create(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
			local themeKey = themeKeyForColor(v)
			if themeKey then
				Library:AddToRegistry(inst, { [k] = themeKey })
			end
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

-- Mouse -> GUI-space conversion.
-- Instead of assuming how IgnoreGuiInset is honoured (it can differ between
-- CoreGui / gethui containers), measure where GUI (0,0) really sits on screen:
-- if the ScreenGui is shorter than the viewport, its origin is pushed down by
-- the difference.
Library.MouseOffset = Vector2.new(0, 0) -- manual fine-tune (pixels), added last

-- Screen -> GUI space for the software cursor / hover helpers. The ScreenGui uses
-- IgnoreGuiInset = true, so GetMouseLocation() is used as is (offset 0).
-- NOTE: drags inside popups (colour picker) do NOT use this: they use the position
-- carried by the input event itself, which is what the engine hit-tested.
Library._MouseDY = nil -- learned vertical offset between screen space and GUI space

local function getScreenToGui()
	if Library._MouseDY ~= nil then
		return Vector2.new(0, Library._MouseDY)
	end
	return Vector2.new(0, 0)
end

local function getMouseLocation()
	return UserInputService:GetMouseLocation() - getScreenToGui() + Library.MouseOffset
end

local function getInputPosition(input)
	local screenPos
	if input and input.UserInputType == Enum.UserInputType.Touch then
		-- InputObject.Position excludes the top-bar inset; GetMouseLocation does not.
		screenPos = Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
	else
		screenPos = UserInputService:GetMouseLocation()
	end
	return screenPos - getScreenToGui() + Library.MouseOffset
end

-- Call this from an InputBegan that the ENGINE delivered to guiObj (so the cursor is
-- certainly inside it). If only one candidate offset puts the cursor inside, remember it.
local function calibrateMouse(input, guiObj)
	if not input or not guiObj or not guiObj.Parent then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local m = UserInputService:GetMouseLocation()
	local ap, as = guiObj.AbsolutePosition, guiObj.AbsoluteSize
	if as.X <= 0 or as.Y <= 0 or m.X < ap.X or m.X > ap.X + as.X then
		return
	end
	local fits = {}
	for _, dy in ipairs({ 0, GuiService:GetGuiInset().Y }) do
		local y = m.Y - dy
		if y >= ap.Y and y <= ap.Y + as.Y then
			table.insert(fits, dy)
		end
	end
	if #fits == 1 then
		Library._MouseDY = fits[1]
	end
end

local function makeDraggable(handle, target, adjust)
	local dragging = false
	local dragStart
	local startPos

	handle.InputBegan:Connect(function(input)
		if Library.DragLocked then
			return
		end
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
		local newPos = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
		if adjust then
			newPos = adjust(newPos) or newPos
		end
		target.Position = newPos
	end)
end

-- true when the instance and every GuiObject ancestor up to the ScreenGui is visible
local function isGuiVisible(inst)
	while inst and not inst:IsA("LayerCollector") do
		if inst:IsA("GuiObject") and not inst.Visible then
			return false
		end
		inst = inst.Parent
	end
	return inst ~= nil
end

-- Obsidian resolves an icon name through the installed IconModule. The result
-- is either a sprite descriptor (Url + rect) or a font descriptor (FontFace +
-- Text). Keep both here so ImageLabel call sites and CreateIcon call sites can
-- share one lookup path.
local function getIconData(icon)
	if type(icon) == "table" and (icon.Url or icon.FontFace) then
		return icon
	end
	local data = Library:GetCustomIcon(icon)
	if type(data) == "table" and (data.Url or data.FontFace) then
		return data
	end
	return nil
end

local function resolveIcon(icon)
	local data = getIconData(icon)
	-- Font glyphs need a TextLabel; the ImageLabel call sites below only want
	-- a URL.
	if type(data) == "table" and not data.FontFace then
		return data.Url or nil
	end
	return nil
end

-- Applies the full image descriptor (including sprite-sheet rects) to an
-- already-created ImageLabel/ImageButton. Returns the instance either way.
local function applyIconData(target, icon)
	if not target then
		return target
	end
	local data = getIconData(icon)
	if type(data) ~= "table" or data.FontFace then
		return target
	end
	target.Image = data.Url or ""
	target.ImageRectOffset = data.ImageRectOffset or Vector2.zero
	target.ImageRectSize = data.ImageRectSize or Vector2.zero
	return target
end

-- Creates the right GuiObject for either a sprite or a font glyph and applies
-- the descriptor. Props must not contain Image/Text/FontFace; ApplyIcon sets
-- those.
local function createIconInstance(icon, props, isButton)
	local data = getIconData(icon)
	if not data then
		return nil
	end
	return Library:CreateIcon(data, props, isButton)
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

-- Obsidian-style Tooltip / DisabledTooltip: attach a tooltip to the element's
-- primary GUI object when the Info table provides either string.
local function attachInfoTooltip(element, info, hoverInstance)
	if type(info) ~= "table" or typeof(hoverInstance) ~= "Instance" then
		return nil
	end
	if typeof(info.Tooltip) ~= "string" and typeof(info.DisabledTooltip) ~= "string" then
		return nil
	end
	local ok, tip = pcall(function()
		return Library:AddTooltip(info.Tooltip, info.DisabledTooltip, hoverInstance)
	end)
	if not ok or not tip then
		Library._TooltipError = tostring(tip)
		return nil
	end
	Library._TooltipError = nil
	Library._TooltipCount = (Library._TooltipCount or 0) + 1
	if element then
		element.TooltipTable = tip
	end
	-- Use Info.Disabled as the source of truth: many elements (e.g. Button)
	-- don't initialize .Disabled themselves, and a disabled-only tooltip must
	-- still be selectable when the element starts disabled.
	tip.Disabled = (info.Disabled == true) or (element and element.Disabled == true) or false
	return tip
end

local function createOptionObject(kind, id, defaults)
	local obj = {
		Type = kind,
		Idx = id,
		Value = defaults.Value,
		ChangedCallbacks = {},
		Changed = nil,
	}
	function obj:OnChanged(fn)
		if type(fn) ~= "function" then
			return fn
		end
		table.insert(self.ChangedCallbacks, fn)
		if self.Value ~= nil then
			Library:SafeCallback(fn, self.Value)
		end
		return fn
	end
	function obj:GetValue()
		return self.Value
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
		if self.Changed then
			Library:SafeCallback(self.Changed, value, ...)
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
		return self
	end
	function obj:Destroy()
		if self.Instance then
			safeDestroy(self.Instance)
		end
	end
	return obj
end

-- ====================================================================
-- Obsidian compatibility layer (stubs + utilities)
-- ====================================================================

function Library:SetFont(font)
	local newFont
	if typeof(font) == "EnumItem" then
		newFont = font
	elseif type(font) == "string" and Enum.Font[font] then
		newFont = Enum.Font[font]
	end
	if not newFont then
		warn("[PESUI] SetFont expects an Enum.Font (or its name); got " .. typeof(font))
		return
	end
	self.Theme.Font = newFont
	if self.ScreenGui then
		for _, d in ipairs(self.ScreenGui:GetDescendants()) do
			if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
				pcall(function() d.Font = newFont end)
			end
		end
	end
end

function Library:SetBackgroundImage(image)
	if self.ActiveWindow then
		self.ActiveWindow:SetBackgroundImage(image)
	end
end

function Library:SetNotifySide(side)
	self.NotifySide = side
end

function Library:UpdateNotificationPositions(snap) end

function Library:DropdownDivider(title)
	return { DropdownDivider = true, Title = title }
end

function Library:Validate(tbl, template)
	if typeof(tbl) ~= "table" then
		return template
	end
	for k, v in pairs(template or {}) do
		if typeof(k) == "number" then
			continue
		end
		if typeof(v) == "table" then
			tbl[k] = self:Validate(tbl[k], v)
		elseif tbl[k] == nil then
			tbl[k] = v
		end
	end
	return tbl
end

function Library:GiveSignal(conn)
	if conn then
		table.insert(self.Connections, conn)
	end
	return conn
end

function Library:SetDPIScale(scale)
	self.DPIScale = (tonumber(scale) or 100) / 100
	if self.OriginalMinSize then
		self.MinSize = self.OriginalMinSize * self.DPIScale
	end
	for _, uiScale in pairs(self.Scales or {}) do
		local offset = tonumber((self.ScalesOffset or {})[uiScale]) or 0
		pcall(function()
			uiScale.Scale = self.DPIScale - offset
		end)
	end
end

function Library:UpdateColorsUsingRegistry()
	-- ThemeManager swaps Library.Scheme for a plain table instead of writing
	-- individual keys. Mirror the Obsidian palette names back into PESUI's
	-- live Theme first, otherwise the registry would keep applying the old
	-- colors.
	if self.Scheme ~= nil and self.Theme ~= nil then
		local schemeToTheme = {
			BackgroundColor = "Background",
			MainColor = "Surface",
			AccentColor = "Accent",
			OutlineColor = "Outline",
			FontColor = "Text",
			Font = "Font",
			RedColor = "Danger",
			DarkColor = "SurfaceAlt",
		}
		for schemeKey, themeKey in pairs(schemeToTheme) do
			local value = self.Scheme[schemeKey]
			if value ~= nil then
				-- ThemeManager stores Font.fromEnum(...) (a Font object) in
				-- Scheme.Font. TextLabel.Font needs an Enum.Font, so ignore
				-- that implicit value and keep PESUI's default unless the user
				-- explicitly calls SetFont from the font dropdown.
				if schemeKey == "Font" and typeof(value) == "Font" then
					continue
				end
				self.Theme[themeKey] = value
			end
		end
	end
	for key, entry in pairs(self.Registry or {}) do
		if typeof(key) == "Instance" and type(entry) == "table" then
			-- { [instance] = { Property = ThemeKey | function } }
			for prop, idx in pairs(entry) do
				local val
				if type(idx) == "function" then
					local ok, res = pcall(idx)
					if ok then
						val = res
					end
				elseif self.Theme and self.Theme[idx] ~= nil then
					val = self.Theme[idx]
				end
				if val ~= nil then
					pcall(function()
						key[prop] = val
					end)
				end
			end
		elseif type(entry) == "table" and type(entry.UpdateColors) == "function" then
			-- element objects (labels etc.) registered by Idx
			pcall(entry.UpdateColors, entry)
		end
	end
end

function Library:UpdateDependencyBoxes()
	if type(self._UpdateDependencyBoxes) == "function" then
		pcall(self._UpdateDependencyBoxes, self)
	end
end

function Library:UpdateAddons(parent) end

function Library:UpdateSearch(text)
	self.SearchText = text
	self.Searching = type(text) == "string" and text ~= ""
	local query = self.Searching and string.lower(text) or nil
	local activePage = self.ActiveTab and self.ActiveTab.Page or nil

	for id, obj in pairs(self.Options or {}) do
		if type(obj) == "table" then
			local inst = obj.Instance
			if typeof(inst) == "Instance" and inst:IsA("GuiObject") then
				if obj._SearchOriginalVisible == nil then
					obj._SearchOriginalVisible = inst.Visible
				end

				-- GlobalSearch = false only filters the active tab, like Obsidian.
				local inScope = true
				if query and not self.GlobalSearch and typeof(activePage) == "Instance" and activePage:IsA("GuiObject") then
					inScope = inst == activePage or inst:IsDescendantOf(activePage)
				end

				if not query or not inScope then
					inst.Visible = obj._SearchOriginalVisible
					if not query then
						obj._SearchOriginalVisible = nil
					end
				else
					local haystack = {}
					local function add(value)
						if value ~= nil then
							haystack[#haystack + 1] = tostring(value):lower()
						end
					end
					add(obj.Text)
					add(obj.DisplayName)
					add(obj.Title)
					add(obj.Value)
					add(id)
					pcall(function()
						for _, d in ipairs(inst:GetDescendants()) do
							if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
								add(d.Text)
							end
						end
					end)
					local matched = false
					for _, s in ipairs(haystack) do
						if s:find(query, 1, true) then
							matched = true
							break
						end
					end
					inst.Visible = matched
				end
			end
		end
	end
end

function Library:GetBetterColor(color, add)
	add = tonumber(add) or 0
	if typeof(color) ~= "Color3" then
		return Color3.new(1, 1, 1)
	end
	local h, s, v = color:ToHSV()
	v = math.clamp(v + add, 0, 1)
	s = math.clamp(s + add * 0.5, 0, 1)
	return Color3.fromHSV(h, s, v)
end

function Library:GetLighterColor(color)
	return self:GetBetterColor(color, 0.12)
end

function Library:GetDarkerColor(color)
	return self:GetBetterColor(color, -0.12)
end

function Library:GetKeyString(keyCode)
	if typeof(keyCode) == "EnumItem" then
		return keyCode.Name
	end
	return tostring(keyCode or "")
end

function Library:GetTextBounds(text, font, size, width)
	return getTextSize(text, size, font, width)
end

function Library:MouseIsOverFrame(frame, mouse)
	if not frame or not frame.Parent then
		return false
	end
	local pos
	if typeof(mouse) == "Vector2" then
		pos = mouse
	else
		pos = getMouseLocation()
	end
	local ap = frame.AbsolutePosition
	local as = frame.AbsoluteSize
	return pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y
end

function Library:IsInsideFrame(parentFrame, frame)
	if not parentFrame or not frame then
		return false
	end
	local p = frame.AbsolutePosition
	local s = parentFrame.AbsolutePosition
	local sz = parentFrame.AbsoluteSize
	return p.X >= s.X and p.Y >= s.Y and p.X + frame.AbsoluteSize.X <= s.X + sz.X and p.Y + frame.AbsoluteSize.Y <= s.Y + sz.Y
end

function Library:SetIconModule(module)
	self._IconModule = module
	self.IconModule = module
	self._FetchIcons = module ~= nil
	local _, names = pcall(function()
		return type(module.Icons) == "table" and module.Icons or nil
	end)
	self._IconNames = names
end

function Library:GetIcon(name)
	if not self._FetchIcons or not self._IconModule then
		return nil
	end
	if type(self._IconModule.GetAsset) ~= "function" then
		return nil
	end
	local ok, res = pcall(self._IconModule.GetAsset, name)
	return ok and res or nil
end

function Library:GetCustomIcon(name)
	if not name then
		return nil
	end
	if type(name) == "number" then
		name = "rbxassetid://" .. tostring(name)
	end
	if type(name) == "string" then
		if name:match("^rbxasset") or name:match("^http") then
			return { Url = name, ImageRectOffset = Vector2.zero, ImageRectSize = Vector2.zero }
		end
		if name:match("^%d+$") then
			return { Url = "rbxassetid://" .. name, ImageRectOffset = Vector2.zero, ImageRectSize = Vector2.zero }
		end
	end
	return self:GetIcon(name)
end

-- Obsidian loads a Lucide icon module at startup. The module exposes
-- `GetAsset(name)` and returns either a sprite descriptor
-- (`Url`/`ImageRectOffset`/`ImageRectSize`) or a font descriptor
-- (`FontFace`/`Text`). Failures are silent so the UI still builds offline.
local function loadIconModule()
	if env and env.PESUI_NO_ICON_FETCH == true then
		return
	end
	if typeof(loadstring) ~= "function" or not game or typeof(game.HttpGet) ~= "function" then
		return
	end
	local sources = {
		{
			url = "https://raw.githubusercontent.com/notpoiu/Molto/main/source.lua",
			provider = "lucide",
		},
		{
			url = "https://raw.githubusercontent.com/notpoiu/lucide-roblox-direct/main/source.lua",
		},
	}
	for _, source in ipairs(sources) do
		local ok, module = pcall(function()
			return loadstring(game:HttpGet(source.url))()
		end)
		if ok and type(module) == "table" and type(module.GetAsset) == "function" then
			if source.provider and type(module.SetProvider) == "function" then
				pcall(module.SetProvider, source.provider)
			end
			Library:SetIconModule(module)
			return
		end
	end
end
pcall(loadIconModule)

local IconTextProperties = { ImageColor3 = "TextColor3", ImageTransparency = "TextTransparency" }
local IconSharedProperties = {
	"Name", "AnchorPoint", "Position", "Size", "SizeConstraint", "LayoutOrder",
	"ZIndex", "Visible", "Rotation", "ImageColor3", "ImageTransparency",
}

local function isFontIcon(icon)
	return type(icon) == "table" and icon.FontFace ~= nil
end

local function mapIconProperties(className, props)
	if className ~= "TextLabel" and className ~= "TextButton" then
		return props
	end
	local mapped = {}
	for prop, value in pairs(props or {}) do
		mapped[IconTextProperties[prop] or prop] = value
	end
	return mapped
end

function Library:CreateIcon(icon, props, isButton)
	local font = isFontIcon(icon)
	local className = (font and "Text" or "Image") .. (isButton and "Button" or "Label")
	local merged = {
		BackgroundTransparency = 1,
		ImageColor3 = Color3.new(1, 1, 1),
	}
	if not font then
		merged.ScaleType = Enum.ScaleType.Fit
	end
	for prop, value in pairs(props or {}) do
		merged[prop] = value
	end
	local inst = create(className, mapIconProperties(className, merged))
	return self:ApplyIcon(inst, icon)
end

function Library:ApplyIcon(target, icon)
	local font = isFontIcon(icon)
	local isText = target:IsA("TextLabel") or target:IsA("TextButton")
	if font ~= isText then
		local props = { Parent = target.Parent }
		for _, prop in ipairs(IconSharedProperties) do
			local source = isText and (IconTextProperties[prop] or prop) or prop
			local ok, value = pcall(function() return target[source] end)
			props[prop] = ok and value or nil
		end
		local replacement = self:CreateIcon(icon, props, target:IsA("GuiButton"))
		safeDestroy(target)
		return replacement
	end
	if font and icon then
		target.FontFace = icon.FontFace
		target.RichText = false
		target.Text = icon.Text or ""
		target.TextScaled = true
		if not target:FindFirstChild("IconPadding") then
			create("UIPadding", {
				Name = "IconPadding",
				PaddingLeft = UDim.new(-0.5, -0.5),
				PaddingRight = UDim.new(-0.5, 0),
				Parent = target,
			})
		end
	elseif type(icon) == "table" then
		target.Image = icon.Url or ""
		target.ImageRectOffset = icon.ImageRectOffset or Vector2.zero
		target.ImageRectSize = icon.ImageRectSize or Vector2.zero
	end
	return target
end

function Library:ApplyLucideIcon(imageGui, icon, rotation)
	if rotation ~= nil then
		imageGui.Rotation = rotation
	end
	return self:ApplyIcon(imageGui, icon)
end

function Library:MakeDraggable(handle, target, adjust)
	makeDraggable(handle, target, adjust)
end

function Library:MakeResizable(ui, dragFrame, callback) end

function Library:MakeCover(holder, place) end

function Library:MakeLine(frame, info) end

function Library:AddOutline(frame)
	return addStroke(frame)
end

function Library:AddBlank(frame, size)
	local f = create("Frame", {
		Size = size or UDim2.new(1, 0, 0, 4),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	return f
end

function Library:MakeBoxPopOut(box, opts)
	return box
end

-- Shared tooltip label + hover owner, mirroring Obsidian's single-label design.
local tooltipLabel = nil
local tooltipOwner = nil
local function ensureTooltipLabel(self)
	if tooltipLabel and tooltipLabel.Parent then
		return tooltipLabel
	end
	local parent = self.OverlayFrame or self.ScreenGui
	if not parent then
		return nil
	end
	tooltipLabel = create("TextLabel", {
		Name = "Tooltip",
		Visible = false,
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 0.1,
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		Font = self.Theme.Font,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = self.Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 100000,
		Parent = parent,
	})
	addCorner(tooltipLabel, self.Theme.CornerRadius)
	addPadding(tooltipLabel, 6)
	return tooltipLabel
end

function Library:AddTooltip(infoStr, disabledInfoStr, hoverInstance)
	if typeof(hoverInstance) ~= "Instance" then
		return { Destroy = function() end }
	end
	local t = {
		Text = infoStr,
		DisabledText = disabledInfoStr,
		Instance = hoverInstance,
		Disabled = false,
		Hovering = false,
		Destroyed = false,
		Signals = {},
	}
	local function giveSignal(conn)
		if conn then
			table.insert(t.Signals, conn)
		end
		return conn
	end
	local function positionTooltip()
		local label = ensureTooltipLabel(self)
		if not label then
			return
		end
		local mouse = getMouseLocation()
		label.Position = UDim2.fromOffset(mouse.X + 14, mouse.Y + 12)
	end
	local function doHover()
		Library._TooltipHoverCount = (Library._TooltipHoverCount or 0) + 1
		if t.Destroyed or tooltipOwner == hoverInstance then
			return
		end
		if t.Disabled and typeof(disabledInfoStr) ~= "string" then
			return
		end
		if not t.Disabled and typeof(infoStr) ~= "string" then
			return
		end
		local label = ensureTooltipLabel(self)
		if not label then
			return
		end
		tooltipOwner = hoverInstance
		t.Hovering = true
		label.Text = t.Disabled and disabledInfoStr or infoStr
		positionTooltip()
		label.Visible = true
		Library._TooltipShown = tick()

		-- Keep the label visible until MouseLeave / Destroy explicitly clears
		-- the owner. Obsidian also polls MouseIsOverFrame here, but a small
		-- coordinate mismatch (inset / offset) makes that check fail on the
		-- first frame and the tooltip vanishes before it can be seen.
		-- MouseLeave is the authoritative hide signal.
		while not t.Destroyed and tooltipOwner == hoverInstance do
			positionTooltip()
			RunService.RenderStepped:Wait()
		end

		label.Visible = false
		t.Hovering = false
		if tooltipOwner == hoverInstance then
			tooltipOwner = nil
		end
	end
	giveSignal(hoverInstance.MouseEnter:Connect(doHover))
	giveSignal(hoverInstance.MouseMoved:Connect(doHover))
	giveSignal(hoverInstance.MouseLeave:Connect(function()
		if tooltipOwner ~= hoverInstance then
			return
		end
		if tooltipLabel then
			tooltipLabel.Visible = false
		end
		t.Hovering = false
		tooltipOwner = nil
	end))
	function t:Destroy()
		if t.Destroyed then
			return
		end
		t.Destroyed = true
		for i = #t.Signals, 1, -1 do
			local conn = table.remove(t.Signals, i)
			if conn and conn.Connected then
				pcall(function() conn:Disconnect() end)
			end
		end
		if tooltipOwner == hoverInstance and tooltipLabel then
			tooltipLabel.Visible = false
			tooltipOwner = nil
		end
	end
	self:OnUnload(function()
		t:Destroy()
	end)
	return t
end

function Library:AddContextMenu(...)
	local menu = { Open = function() end, Close = function() end, Toggle = function() end, Destroy = function() end }
	return menu
end

function Library:AddDraggableLabel(...)
	local obj = { Text = "", Icon = nil, Visible = true }
	function obj:SetText(text)
		obj.Text = tostring(text or "")
	end
	function obj:SetIcon(icon) obj.Icon = icon end
	function obj:SetIconPosition(pos) end
	function obj:SetVisible(state) obj.Visible = state ~= false end
	function obj:Destroy() end
	return obj
end

function Library:AddDraggableButton(...)
	local obj = { Text = "" }
	function obj:SetText(text) obj.Text = tostring(text or "") end
	function obj:Destroy() end
	return obj
end

function Library:AddDraggableMenu(name)
	local obj = { Name = name, Destroyed = false }
	function obj:Destroy() obj.Destroyed = true end
	return obj
end

function Library:AddDraggableImageButton(...)
	local obj = { Icon = nil, IconSize = 24 }
	function obj:SetIcon(icon) obj.Icon = icon end
	function obj:SetIconSize(size) obj.IconSize = size end
	function obj:Destroy() end
	return obj
end

Library.Cursor = {
	ResetCross = function() end,
	ResetIcon = function() end,
	ResetCursor = function() end,
	ChangeCrossColor = function() end,
	ChangeIcon = function() end,
	ChangeIconColor = function() end,
	ChangeIconSize = function() end,
}

-- ====================================================================
-- Obsidian API surface compatibility
-- ====================================================================
-- Obsidian scripts commonly touch Library.Scheme.* and Library.DPIScale.
-- PESUI stores its palette in Library.Theme, so Scheme is a live two-way
-- proxy: reading/writing an Obsidian key reads/writes the matching Theme
-- entry, while non-mapped keys live in a private side table.
do
	local schemeExtra = {
		WhiteColor = Color3.new(1, 1, 1),
		DestructiveColor = Color3.fromRGB(220, 38, 38),
		BackgroundImage = "",
	}
	local schemeMap = {
		BackgroundColor = "Background",
		MainColor = "Surface",
		AccentColor = "Accent",
		OutlineColor = "Outline",
		FontColor = "Text",
		Font = "Font",
		RedColor = "Danger",
		DarkColor = "SurfaceAlt",
	}
	Library.Scheme = setmetatable({}, {
		__index = function(_, key)
			local themeKey = schemeMap[key]
			if themeKey and Library.Theme[themeKey] ~= nil then
				return Library.Theme[themeKey]
			end
			return schemeExtra[key]
		end,
		__newindex = function(_, key, value)
			local themeKey = schemeMap[key]
			if themeKey then
				Library.Theme[themeKey] = value
				pcall(function()
					Library:UpdateColorsUsingRegistry()
				end)
			else
				schemeExtra[key] = value
			end
		end,
	})
	Library.IsLightTheme = false
end

Library.DPIScale = Library.DPIScale or 1
Library.Scales = Library.Scales or {}
Library.ScalesOffset = Library.ScalesOffset or {}
Library.OriginalMinSize = Library.OriginalMinSize or Vector2.new(480, 360)
Library.MinSize = Library.MinSize or Vector2.new(480, 360)
Library.ImageManager = Library.ImageManager or {}

function Library.ImageManager.AddAsset(name, assetId, url, force)
	return Library:GetIcon(name)
end
function Library.ImageManager.GetAsset(name)
	return Library:GetIcon(name)
end
function Library.ImageManager.DownloadAsset(name, force)
	return Library:GetIcon(name)
end
function Library:AddAsset(name, url)
	return self:GetIcon(name)
end
function Library:GetAsset(name)
	return self:GetCustomIcon(name)
end
function Library:DownloadAsset(name, force)
	return self:GetCustomIcon(name)
end

function Library:AddToRegistry(instance, properties)
	local entry = self.Registry[instance]
	if type(entry) ~= "table" then
		entry = {}
		self.Registry[instance] = entry
	end
	for prop, key in pairs(properties or {}) do
		entry[prop] = key
	end
end
function Library:RemoveFromRegistry(instance)
	self.Registry[instance] = nil
end
function Library:MakeOutline(frame, corner, zindex)
	return addStroke(frame)
end
function Library:PlayTabAnimation(tab, showing, onComplete, previousTab)
	if type(onComplete) == "function" then
		Library:SafeCallback(onComplete)
	end
end

-- Deprecated Obsidian cursor helpers -> forward to Library.Cursor
local cursorAlias = {
	ChangeCursorCrossColor = "ChangeCrossColor",
	ResetCursorCross = "ResetCross",
	ChangeCursorIcon = "ChangeIcon",
	ChangeCursorIconColor = "ChangeIconColor",
	ChangeCursorIconSize = "ChangeIconSize",
	ResetCursorIcon = "ResetIcon",
}
for libName, cursorName in pairs(cursorAlias) do
	Library[libName] = function(_, ...)
		local fn = Library.Cursor and Library.Cursor[cursorName]
		if type(fn) == "function" then
			return fn(Library.Cursor, ...)
		end
	end
end

-- Watermark
local watermarkLabel = nil
local watermarkVisible = true
function Library:SetWatermark(text)
	if not self.ScreenGui then
		return
	end
	if not watermarkLabel or not watermarkLabel.Parent then
		watermarkLabel = create("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 12),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			Font = self.Theme.Font,
			TextSize = 13,
			TextColor3 = self.Theme.Text,
			TextStrokeTransparency = 0.5,
			ZIndex = 9000,
			Parent = self.ScreenGui,
		})
	end
	watermarkLabel.Text = tostring(text or "")
	watermarkLabel.Visible = watermarkVisible
end

function Library:SetWatermarkVisibility(visible)
	watermarkVisible = visible ~= false
	if watermarkLabel then
		watermarkLabel.Visible = watermarkVisible
	end
end

-- CreateLoading. Obsidian gives the loader its own ScreenGui so it can be
-- shown before CreateWindow and can restore the main window on Continue.
local DEFAULT_LOADING_ICON = "rbxassetid://97544096941083"

function Library:CreateLoading(info)
	if self.ActiveLoading then
		warn("PESUI: Loading GUI already exists, you cannot create multiple Loading GUIs.")
		return self.ActiveLoading
	end

	local cfg = self:Validate(info or {}, {
		Title = "mspaint",
		Icon = 95816097006870,
		IconSize = UDim2.fromOffset(30, 30),
		LoadingIcon = DEFAULT_LOADING_ICON,
		LoadingIconColor = nil,
		LoadingIconTweenTime = 1,
		CurrentStep = 0,
		TotalSteps = 10,
		ShowSidebar = false,
		AutoResizeHeight = false,
		AlwaysOnTop = true,
		WindowWidth = 450,
		WindowHeight = 275,
		ContentWidth = 450,
		SidebarWidth = 250,
	})

	local screenGui = create("ScreenGui", {
		Name = "PESUILoading",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = cfg.AlwaysOnTop ~= false and 1000000 or 999,
	})
	protectGui(screenGui)

	local loading = {
		ScreenGui = screenGui,
		CurrentStep = tonumber(cfg.CurrentStep) or 0,
		TotalSteps = tonumber(cfg.TotalSteps) or 10,
		ShowSidebar = cfg.ShowSidebar == true,
		AutoResizeHeight = cfg.AutoResizeHeight == true,
		AlwaysOnTop = cfg.AlwaysOnTop ~= false,
		WindowWidth = tonumber(cfg.WindowWidth) or 450,
		WindowHeight = tonumber(cfg.WindowHeight) or 275,
		ContentWidth = tonumber(cfg.ContentWidth) or 450,
		SidebarWidth = tonumber(cfg.SidebarWidth) or 250,
		IsError = false,
		Destroyed = false,
	}
	loading.BaseWindowHeight = loading.WindowHeight
	loading.WindowErrorHeight = loading.WindowHeight

	local restoreWindow = false
	if self.ActiveWindow and self.ActiveWindow.Visible then
		restoreWindow = true
		pcall(function() self.ActiveWindow:Toggle(false) end)
	end
	self.ActiveLoading = loading

	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local connections = {}
	local rotationTween
	local function track(signal, fn)
		local conn = signal:Connect(fn)
		table.insert(connections, conn)
		return conn
	end
	local function stopRotation()
		if rotationTween then
			pcall(function() rotationTween:Cancel() end)
			rotationTween = nil
		end
	end

	local main = create("TextButton", {
		Name = "Main",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(loading.ShowSidebar and (loading.ContentWidth + loading.SidebarWidth) or loading.WindowWidth, loading.WindowHeight),
		BackgroundColor3 = self.Theme.Surface,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		Parent = screenGui,
	})
	addCorner(main, self.Theme.CornerRadius)
	addStroke(main, self.Theme.Outline)

	local content = create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, loading.ContentWidth, 1, 0),
		Parent = main,
	})
	local sideBar = create("Frame", {
		Name = "SideBar",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(loading.ContentWidth, 0),
		Size = UDim2.new(0, loading.ShowSidebar and loading.SidebarWidth or 0, 1, 0),
		ClipsDescendants = true,
		Visible = loading.ShowSidebar,
		Parent = main,
	})
	local sidebarDivider = create("Frame", {
		Name = "Divider",
		BackgroundColor3 = self.Theme.Outline,
		BorderSizePixel = 0,
		Size = UDim2.new(0, 1, 1, 0),
		Visible = loading.ShowSidebar,
		Parent = sideBar,
	})

	local topBar = create("Frame", {
		Name = "TopBar",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 48),
		Parent = content,
	})
	local titleHolder = create("Frame", {
		Name = "TitleHolder",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = topBar,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		Parent = titleHolder,
	})
	create("UIPadding", { PaddingLeft = UDim.new(0, 12), Parent = titleHolder })

	local iconOffset = 0
	if cfg.Icon then
		if createIconInstance(cfg.Icon, { Size = cfg.IconSize, Parent = titleHolder }) then
			iconOffset = cfg.IconSize.X.Offset + 6
		end
	end
	local titleWidth = math.min(
		(self:GetTextBounds(tostring(cfg.Title), self.Theme.Font, 20) or Vector2.zero).X,
		math.max(0, loading.ContentWidth - iconOffset - 24)
	)
	local titleLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, titleWidth, 1, 0),
		Font = self.Theme.Font,
		TextSize = 20,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = self.Theme.Text,
		Text = tostring(cfg.Title),
		Parent = titleHolder,
	})
	create("Frame", {
		Name = "TopDivider",
		BackgroundColor3 = self.Theme.Outline,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 1),
		Parent = content,
	})

	local inner = create("Frame", {
		Name = "InnerContent",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 49),
		Size = UDim2.new(1, 0, 1, -49),
		Parent = content,
	})
	local innerLayout = create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		Parent = inner,
	})

	local iconHolder = create("Frame", {
		Name = "IconHolder",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(64, 64),
		Parent = inner,
	})
	local loadingIcon = createIconInstance(cfg.LoadingIcon, {
		Name = "LoaderIcon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ImageColor3 = cfg.LoadingIconColor or (cfg.LoadingIcon == DEFAULT_LOADING_ICON and self.Theme.Accent or Color3.new(1, 1, 1)),
		Parent = iconHolder,
	})

	local function startRotation(duration)
		stopRotation()
		if not loadingIcon then
			return
		end
		duration = tonumber(duration) or 0
		if duration <= 0 then
			pcall(function() loadingIcon.Rotation = 0 end)
			return
		end
		local ok, tween = pcall(function()
			return TweenService:Create(loadingIcon, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1), { Rotation = 360 })
		end)
		if ok and tween then
			rotationTween = tween
			tween:Play()
		end
	end
	startRotation(cfg.LoadingIconTweenTime)

	local messageLabel = create("TextLabel", {
		Name = "Message",
		BackgroundTransparency = 1,
		AutomaticSize = loading.AutoResizeHeight and Enum.AutomaticSize.Y or Enum.AutomaticSize.XY,
		Size = loading.AutoResizeHeight and UDim2.new(1, -60, 0, 0) or UDim2.fromOffset(0, 0),
		Font = self.Theme.Font,
		TextSize = 18,
		TextWrapped = loading.AutoResizeHeight,
		TextColor3 = self.Theme.Text,
		Parent = inner,
	})
	local descriptionLabel = create("TextLabel", {
		Name = "Description",
		BackgroundTransparency = 1,
		AutomaticSize = loading.AutoResizeHeight and Enum.AutomaticSize.Y or Enum.AutomaticSize.XY,
		Size = loading.AutoResizeHeight and UDim2.new(1, -60, 0, 0) or UDim2.fromOffset(0, 0),
		Font = self.Theme.Font,
		TextSize = 14,
		TextWrapped = loading.AutoResizeHeight,
		TextTransparency = 0.5,
		TextColor3 = self.Theme.Text,
		Parent = inner,
	})

	local progressBar = create("Frame", {
		Name = "ProgressBar",
		BackgroundColor3 = self.Theme.SurfaceAlt,
		BorderSizePixel = 0,
		Size = UDim2.new(0.7, 0, 0, 15),
		Parent = inner,
	})
	addCorner(progressBar, self.Theme.CornerRadius / 2)
	addStroke(progressBar, self.Theme.Outline)
	local progressFill = create("Frame", {
		Name = "Fill",
		BackgroundColor3 = self.Theme.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = progressBar,
	})
	addCorner(progressFill, self.Theme.CornerRadius / 2)
	local progressLabel = create("TextLabel", {
		Name = "Progress",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = self.Theme.Font,
		TextSize = 14,
		TextColor3 = self.Theme.Text,
		ZIndex = 2,
		Parent = progressBar,
	})

	local sidebarScrolling = create("ScrollingFrame", {
		Name = "SidebarScrolling",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = self.Theme.Outline,
		Parent = sideBar,
	})
	local sidebarList = create("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sidebarScrolling,
	})
	create("UIPadding", {
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 12),
		Parent = sidebarScrolling,
	})
	local sidebar = {
		Elements = {},
		DependencyBoxes = {},
		Tabboxes = {},
		BoxHolder = sidebarScrolling,
		Container = sidebarScrolling,
		Holder = sidebarScrolling,
		Tab = { Elements = {}, DependencyBoxes = {}, Tabboxes = {} },
	}
	function sidebar:Resize()
		sidebarScrolling.CanvasSize = UDim2.fromOffset(0, sidebarList.AbsoluteContentSize.Y + 24)
	end
	track(sidebarList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		sidebar:Resize()
	end)
	function sidebar:AddDivider()
		local div = create("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundColor3 = Library.Theme.Outline,
			BorderSizePixel = 0,
			Parent = sidebarScrolling,
		})
		return div
	end
	function sidebar:AddLabel(arg1, arg2, arg3)
		local text, wrap, idx, info
		if type(arg1) == "table" then
			info = arg1
			text = info.Text or info.Name or ""
			wrap = info.DoesWrap
			idx = info.Idx or info.Index
		elseif type(arg2) == "table" then
			idx = arg1
			info = arg2
			text = info.Text or info.Name or tostring(idx or "")
			wrap = info.DoesWrap
		else
			text = arg1
			wrap = arg2
			idx = arg3
		end
		info = info or {}
		if wrap == nil then
			wrap = false
		end
		local label = create("TextLabel", {
			Name = "Label_" .. tostring(idx or ""),
			LayoutOrder = tonumber(idx) or 0,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = Library.Theme.Font,
			TextSize = 14,
			TextWrapped = wrap,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Library.Theme.Text,
			Text = tostring(text or ""),
			Parent = sidebarScrolling,
		})
		local obj = { Instance = label, Label = label, Text = label.Text }
		function obj:SetText(value)
			obj.Text = tostring(value or "")
			label.Text = obj.Text
		end
		function obj:Destroy()
			safeDestroy(label)
		end
		sidebar.Elements[idx or #sidebar.Elements + 1] = obj
		return obj
	end
	function sidebar:AddParagraph(text, wrap)
		return sidebar:AddLabel({ Text = text, DoesWrap = wrap ~= false })
	end
	function sidebar:AddButton(arg1, arg2)
		local info = type(arg1) == "table" and arg1 or { Text = arg1, Func = arg2 }
		info = info or {}
		local wrapper = createBaseElement(sidebarScrolling, 32)
		local button = create("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Library.Theme.SurfaceAlt,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Font = Library.Theme.Font,
			TextSize = 14,
			TextColor3 = Library.Theme.Text,
			Text = tostring(info.Text or info.Name or "Button"),
			Parent = wrapper,
		})
		addCorner(button, Library.Theme.CornerRadius)
		addStroke(button, Library.Theme.Outline)
		bindHover(button, Library.Theme.SurfaceAlt, Library.Theme.Outline)
		local obj = { Instance = wrapper, Button = button, Disabled = info.Disabled == true }
		button.MouseButton1Click:Connect(function()
			if not obj.Disabled then
				Library:SafeCallback(info.Func or info.Callback or info.Function)
			end
		end)
		function obj:SetDisabled(state) obj.Disabled = state == true end
		function obj:SetText(text) button.Text = tostring(text or "") end
		function obj:Destroy() safeDestroy(wrapper) end
		attachInfoTooltip(obj, info, button)
		table.insert(sidebar.Elements, obj)
		return obj
	end
	loading.Sidebar = sidebar

	local errorFrame = create("Frame", {
		Name = "Error",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 49),
		Size = UDim2.new(1, 0, 1, -49),
		ClipsDescendants = true,
		Visible = false,
		Parent = content,
	})
	create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(15, 15),
		Size = UDim2.new(1, -30, 0, 18),
		Font = self.Theme.Font,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = self.Theme.Danger,
		Text = "Error",
		Parent = errorFrame,
	})
	local errorMessage = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(15, 39),
		Size = UDim2.new(1, -30, 1, -90),
		Font = self.Theme.Font,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextTransparency = 0.2,
		TextColor3 = self.Theme.Text,
		Text = "Error Message",
		Parent = errorFrame,
	})
	local errorDivider = create("Frame", {
		BackgroundTransparency = 0,
		BackgroundColor3 = self.Theme.Outline,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, -48),
		Size = UDim2.new(1, -30, 0, 1),
		Visible = false,
		Parent = errorFrame,
	})
	local errorButtons = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 42),
		Visible = false,
		Parent = errorFrame,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = errorButtons,
	})
	create("UIPadding", {
		PaddingTop = UDim.new(0, 5),
		PaddingBottom = UDim.new(0, 15),
		PaddingRight = UDim.new(0, 15),
		Parent = errorButtons,
	})

	local function updateLayout()
		if loading.Destroyed then
			return
		end
		local show = loading.ShowSidebar
		local finalWidth = show and (loading.ContentWidth + loading.SidebarWidth) or loading.WindowWidth
		local finalHeight = loading.IsError and loading.WindowErrorHeight or loading.WindowHeight
		if show then
			sideBar.Visible = true
			sidebarDivider.Visible = true
		end
		pcall(function()
			TweenService:Create(main, tweenInfo, { Size = UDim2.fromOffset(finalWidth, finalHeight) }):Play()
			TweenService:Create(sideBar, tweenInfo, {
				Position = UDim2.fromOffset(loading.ContentWidth, 0),
				Size = UDim2.new(0, show and loading.SidebarWidth or 0, 1, 0),
			}):Play()
			TweenService:Create(content, tweenInfo, {
				Size = UDim2.new(0, show and loading.ContentWidth or loading.WindowWidth, 1, 0),
			}):Play()
		end)
		if not show then
			task.delay(tweenInfo.Time, function()
				if not loading.ShowSidebar and not loading.Destroyed then
					sideBar.Visible = false
					sidebarDivider.Visible = false
				end
			end)
		end
	end

	function loading:UpdateLayout()
		updateLayout()
	end
	function loading:RecalculateLoadingHeight()
		if not self.AutoResizeHeight then
			return
		end
		local required = 49 + 48 + innerLayout.AbsoluteContentSize.Y
		self.WindowHeight = math.max(self.BaseWindowHeight, required)
	end
	function loading:RecalculateErrorHeight()
		local targetWidth = (self.ShowSidebar and self.ContentWidth or self.WindowWidth) - 30
		local bounds = Library:GetTextBounds(errorMessage.Text, Library.Theme.Font, 14, targetWidth)
		local textHeight = (bounds and bounds.Y) or 14
		errorMessage.Size = UDim2.new(1, -30, 0, textHeight)
		self.WindowErrorHeight = 49 + 15 + 18 + 6 + textHeight + 15 + (errorButtons.Visible and 48 or 0)
	end
	function loading:SetMessage(text)
		messageLabel.Text = tostring(text or "")
		if self.AutoResizeHeight then
			self:RecalculateLoadingHeight()
			updateLayout()
		end
	end
	function loading:SetDescription(text)
		descriptionLabel.Text = tostring(text or "")
		if self.AutoResizeHeight then
			self:RecalculateLoadingHeight()
			updateLayout()
		end
	end
	function loading:SetCurrentStep(step)
		local total = math.max(1, tonumber(self.TotalSteps) or 1)
		self.CurrentStep = math.clamp(tonumber(step) or self.CurrentStep, 0, total)
		local progress = self.CurrentStep / total
		pcall(function()
			TweenService:Create(progressFill, tweenInfo, { Size = UDim2.fromScale(progress, 1) }):Play()
		end)
		progressLabel.Text = string.format("%d/%d", self.CurrentStep, total)
	end
	function loading:SetTotalSteps(steps)
		self.TotalSteps = math.max(1, tonumber(steps) or self.TotalSteps)
		self:SetCurrentStep(self.CurrentStep)
	end
	function loading:SetLoadingIcon(icon)
		local iconData = Library:GetCustomIcon(icon)
		assert(iconData, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")
		local replacement = Library:ApplyIcon(loadingIcon, iconData)
		if replacement ~= loadingIcon then
			loadingIcon = replacement
			startRotation(cfg.LoadingIconTweenTime)
		end
	end
	function loading:SetLoadingIconTweenTime(duration)
		cfg.LoadingIconTweenTime = tonumber(duration) or 0
		startRotation(cfg.LoadingIconTweenTime)
	end
	function loading:SetLoadingIconColor(color)
		if not loadingIcon then
			return
		end
		if loadingIcon:IsA("TextLabel") or loadingIcon:IsA("TextButton") then
			loadingIcon.TextColor3 = color
		else
			loadingIcon.ImageColor3 = color
		end
	end
	function loading:SetWindowHeight(height)
		self.WindowHeight = tonumber(height) or self.WindowHeight
		updateLayout()
	end
	function loading:SetWindowWidth(width)
		self.WindowWidth = tonumber(width) or self.WindowWidth
		updateLayout()
	end
	function loading:SetContentWidth(width)
		self.ContentWidth = tonumber(width) or self.ContentWidth
		updateLayout()
	end
	function loading:SetSidebarWidth(width)
		self.SidebarWidth = tonumber(width) or self.SidebarWidth
		updateLayout()
	end
	function loading:ShowSidebarPage(enabled)
		self.ShowSidebar = enabled == true
		updateLayout()
	end
	function loading:ShowErrorPage(enabled)
		self.IsError = enabled == true
		if self.IsError then
			self:RecalculateErrorHeight()
		end
		inner.Visible = not self.IsError
		errorFrame.Visible = self.IsError
		if self.ShowSidebar then
			self:ShowSidebarPage(not self.IsError)
		else
			updateLayout()
		end
	end
	function loading:SetErrorMessage(text)
		errorMessage.Text = tostring(text or "")
		if self.IsError then
			self:RecalculateErrorHeight()
			updateLayout()
		end
	end
	function loading:SetErrorButtons(buttons)
		assert(type(buttons) == "table", "Buttons must be a table")
		for _, child in ipairs(errorButtons:GetChildren()) do
			if child:IsA("Frame") then
				safeDestroy(child)
			end
		end
		local hasButtons = false
		for _ in pairs(buttons) do
			hasButtons = true
			break
		end
		errorButtons.Visible = hasButtons
		errorDivider.Visible = hasButtons
		for key, btnInfo in pairs(buttons) do
			btnInfo = type(btnInfo) == "table" and btnInfo or {}
			local variant = btnInfo.Variant or "Primary"
			local background = Library.Theme.Accent
			local textColor = Library.Theme.Background
			if variant == "Secondary" then
				background = Library.Theme.SurfaceAlt
				textColor = Library.Theme.Text
			elseif variant == "Destructive" then
				background = Library.Theme.Danger
				textColor = Color3.new(1, 1, 1)
			elseif variant == "Ghost" then
				background = Library.Theme.Surface
				textColor = Library.Theme.Text
			end
			local text = tostring(btnInfo.Title or key)
			local width = (Library:GetTextBounds(text, Library.Theme.Font, 14) or Vector2.zero).X + 30
			local holder = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(width, 26),
				Parent = errorButtons,
			})
			local button = create("TextButton", {
				BackgroundColor3 = background,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = Library.Theme.Font,
				Text = "",
				TextColor3 = textColor,
				Size = UDim2.fromOffset(width, 26),
				Parent = holder,
			})
			addCorner(button, Library.Theme.CornerRadius)
			addStroke(button, background)
			create("UIPadding", {
				PaddingLeft = UDim.new(0, 15),
				PaddingRight = UDim.new(0, 15),
				Parent = button,
			})
			create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Font = Library.Theme.Font,
				TextSize = 14,
				TextColor3 = textColor,
				Text = text,
				Parent = button,
			})
			bindHover(button, background, background)
			button.MouseButton1Click:Connect(function()
				Library:SafeCallback(btnInfo.Callback, loading)
			end)
		end
		if self.IsError then
			self:RecalculateErrorHeight()
		end
		updateLayout()
	end
	function loading:ChangeDescription(text) self:SetDescription(text) end
	function loading:ChangeStep(step) self:SetCurrentStep(step) end

	function loading:Destroy()
		if self.Destroyed then
			return
		end
		self.Destroyed = true
		stopRotation()
		for _, conn in ipairs(connections) do
			pcall(function() conn:Disconnect() end)
		end
		safeDestroy(screenGui)
		if Library.ActiveLoading == self then
			Library.ActiveLoading = nil
		end
		if (restoreWindow or self._RestoreWindow) and Library.ActiveWindow then
			pcall(function() Library.ActiveWindow:Toggle(true) end)
		end
	end
	loading.Continue = loading.Destroy

	loading:SetCurrentStep(loading.CurrentStep)
	sidebar:Resize()
	updateLayout()
	return loading
end

function Library:CreateWindow(config)
	config = config or {}
	local selfLib = self

	local windowTitle = config.Title or "UI Library"
	local footerText = config.Footer or ""
	local toggleKey = config.ToggleKeybind or config.MenuKeybind or Enum.KeyCode.RightControl
	local size = config.Size or UDim2.fromOffset(680, 460)
	local position = config.Position or UDim2.fromScale(0.5, 0.5)
	if config.Center then
		position = UDim2.fromScale(0.5, 0.5)
	end

	-- theme overrides from the window props
	if typeof(config.Font) == "EnumItem" then
		selfLib.Theme.Font = config.Font
	elseif type(config.Font) == "string" and Enum.Font[config.Font] then
		selfLib.Theme.Font = Enum.Font[config.Font]
	end
	if tonumber(config.CornerRadius) then
		selfLib.Theme.CornerRadius = tonumber(config.CornerRadius)
	end

	-- opt-in animations (all off unless enabled, like Obsidian)
	selfLib.Animations = { ToggleWindow = false, TabSwitch = false, Groupbox = false, Dropdown = false, KeyPicker = false }
	if type(config.Animations) == "table" then
		for k, v in pairs(config.Animations) do
			selfLib.Animations[k] = v == true
		end
	end
	selfLib.TabTransitionTime = tonumber(config.TabTransitionTime) or 0.22
	selfLib.TabSwipeOffset = tonumber(config.TabSwipeOffset) or 26
	selfLib.TabSwipeFrom = string.lower(tostring(config.TabSwipeFrom or "bottom"))

	selfLib.TabButtonsStyle = {
		Gap = 6,
		Padding = 8,
		CornerRadius = selfLib.Theme.CornerRadius,
		Indicator = false,
		IndicatorWidth = 2,
		IndicatorHeight = 20,
	}
	if type(config.TabButtonsStyle) == "table" then
		for k, v in pairs(config.TabButtonsStyle) do
			selfLib.TabButtonsStyle[k] = v
		end
	end

	local screenGui = create("ScreenGui", {
		Name = "PESUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = config.AlwaysOnTop == true and 999999 or 0,
	})
	protectGui(screenGui)
	self.ScreenGui = screenGui
	selfLib.NotifySide = config.NotifySide or selfLib.NotifySide

	local overlay = create("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5000,
		Parent = screenGui,
	})
	self.OverlayFrame = overlay
	selfLib.OverlayFrame = overlay

	local notifyHolder = create("Frame", {
		Name = "Notifications",
		AnchorPoint = selfLib.NotifySide == "Left" and Vector2.new(0, 1) or Vector2.new(1, 1),
		Position = selfLib.NotifySide == "Left" and UDim2.new(0, 20, 1, -20) or UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(260, 400),
		BackgroundTransparency = 1,
		ZIndex = 6000,
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

	local function getOverlayParent()
		local overlayFrame = selfLib.OverlayFrame
		if (not overlayFrame or not overlayFrame.Parent) and selfLib.ScreenGui then
			overlayFrame = selfLib.ScreenGui:FindFirstChild("Overlay")
			if not overlayFrame then
				overlayFrame = create("Frame", {
					Name = "Overlay",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ZIndex = 5000,
					Parent = selfLib.ScreenGui,
				})
			end
			selfLib.OverlayFrame = overlayFrame
		end
		return overlayFrame or selfLib.ScreenGui or screenGui
	end

	-- ====================================================================
	-- Unified KeyPicker (used by Label / Toggle / groupbox variants)
	-- ====================================================================
	-- small "pop" for popups (dropdown menus) when the Dropdown animation is on
	local function popIn(frame)
		if not (selfLib.Animations and selfLib.Animations.Dropdown) then
			return
		end
		local sc = frame:FindFirstChildOfClass("UIScale") or create("UIScale", { Parent = frame })
		sc.Scale = 0.9
		TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	local MODIFIER_KEYS = {
		LeftShift = true, RightShift = true,
		LeftControl = true, RightControl = true,
		LeftAlt = true, RightAlt = true,
	}
	local MODIFIER_ORDER = { "LeftControl", "RightControl", "LeftShift", "RightShift", "LeftAlt", "RightAlt" }

	local function createKeyPicker(id, info, opts)
		info = info or {}
		opts = opts or {}

		local picker = createOptionObject("KeyPicker", id, { Value = info.Default or "None" })
		if typeof(picker.Value) == "EnumItem" then
			picker.Value = picker.Value.Name
		end
		picker.Mode = info.Mode or "Toggle"
		picker.Modes = {}
		for _, m in ipairs(info.Modes or { "Always", "Toggle", "Hold" }) do
			table.insert(picker.Modes, m)
		end
		if not table.find(picker.Modes, picker.Mode) then
			table.insert(picker.Modes, picker.Mode)
		end
		picker.Callback = info.Callback
		picker.Clicked = info.Clicked or info.Callback
		picker.ChangedCallback = info.ChangedCallback
		picker.Changed = info.Changed
		picker.WaitForCallback = info.WaitForCallback == true
		picker.Modifiers = {}
		if type(info.DefaultModifiers) == "table" then
			for _, m in ipairs(info.DefaultModifiers) do
				table.insert(picker.Modifiers, m)
			end
		elseif type(info.Modifiers) == "table" then
			for _, m in ipairs(info.Modifiers) do
				table.insert(picker.Modifiers, m)
			end
		end
		-- Obsidian source uses Blacklisted*; the docs spell them Blacklist*.
		-- Accept both so either style works.
		local blacklisted = info.Blacklisted or info.Blacklist
		local blacklistedModifiers = info.BlacklistedModifiers or info.BlacklistModifiers
		picker.Whitelisted = type(info.Whitelisted) == "table" and info.Whitelisted or nil
		picker.Blacklisted = type(blacklisted) == "table" and blacklisted or nil
		picker.WhitelistedModifiers = type(info.WhitelistedModifiers) == "table" and info.WhitelistedModifiers or nil
		picker.BlacklistedModifiers = type(blacklistedModifiers) == "table" and blacklistedModifiers or nil
		local function isKeyAllowed(keyStr)
			if picker.Blacklisted and table.find(picker.Blacklisted, keyStr) then
				return false
			end
			if picker.Whitelisted and #picker.Whitelisted > 0 and not table.find(picker.Whitelisted, keyStr) then
				return false
			end
			return true
		end
		picker.ClickCallbacks = {}
		picker.SyncToggleState = info.SyncToggleState == true
		picker.NoUI = info.NoUI == true
		-- SaveManager persists "hidden from the keybind list" through this
		-- flag; Obsidian's default is visible.
		picker.MenuVisible = info.MenuVisible ~= false
		picker.DisplayName = tostring(info.Text or info.Title or id)
		picker.Toggled = picker.Mode == "Always"
		picker.Destroyed = false

		local props = {
			Size = UDim2.fromOffset(64, 18),
			BackgroundColor3 = selfLib.Theme.SurfaceAlt,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Font = selfLib.Theme.Font,
			TextSize = 12,
			TextColor3 = selfLib.Theme.Text,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = "",
			Parent = opts.Parent,
		}
		for k, v in pairs(opts.ButtonProps or {}) do
			props[k] = v
		end
		local button = create("TextButton", props)
		addCorner(button, 4)
		addStroke(button, selfLib.Theme.Outline)
		if picker.NoUI then
			button.Visible = false
		end

		local listening = false
		local hovering = false
		local pending = {}
		local keyConns = {}
		local modeMenu, modeBackdrop, modeHover, skipReopen = nil, nil, false, false

		local function refreshList()
			if selfLib._RefreshKeybindList then
				selfLib:_RefreshKeybindList()
			end
		end

		local function pendingList()
			local list = {}
			for _, name in ipairs(MODIFIER_ORDER) do
				if pending[name] then
					table.insert(list, name)
				end
			end
			return list
		end

		local function displayText()
			local key = tostring(picker.Value)
			if key == "" or key == "None" then
				return "None"
			end
			if #picker.Modifiers > 0 then
				return table.concat(picker.Modifiers, " + ") .. " + " .. key
			end
			return key
		end
		function picker:GetDisplayText()
			return displayText()
		end

		local function refreshButton()
			if not listening then
				button.Text = displayText()
			end
		end

		local function modsKey()
			return table.concat(picker.Modifiers, "+")
		end

		local function keyToString(input)
			local t = input.UserInputType
			if t == Enum.UserInputType.Keyboard then
				return input.KeyCode.Name
			elseif t == Enum.UserInputType.MouseButton1 then
				return "MB1"
			elseif t == Enum.UserInputType.MouseButton2 then
				return "MB2"
			elseif t == Enum.UserInputType.MouseButton3 then
				return "MB3"
			end
			return nil
		end

		local function modifiersHeld()
			for _, name in ipairs(picker.Modifiers) do
				local ok, kc = pcall(function()
					return Enum.KeyCode[name]
				end)
				if not ok or not UserInputService:IsKeyDown(kc) then
					return false
				end
			end
			return true
		end

		local function matchesKey(input)
			local key = tostring(picker.Value)
			if key == "None" or key == "" then
				return false
			end
			return keyToString(input) == key
		end

		local function applyModeState()
			if picker.Mode == "Always" then
				picker.Toggled = true
			elseif picker._Sync and picker.Mode == "Toggle" then
				picker.Toggled = picker._Sync.Value == true
			else
				picker.Toggled = false
			end
		end

		local function fireClick(state)
			selfLib:SafeCallback(picker.Callback, state)
			selfLib:SafeCallback(picker.Clicked, state)
			for _, cb in ipairs(picker.ClickCallbacks) do
				selfLib:SafeCallback(cb, state)
			end
		end

		local function fireChanged()
			selfLib:SafeCallback(picker.ChangedCallback, picker.Value, picker.Modifiers)
			selfLib:SafeCallback(picker.Changed, picker.Value, picker.Modifiers)
			for _, fn in ipairs(picker.ChangedCallbacks) do
				selfLib:SafeCallback(fn, picker.Value, picker.Modifiers)
			end
		end

		local function pulse()
			if not (selfLib.Animations and selfLib.Animations.KeyPicker) then
				return
			end
			button.BackgroundColor3 = selfLib.Theme.Accent
			TweenService:Create(button, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
			}):Play()
		end

		-- "Always" has a constant state (true); it never reacts to the key.
		local function press()
			pulse()
			if picker.Mode == "Toggle" then
				picker.Toggled = not picker.Toggled
				fireClick(picker.Toggled)
			elseif picker.Mode == "Hold" then
				picker.Toggled = true
				fireClick(true)
			elseif picker.Mode == "Press" then
				-- Obsidian: with WaitForCallback, stay latched until the
				-- consumer resets Toggled; otherwise re-press fires again.
				if picker.Toggled and picker.WaitForCallback then
					return
				end
				picker.Toggled = true
				fireClick(true)
			end
			refreshList()
		end

		-- ---------- mode menu (right click) ----------
		local function closeModeMenu()
			if modeMenu then
				safeDestroy(modeMenu)
				modeMenu = nil
			end
			if modeBackdrop then
				safeDestroy(modeBackdrop)
				modeBackdrop = nil
			end
			modeHover = false
			if selfLib._CloseKeyModeMenu == closeModeMenu then
				selfLib._CloseKeyModeMenu = nil
			end
		end

		local function openModeMenu()
			if selfLib._CloseKeyModeMenu then
				pcall(selfLib._CloseKeyModeMenu)
			end
			closeModeMenu()
			local overlayParent = getOverlayParent()
			modeBackdrop = create("TextButton", {
				Name = "KeyModeBackdrop",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 6009,
				Parent = overlayParent,
			})
			modeBackdrop.InputBegan:Connect(function(input)
				local t = input.UserInputType
				if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.Touch then
					closeModeMenu()
				end
			end)
			local ap, as = button.AbsolutePosition, button.AbsoluteSize
			local width = math.max(as.X, 80)
			local rowH = 22
			local height = #picker.Modes * rowH + 4
			local x = ap.X + as.X - width
			local y = ap.Y + as.Y + 2
			local vp = overlayParent.AbsoluteSize
			if vp.Y > 0 and y + height > vp.Y - 8 then
				y = ap.Y - height - 2
			end
			if vp.X > 0 then
				x = math.clamp(x, 8, math.max(8, vp.X - width - 8))
			end
			modeMenu = create("Frame", {
				Name = "KeyModeMenu",
				Size = UDim2.fromOffset(width, height),
				Position = UDim2.fromOffset(math.floor(x), math.floor(y)),
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				Active = true,
				ZIndex = 6010,
				Parent = overlayParent,
			})
			addCorner(modeMenu, 4)
			addStroke(modeMenu, selfLib.Theme.Outline)
			modeMenu.MouseEnter:Connect(function()
				modeHover = true
			end)
			modeMenu.MouseLeave:Connect(function()
				modeHover = false
			end)
			for i, mode in ipairs(picker.Modes) do
				local opt = create("TextButton", {
					Position = UDim2.fromOffset(0, 2 + (i - 1) * rowH),
					Size = UDim2.new(1, 0, 0, rowH),
					BackgroundTransparency = 1,
					AutoButtonColor = false,
					Font = selfLib.Theme.Font,
					TextSize = 13,
					TextColor3 = mode == picker.Mode and selfLib.Theme.Accent or selfLib.Theme.Text,
					Text = mode,
					ZIndex = 6011,
					Parent = modeMenu,
				})
				opt.MouseButton1Click:Connect(function()
					picker:SetMode(mode)
					closeModeMenu()
				end)
			end
			selfLib._CloseKeyModeMenu = closeModeMenu
		end

		-- ---------- listening ----------
		local function setListening(state)
			state = state and true or false
			pending = {}
			if state then
				local prev = selfLib._ListeningKey
				if prev and prev ~= picker and prev._CancelListening then
					prev._CancelListening()
				end
				closeModeMenu()
				selfLib._ListeningKey = picker
				listening = true
				button.Text = "..."
			else
				listening = false
				button.Text = displayText()
				-- keep the flag up until every handler of the current input
				-- event has run (see _ListeningKey checks)
				task.defer(function()
					if not listening and selfLib._ListeningKey == picker then
						selfLib._ListeningKey = nil
					end
				end)
			end
		end
		picker._CancelListening = function()
			setListening(false)
		end

		button.MouseEnter:Connect(function()
			hovering = true
		end)
		button.MouseLeave:Connect(function()
			hovering = false
		end)
		button.MouseButton1Click:Connect(function()
			setListening(not listening)
		end)
		button.MouseButton2Click:Connect(function()
			if listening then
				return
			end
			if skipReopen then
				skipReopen = false
				return
			end
			if modeMenu then
				closeModeMenu()
			else
				openModeMenu()
			end
		end)

		table.insert(keyConns, selfLib:Connect(UserInputService.InputBegan, function(input, gpe)
			local t = input.UserInputType
			if listening then
				-- presses on our own button are handled by its Click events
				if hovering and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2) then
					return
				end
				if t == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.Escape then
						picker:SetValue({ "None", Modifiers = {} })
						setListening(false)
						return
					end
					if input.KeyCode == Enum.KeyCode.Unknown then
						return
					end
					if MODIFIER_KEYS[input.KeyCode.Name] then
						pending[input.KeyCode.Name] = true
						button.Text = table.concat(pendingList(), " + ") .. " + ..."
						return
					end
				end
				local keyStr = keyToString(input)
				if keyStr and isKeyAllowed(keyStr) then
					picker:SetValue({ keyStr, Modifiers = pendingList() })
					setListening(false)
				end
				return
			end

			if selfLib._ListeningKey then
				return
			end
			if gpe then
				return
			end
			if not matchesKey(input) or not modifiersHeld() then
				return
			end
			press()
		end))

		table.insert(keyConns, selfLib:Connect(UserInputService.InputEnded, function(input)
			if listening then
				-- a modifier released without a normal key => bind the modifier (combo)
				if input.UserInputType == Enum.UserInputType.Keyboard and pending[input.KeyCode.Name] then
					local name = input.KeyCode.Name
					pending[name] = nil
					local mods = pendingList()
					picker:SetValue({ name, Modifiers = mods })
					setListening(false)
				end
				return
			end
			if picker.Mode == "Hold" and picker.Toggled and matchesKey(input) then
				picker.Toggled = false
				fireClick(false)
				refreshList()
			end
		end))

		-- ---------- API ----------
		picker.Instance = opts.Instance or button
		picker._setter = function(value)
			if type(value) == "table" then
				local key = value[1] or value.Key
				if typeof(key) == "EnumItem" then
					key = key.Name
				end
				if key ~= nil then
					picker.Value = key
				end
				local mode = value[2] or value.Mode
				if type(mode) == "string" then
					picker.Mode = mode
					if not table.find(picker.Modes, mode) then
						table.insert(picker.Modes, mode)
					end
				end
				local mods = {}
				if type(value.Modifiers) == "table" then
					for _, m in ipairs(value.Modifiers) do
						table.insert(mods, m)
					end
				end
				picker.Modifiers = mods
			else
				if typeof(value) == "EnumItem" then
					value = value.Name
				end
				picker.Value = value or "None"
				picker.Modifiers = {}
			end
			selfLib.Flags[id] = picker.Value
		end

		function picker:SetValue(value)
			local oldKey, oldMode, oldMods = picker.Value, picker.Mode, modsKey()
			picker._setter(value)
			if oldMode ~= picker.Mode then
				applyModeState()
			end
			if oldKey ~= picker.Value or oldMods ~= modsKey() then
				applyModeState()
				fireChanged()
				pulse()
			end
			refreshButton()
			refreshList()
		end

		function picker:SetMode(mode)
			if type(mode) ~= "string" then
				return
			end
			if not table.find(picker.Modes, mode) then
				table.insert(picker.Modes, mode)
			end
			picker.Mode = mode
			applyModeState()
			refreshList()
		end

		function picker:GetState()
			return picker.Mode == "Always" or picker.Toggled == true
		end

		function picker:DoClick()
			press()
		end

		function picker:OnClick(cb)
			if type(cb) == "function" then
				table.insert(picker.ClickCallbacks, cb)
			end
			return cb
		end

		-- does not fire immediately on registration (matches Obsidian/Linoria)
		function picker:OnChanged(cb)
			if type(cb) == "function" then
				table.insert(picker.ChangedCallbacks, cb)
			end
			return cb
		end

		function picker:SetText(text)
			picker.DisplayName = tostring(text or "")
			if opts.Label then
				opts.Label.Text = picker.DisplayName
			end
			refreshList()
		end

		-- two-way link with a Toggle (SyncToggleState)
		function picker:SyncToggle(toggle)
			picker._Sync = toggle
			picker.SyncToggleState = true
			toggle:OnChanged(function(v)
				if picker.Mode == "Toggle" then
					picker.Toggled = v == true
					refreshList()
				end
			end)
			picker:OnClick(function(state)
				if type(state) == "boolean" and (picker.Mode == "Toggle" or picker.Mode == "Hold") then
					toggle:SetValue(state)
				end
			end)
		end

		function picker:Update() end
		function picker:Display(text)
			if text ~= nil then
				picker:SetText(text)
			end
		end
		function picker:SetMenuVisibility(visible)
			picker.MenuVisible = visible ~= false
			if selfLib and selfLib._RefreshKeybindList then
				task.defer(function()
					if selfLib and selfLib._RefreshKeybindList then
						pcall(selfLib._RefreshKeybindList, selfLib)
					end
				end)
			end
		end
		function picker:RunChanged()
			if picker.ChangedCallback then
				Library:SafeCallback(picker.ChangedCallback, picker.Value, picker.Modifiers)
			end
		end

		function picker:Destroy()
			picker.Destroyed = true
			for _, c in ipairs(keyConns) do
				pcall(function()
					c:Disconnect()
				end)
			end
			table.clear(keyConns)
			closeModeMenu()
			if selfLib._ListeningKey == picker then
				selfLib._ListeningKey = nil
			end
			if selfLib.KeyPickers then
				local idx = table.find(selfLib.KeyPickers, picker)
				if idx then
					table.remove(selfLib.KeyPickers, idx)
				end
			end
			if selfLib.Options[id] == picker then
				selfLib.Options[id] = nil
			end
			if picker.Instance then
				safeDestroy(picker.Instance)
			end
			refreshList()
		end

		refreshButton()
		attachInfoTooltip(picker, info, button)
		selfLib.Options[id] = picker
		selfLib.Flags[id] = picker.Value
		selfLib.KeyPickers = selfLib.KeyPickers or {}
		table.insert(selfLib.KeyPickers, picker)
		refreshList()
		return picker
	end

	local function closeOpenColorPicker(exceptPicker)
		local closer = selfLib._OpenColorPickerCloser
		if closer and selfLib._OpenColorPickerOwner ~= exceptPicker then
			pcall(closer)
		end
	end

	local function createColorPickerControl(id, info, opts)
		opts = opts or {}
		info = info or {}
		local defaultColor = info.Default
		if typeof(defaultColor) ~= "Color3" then
			defaultColor = Color3.new(1, 1, 1)
		end
		local hasTransparency = info.Transparency ~= nil
		local defaultTransparency = hasTransparency and math.clamp(tonumber(info.Transparency) or 0, 0, 1) or 0

		local picker = createOptionObject("ColorPicker", id, { Value = defaultColor })
		picker.Title = info.Title or info.Text or opts.LabelText or id
		picker.Callback = info.Callback
		picker.Changed = info.Changed
		picker.Transparency = defaultTransparency
		picker.HasTransparency = hasTransparency
		picker.Resizable = info.Resizable == true
		picker.Hue, picker.Sat, picker.Vib = defaultColor:ToHSV()
		picker.Open = false
		picker.Destroyed = false
		picker.Connections = picker.Connections or {}

		local function registerPicker(value)
			picker.Value = value
			selfLib.Flags[id] = value
			selfLib.Options[id] = picker
		end

		local labelText = tostring(info.Text or info.Title or opts.LabelText or id or "")

		local instance
		local label
		local swatch
		local swatchTransparency
		local swatchStroke

		if opts.Variant == "Row" then
			instance = createBaseElement(opts.Holder, 30)
			label = create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -60, 1, 0),
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = selfLib.Theme.Text,
				Text = labelText,
				Parent = instance,
			})
			swatch = create("TextButton", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 0),
				Size = UDim2.fromOffset(42, 22),
				BackgroundColor3 = defaultColor,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				Parent = instance,
			})
		else
			swatch = create("TextButton", {
				Size = opts.SwatchSize or UDim2.fromOffset(28, 18),
				BackgroundColor3 = defaultColor,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Text = "",
				Parent = opts.AddonsParent,
			})
			instance = swatch
			label = opts.LabelRef
		end

		addCorner(swatch, 4)
		swatchStroke = addStroke(swatch, selfLib.Theme.Outline)

		swatchTransparency = create("ImageLabel", {
			Name = "Transparency",
			BackgroundTransparency = 1,
			Image = "rbxassetid://18274452449",
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(6, 6),
			Size = UDim2.fromScale(1, 1),
			ImageTransparency = hasTransparency and (1 - defaultTransparency) or 1,
			ZIndex = (swatch.ZIndex or 1),
			Parent = swatch,
		})
		addCorner(swatchTransparency, 4)

		local menu = create("Frame", {
			Name = "ColorPickerMenu",
			Visible = false,
			Active = true,
			ClipsDescendants = false,
			BackgroundColor3 = selfLib.Theme.SurfaceAlt,
			BorderSizePixel = 0,
			ZIndex = 6005,
			Size = UDim2.fromOffset(hasTransparency and 228 or 206, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = getOverlayParent(),
		})
		addCorner(menu, selfLib.Theme.CornerRadius)
		addStroke(menu, selfLib.Theme.Outline)
		create("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = menu,
		})
		addPadding(menu, 8)

		if picker.Title and picker.Title ~= "" then
			create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 16),
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = selfLib.Theme.Text,
				Text = tostring(picker.Title),
				LayoutOrder = 0,
				Parent = menu,
			})
		end

		local mapRow = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 150),
			LayoutOrder = 1,
			Parent = menu,
		})
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = mapRow,
		})

		local svMap = create("TextButton", {
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(150, 150),
			BackgroundColor3 = Color3.fromHSV(picker.Hue, 1, 1),
			ClipsDescendants = true,
			LayoutOrder = 1,
			ZIndex = 6006,
			Parent = mapRow,
		})
		addCorner(svMap, 4)
		addStroke(svMap, selfLib.Theme.Outline)

		local satOverlay = create("Frame", {
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 6007,
			Active = false,
			Parent = svMap,
		})
		addCorner(satOverlay, 4)
		create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Parent = satOverlay,
		})

		local valOverlay = create("Frame", {
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 6008,
			Active = false,
			Parent = svMap,
		})
		addCorner(valOverlay, 4)
		create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Parent = valOverlay,
		})

		local svCursor = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 6010,
			Active = false,
			Parent = svMap,
		})
		addCorner(svCursor, 99)
		addStroke(svCursor, Color3.new(0, 0, 0), 0.35)

		local hueBar = create("TextButton", {
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(16, 150),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			LayoutOrder = 2,
			ZIndex = 6006,
			Parent = mapRow,
		})
		addCorner(hueBar, 4)
		addStroke(hueBar, selfLib.Theme.Outline)
		create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(1/6, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(2/6, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(3/6, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(4/6, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(5/6, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
			}),
			Parent = hueBar,
		})

		local hueCursor = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(1, 4, 0, 2),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 6010,
			Active = false,
			Parent = hueBar,
		})
		addCorner(hueCursor, 2)
		addStroke(hueCursor, Color3.new(0, 0, 0), 0.4)

		local transparencyBar
		local transparencyColorOverlay
		local transparencyCursor
		if hasTransparency then
			transparencyBar = create("TextButton", {
				AutoButtonColor = false,
				Text = "",
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(16, 150),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				ClipsDescendants = true,
				LayoutOrder = 3,
				ZIndex = 6006,
				Parent = mapRow,
			})
			addCorner(transparencyBar, 4)
			addStroke(transparencyBar, selfLib.Theme.Outline)
			create("ImageLabel", {
				BackgroundTransparency = 1,
				Image = "rbxassetid://18274452449",
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromOffset(6, 6),
				Size = UDim2.fromScale(1, 1),
				ZIndex = 6007,
				Active = false,
				Parent = transparencyBar,
			})
			transparencyColorOverlay = create("Frame", {
				BackgroundColor3 = defaultColor,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 6008,
				Active = false,
				Parent = transparencyBar,
			})
			addCorner(transparencyColorOverlay, 4)
			create("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Parent = transparencyColorOverlay,
			})
			transparencyCursor = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.new(1, 4, 0, 2),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BorderSizePixel = 0,
				ZIndex = 6010,
				Active = false,
				Parent = transparencyBar,
			})
			addCorner(transparencyCursor, 2)
			addStroke(transparencyCursor, Color3.new(0, 0, 0), 0.4)
		end

		local infoHolder = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 2,
			Parent = menu,
		})
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = infoHolder,
		})

		local hexBox = create("TextBox", {
			BackgroundColor3 = selfLib.Theme.Surface,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = selfLib.Theme.Font,
			TextSize = 13,
			TextColor3 = selfLib.Theme.Text,
			PlaceholderText = "Hex",
			PlaceholderColor3 = selfLib.Theme.SubText,
			Size = UDim2.new(0.42, -3, 1, 0),
			Text = "#FFFFFF",
			LayoutOrder = 1,
			Parent = infoHolder,
		})
		addCorner(hexBox, 4)
		addStroke(hexBox, selfLib.Theme.Outline)

		local rgbBox = create("TextBox", {
			BackgroundColor3 = selfLib.Theme.Surface,
			BorderSizePixel = 0,
			ClearTextOnFocus = false,
			Font = selfLib.Theme.Font,
			TextSize = 13,
			TextColor3 = selfLib.Theme.Text,
			PlaceholderText = "R, G, B",
			PlaceholderColor3 = selfLib.Theme.SubText,
			Size = UDim2.new(0.58, -3, 1, 0),
			Text = "255, 255, 255",
			LayoutOrder = 2,
			Parent = infoHolder,
		})
		addCorner(rgbBox, 4)
		addStroke(rgbBox, selfLib.Theme.Outline)

		local function getOverlayGui()
			return selfLib.OverlayFrame or (selfLib.ScreenGui and selfLib.ScreenGui:FindFirstChild("Overlay")) or selfLib.ScreenGui or screenGui
		end

		local function isDragInput(input)
			return input and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch)
		end

		local updateMenuPosition -- forward declaration (defined below)
		local positionConn
		local function stopMenuTracking()
			if positionConn then
				pcall(function()
					positionConn:Disconnect()
				end)
				positionConn = nil
			end
		end
		local function startMenuTracking()
			stopMenuTracking()
			positionConn = RunService.RenderStepped:Connect(function()
				if picker.Destroyed or not menu or not menu.Parent or not menu.Visible or not picker.Open then
					stopMenuTracking()
					return
				end
				updateMenuPosition()
			end)
		end

		local backdrop
		local function setBackdrop(state)
			if state then
				if not backdrop or not backdrop.Parent then
					backdrop = create("TextButton", {
						Name = "ColorPickerBackdrop",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						AutoButtonColor = false,
						ZIndex = 6004,
						Visible = false,
						Parent = menu.Parent,
					})
					backdrop.InputBegan:Connect(function(input)
						local t = input.UserInputType
						if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.Touch then
							if selfLib._OpenColorPickerCloser then
								pcall(selfLib._OpenColorPickerCloser)
							end
						end
					end)
					menu.Destroying:Connect(function()
						safeDestroy(backdrop)
					end)
				end
				backdrop.Parent = menu.Parent
				backdrop.Visible = true
			elseif backdrop then
				backdrop.Visible = false
			end
		end

		local function setMenuOpen(state)
			state = state and true or false
			if picker.Destroyed then
				return
			end
			if state then
				if selfLib._OpenDropdownCloser then
					pcall(selfLib._OpenDropdownCloser)
				end
				closeOpenColorPicker(picker)

				local overlayGui = getOverlayGui()
				if menu.Parent ~= overlayGui then
					menu.Parent = overlayGui
				end
				menu.Visible = true
				setBackdrop(true)
				picker.Open = true

				local closer
				closer = function()
					if picker.Destroyed then
						return
					end
					menu.Visible = false
					setBackdrop(false)
					picker.Open = false
					stopMenuTracking()
					if selfLib._OpenColorPickerCloser == closer then
						selfLib._OpenColorPickerCloser = nil
						selfLib._OpenColorPickerOwner = nil
					end
				end
				selfLib._OpenColorPickerOwner = picker
				selfLib._OpenColorPickerCloser = closer

				startMenuTracking()
				updateMenuPosition()
				task.defer(updateMenuPosition)
				task.delay(0.05, function()
					if picker.Open and menu.Visible and not picker.Destroyed then
						updateMenuPosition()
					end
				end)
			else
				menu.Visible = false
				setBackdrop(false)
				picker.Open = false
				stopMenuTracking()
				if selfLib._OpenColorPickerOwner == picker then
					selfLib._OpenColorPickerCloser = nil
					selfLib._OpenColorPickerOwner = nil
				end
			end
		end

		function updateMenuPosition()
			if not menu.Visible or not swatch or not swatch.Parent then
				return
			end

			local absPos = swatch.AbsolutePosition
			local absSize = swatch.AbsoluteSize
			local menuSize = menu.AbsoluteSize
			if menuSize.X <= 0 or menuSize.Y <= 0 then
				menuSize = Vector2.new(hasTransparency and 228 or 206, 230)
			end

			local gui = selfLib.ScreenGui
			local viewport = gui and gui.AbsoluteSize or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1920, 1080)

			local x = absPos.X
			if opts.Variant == "Row" then
				x = absPos.X + absSize.X - menuSize.X
			else
				x = absPos.X - 1
			end

			local belowY = absPos.Y + absSize.Y + 4
			local aboveY = absPos.Y - menuSize.Y - 4
			local y = belowY
			if belowY + menuSize.Y > viewport.Y - 8 and aboveY >= 8 then
				y = aboveY
			end

			x = math.clamp(x, 8, math.max(8, viewport.X - menuSize.X - 8))
			y = math.clamp(y, 8, math.max(8, viewport.Y - menuSize.Y - 8))
			menu.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
		end

		local function currentColor()
			return Color3.fromHSV(math.clamp(picker.Hue or 0, 0, 1), math.clamp(picker.Sat or 0, 0, 1), math.clamp(picker.Vib or 0, 0, 1))
		end

		local function display()
			local color = currentColor()
			picker.Value = color
			registerPicker(color)

			svMap.BackgroundColor3 = Color3.fromHSV(picker.Hue, 1, 1)
			svCursor.Position = UDim2.fromScale(math.clamp(picker.Sat, 0, 1), 1 - math.clamp(picker.Vib, 0, 1))
			hueCursor.Position = UDim2.fromScale(0.5, math.clamp(picker.Hue, 0, 1))
			if transparencyCursor then
				transparencyCursor.Position = UDim2.fromScale(0.5, math.clamp(picker.Transparency, 0, 1))
			end
			if transparencyColorOverlay then
				transparencyColorOverlay.BackgroundColor3 = color
			end

			swatch.BackgroundColor3 = color
			if swatchStroke then
				swatchStroke.Color = selfLib.Theme.Outline
			end
			if swatchTransparency then
				swatchTransparency.ImageTransparency = hasTransparency and (1 - math.clamp(picker.Transparency, 0, 1)) or 1
			end

			if not hexBox:IsFocused() then
				hexBox.Text = "#" .. string.upper(color:ToHex())
			end
			if not rgbBox:IsFocused() then
				rgbBox.Text = string.format("%d, %d, %d", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
			end
		end

		local function fireChanged()
			picker.Value = currentColor()
			registerPicker(picker.Value)

			if type(picker.Changed) == "function" then
				selfLib:SafeCallback(picker.Changed, picker.Value, picker.Transparency)
			end

			for _, fn in ipairs(picker.ChangedCallbacks) do
				if fn ~= picker.Changed then
					selfLib:SafeCallback(fn, picker.Value, picker.Transparency)
				end
			end

			if type(picker.Callback) == "function" then
				selfLib:SafeCallback(picker.Callback, picker.Value, picker.Transparency)
			end
		end

		local function setHSVFromRGB(color)
			if typeof(color) ~= "Color3" then
				return
			end
			picker.Hue, picker.Sat, picker.Vib = color:ToHSV()
		end

		function picker:Display()
			display()
		end

		function picker:Update(silent)
			display()
			if not silent then
				fireChanged()
			end
			if menu.Visible then
				task.defer(updateMenuPosition)
			end
		end

		function picker:SetValueHSVFromRGB(color)
			setHSVFromRGB(color)
		end
		-- Obsidian name
		function picker:SetHSVFromRGB(color)
			setHSVFromRGB(color)
		end

		function picker:SetValueRGB(a, b, c, d)
			local color
			local transparency
			if typeof(a) == "Color3" then
				color = a
				transparency = b
			else
				color = Color3.fromRGB(
					math.clamp(tonumber(a) or 0, 0, 255),
					math.clamp(tonumber(b) or 0, 0, 255),
					math.clamp(tonumber(c) or 0, 0, 255)
				)
				transparency = d
			end

			if color then
				setHSVFromRGB(color)
			end
			if hasTransparency and transparency ~= nil then
				picker.Transparency = math.clamp(tonumber(transparency) or picker.Transparency, 0, 1)
			end
			picker:Update()
		end

		function picker:SetValueHSV(h, s, v, transparency)
			if type(h) == "table" then
				transparency = s
				h, s, v = h[1] or h.H or 0, h[2] or h.S or 0, h[3] or h.V or 0
			end
			if typeof(h) == "Color3" then
				setHSVFromRGB(h)
			else
				picker.Hue = math.clamp(tonumber(h) or 0, 0, 1)
				picker.Sat = math.clamp(tonumber(s) or 0, 0, 1)
				picker.Vib = math.clamp(tonumber(v) or 0, 0, 1)
			end
			if hasTransparency and transparency ~= nil then
				picker.Transparency = math.clamp(tonumber(transparency) or picker.Transparency, 0, 1)
			end
			picker:Update()
		end

		picker._setter = function(value, transparency)
			if type(value) == "table" and typeof(value) ~= "Color3" then
				picker:SetValueHSV(value, transparency)
				return
			end
			if typeof(value) == "Color3" then
				picker:SetValueRGB(value, transparency)
				return
			end
			setHSVFromRGB(defaultColor)
			if hasTransparency and transparency ~= nil then
				picker.Transparency = math.clamp(tonumber(transparency) or defaultTransparency, 0, 1)
			end
			display()
			fireChanged()
		end

		function picker:SetValue(value, transparency)
			if type(value) == "table" and typeof(value) ~= "Color3" then
				picker:SetValueHSV(value, transparency)
				return
			end
			picker:SetValueRGB(value, transparency)
		end

		function picker:SetText(text)
			local newText = tostring(text or "")
			picker.Title = newText
			if label and label:IsA("TextLabel") then
				label.Text = newText
			end
		end

		function picker:OnChanged(fn)
			if type(fn) == "function" then
				table.insert(picker.ChangedCallbacks, fn)
				fn(picker.Value, picker.Transparency)
			end
			return fn
		end

		function picker:Toggle(state)
			if state == nil then
				setMenuOpen(not menu.Visible)
			else
				setMenuOpen(state)
			end
			if menu.Visible then
				task.defer(updateMenuPosition)
			end
		end
		function picker:RunChanged()
			if type(picker.Changed) == "function" then
				Library:SafeCallback(picker.Changed, picker.Value, picker.Transparency)
			end
		end
		function picker:UpdateColors() end

		table.insert(picker.Connections, swatch.MouseButton1Click:Connect(function()
			picker:Toggle()
		end))

		local function beginDrag(target, callback)
			-- InputObject.Position is in the same space the engine used to decide that
			-- the press landed on `target`, so it always lines up with AbsolutePosition.
			local function posOf(inp)
				return Vector2.new(inp.Position.X, inp.Position.Y)
			end
			table.insert(picker.Connections, target.InputBegan:Connect(function(input)
				if not isDragInput(input) then
					return
				end
				local function applyAt(pos)
					if picker.Destroyed or not target.Parent then
						return
					end
					local rel = pos - target.AbsolutePosition
					local size = target.AbsoluteSize
					local x = size.X > 0 and math.clamp(rel.X / size.X, 0, 1) or 0
					local y = size.Y > 0 and math.clamp(rel.Y / size.Y, 0, 1) or 0
					callback(x, y)
				end

				if Library.DebugColorPicker then
					local m = UserInputService:GetMouseLocation()
					local g = selfLib.ScreenGui
					local cam = workspace.CurrentCamera
					local ip = input.Position
					warn(string.format(
						"[PESUI color debug] mouse=(%.1f, %.1f) input.Position=(%.1f, %.1f) used=(%.1f, %.1f) DY=%s\n"
							.. "  target pos=(%.1f, %.1f) size=(%.1f, %.1f)  rel=(%.1f, %.1f)\n"
							.. "  screenGui size=(%.1f, %.1f) viewport=(%.1f, %.1f) guiInset=(%.1f, %.1f) touch=%s",
						m.X, m.Y, ip.X, ip.Y,
						posOf(input).X, posOf(input).Y, tostring(Library._MouseDY),
						target.AbsolutePosition.X, target.AbsolutePosition.Y, target.AbsoluteSize.X, target.AbsoluteSize.Y,
						posOf(input).X - target.AbsolutePosition.X, posOf(input).Y - target.AbsolutePosition.Y,
						g and g.AbsoluteSize.X or 0, g and g.AbsoluteSize.Y or 0,
						cam and cam.ViewportSize.X or 0, cam and cam.ViewportSize.Y or 0,
						GuiService:GetGuiInset().X, GuiService:GetGuiInset().Y,
						tostring(UserInputService.TouchEnabled)
					))
				end
				applyAt(posOf(input))
				if Library.DebugColorPicker then
					task.defer(function()
						for _, child in ipairs(target:GetChildren()) do
							if child:IsA("Frame") and child.AnchorPoint == Vector2.new(0.5, 0.5) then
								local c = child.AbsolutePosition + child.AbsoluteSize / 2
								local m = UserInputService:GetMouseLocation()
								warn(string.format(
									"[PESUI color debug] dot center=(%.1f, %.1f)  mouse now=(%.1f, %.1f)  diff(dot-mouse)=(%.1f, %.1f)",
									c.X, c.Y, m.X, m.Y, c.X - m.X, c.Y - m.Y
								))
							end
						end
					end)
				end

				local moveConn, endConn
				local function stop()
					if moveConn then
						moveConn:Disconnect()
						moveConn = nil
					end
					if endConn then
						endConn:Disconnect()
						endConn = nil
					end
				end
				moveConn = UserInputService.InputChanged:Connect(function(changed)
					if picker.Destroyed or not target.Parent then
						stop()
						return
					end
					if changed.UserInputType == Enum.UserInputType.MouseMovement
						or (changed.UserInputType == Enum.UserInputType.Touch and changed == input) then
						applyAt(posOf(changed))
					end
				end)
				endConn = UserInputService.InputEnded:Connect(function(ended)
					if ended == input
						or (input.UserInputType == Enum.UserInputType.MouseButton1
							and ended.UserInputType == Enum.UserInputType.MouseButton1) then
						stop()
					end
				end)
				table.insert(picker.Connections, moveConn)
				table.insert(picker.Connections, endConn)
			end))
		end

		beginDrag(svMap, function(x, y)
			picker.Sat = x
			picker.Vib = 1 - y
			picker:Update()
		end)
		beginDrag(hueBar, function(_, y)
			picker.Hue = math.clamp(y, 0, 0.9999)
			picker:Update()
		end)
		if transparencyBar then
			beginDrag(transparencyBar, function(_, y)
				picker.Transparency = y
				picker:Update()
			end)
		end

		table.insert(picker.Connections, hexBox.FocusLost:Connect(function(enterPressed)
			if not enterPressed then
				picker:Update(true)
				return
			end
			local text = tostring(hexBox.Text or ""):gsub("#", ""):gsub("%s+", "")
			if #text == 3 then
				text = text:sub(1,1)..text:sub(1,1)..text:sub(2,2)..text:sub(2,2)..text:sub(3,3)..text:sub(3,3)
			end
			if #text == 6 then
				local r = tonumber(text:sub(1, 2), 16)
				local g = tonumber(text:sub(3, 4), 16)
				local b = tonumber(text:sub(5, 6), 16)
				if r and g and b then
					picker:SetValueRGB(Color3.fromRGB(r, g, b))
					return
				end
			end
			picker:Update(true)
		end))

		table.insert(picker.Connections, rgbBox.FocusLost:Connect(function(enterPressed)
			if not enterPressed then
				picker:Update(true)
				return
			end
			local nums = {}
			for n in tostring(rgbBox.Text or ""):gmatch("%-?%d+%.?%d*") do
				table.insert(nums, tonumber(n))
				if #nums >= 3 then
					break
				end
			end
			if #nums == 3 then
				local r = math.clamp(math.floor(nums[1] or 0), 0, 255)
				local g = math.clamp(math.floor(nums[2] or 0), 0, 255)
				local b = math.clamp(math.floor(nums[3] or 0), 0, 255)
				picker:SetValueRGB(Color3.fromRGB(r, g, b))
				return
			end
			picker:Update(true)
		end))

		-- (clicking outside the menu is handled by the backdrop in setMenuOpen)

		table.insert(picker.Connections, menu:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if menu.Visible then
				updateMenuPosition()
			end
		end))
		if swatch and swatch:IsA("GuiObject") then
			table.insert(picker.Connections, swatch:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
				if menu.Visible then
					updateMenuPosition()
				end
			end))
		end

		function picker:Destroy()
			picker.Destroyed = true
			setMenuOpen(false)
			stopMenuTracking()
			for _, conn in ipairs(picker.Connections or {}) do
				pcall(function()
					conn:Disconnect()
				end)
			end
			safeDestroy(menu)
			if instance and instance.Parent then
				safeDestroy(instance)
			elseif swatch and swatch.Parent then
				safeDestroy(swatch)
			end
			picker.Instance = nil
		end

		display()
		registerPicker(picker.Value)
		picker.Instance = instance
		picker.Swatch = swatch
		picker.Menu = menu
		attachInfoTooltip(picker, info, swatch)

		return picker
	end


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
	local mainScale = create("UIScale", { Scale = 1, Parent = main })

	local bgAsset = resolveIcon(config.BackgroundImage)
	if bgAsset then
		local bg = create("ImageLabel", {
			Name = "BackgroundImage",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = bgAsset,
			ImageTransparency = 0.5,
			ScaleType = Enum.ScaleType.Crop,
			ZIndex = 0,
			Parent = main,
		})
		applyIconData(bg, config.BackgroundImage)
		addCorner(bg, self.Theme.CornerRadius)
	end

	-- unlock the mouse (first-person / shift-lock) while the window is visible
	if config.UnlockMouseWhileOpen then
		create("TextButton", {
			Name = "ModalUnlock",
			Modal = true,
			Size = UDim2.fromOffset(0, 0),
			BackgroundTransparency = 1,
			Text = "",
			Parent = main,
		})
	end

	-- software cursor drawn on top of everything while the window is visible
	if config.ShowCustomCursor then
		local cursor = create("Frame", {
			Name = "CustomCursor",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(8, 8),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 10000,
			Parent = screenGui,
		})
		addCorner(cursor, 4)
		addStroke(cursor, Color3.new(0, 0, 0))

		local hidSystemCursor, prevIconEnabled = false, true
		local function restoreCursor()
			cursor.Visible = false
			if hidSystemCursor then
				hidSystemCursor = false
				UserInputService.MouseIconEnabled = prevIconEnabled
			end
		end
		selfLib:Connect(RunService.RenderStepped, function()
			if main.Visible and not selfLib.Unloaded then
				if not hidSystemCursor then
					hidSystemCursor = true
					prevIconEnabled = UserInputService.MouseIconEnabled
				end
				UserInputService.MouseIconEnabled = false
				local pos = getMouseLocation()
				cursor.Position = UDim2.fromOffset(pos.X, pos.Y)
				cursor.Visible = true
			else
				restoreCursor()
			end
		end)
		table.insert(selfLib.UnloadCallbacks, restoreCursor)
	end

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

	-- global search bar + tab info (Obsidian window props)
	local disableSearch = config.DisableSearch == true
	local searchbarSize = typeof(config.SearchbarSize) == "UDim2" and config.SearchbarSize or UDim2.fromScale(1, 1)
	local isDefaultSearchbarSize = searchbarSize == UDim2.fromScale(1, 1)
	local searchReserve = disableSearch and 0 or math.max(190, searchbarSize.X.Offset + 8)
	selfLib.GlobalSearch = config.GlobalSearch == true

	local titleLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -(120 + searchReserve), 1, 0),
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

	-- window icon (left of the title)
	local iconSize = typeof(config.IconSize) == "UDim2" and config.IconSize or UDim2.fromOffset(20, 20)
	if createIconInstance(config.Icon, {
		Name = "WindowIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = iconSize,
		BackgroundTransparency = 1,
		Parent = topbar,
	}) then
		local shift = 12 + iconSize.X.Offset + 8
		titleLabel.Position = UDim2.fromOffset(shift, 0)
		titleLabel.Size = UDim2.new(1, -(shift + 106 + searchReserve), 1, 0)
	end

	-- right side of the topbar: tab info + global search (Obsidian-style)
	local rightWrapper = create("Frame", {
		Name = "RightWrapper",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -46, 0.5, 0),
		Size = UDim2.new(0, searchReserve, 1, -6),
		BackgroundTransparency = 1,
		Parent = topbar,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = rightWrapper,
	})

	local tabInfoFrame = create("Frame", {
		Name = "TabInfo",
		Size = UDim2.fromScale(disableSearch and 1 or 0.5, 1),
		Visible = false,
		BackgroundTransparency = 1,
		Parent = rightWrapper,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 1),
		Parent = tabInfoFrame,
	})
	local tabInfoName = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = self.Theme.Font,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = self.Theme.Text,
		Text = "",
		Parent = tabInfoFrame,
	})
	local tabInfoDesc = create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 13),
		Font = self.Theme.Font,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = self.Theme.SubText,
		TextWrapped = true,
		Text = "",
		Visible = false,
		Parent = tabInfoFrame,
	})

	local searchBox
	if not disableSearch then
		searchBox = create("TextBox", {
			Name = "SearchBox",
			BackgroundColor3 = self.Theme.SurfaceAlt,
			Font = self.Theme.Font,
			PlaceholderColor3 = self.Theme.SubText,
			PlaceholderText = "Search",
			Size = searchbarSize,
			Text = "",
			TextColor3 = self.Theme.Text,
			TextSize = 13,
			Parent = rightWrapper,
		})
		addCorner(searchBox, self.Theme.CornerRadius)
		addStroke(searchBox, self.Theme.Outline)
		addPadding(searchBox, 6)
		searchBox:GetPropertyChangedSignal("Text"):Connect(function()
			selfLib:UpdateSearch(searchBox.Text)
		end)
	end

	-- edge / center snapping while dragging
	local snapState = {
		Enabled = config.Snapping == true,
		Distance = tonumber(config.SnapDistance) or 12,
		Margin = tonumber(config.SnapMargin) or 8,
		AvoidCoreGui = config.SnapAvoidCoreGui == true,
	}
	local function snapAxis(c, h, total, loMargin, hiMargin)
		local dist = snapState.Distance
		if math.abs((c - h) - loMargin) <= dist then
			return loMargin + h
		elseif math.abs((c + h) - (total - hiMargin)) <= dist then
			return total - hiMargin - h
		elseif math.abs(c - total / 2) <= dist then
			return total / 2
		end
		return c
	end
	local function snapAdjust(pos)
		if not snapState.Enabled then
			return pos
		end
		local gui = screenGui.AbsoluteSize
		if gui.X <= 0 or gui.Y <= 0 then
			return pos
		end
		local half = main.AbsoluteSize / 2
		local margin = snapState.Margin
		local topMargin = margin
		if snapState.AvoidCoreGui then
			topMargin += GuiService:GetGuiInset().Y
		end
		local cx = pos.X.Scale * gui.X + pos.X.Offset
		local cy = pos.Y.Scale * gui.Y + pos.Y.Offset
		cx = snapAxis(cx, half.X, gui.X, margin, margin)
		cy = snapAxis(cy, half.Y, gui.Y, topMargin, margin)
		return UDim2.new(pos.X.Scale, cx - pos.X.Scale * gui.X, pos.Y.Scale, cy - pos.Y.Scale * gui.Y)
	end

	makeDraggable(topbar, main, snapAdjust)

	-- ---------- resize grip (bottom-right corner) ----------
	if config.Resizable ~= false then
		local minSize = Vector2.new(480, 320)
		if typeof(config.MinSize) == "Vector2" then
			minSize = config.MinSize
		elseif typeof(config.MinSize) == "UDim2" then
			minSize = Vector2.new(config.MinSize.X.Offset, config.MinSize.Y.Offset)
		end

		local grip = create("TextButton", {
			Name = "ResizeGrip",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -4, 1, -4),
			Size = UDim2.fromOffset(14, 14),
			BackgroundColor3 = self.Theme.SurfaceAlt,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 100,
			Parent = main,
		})
		addCorner(grip, 3)
		addStroke(grip, self.Theme.Outline)
		bindHover(grip, self.Theme.SurfaceAlt, self.Theme.Outline)

		local resizing = false
		local dragStart, startSize, startPos

		grip.InputBegan:Connect(function(input)
			if Library.DragLocked then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing = true
				dragStart = input.Position
				startSize = main.AbsoluteSize
				startPos = main.Position
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						resizing = false
					end
				end)
			end
		end)

		selfLib:Connect(UserInputService.InputChanged, function(input)
			if not resizing then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local delta = input.Position - dragStart
			local maxW, maxH = math.huge, math.huge
			local gui = selfLib.ScreenGui
			if gui and gui.AbsoluteSize.X > 0 then
				maxW, maxH = gui.AbsoluteSize.X - 20, gui.AbsoluteSize.Y - 20
			end
			local w = math.clamp(startSize.X + delta.X, minSize.X, math.max(minSize.X, maxW))
			local h = math.clamp(startSize.Y + delta.Y, minSize.Y, math.max(minSize.Y, maxH))
			-- the window is center-anchored: shift by half the change so the
			-- top-left corner stays put while the bottom-right follows the cursor
			local dx, dy = w - startSize.X, h - startSize.Y
			main.Size = UDim2.fromOffset(w, h)
			main.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + dx / 2,
				startPos.Y.Scale,
				startPos.Y.Offset + dy / 2
			)
		end)
		selfLib:Connect(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing = false
			end
		end)
	end

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
	addPadding(tabButtons, selfLib.TabButtonsStyle.Padding)
	do
		local tbLayout = tabButtons:FindFirstChildOfClass("UIListLayout")
		if tbLayout then
			tbLayout.Padding = UDim.new(0, tonumber(selfLib.TabButtonsStyle.Gap) or 6)
		end
	end

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

	local tabButtonInfos = {}
	local applyButtonCompact

	-- ====================================================================
	-- Sidebar: resize handle, compact (icon-only) mode
	-- ====================================================================
	local sb = {
		Min = tonumber(config.MinSidebarWidth) or 140,
		CompactWidth = tonumber(config.SidebarCompactWidth) or 56,
		MinContainer = tonumber(config.MinContainerWidth) or 300,
		EnableResize = config.EnableSidebarResize == true,
		EnableCompacting = config.EnableCompacting == true,
		NoSnap = config.DisableCompactingSnap == true,
		Activation = tonumber(config.CompactWidthActivation) or 0,
		Compacted = config.SidebarCompacted == true,
		Auto = false,
	}
	sb.CollapseThreshold = tonumber(config.SidebarCollapseThreshold) or (sb.Min - 20)
	sb.Width = math.max(170, sb.Min)

	local function isSidebarCompact()
		return sb.Compacted or sb.Auto
	end

	local function firstChar(str)
		local ok, c = pcall(function()
			return utf8.char(utf8.codepoint(str, 1))
		end)
		if ok and c then
			return c
		end
		return str:sub(1, 1)
	end

	function applyButtonCompact(info, compact)
		local label, icon = info.label, info.icon
		if compact then
			if not info.compact then
				info.fullText = label.Text
			end
			if icon then
				label.Visible = false
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Position = UDim2.fromScale(0.5, 0.5)
			else
				label.Position = UDim2.fromOffset(0, 0)
				label.Size = UDim2.fromScale(1, 1)
				label.TextXAlignment = Enum.TextXAlignment.Center
				label.Text = firstChar(info.fullText or info.name)
			end
		elseif info.compact then
			label.Visible = true
			label.TextXAlignment = Enum.TextXAlignment.Left
			label.Position = UDim2.fromOffset(icon and 30 or 10, 0)
			label.Size = UDim2.new(1, icon and -36 or -16, 1, 0)
			label.Text = info.fullText or info.name
			if icon then
				icon.AnchorPoint = Vector2.new(0, 0.5)
				icon.Position = UDim2.new(0, 8, 0.5, 0)
			end
		end
		info.compact = compact
	end

	local function maxSidebarWidth()
		local mw = main.AbsoluteSize.X
		if mw <= 0 then
			-- layout not computed yet: fall back to the requested window width
			mw = size.X.Offset > 0 and size.X.Offset or 680
		end
		return math.max(sb.Min, mw - sb.MinContainer)
	end

	local function applySidebar()
		local compact = isSidebarCompact()
		local w
		if compact then
			w = sb.CompactWidth
		else
			sb.Width = math.clamp(sb.Width, sb.Min, maxSidebarWidth())
			w = sb.Width
		end
		sidebar.Size = UDim2.new(0, w, 1, 0)
		pages.Position = UDim2.fromOffset(w, 0)
		pages.Size = UDim2.new(1, -w, 1, 0)
		footer.Visible = not compact
		for _, info in ipairs(tabButtonInfos) do
			applyButtonCompact(info, compact)
		end
	end

	local function updateAutoCompact()
		local auto = sb.Activation > 0 and main.AbsoluteSize.X < sb.Activation
		if auto ~= sb.Auto then
			sb.Auto = auto
		end
		applySidebar()
	end
	main:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateAutoCompact)

	if sb.EnableResize then
		local handle = create("TextButton", {
			Name = "SidebarResizeHandle",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 6, 1, 0),
			BackgroundColor3 = selfLib.Theme.Accent,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			ZIndex = 20,
			Parent = sidebar,
		})
		local dragging = false
		local dragStart, startWidth
		handle.MouseEnter:Connect(function()
			handle.BackgroundTransparency = 0.6
		end)
		handle.MouseLeave:Connect(function()
			if not dragging then
				handle.BackgroundTransparency = 1
			end
		end)
		handle.InputBegan:Connect(function(input)
			if Library.DragLocked then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startWidth = sidebar.AbsoluteSize.X
				handle.BackgroundTransparency = 0.4
				input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						handle.BackgroundTransparency = 1
					end
				end)
			end
		end)
		selfLib:Connect(UserInputService.InputChanged, function(input)
			if not dragging then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local raw = startWidth + (input.Position.X - dragStart.X)
			if sb.EnableCompacting and not sb.NoSnap and raw < sb.CollapseThreshold then
				sb.Compacted = true
			else
				sb.Compacted = false
				sb.Width = math.clamp(raw, sb.Min, maxSidebarWidth())
			end
			applySidebar()
		end)
		selfLib:Connect(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
				handle.BackgroundTransparency = 1
			end
		end)
	end

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

	function Window:RefreshTitleSize()
		if self.TitleLabel then
			local size = getTextSize(self.TitleLabel.Text, self.TitleLabel.TextSize, self.TitleLabel.Font, 1000)
			self.TitleLabel.Size = UDim2.new(0, size.X + 4, 1, 0)
		end
	end

	function Window:SetBackgroundImage(image)
		local asset = resolveIcon(image)
		local existing = self.Main:FindFirstChild("BackgroundImage")
		if existing then
			safeDestroy(existing)
		end
		if asset then
			local bg = create("ImageLabel", {
				Name = "BackgroundImage",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ImageTransparency = 0.5,
				ScaleType = Enum.ScaleType.Crop,
				ZIndex = 0,
				Parent = self.Main,
			})
			applyIconData(bg, image)
			addCorner(bg, Library.Theme.CornerRadius)
		end
	end

	function Window:SetSnapping(enabled, distance, margin, avoidCoreGui)
		snapState.Enabled = enabled and true or false
		if tonumber(distance) then
			snapState.Distance = tonumber(distance)
		end
		if tonumber(margin) then
			snapState.Margin = tonumber(margin)
		end
		if avoidCoreGui ~= nil then
			snapState.AvoidCoreGui = avoidCoreGui and true or false
		end
		self.Snapping = snapState.Enabled
	end

	function Window:SetCornerRadius(radius)
		radius = tonumber(radius)
		if not radius then
			return
		end
		local old = Library.Theme.CornerRadius
		Library.Theme.CornerRadius = radius
		if Library.ScreenGui then
			for _, d in ipairs(Library.ScreenGui:GetDescendants()) do
				if d:IsA("UICorner") and d.CornerRadius.Scale == 0 and d.CornerRadius.Offset == old then
					d.CornerRadius = UDim.new(0, radius)
				end
			end
		end
	end

	function Window:ShowTabInfo(name, description)
		tabInfoName.Text = tostring(name or "")
		tabInfoDesc.Text = tostring(description or "")
		tabInfoDesc.Visible = type(description) == "string" and description ~= ""
		if isDefaultSearchbarSize and searchBox then
			searchBox.Size = UDim2.fromScale(0.5, 1)
		end
		tabInfoFrame.Visible = true
	end

	function Window:HideTabInfo()
		tabInfoFrame.Visible = false
		if isDefaultSearchbarSize and searchBox then
			searchBox.Size = UDim2.fromScale(1, 1)
		end
	end

	function Window:AddDialog(idx, info)
		info = info or {}
		local windowRef = self
		local screenGui = Library.ScreenGui
		local overlay = create("Frame", {
			Name = "Dialog_" .. tostring(idx or ""),
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Active = true, -- swallow clicks so the window underneath is not usable
			ZIndex = 4000, -- below the popup overlay (5000) so dropdowns inside dialogs work
			Parent = screenGui,
		})
		local dlg = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(tonumber(info.Width) or 360, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Library.Theme.Surface,
			BorderSizePixel = 0,
			Active = true,
			ZIndex = 4001,
			Parent = screenGui,
		})
		addCorner(dlg, Library.Theme.CornerRadius)
		addStroke(dlg, Library.Theme.Outline)
		addPadding(dlg, 14)
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = dlg,
		})
		local titleLbl = create("TextLabel", {
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 22),
			Font = Library.Theme.Font,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Library.Theme.Text,
			Text = tostring(info.Title or "Dialog"),
			Parent = dlg,
		})
		local descLbl = create("TextLabel", {
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Font = Library.Theme.Font,
			TextSize = 13,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = Library.Theme.SubText,
			Text = tostring(info.Description or ""),
			Visible = info.Description ~= nil and info.Description ~= "",
			Parent = dlg,
		})
		local holder = create("Frame", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = dlg,
		})
		local footer = create("Frame", {
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			Parent = dlg,
		})
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = footer,
		})

		-- a Dialog inherits every Groupbox method: build a real groupbox and
		-- move its element holder into the dialog body
		local dialog
		if self._CreateGroupbox then
			dialog = self._CreateGroupbox(overlay, { Name = "" })
			create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
			dialog.Holder.Parent = holder
			if dialog.Container then
				safeDestroy(dialog.Container)
			end
			dialog.Container = nil
		else
			dialog = {}
			dialog.Holder = holder
		end
		dialog.Instance = dlg
		dialog.Overlay = overlay
		dialog.TitleLabel = titleLbl
		dialog.DescriptionLabel = descLbl
		dialog.Footer = footer
		dialog.Buttons = {}
		dialog.Destroyed = false

		local nextOrder = 0
		local waiting, disabled = {}, {}

		function dialog:SetTitle(t)
			titleLbl.Text = tostring(t or "")
		end
		function dialog:SetDescription(t)
			descLbl.Text = tostring(t or "")
			descLbl.Visible = t ~= nil and t ~= ""
		end
		function dialog:Dismiss()
			if dialog.Destroyed then
				return
			end
			dialog.Destroyed = true
			if windowRef.Dialogs then
				windowRef.Dialogs[idx] = nil
			end
			safeDestroy(overlay)
			safeDestroy(dlg)
		end
		function dialog:RemoveFooterButton(key)
			local b = dialog.Buttons[key]
			if b then
				safeDestroy(b)
				dialog.Buttons[key] = nil
			end
		end
		function dialog:SetButtonDisabled(key, state)
			local b = dialog.Buttons[key]
			if b then
				disabled[key] = state and true or false
				b.TextTransparency = state and 0.5 or 0
			end
		end
		function dialog:SetButtonOrder(key, order)
			local b = dialog.Buttons[key]
			if b then
				b.LayoutOrder = tonumber(order) or 0
			end
		end
		function dialog:AddFooterButton(key, btnInfo)
			btnInfo = btnInfo or {}
			nextOrder += 1
			local variant = string.lower(tostring(btnInfo.Variant or "Secondary"))
			local bg, fg, transparent = Library.Theme.SurfaceAlt, Library.Theme.Text, false
			if variant == "primary" then
				bg, fg = Library.Theme.Accent, Color3.fromRGB(20, 20, 24)
			elseif variant == "destructive" then
				bg, fg = Library.Theme.Danger, Color3.new(1, 1, 1)
			elseif variant == "ghost" then
				transparent = true
			end
			local b = create("TextButton", {
				LayoutOrder = tonumber(btnInfo.Order) or nextOrder,
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = bg,
				BackgroundTransparency = transparent and 1 or 0,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = Library.Theme.Font,
				TextSize = 13,
				TextColor3 = fg,
				Text = tostring(btnInfo.Title or btnInfo.Text or key or "Button"),
				ClipsDescendants = true,
				Parent = footer,
			})
			create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = b })
			addCorner(b, Library.Theme.CornerRadius)
			addStroke(b, Library.Theme.Outline)

			-- WaitTime: locked until an animated progress bar fills up
			local waitTime = tonumber(btnInfo.WaitTime)
			if waitTime and waitTime > 0 then
				waiting[key] = true
				b.TextTransparency = 0.5
				local bar = create("Frame", {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(0, 0, 0, 3),
					BackgroundColor3 = Library.Theme.Accent,
					BorderSizePixel = 0,
					ZIndex = 2,
					Parent = b,
				})
				local tw = TweenService:Create(bar, TweenInfo.new(waitTime, Enum.EasingStyle.Linear), { Size = UDim2.new(1, 0, 0, 3) })
				tw.Completed:Connect(function()
					waiting[key] = nil
					if not disabled[key] then
						b.TextTransparency = 0
					end
					safeDestroy(bar)
				end)
				tw:Play()
			end

			b.MouseButton1Click:Connect(function()
				if waiting[key] or disabled[key] then
					return
				end
				if type(btnInfo.Callback) == "function" then
					Library:SafeCallback(btnInfo.Callback)
				end
				local auto = info.AutoDismiss ~= false
				if btnInfo.AutoDismiss ~= nil then
					auto = btnInfo.AutoDismiss and true or false
				end
				if btnInfo.CloseOnClick == false then
					auto = false
				end
				if auto then
					dialog:Dismiss()
				end
			end)
			dialog.Buttons[key or nextOrder] = b
			return b
		end

		-- click on the dim area (not on the dialog) dismisses it
		if info.OutsideClickDismiss ~= false then
			-- the dialog is a sibling of the dim layer, so a click that reaches the dim layer is outside
			overlay.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					dialog:Dismiss()
				end
			end)
		end

		-- FooterButtons is a dictionary { Name = { Title, Variant, Order, Callback, WaitTime } };
		-- a plain array of such tables is accepted too
		if type(info.FooterButtons) == "table" then
			local entries = {}
			for key, fb in pairs(info.FooterButtons) do
				if type(fb) == "table" then
					table.insert(entries, { key = key, info = fb })
				end
			end
			table.sort(entries, function(a, b)
				local oa = tonumber(a.info.Order) or math.huge
				local ob = tonumber(b.info.Order) or math.huge
				if oa ~= ob then
					return oa < ob
				end
				return tostring(a.key) < tostring(b.key)
			end)
			for _, e in ipairs(entries) do
				dialog:AddFooterButton(e.key, e.info)
			end
		end

		self.Dialogs = self.Dialogs or {}
		self.Dialogs[idx] = dialog
		return dialog
	end

	function Window:AddCustomTab(...)
		local tab = self:AddTab(...)
		if not tab then
			return nil, nil
		end
		if tab.Scroll then tab.Scroll.Visible = false end
		if tab.LeftColumn then tab.LeftColumn.Visible = false end
		if tab.RightColumn then tab.RightColumn.Visible = false end

		local container = create("Frame", {
			Name = "CustomTabContainer",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = tab.Page,
		})
		addPadding(container, 10)

		-- Custom tabs deliberately expose no groupbox/tabbox helpers.
		for _, method in ipairs({
			"AddGroupbox", "AddLeftGroupbox", "AddRightGroupbox",
			"AddTabbox", "AddLeftTabbox", "AddRightTabbox",
			"UpdateWarningBox", "AddSubTab",
		}) do
			tab[method] = nil
		end
		function tab:Hide()
			if self.Page then
				self.Page.Visible = false
			end
			if Window.ActiveTab == self then
				Window.ActiveTab = nil
			end
		end
		tab.Container = container
		return container, tab
	end

	function Window:ChangeTitle(text)
		self.TitleLabel.Text = tostring(text or "")
	end

	function Window:SetFooter(text)
		self.FooterLabel.Text = tostring(text or "")
	end

	function Window:SetAlwaysOnTop(state)
		screenGui.DisplayOrder = state and 999999 or 0
	end

	function Window:GetSidebarWidth()
		return self.Sidebar.AbsoluteSize.X
	end
	function Window:IsSidebarCompacted()
		return isSidebarCompact()
	end
	function Window:SetSidebarWidth(width)
		sb.Width = math.clamp(tonumber(width) or sb.Width, sb.Min, maxSidebarWidth())
		applySidebar()
	end
	function Window:SetCompact(state)
		sb.Compacted = state == true
		applySidebar()
	end
	function Window:SetAnimations(animations, transitionTime, swipeOffset, swipeFrom)
		if type(animations) == "table" then
			for k, v in pairs(animations) do
				selfLib.Animations[k] = v == true
			end
		end
		if tonumber(transitionTime) then
			selfLib.TabTransitionTime = tonumber(transitionTime)
		end
		if tonumber(swipeOffset) then
			selfLib.TabSwipeOffset = tonumber(swipeOffset)
		end
		if type(swipeFrom) == "string" then
			selfLib.TabSwipeFrom = string.lower(swipeFrom)
		end
	end

	function Window:Toggle(force)
		local state = force
		if state == nil then
			state = not self.Visible
		end
		self.Visible = state
		if not state then
			-- popups live in the overlay: close them so they don't float over the game
			if selfLib._OpenDropdownCloser then
				pcall(selfLib._OpenDropdownCloser)
			end
			if selfLib._OpenColorPickerCloser then
				pcall(selfLib._OpenColorPickerCloser)
			end
			if selfLib._CloseKeyModeMenu then
				pcall(selfLib._CloseKeyModeMenu)
			end
		end
		if selfLib.Animations.ToggleWindow then
			self._toggleToken = (self._toggleToken or 0) + 1
			local token = self._toggleToken
			if state then
				self.Main.Visible = true
				mainScale.Scale = 0.92
				TweenService:Create(mainScale, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			else
				local tw = TweenService:Create(mainScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.92 })
				tw.Completed:Connect(function()
					if self._toggleToken == token then
						self.Main.Visible = false
						mainScale.Scale = 1
					end
				end)
				tw:Play()
			end
		else
			mainScale.Scale = 1
			self.Main.Visible = state
		end
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
		addCorner(button, tonumber(selfLib.TabButtonsStyle.CornerRadius) or selfLib.Theme.CornerRadius)
		addStroke(button, selfLib.Theme.Outline)

		if selfLib.TabButtonsStyle.Indicator then
			local ind = create("Frame", {
				Name = "Indicator",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 2, 0.5, 0),
				Size = UDim2.fromOffset(tonumber(selfLib.TabButtonsStyle.IndicatorWidth) or 2, tonumber(selfLib.TabButtonsStyle.IndicatorHeight) or 20),
				BackgroundColor3 = selfLib.Theme.Accent,
				BorderSizePixel = 0,
				Visible = false,
				ZIndex = 3,
				Parent = button,
			})
			addCorner(ind, 2)
		end

		local iconImage = createIconInstance(icon, {
			Name = "IconImage",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Parent = button,
		})

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

		local info = { button = button, label = label, icon = iconImage, name = tostring(name) }
		table.insert(tabButtonInfos, info)
		applyButtonCompact(info, isSidebarCompact())

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

	-- Set by attachTabMethods so groupboxes can create nested tabboxes with
	-- the same implementation (Obsidian: Groupbox:AddTabbox()).
	local addTabboxImpl

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
		function groupbox:SetMaxHeight(h)
			self.MaxHeight = tonumber(h) or nil
			self:_ApplyMaxHeight()
		end
		function groupbox:_ApplyMaxHeight()
			local holder = self.Holder
			if not holder then return end
			if not self.MaxHeight then
				if self._HolderScroll then
					holder.Parent = self._HolderScrollParent
					holder.Size = UDim2.new(1, 0, 0, 0)
					holder.AutomaticSize = Enum.AutomaticSize.Y
					safeDestroy(self._HolderScroll)
					self._HolderScroll = nil
					self._HolderScrollParent = nil
				end
				return
			end
			if not self._HolderScroll then
				local parent = holder.Parent
				local scroll = create("ScrollingFrame", {
					Size = UDim2.new(1, 0, 0, self.MaxHeight),
					CanvasSize = UDim2.new(),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollBarThickness = 3,
					ScrollBarImageColor3 = selfLib.Theme.Outline,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = holder.LayoutOrder,
					Parent = parent,
				})
				holder.Parent = scroll
				self._HolderScroll = scroll
				self._HolderScrollParent = parent
			else
				self._HolderScroll.Size = UDim2.new(1, 0, 0, self.MaxHeight)
			end
		end
		function groupbox:SetPoppedOut(v, position)
			if not self.PopOutEnabled or self.Destroyed then return end
			local value = v == true
			if self.PoppedOut == value then
				if value and position and self.PopOutFloat then
					self.PopOutFloat.Position = position
				end
				return
			end
			self.PoppedOut = value
			if self.PoppedOut then
				if not self.PopOutFloat or not self.PopOutFloat.Parent then
					local float = create("Frame", {
						Name = "PopOutFloat",
						Size = UDim2.fromOffset(self.PopOutWidth or 300, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = selfLib.Theme.Surface,
						BorderSizePixel = 0,
						ZIndex = 6000,
						Parent = selfLib.OverlayFrame or selfLib.ScreenGui,
					})
					addCorner(float, selfLib.Theme.CornerRadius)
					addStroke(float, selfLib.Theme.Outline)
					local header = create("TextLabel", {
						Name = "PopOutTitle",
						LayoutOrder = 1,
						BackgroundTransparency = 1,
						Size = UDim2.new(1, -24, 0, 24),
						Font = selfLib.Theme.Font,
						TextSize = 14,
						TextColor3 = selfLib.Theme.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
						Text = tostring(self.Name or "Groupbox"),
						Parent = float,
					})
					create("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = header })
					local close = create("TextButton", {
						Name = "PopOutClose",
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(24, 24),
						BackgroundTransparency = 1,
						Font = selfLib.Theme.Font,
						TextSize = 16,
						TextColor3 = selfLib.Theme.SubText,
						Text = "×",
						ZIndex = 6001,
						Parent = float,
					})
					close.MouseButton1Click:Connect(function()
						self:SetPoppedOut(false)
					end)
					self.PopOutFloat = float
				end
				if typeof(position) == "UDim2" then
					self.PopOutFloat.Position = position
				elseif self.PopOutFloat.Position == UDim2.new() then
					self.PopOutFloat.Position = UDim2.fromOffset(80, 80)
				end
				if self.Container then
					self._PopOutOriginalParent = self._PopOutOriginalParent or self.Container.Parent
					self.Container.Parent = self.PopOutFloat
					self.Container.Position = UDim2.fromOffset(0, 24)
				end
			else
				if self.Container and self._PopOutOriginalParent then
					self.Container.Parent = self._PopOutOriginalParent
					self.Container.Position = UDim2.new()
					self._PopOutOriginalParent = nil
				end
				if self.PopOutFloat then
					safeDestroy(self.PopOutFloat)
					self.PopOutFloat = nil
				end
			end
		end
		function groupbox:TogglePoppedOut()
			self:SetPoppedOut(not self.PoppedOut)
		end
		function groupbox:SetMaxPopOutHeight(h)
			self.MaxPopOutHeight = tonumber(h) or nil
			if self.PoppedOut and self.PopOutFloat then
				self.PopOutFloat.AutomaticSize = self.MaxPopOutHeight and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
				if self.MaxPopOutHeight then
					self.PopOutFloat.Size = UDim2.fromOffset(self.PopOutWidth or 300, self.MaxPopOutHeight)
				end
			end
		end
		function groupbox:SetPopOutWidth(w)
			self.PopOutWidth = tonumber(w) or nil
			if self.PopOutFloat then
				self.PopOutFloat.Size = UDim2.fromOffset(
					self.PopOutWidth or 300,
					self.MaxPopOutHeight or self.PopOutFloat.Size.Y.Offset
				)
			end
		end
		function groupbox:RefreshPopOutPlaceholder() end
		function groupbox:SetCollapsed(state)
			state = state == true
			self._collapsed = state
			self.Collapsed = state
			-- keep the title row, hide only the contents
			if self.Holder then
				self.Holder.Visible = not state
			end
			if self.DescriptionLabel then
				self.DescriptionLabel.Visible = not state and (self.DescriptionLabel.Text or "") ~= ""
			end
		end
		function groupbox:ToggleCollapsed()
			if self.DisableCollapsing then return end
			self:SetCollapsed(not (self._collapsed == true))
		end
		function groupbox:IsCollapsed()
			return self._collapsed == true
		end
		function groupbox:Resize() end
		function groupbox:AddTabbox(info)
			info = info or {}
			self.Tabboxes = self.Tabboxes or {}
			local proxy = {
				AddGroupbox = function(_, gbInfo)
					if Window._CreateGroupbox then
						return Window._CreateGroupbox(self.Holder, gbInfo or {})
					end
					return self
				end,
				Tabboxes = self.Tabboxes,
			}
			if addTabboxImpl then
				return addTabboxImpl(proxy, info)
			end
			return nil
		end
		function groupbox:Destroy()
			if self.Destroyed then return end
			self.Destroyed = true
			if self._Tooltip then
				pcall(function() self._Tooltip:Destroy() end)
				self._Tooltip = nil
			end
			if self.PopOutFloat then safeDestroy(self.PopOutFloat) end
			if self._HolderScroll then safeDestroy(self._HolderScroll) end
			if self.Container then safeDestroy(self.Container) end
		end
	end

	local function createGroupbox(parent, info)
		info = info or {}
		local container = create("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = selfLib.Theme.Surface,
			BorderSizePixel = 0,
			Visible = info.Visible ~= false,
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

		-- Keep the icon and the title as siblings inside a header. Parenting the
		-- icon to the title (then moving the title) also moved the icon into the
		-- text, which is what Obsidian avoids with its GroupboxTop/TextsFrame.
		local iconData = getIconData(info.IconName or info.Icon)
		local header = create("Frame", {
			Name = "GroupboxHeader",
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Parent = bodyFrame,
		})
		local textsFrame = create("Frame", {
			Name = "GroupboxTexts",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(iconData and 20 or 0, 0),
			Size = UDim2.new(1, -(iconData and 20 or 0), 0, 18),
			Parent = header,
		})
		local title = create("TextLabel", {
			Name = "GroupboxTitle",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Font = selfLib.Theme.Font,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = selfLib.Theme.Text,
			Text = tostring(info.Name or "Groupbox"),
			Parent = textsFrame,
		})

		if iconData then
			createIconInstance(iconData, {
				Name = "GroupboxIcon",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Parent = header,
			})
		end

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
			Name = info.Name,
			Container = container,
			Holder = elementsHolder,
			DescriptionLabel = desc,
			Elements = {},
			Collapsed = info.Collapsed == true,
			DisableCollapsing = info.DisableCollapsing == true,
			PoppedOut = false,
			PopOutEnabled = info.PopOut ~= false,
			MaxHeight = tonumber(info.MaxHeight),
			MaxPopOutHeight = tonumber(info.MaxPopOutHeight),
			PopOutWidth = tonumber(info.PopOutWidth),
		}
		attachGroupboxMethods(groupbox)
		if groupbox.Collapsed then
			groupbox:SetCollapsed(true)
		end
		if groupbox.MaxHeight then
			groupbox:SetMaxHeight(groupbox.MaxHeight)
		end
		if info.PopOut then
			groupbox:SetPoppedOut(true)
		end

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
				TextSize = tonumber(info and info.Size) or 14,
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
			function obj:Display() end
			function obj:UpdateColors() end
			function obj:Destroy()
				safeDestroy(wrapper)
			end

			function obj:AddColorPicker(cid, cinfo)
				local idArg, infoArg = cid, cinfo
				if type(cid) == "table" then
					infoArg = cid
					idArg = infoArg.Flag or infoArg.Idx or infoArg.Index or ("LabelColor_" .. HttpService:GenerateGUID(false))
				end
				infoArg = infoArg or {}
				idArg = idArg or infoArg.Flag or infoArg.Idx or infoArg.Index or ("LabelColor_" .. HttpService:GenerateGUID(false))

				local picker = createColorPickerControl(idArg, infoArg, {
					Variant = "Addon",
					AddonsParent = addons,
					LabelRef = label,
					SwatchSize = UDim2.fromOffset(28, 18),
				})

				function picker:AddColorPicker(cid2, cinfo2)
					return obj:AddColorPicker(cid2, cinfo2)
				end
				function picker:AddKeyPicker(kid2, kinfo2)
					return obj:AddKeyPicker(kid2, kinfo2)
				end

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
				idArg = idArg or ("LabelKey_" .. HttpService:GenerateGUID(false))
				local picker = createKeyPicker(idArg, infoArg, {
					Parent = addons,
					ButtonProps = { Size = UDim2.fromOffset(64, 18) },
				})
				function picker:AddColorPicker(cid2, cinfo2)
					return obj:AddColorPicker(cid2, cinfo2)
				end
				function picker:AddKeyPicker(kid2, kinfo2)
					return obj:AddKeyPicker(kid2, kinfo2)
				end
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

			local obj = { Instance = wrapper, Button = button, Text = text, Disabled = info.Disabled == true }
			button.MouseButton1Click:Connect(function()
				if obj.Disabled then
					return
				end
				selfLib:SafeCallback(func)
			end)

			function obj:SetDisabled(state)
				obj.Disabled = state and true or false
				if obj.TooltipTable then
					obj.TooltipTable.Disabled = obj.Disabled
				end
			end
			function obj:SetText(newText)
				obj.Text = tostring(newText or "")
				button.Text = obj.Text
			end
			function obj:Display() end
			function obj:UpdateColors() end
			function obj:RunChanged() end
			function obj:Destroy()
				safeDestroy(wrapper)
			end
			function obj:SetIcon(_) end
			attachInfoTooltip(obj, info, button)
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
			toggle.Callback = info.Callback or info.Changed
			local wrapper = createBaseElement(self.Holder, 30)

			local button = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				Parent = wrapper,
			})

			local asCheckbox = selfLib.ForceCheckbox == true or info.Variant == "Checkbox" or info.Checkbox == true
			local box, fill, switch, switchStroke, ball

			if asCheckbox then
				box = create("Frame", {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.fromOffset(18, 18),
					BackgroundColor3 = selfLib.Theme.SurfaceAlt,
					BorderSizePixel = 0,
					Parent = button,
				})
				addCorner(box, 4)
				addStroke(box, selfLib.Theme.Outline)

				fill = create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(10, 10),
					BackgroundColor3 = selfLib.Theme.Accent,
					BorderSizePixel = 0,
					Visible = toggle.Value,
					Parent = box,
				})
				addCorner(fill, 3)
			else
				-- Obsidian-style pill switch: 32x18 capsule with a sliding ball.
				switch = create("Frame", {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(32, 18),
					BackgroundColor3 = toggle.Value and selfLib.Theme.Accent or selfLib.Theme.SurfaceAlt,
					BorderSizePixel = 0,
					Parent = button,
				})
				create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = switch })
				addPadding(switch, 2)
				switchStroke = addStroke(switch, toggle.Value and selfLib.Theme.Accent or selfLib.Theme.Outline)

				ball = create("Frame", {
					AnchorPoint = Vector2.new(toggle.Value and 1 or 0, 0),
					Position = UDim2.fromScale(toggle.Value and 1 or 0, 0),
					Size = UDim2.fromScale(1, 1),
					SizeConstraint = Enum.SizeConstraint.RelativeYY,
					BackgroundColor3 = selfLib.Theme.Text,
					BorderSizePixel = 0,
					Parent = switch,
				})
				create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ball })
			end

			local labelPad = asCheckbox and 26 or 38
			local label = create("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(asCheckbox and 26 or 6, 0),
				Size = UDim2.new(1, -labelPad, 1, 0),
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = selfLib.Theme.Text,
				Text = tostring(text),
				Parent = button,
			})

			-- right-aligned container for key/color pickers (like Obsidian/Linoria)
			local addons = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				-- In switch mode, sit to the left of the 32px switch (4px gap).
				Position = UDim2.new(1, asCheckbox and 0 or -36, 0.5, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundTransparency = 1,
				Parent = button,
			})
			local addonsLayout = create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = addons,
			})
			addonsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				local pad = addonsLayout.AbsoluteContentSize.X
				if pad > 0 then
					pad += 6
				end
				label.Size = UDim2.new(1, -(labelPad + pad), 1, 0)
			end)

			local function render()
				if asCheckbox then
					fill.Visible = toggle.Value and true or false
					box.BackgroundColor3 = toggle.Value and selfLib.Theme.AccentDark or selfLib.Theme.SurfaceAlt
					label.TextColor3 = toggle.Disabled and selfLib.Theme.SubText or selfLib.Theme.Text
					return
				end

				local offset = toggle.Value and 1 or 0
				switch.BackgroundColor3 = toggle.Value and selfLib.Theme.Accent or selfLib.Theme.SurfaceAlt
				switchStroke.Color = toggle.Value and selfLib.Theme.Accent or selfLib.Theme.Outline
				switch.BackgroundTransparency = toggle.Disabled and 0.75 or 0
				switchStroke.Transparency = toggle.Disabled and 0.75 or 0
				ball.BackgroundColor3 = toggle.Disabled and selfLib.Theme.SubText or selfLib.Theme.Text
				label.TextColor3 = selfLib.Theme.Text
				label.TextTransparency = toggle.Disabled and 0.8 or (toggle.Value and 0 or 0.4)
				pcall(function()
					tween(ball, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						AnchorPoint = Vector2.new(offset, 0),
						Position = UDim2.fromScale(offset, 0),
					})
				end)
			end

			toggle.Instance = wrapper
			toggle.Variant = asCheckbox and "Checkbox" or "Switch"
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
				if toggle.TooltipTable then
					toggle.TooltipTable.Disabled = toggle.Disabled
				end
				render()
			end
			function toggle:SetVisible(state)
				wrapper.Visible = state and true or false
			end
			function toggle:Display()
				render()
			end
			function toggle:UpdateColors()
				render()
			end
			function toggle:RunChanged()
				if toggle.Callback then
					Library:SafeCallback(toggle.Callback, toggle.Value)
				end
			end
			function toggle:Destroy()
				safeDestroy(wrapper)
			end
			function toggle:AddKeyPicker(kid, kinfo)
				local idArg, infoArg = kid, kinfo
				if type(kid) == "table" then
					infoArg = kid
					idArg = infoArg.Flag or infoArg.Idx or infoArg.Index or (id .. "_KeyPicker")
				end
				infoArg = infoArg or {}
				idArg = idArg or (id .. "_KeyPicker")
				local picker = createKeyPicker(idArg, infoArg, {
					Parent = addons,
					ButtonProps = { Size = UDim2.fromOffset(64, 18) },
				})
				if infoArg.SyncToggleState then
					picker:SyncToggle(toggle)
				end
				function picker:AddColorPicker(cid2, cinfo2)
					return toggle:AddColorPicker(cid2, cinfo2)
				end
				function picker:AddKeyPicker(kid2, kinfo2)
					return toggle:AddKeyPicker(kid2, kinfo2)
				end
				return picker
			end
			function toggle:AddColorPicker(cid, cinfo)
				local idArg, infoArg = cid, cinfo
				if type(cid) == "table" then
					infoArg = cid
					idArg = infoArg.Flag or infoArg.Idx or infoArg.Index or (id .. "_ColorPicker")
				end
				idArg = idArg or (id .. "_ColorPicker")
				local picker = createColorPickerControl(idArg, infoArg or {}, {
					Variant = "Addon",
					AddonsParent = addons,
					LabelRef = label,
					SwatchSize = UDim2.fromOffset(28, 18),
				})
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
			attachInfoTooltip(toggle, info, button)
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
			slider.Callback = info.Callback or info.Changed
			slider.Min = minValue
			slider.Max = maxValue
			slider.Rounding = rounding
			slider.Disabled = info.Disabled == true
			slider.Steps = type(info.Steps) == "table" and info.Steps or nil
			slider.AllowRightClickInput = info.AllowRightClickInput ~= false
			local function snapToSteps(value)
				if not slider.Steps or #slider.Steps == 0 then
					return value
				end
				local best, bestDiff = slider.Steps[1], math.huge
				for _, step in ipairs(slider.Steps) do
					local diff = math.abs((tonumber(step) or 0) - value)
					if diff < bestDiff then
						best, bestDiff = step, diff
					end
				end
				return tonumber(best) or value
			end

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
				local str = type(info.FormatValue) == "function"
					and tostring(info.FormatValue(shown))
					or tostring(shown)
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
				stepped = snapToSteps(stepped)
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
				local isLeft = input.UserInputType == Enum.UserInputType.MouseButton1
				local isRight = info.AllowRightClickInput and input.UserInputType == Enum.UserInputType.MouseButton2
				if isLeft or isRight or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					updateFromInput(input)
				end
			end)

			-- Listen globally so releasing the mouse outside the bar still ends the drag.
			selfLib:Connect(UserInputService.InputEnded, function(input)
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
				num = snapToSteps(math.clamp(round(num, slider.Rounding), slider.Min, slider.Max))
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
				if slider.TooltipTable then
					slider.TooltipTable.Disabled = slider.Disabled
				end
				wrapper.Active = not slider.Disabled
			end
			function slider:SetVisible(state)
				wrapper.Visible = state and true or false
			end
			function slider:Display() end
			function slider:UpdateColors() end
			function slider:RunChanged()
				if slider.Callback then
					Library:SafeCallback(slider.Callback, slider.Value)
				end
			end
			function slider:Destroy()
				safeDestroy(wrapper)
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
			attachInfoTooltip(slider, info, bar)
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
			inputObj.Callback = info.Callback or info.Changed
			inputObj.Disabled = info.Disabled == true
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

			local maxLength = tonumber(info.MaxLength) or 0
			local emptyReset = info.EmptyReset or "---"
			-- Mirrors Obsidian's Input:SetValue: validation lives here and both
			-- the UI events and programmatic SetValue funnel through it.
			local function applyValue(text)
				local value = tostring(text == nil and "" or text)
				if maxLength > 0 and #value > maxLength then
					value = value:sub(1, maxLength)
				end
				if info.AllowEmpty == false and value:gsub("%s", "") == "" then
					value = emptyReset
				end
				if info.Numeric then
					local n = tonumber(value)
					if #value > 0 and n == nil then
						value = tostring(inputObj.Value or "")
					else
						value = n or ""
					end
				end
				if type(info.VerifyValue) == "function" and value ~= emptyReset then
					local ok, verified = pcall(info.VerifyValue, value)
					if not ok or verified ~= true then
						value = emptyReset
					end
				end
				if box.Text ~= tostring(value) then
					box.Text = tostring(value)
				end
				inputObj:Fire(value)
			end

			box.FocusLost:Connect(function(enterPressed)
				if info.Finished then
					if not enterPressed then
						if info.ClearTextOnBlur then
							box.Text = tostring(inputObj.Value or "")
						end
						return
					end
					applyValue(box.Text)
				end
			end)

			if not info.Finished then
				box:GetPropertyChangedSignal("Text"):Connect(function()
					if box.Text == tostring(inputObj.Value) then
						return
					end
					applyValue(box.Text)
				end)
			end

			inputObj.Instance = wrapper
			inputObj._setter = function(value)
				applyValue(value)
			end
			function inputObj:SetText(text)
				label.Text = tostring(text or "")
			end
			function inputObj:SetDisabled(state)
				inputObj.Disabled = state and true or false
				box.TextEditable = not state
				if inputObj.TooltipTable then
					inputObj.TooltipTable.Disabled = inputObj.Disabled
				end
			end
			function inputObj:SetVisible(state)
				wrapper.Visible = state and true or false
			end
			function inputObj:Display() end
			function inputObj:UpdateColors() end
			function inputObj:RunChanged()
				if inputObj.Callback then
					Library:SafeCallback(inputObj.Callback, inputObj.Value)
				end
			end
			function inputObj:Destroy()
				safeDestroy(wrapper)
			end
			inputObj.VerifyValue = info.VerifyValue
			inputObj.AllowEmpty = info.AllowEmpty ~= false
			inputObj.EmptyReset = emptyReset
			inputObj.ClearTextOnBlur = info.ClearTextOnBlur == true

			attachInfoTooltip(inputObj, info, box)
			selfLib.Options[id] = inputObj
			selfLib.Flags[id] = inputObj.Value
			return inputObj
		end

		function groupbox:AddTextbox(id, info)
			return groupbox.AddInput(self, id, info)
		end

		function groupbox:AddDropdown(id, info)
			info = info or {}

			local function copyValues(tbl)
				if type(tbl) ~= "table" then
					return {}
				end
				local out = {}
				for i, v in ipairs(tbl) do
					out[i] = v
				end
				if #out == 0 then
					for k, v in pairs(tbl) do
						out[k] = v
					end
				end
				return out
			end

			local function getPlayers(excludeLocal)
				local list = {}
				local ok, players = pcall(function()
					return Players:GetPlayers()
				end)
				if not ok or type(players) ~= "table" then
					return list
				end

				local lp = LocalPlayer
				if lp == nil then
					pcall(function()
						lp = Players.LocalPlayer
					end)
				end

				for _, p in ipairs(players) do
					local okName, name = pcall(function()
						if excludeLocal and lp and p == lp then
							return nil
						end
						return p.Name
					end)
					if okName and type(name) == "string" and name ~= "" then
						table.insert(list, name)
					end
				end

				table.sort(list)
				return list
			end

			local function getTeams()
				local teamsService = game:GetService("Teams")
				local list = {}
				local children = {}

				if teamsService then
					local ok, res = pcall(function()
						return teamsService:GetTeams()
					end)
					if ok and type(res) == "table" then
						children = res
					else
						local ok2, res2 = pcall(function()
							return teamsService:GetChildren()
						end)
						if ok2 and type(res2) == "table" then
							children = res2
						end
					end
				end

				for _, t in ipairs(children) do
					if typeof(t) == "Instance" and t:IsA("Team") then
						table.insert(list, t.Name)
					end
				end
				table.sort(list)
				return list
			end

			local values = copyValues(info.Values or {})
			if info.SpecialType == "Player" then
				values = getPlayers(info.ExcludeLocalPlayer)
			elseif info.SpecialType == "Team" then
				values = getTeams()
			end

			local multi = info.Multi == true
			local disabledValues = copyValues(info.DisabledValues or {})
			local searchable = info.Searchable == true
			local valueImages = type(info.ValueImages) == "table" and info.ValueImages or nil
			local maxVisible = tonumber(info.MaxVisibleDropdownItems) or 8
			if maxVisible < 1 then
				maxVisible = 8
			end

			local function isArray(t)
				if type(t) ~= "table" then
					return false
				end
				local n = #t
				for k in pairs(t) do
					if type(k) ~= "number" or k < 1 or k > n then
						return false
					end
				end
				return true
			end

			local function isDisabledValue(value)
				for _, dv in ipairs(disabledValues) do
					if dv == value then
						return true
					end
				end
				return false
			end

			local function formatDisplay(value)
				if value == nil then
					return "None"
				end
				local formatter = info.FormatValue or info.FormatDisplayValue
				if type(formatter) == "function" then
					local ok, res = pcall(formatter, value)
					if ok and res ~= nil then
						return tostring(res)
					end
				end
				return tostring(value)
			end
			local function formatListItem(value)
				if type(info.FormatListValue) == "function" then
					local ok, res = pcall(info.FormatListValue, value)
					if ok and res ~= nil then
						return tostring(res)
					end
				end
				return formatDisplay(value)
			end

			local function valueToText(value)
				if value == nil then
					return "None"
				end
				return formatDisplay(value)
			end

			local function resolveSingleDefault(v)
				if v == nil then
					-- Obsidian: AllowNull keeps a cleared dropdown empty
					-- instead of silently snapping back to the first item.
					if info.AllowNull then
						return nil
					end
					if #values > 0 then
						return values[1]
					end
					return nil
				end
				if type(v) == "number" and #values > 0 and values[v] ~= nil then
					local foundLiteral = false
					for _, item in ipairs(values) do
						if item == v then
							foundLiteral = true
							break
						end
					end
					if not foundLiteral then
						return values[v]
					end
				end
				return v
			end

			local function normalizeMultiMap(v)
				if type(v) ~= "table" then
					return {}
				end
				local out = {}
				local count = 0
				local arrayLike = true
				for k, val in pairs(v) do
					count += 1
					if type(k) ~= "number" or val ~= true then
						arrayLike = false
					end
				end
				if count == #v and #v > 0 then
					for _, item in ipairs(v) do
						out[item] = true
					end
					return out
				end
				for k, val in pairs(v) do
					if type(k) == "number" and val ~= true and val ~= false and val ~= nil then
						out[val] = true
					elseif val == true then
						out[k] = true
					end
				end
				return out
			end

			local function resolveMultiDefault(v)
				if v == nil then
					return {}
				end
				if type(v) == "number" and #values > 0 and values[v] ~= nil then
					local foundLiteral = false
					for _, item in ipairs(values) do
						if item == v then
							foundLiteral = true
							break
						end
					end
					if foundLiteral then
						return { [v] = true }
					end
					return { [values[v]] = true }
				end
				if type(v) == "table" then
					return normalizeMultiMap(v)
				end
				return { [v] = true }
			end

			local dropdown = createOptionObject("Dropdown", id, { Value = multi and resolveMultiDefault(info.Default) or resolveSingleDefault(info.Default) })
			dropdown.Callback = info.Callback or info.Changed
			dropdown.Values = values
			dropdown.Multi = multi
			dropdown.DisabledValues = disabledValues
			dropdown.Searchable = searchable
			dropdown.MaxVisibleDropdownItems = maxVisible
			dropdown.SpecialType = info.SpecialType
			dropdown.ExcludeLocalPlayer = info.ExcludeLocalPlayer == true
			dropdown.EnablePlayerImages = info.EnablePlayerImages == true
			dropdown.Disabled = info.Disabled == true
			dropdown.Visible = info.Visible ~= false
			dropdown._normalizeMultiDefault = resolveMultiDefault
			dropdown.Open = false

			local hasLabel = (info.Text or info.Title) ~= nil and tostring(info.Text or info.Title) ~= ""
			local wrapperHeight = hasLabel and 52 or 30
			local wrapper = createBaseElement(self.Holder, wrapperHeight)
			wrapper.Visible = dropdown.Visible

			local label = create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 18),
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = selfLib.Theme.Text,
				Text = tostring(info.Text or info.Title or ""),
				Visible = hasLabel,
				Parent = wrapper,
			})

			local button = create("TextButton", {
				AnchorPoint = hasLabel and Vector2.new(0, 1) or Vector2.new(0, 0),
				Position = hasLabel and UDim2.new(0, 0, 1, 0) or UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = selfLib.Theme.Text,
				Text = "",
				Parent = wrapper,
			})
			addCorner(button, selfLib.Theme.CornerRadius)
			addStroke(button, selfLib.Theme.Outline)
			addPadding(button, 8)

			local overlay = selfLib.OverlayFrame
			if not overlay and selfLib.ScreenGui then
				overlay = selfLib.ScreenGui:FindFirstChild("Overlay")
				if not overlay then
					overlay = create("Frame", {
						Name = "Overlay",
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						ZIndex = 5000,
						Parent = selfLib.ScreenGui,
					})
				end
				selfLib.OverlayFrame = overlay
			end

			local menu = create("Frame", {
				Visible = false,
				ClipsDescendants = true,
				Size = UDim2.fromOffset(160, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				ZIndex = 5005,
				Parent = overlay or wrapper,
			})
			addCorner(menu, selfLib.Theme.CornerRadius)
			addStroke(menu, selfLib.Theme.Outline)

			-- transparent click-catcher behind the menu: any click outside closes the list
			-- (no cursor-coordinate maths, so it works whatever the GUI inset is)
			local backdrop = create("TextButton", {
				Name = "DropdownBackdrop",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				Visible = false,
				ZIndex = 5001,
				Parent = overlay or wrapper,
			})

			local menuList = create("UIListLayout", {
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = menu,
			})
			addPadding(menu, 6)

			local searchBox
			local searchRow
			if searchable then
				searchRow = create("Frame", {
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					LayoutOrder = 0,
					Parent = menu,
				})
				searchBox = create("TextBox", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundColor3 = selfLib.Theme.Surface,
					BorderSizePixel = 0,
					ClearTextOnFocus = false,
					Font = selfLib.Theme.Font,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = selfLib.Theme.Text,
					PlaceholderText = "Search...",
					PlaceholderColor3 = selfLib.Theme.SubText,
					Text = "",
					Parent = searchRow,
				})
				addCorner(searchBox, 4)
				addStroke(searchBox, selfLib.Theme.Outline)
				addPadding(searchBox, 6)
			end

			local itemsScroll = create("ScrollingFrame", {
				Size = UDim2.new(1, 0, 0, 0),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = selfLib.Theme.Outline,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				LayoutOrder = 1,
				Parent = menu,
			})
			local itemsLayout = create("UIListLayout", {
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = itemsScroll,
			})

			local closeList -- forward declarations (defined below)
			local updateMenuPosition
			local outsideConn
			local positionConn
			local function stopPositionTracking()
				if positionConn then
					pcall(function()
						positionConn:Disconnect()
					end)
					positionConn = nil
				end
			end
			local function startPositionTracking()
				stopPositionTracking()
				positionConn = RunService.RenderStepped:Connect(function()
					local ok = pcall(function()
						if dropdown.Destroyed or not menu or not menu.Parent or not menu.Visible then
							stopPositionTracking()
							return
						end
						if not button or not button.Parent then
							stopPositionTracking()
							return
						end
						updateMenuPosition()
					end)
					if not ok then
						stopPositionTracking()
					end
				end)
			end

			dropdown.Destroyed = false
			function dropdown:Destroy()
				dropdown.Destroyed = true
				stopPositionTracking()
				closeList()
				if outsideConn then
					pcall(function()
						outsideConn:Disconnect()
					end)
					outsideConn = nil
				end
				if dropdown.Instance then
					safeDestroy(dropdown.Instance)
				end
				if menu then
					safeDestroy(menu)
				end
				safeDestroy(backdrop)
			end

			backdrop.InputBegan:Connect(function(input)
				local t = input.UserInputType
				if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.Touch then
					closeList()
				end
			end)

			function closeList()
				backdrop.Visible = false
				if menu.Visible then
					menu.Visible = false
					dropdown.Open = false
					if selfLib._OpenDropdownCloser == closeList then
						selfLib._OpenDropdownCloser = nil
					end
				end
				stopPositionTracking()
			end

			function updateMenuPosition()
				if not menu.Visible then
					return
				end
				if not button or not button.Parent then
					return
				end
				-- the button got hidden (tab switch, dependency box, window hidden...)
				if not isGuiVisible(button) then
					closeList()
					return
				end

				local absPos = button.AbsolutePosition
				local absSize = button.AbsoluteSize
				local width = math.max(absSize.X, 140)
				menu.Size = UDim2.fromOffset(width, 0)

				local itemHeight = 24
				local itemPad = 4
				local visibleCount = 0
				for _, child in ipairs(itemsScroll:GetChildren()) do
					if child:IsA("TextButton") and child.Visible then
						visibleCount += 1
					end
				end

				local listContent = itemsLayout.AbsoluteContentSize.Y
				if listContent <= 0 and visibleCount > 0 then
					listContent = visibleCount * itemHeight + math.max(0, visibleCount - 1) * itemPad
				end

				local searchHeight = (searchable and searchRow and searchRow.Visible ~= false) and 28 or 0
				local maxListHeight = maxVisible * itemHeight + math.max(0, maxVisible - 1) * itemPad
				local desiredList
				if visibleCount == 0 then
					desiredList = itemHeight
				else
					desiredList = math.clamp(listContent, itemHeight, math.max(itemHeight, maxListHeight))
				end

				itemsScroll.Size = UDim2.new(1, 0, 0, desiredList)

				local menuPadding = 12
				local gap = (searchable and 4 or 0)
				local totalHeight = desiredList + searchHeight + menuPadding + gap

				local gui = selfLib.ScreenGui
				local viewport = gui and gui.AbsoluteSize or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1920, 1080)
				local yBelow = absPos.Y + absSize.Y + 4
				local yAbove = absPos.Y - totalHeight - 4
				local yPos = yBelow
				if yBelow + totalHeight > viewport.Y - 8 and yAbove >= 8 then
					yPos = yAbove
				end

				local xPos = math.clamp(absPos.X, 8, math.max(8, viewport.X - width - 8))
				menu.Position = UDim2.fromOffset(math.floor(xPos), math.floor(math.max(8, yPos)))
			end

			itemsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
				if menu.Visible then
					task.defer(updateMenuPosition)
				end
			end)

			local function syncSpecialValues()
				if dropdown.SpecialType == "Player" then
					dropdown.Values = getPlayers(dropdown.ExcludeLocalPlayer)
				elseif dropdown.SpecialType == "Team" then
					dropdown.Values = getTeams()
				end

				if dropdown.Multi then
					local map = normalizeMultiMap(dropdown.Value)
					for k in pairs(map) do
						local found = false
						for _, v in ipairs(dropdown.Values) do
							if v == k then
								found = true
								break
							end
						end
						if not found then
							map[k] = nil
						end
					end
					dropdown.Value = map
					selfLib.Flags[id] = dropdown.Value
					selfLib.Options[id] = dropdown
				else
					local found = false
					for _, v in ipairs(dropdown.Values) do
						if v == dropdown.Value then
							found = true
							break
						end
					end
					if not found then
						if #dropdown.Values > 0 then
							dropdown.Value = dropdown.Values[1]
						else
							dropdown.Value = nil
						end
					end
					selfLib.Flags[id] = dropdown.Value
					selfLib.Options[id] = dropdown
				end
			end

			local function openList()
				if dropdown.Disabled or dropdown.Visible == false then
					return
				end
				-- ensure menu has a usable size immediately
				local width = math.max((button and button.AbsoluteSize.X) or 0, 140)
				menu.Size = UDim2.fromOffset(width, 0)
				if selfLib._OpenDropdownCloser and selfLib._OpenDropdownCloser ~= closeList then
					pcall(selfLib._OpenDropdownCloser)
				end
				if selfLib._OpenColorPickerCloser then
					pcall(selfLib._OpenColorPickerCloser)
				end
				if dropdown.SpecialType == "Player" or dropdown.SpecialType == "Team" then
					syncSpecialValues()
				end
				menu.Parent = overlay or (selfLib.OverlayFrame or menu.Parent)
				backdrop.Parent = menu.Parent
				backdrop.Visible = true
				menu.Visible = true
				popIn(menu)
				dropdown.Open = true
				selfLib._OpenDropdownCloser = closeList
				if searchBox then
					searchBox.Text = ""
				end
				dropdown:Refresh()
				startPositionTracking()
				task.defer(updateMenuPosition)
			end

			-- (clicking outside the menu is handled by the backdrop behind it)

			local function isSelected(value)
				if multi then
					return type(dropdown.Value) == "table" and dropdown.Value[value] == true
				end
				return dropdown.Value == value
			end

			local function setSingleValue(value)
				dropdown.Value = value
				selfLib.Flags[id] = value
				if dropdown.Type == "Toggle" then
					selfLib.Toggles[id] = dropdown
				else
					selfLib.Options[id] = dropdown
				end
				for _, fn in ipairs(dropdown.ChangedCallbacks) do
					selfLib:SafeCallback(fn, value)
				end
				if dropdown.Callback then
					selfLib:SafeCallback(dropdown.Callback, value)
				end
			end

			local function fireValue(value)
				dropdown.Value = value
				selfLib.Flags[id] = value
				selfLib.Options[id] = dropdown
				for _, fn in ipairs(dropdown.ChangedCallbacks) do
					selfLib:SafeCallback(fn, value)
				end
				if dropdown.Callback then
					selfLib:SafeCallback(dropdown.Callback, value)
				end
			end

			local function selectValue(value)
				if isDisabledValue(value) then
					return
				end
				if multi then
					local map = normalizeMultiMap(dropdown.Value)
					if map[value] then
						map[value] = nil
					else
						map[value] = true
					end
					dropdown.Value = map
					fireValue(deepCopy(map))
					dropdown:Refresh()
					task.defer(updateMenuPosition)
				else
					if dropdown.Value == value then
						-- clicking the current value: only AllowNull clears it
						if info.AllowNull then
							setSingleValue(nil)
							dropdown:Refresh()
						end
						closeList()
						return
					end
					setSingleValue(value)
					closeList()
					dropdown:Refresh()
				end
			end

			function dropdown:DisplayText()
				if multi then
					local picked = {}
					for _, v in ipairs(dropdown.Values or {}) do
						if type(dropdown.Value) == "table" and dropdown.Value[v] == true then
							table.insert(picked, valueToText(v))
						end
					end
					if #picked == 0 then
						return "None"
					end
					return table.concat(picked, ", ")
				end
				if dropdown.Value == nil then
					return "None"
				end
				return valueToText(dropdown.Value)
			end

			local function passesSearch(value)
				if not searchable or not searchBox then
					return true
				end
				local q = string.lower(tostring(searchBox.Text or ""))
				if q == "" then
					return true
				end
				local txt = string.lower(valueToText(value))
				return string.find(txt, q, 1, true) ~= nil
			end

			function dropdown:Refresh()
				button.Text = self:DisplayText()
				button.TextColor3 = dropdown.Disabled and selfLib.Theme.SubText or selfLib.Theme.Text

				for _, child in ipairs(itemsScroll:GetChildren()) do
					if child:IsA("TextButton") then
						child:Destroy()
					end
				end

				for _, value in ipairs(dropdown.Values or {}) do
					if passesSearch(value) then
						local disabled = isDisabledValue(value)
						local selected = isSelected(value)
						local opt = create("TextButton", {
							Size = UDim2.new(1, 0, 0, 24),
							BackgroundColor3 = selected and selfLib.Theme.AccentDark or selfLib.Theme.Surface,
							BorderSizePixel = 0,
							AutoButtonColor = false,
							Font = selfLib.Theme.Font,
							TextSize = 13,
							TextXAlignment = Enum.TextXAlignment.Left,
							TextTruncate = Enum.TextTruncate.AtEnd,
							TextColor3 = disabled and selfLib.Theme.SubText or selfLib.Theme.Text,
							Text = formatListItem(value),
							ZIndex = 5006,
							Parent = itemsScroll,
						})
						addCorner(opt, 4)
						addPadding(opt, 6)
						if not disabled then
							opt.MouseButton1Click:Connect(function()
								selectValue(value)
							end)
						end
					end
				end

				if menu.Visible then
					task.defer(updateMenuPosition)
				end
			end

			function dropdown:SetValues(newValues)
				dropdown.Values = copyValues(newValues or {})
				if info.SpecialType == "Player" then
					dropdown.Values = getPlayers(dropdown.ExcludeLocalPlayer)
				elseif info.SpecialType == "Team" then
					dropdown.Values = getTeams()
				end
				if multi then
					local map = normalizeMultiMap(dropdown.Value)
					for k in pairs(map) do
						local found = false
						for _, v in ipairs(dropdown.Values) do
							if v == k then found = true break end
						end
						if not found then
							map[k] = nil
						end
					end
					dropdown.Value = map
				else
					local found = false
					for _, v in ipairs(dropdown.Values) do
						if v == dropdown.Value then
							found = true
							break
						end
					end
					if not found then
						dropdown.Value = #dropdown.Values > 0 and dropdown.Values[1] or nil
					end
				end
				dropdown:Refresh()
			end
			function dropdown:AddValues(newValues)
				if info.SpecialType == "Player" then
					dropdown:SetValues(getPlayers(dropdown.ExcludeLocalPlayer))
					return
				end
				if info.SpecialType == "Team" then
					dropdown:SetValues(getTeams())
					return
				end
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
				disabledValues = copyValues(vals or {})
				dropdown.DisabledValues = disabledValues
				dropdown:Refresh()
			end
			function dropdown:AddDisabledValues(vals)
				if type(vals) == "table" then
					for _, v in ipairs(vals) do
						table.insert(disabledValues, v)
					end
				elseif vals ~= nil then
					table.insert(disabledValues, vals)
				end
				dropdown.DisabledValues = disabledValues
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
				if dropdown.TooltipTable then
					dropdown.TooltipTable.Disabled = dropdown.Disabled
				end
				button.Active = not dropdown.Disabled
				dropdown:Refresh()
				if dropdown.Disabled then
					closeList()
				end
			end
			function dropdown:SetVisible(state)
				dropdown.Visible = state and true or false
				wrapper.Visible = dropdown.Visible
				if not dropdown.Visible then
					closeList()
				end
			end
			function dropdown:Display()
				dropdown:Refresh()
			end
			function dropdown:UpdateColors()
				dropdown:Refresh()
			end
			function dropdown:RunChanged()
				if dropdown.Callback then
					Library:SafeCallback(dropdown.Callback, dropdown.Value)
				end
			end
			function dropdown:RecalculateListSize(count) end
			function dropdown:RefreshPool() end
			function dropdown:SetValue(value)
				dropdown._setter(value)
				dropdown:Refresh()
			end
			dropdown.KeepDisabledValuePosition = info.KeepDisabledValuePosition == true
			dropdown.AutoWidth = info.AutoWidth == true
			dropdown.DragSelect = info.DragSelect == true
			dropdown.ValueImages = valueImages
			function dropdown:GetActiveValues(asCount)
				if multi then
					if asCount then
						local n = 0
						for _, v in ipairs(dropdown.Values or {}) do
							if type(dropdown.Value) == "table" and dropdown.Value[v] == true then
								n += 1
							end
						end
						return n
					end
					local map = {}
					for _, v in ipairs(dropdown.Values or {}) do
						if type(dropdown.Value) == "table" and dropdown.Value[v] == true then
							map[v] = true
						end
					end
					return map
				end
				return dropdown.Value
			end
			function dropdown:Select(value)
				if multi then
					local current = deepCopy(type(dropdown.Value) == "table" and dropdown.Value or {})
					current[value] = true
					dropdown:SetValue(current)
				else
					dropdown:SetValue(value)
				end
			end
			function dropdown:Deselect(value)
				if multi then
					local current = deepCopy(type(dropdown.Value) == "table" and dropdown.Value or {})
					current[value] = nil
					dropdown:SetValue(current)
				end
			end
			function dropdown:BuildDropdownList()
				dropdown:Refresh()
			end
			function dropdown:UpdateButton()
				dropdown:Display()
			end

			dropdown.Instance = wrapper
			dropdown.Menu = menu
			dropdown.Button = button
			dropdown._setter = function(value)
				if multi then
					dropdown.Value = resolveMultiDefault(value)
					fireValue(deepCopy(dropdown.Value))
				else
					dropdown.Value = resolveSingleDefault(value)
					setSingleValue(dropdown.Value)
				end
				dropdown:Refresh()
			end

			if searchBox then
				searchBox:GetPropertyChangedSignal("Text"):Connect(function()
					dropdown:Refresh()
					if menu.Visible then
						task.defer(updateMenuPosition)
					end
				end)
			end

			button:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
				if menu.Visible then
					task.defer(updateMenuPosition)
				end
			end)
			button:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				if menu.Visible then
					task.defer(updateMenuPosition)
				end
			end)

			button.MouseButton1Click:Connect(function()
				if dropdown.Disabled then
					return
				end
				if menu.Visible then
					closeList()
				else
					openList()
				end
			end)
			button.Active = true
			button.AutoButtonColor = false

			if info.SpecialType == "Player" then
				selfLib:Connect(Players.PlayerAdded, function()
					syncSpecialValues()
					dropdown:Refresh()
				end)
				selfLib:Connect(Players.PlayerRemoving, function()
					task.defer(function()
						syncSpecialValues()
						dropdown:Refresh()
					end)
				end)
				task.defer(function()
					if dropdown and dropdown.Refresh then
						syncSpecialValues()
						dropdown:Refresh()
					end
				end)
			elseif info.SpecialType == "Team" then
				local teamsService = game:GetService("Teams")
				selfLib:Connect(teamsService.ChildAdded, function()
					task.defer(function()
						syncSpecialValues()
						dropdown:Refresh()
					end)
				end)
				selfLib:Connect(teamsService.ChildRemoved, function()
					task.defer(function()
						syncSpecialValues()
						dropdown:Refresh()
					end)
				end)
				selfLib:Connect(teamsService:GetPropertyChangedSignal("Name"), function() end)
				task.defer(function()
					if dropdown and dropdown.Refresh then
						syncSpecialValues()
						dropdown:Refresh()
					end
				end)
			end

			dropdown:Refresh()
			attachInfoTooltip(dropdown, info, button)
			selfLib.Options[id] = dropdown
			selfLib.Flags[id] = dropdown.Value
			return dropdown
		end

		function groupbox:AddKeyPicker(id, info)
			info = info or {}
			local noUI = info.NoUI == true
			local wrapper = createBaseElement(self.Holder, noUI and 0 or 30)
			if noUI then
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

			return createKeyPicker(id, info, {
				Parent = wrapper,
				Instance = wrapper,
				Label = label,
				ButtonProps = {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 0),
					Size = UDim2.fromOffset(84, 24),
				},
			})
		end

		function groupbox:AddColorPicker(id, info)
			info = info or {}
			local picker = createColorPickerControl(id, info, {
				Variant = "Row",
				Holder = self.Holder,
				LabelText = info.Text or info.Title or id,
			})

			selfLib.Options[id] = picker
			selfLib.Flags[id] = picker.Value
			return picker
		end

		function groupbox:AddCheckbox(id, info)
			info = info or {}
			info.Text = info.Text or info.Title or info.Name or id
			info.Variant = "Checkbox"
			return groupbox.AddToggle(self, id, info)
		end

		-- Viewport shell
		function groupbox:AddViewport(id, info)
			info = info or {}
			local h = tonumber(info.Height) or 200
			local wrapper = createBaseElement(self.Holder, h + 20)
			local viewportFrame = create("ViewportFrame", {
				Size = UDim2.new(1, 0, 0, h),
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				Parent = wrapper,
			})
			addCorner(viewportFrame, selfLib.Theme.CornerRadius)
			addStroke(viewportFrame, selfLib.Theme.Outline)
			local cam = Instance.new("Camera")
			viewportFrame.CurrentCamera = cam
			cam.Parent = viewportFrame
			local obj = {
				Instance = wrapper, ViewportFrame = viewportFrame, Camera = cam,
				Object = info.Object, Height = h, Visible = info.Visible ~= false,
				Interactive = info.Interactive == true, AutoFocus = info.AutoFocus == true,
				Callback = info.Callback,
			}
			wrapper.Visible = obj.Visible
			viewportFrame.Active = obj.Interactive

			local function getPivotPosition()
				if not obj.Object then
					return Vector3.zero
				end
				local ok, pivot = pcall(function()
					return obj.Object:GetPivot().Position
				end)
				return ok and pivot or Vector3.zero
			end
			local function getModelSize()
				if not obj.Object then
					return Vector3.one
				end
				local ok, size = pcall(function()
					if obj.Object:IsA("BasePart") then
						return obj.Object.Size
					end
					return select(2, obj.Object:GetBoundingBox())
				end)
				return ok and size or Vector3.one
			end
			local function focusCamera()
				if not obj.Object or not obj.Camera then
					return
				end
				local size = getModelSize()
				local maxExtent = math.max(size.X, size.Y, size.Z)
				local distance = maxExtent * 2
				local pivot = getPivotPosition()
				pcall(function()
					obj.Camera.CFrame = CFrame.new(pivot + Vector3.new(0, maxExtent / 2, distance), pivot)
				end)
			end
			local function orbitCamera(yaw, pitch)
				if not obj.Object or not obj.Camera then
					return
				end
				local pivot = getPivotPosition()
				pcall(function()
					local rotY = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), yaw)
					obj.Camera.CFrame = CFrame.new(pivot) * rotY * CFrame.new(-pivot) * obj.Camera.CFrame
					local rotX = CFrame.fromAxisAngle(obj.Camera.CFrame.RightVector, pitch)
					local pitched = CFrame.new(pivot) * rotX * CFrame.new(-pivot) * obj.Camera.CFrame
					if pitched.UpVector.Y > 0.1 then
						obj.Camera.CFrame = pitched
					end
				end)
			end
			local function zoomCamera(amount)
				if not obj.Camera then
					return
				end
				pcall(function()
					obj.Camera.CFrame = obj.Camera.CFrame + obj.Camera.CFrame.LookVector * amount
				end)
			end
			function obj:SetObject(object, clone)
				obj.Object = object
				if object and viewportFrame then
					for _, c in ipairs(viewportFrame:GetChildren()) do
						if c:IsA("Model") or c:IsA("BasePart") then
							c:Destroy()
						end
					end
					local target = object
					if clone == true or clone == nil then
						pcall(function() target = object:Clone() end)
					end
					if target then
						target.Parent = viewportFrame
					end
					if obj.AutoFocus then
						focusCamera()
					end
					if obj.Callback then
						selfLib:SafeCallback(obj.Callback, obj.Object)
					end
				end
			end
			function obj:SetHeight(height)
				obj.Height = tonumber(height) or obj.Height
				viewportFrame.Size = UDim2.new(1, 0, 0, obj.Height)
				wrapper.Size = UDim2.new(1, 0, 0, obj.Height + 20)
			end
			function obj:Focus()
				focusCamera()
			end
			function obj:SetCamera(camera)
				if camera then
					obj.Camera = camera
					viewportFrame.CurrentCamera = camera
				end
			end
			function obj:SetCameraCFrame(cf)
				if obj.Camera then
					pcall(function() obj.Camera.CFrame = cf end)
				end
			end
			function obj:GetCameraCFrame()
				if obj.Camera then
					local ok, cf = pcall(function() return obj.Camera.CFrame end)
					if ok then return cf end
				end
				return CFrame.new()
			end
			function obj:Rotate(yaw, pitch)
				orbitCamera(math.rad(tonumber(yaw) or 0), math.rad(tonumber(pitch) or 0))
			end
			function obj:Zoom(amount)
				zoomCamera(tonumber(amount) or 0)
			end
			function obj:LookAt(target)
				if not obj.Object and target == nil then
					return
				end
				pcall(function()
					obj.Camera.CFrame = CFrame.lookAt(obj.Camera.CFrame.Position, target or getPivotPosition())
				end)
			end
			function obj:SetDistance(d)
				d = tonumber(d) or 0
				if d <= 0 or not obj.Object then
					return
				end
				pcall(function()
					local pivot = getPivotPosition()
					local offset = obj.Camera.CFrame.Position - pivot
					local direction = offset.Magnitude > 0 and offset.Unit or -obj.Camera.CFrame.LookVector
					obj.Camera.CFrame = CFrame.lookAt(pivot + direction * d, pivot)
				end)
			end
			function obj:GetDistance()
				if not obj.Object or not obj.Camera then
					return 0
				end
				local ok, dist = pcall(function()
					return (obj.Camera.CFrame.Position - getPivotPosition()).Magnitude
				end)
				return ok and dist or 0
			end
			function obj:SetFieldOfView(fov)
				if obj.Camera then
					pcall(function() obj.Camera.FieldOfView = math.clamp(tonumber(fov) or 70, 1, 120) end)
				end
			end
			function obj:SetInteractive(state)
				obj.Interactive = state == true
				viewportFrame.Active = obj.Interactive
			end
			function obj:SetVisible(state)
				obj.Visible = state ~= false
				wrapper.Visible = obj.Visible
			end
			function obj:Destroy()
				for _, conn in ipairs(obj.Connections or {}) do
					pcall(function() conn:Disconnect() end)
				end
				safeDestroy(viewportFrame)
				safeDestroy(wrapper)
			end

			-- Obsidian-style interactive orbit (right-drag) + wheel zoom.
			obj.Connections = {}
			local dragging = false
			local lastMouse = Vector2.zero
			table.insert(obj.Connections, viewportFrame.InputBegan:Connect(function(input)
				if not obj.Interactive then
					return
				end
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					dragging = true
					lastMouse = getInputPosition(input)
				end
			end))
			table.insert(obj.Connections, selfLib:Connect(UserInputService.InputEnded, function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton2 then
					dragging = false
				end
			end))
			table.insert(obj.Connections, selfLib:Connect(UserInputService.InputChanged, function(input)
				if not obj.Interactive or not dragging then
					return
				end
				if input.UserInputType == Enum.UserInputType.MouseMovement then
					local pos = getInputPosition(input)
					local delta = pos - lastMouse
					lastMouse = pos
					orbitCamera(-delta.X * 0.01, -delta.Y * 0.01)
				end
			end))
			table.insert(obj.Connections, viewportFrame.InputChanged:Connect(function(input)
				if obj.Interactive and input.UserInputType == Enum.UserInputType.MouseWheel then
					zoomCamera(input.Position.Z * 2)
				end
			end))

			if info.Object then
				pcall(function() obj:SetObject(info.Object, info.Clone) end)
			end
			if info.Camera then
				pcall(function() obj:SetCamera(info.Camera) end)
			end
			if obj.AutoFocus then
				focusCamera()
			end
			selfLib.Options[id] = obj
			return obj
		end

		-- Image shell
		function groupbox:AddImage(id, info)
			info = info or {}
			local h = tonumber(info.Height) or 200
			local wrapper = createBaseElement(self.Holder, h)
			local img = create("ImageLabel", {
				Size = UDim2.new(1, 0, 0, h),
				BackgroundTransparency = info.BackgroundTransparency or 0,
				Image = resolveIcon(info.Image) or (type(info.Image) == "string" and info.Image or ""),
				ImageColor3 = info.Color or Color3.new(1, 1, 1),
				ImageTransparency = info.Transparency or 0,
				ImageRectOffset = typeof(info.RectOffset) == "Vector2" and info.RectOffset or Vector2.zero,
				ImageRectSize = typeof(info.RectSize) == "Vector2" and info.RectSize or Vector2.zero,
				ScaleType = info.ScaleType or Enum.ScaleType.Fit,
				Parent = wrapper,
			})
			applyIconData(img, info.Image)
			if typeof(info.RectOffset) == "Vector2" then
				img.ImageRectOffset = info.RectOffset
			end
			if typeof(info.RectSize) == "Vector2" then
				img.ImageRectSize = info.RectSize
			end
			addCorner(img, selfLib.Theme.CornerRadius)
			local obj = {
				Instance = wrapper, ImageLabel = img, Height = h, Visible = info.Visible ~= false,
				Callback = info.Callback, Changed = info.Changed,
			}
			local previousAsset = img.Image
			obj.Image = info.Image
			wrapper.Visible = obj.Visible
			function obj:SetHeight(height)
				obj.Height = tonumber(height) or obj.Height
				img.Size = UDim2.new(1, 0, 0, obj.Height)
				wrapper.Size = UDim2.new(1, 0, 0, obj.Height)
			end
			function obj:SetImage(newImage)
				local asset = resolveIcon(newImage) or (type(newImage) == "string" and newImage or "")
				img.Image = asset
				applyIconData(img, newImage)
				obj.Image = newImage
				-- Docs: "Called when the image changes". Fire on actual change
				-- only, with the resolved asset (matches Obsidian's Image.Image).
				if asset ~= previousAsset then
					previousAsset = asset
					selfLib:SafeCallback(obj.Callback, asset)
					selfLib:SafeCallback(obj.Changed, asset)
				end
			end
			function obj:SetColor(color)
				if typeof(color) == "Color3" then img.ImageColor3 = color end
			end
			function obj:SetRectOffset(ro)
				if typeof(ro) == "Vector2" then img.ImageRectOffset = ro end
			end
			function obj:SetRectSize(rs)
				if typeof(rs) == "Vector2" then img.ImageRectSize = rs end
			end
			function obj:SetScaleType(st) img.ScaleType = st end
			function obj:SetTransparency(t) img.ImageTransparency = tonumber(t) or 0 end
			function obj:SetVisible(state)
				obj.Visible = state ~= false
				wrapper.Visible = obj.Visible
			end
			function obj:Destroy()
				safeDestroy(img)
				safeDestroy(wrapper)
			end
			selfLib.Options[id] = obj
			return obj
		end

		-- Video shell
		function groupbox:AddVideo(id, info)
			info = info or {}
			local h = tonumber(info.Height) or 200
			local wrapper = createBaseElement(self.Holder, h)
			local video = create("VideoFrame", {
				Size = UDim2.new(1, 0, 0, h),
				BackgroundTransparency = 1,
				Video = info.Video or "",
				Looped = info.Looped == true,
				Playing = info.Playing == true,
				Volume = tonumber(info.Volume) or 1,
				Parent = wrapper,
			})
			local obj = { Instance = wrapper, VideoFrame = video, Height = h, Visible = info.Visible ~= false }
			wrapper.Visible = obj.Visible
			function obj:SetHeight(height)
				obj.Height = tonumber(height) or obj.Height
				video.Size = UDim2.new(1, 0, 0, obj.Height)
				wrapper.Size = UDim2.new(1, 0, 0, obj.Height)
			end
			function obj:SetVideo(v) video.Video = v or "" end
			function obj:SetLooped(b) video.Looped = b == true end
			function obj:SetVolume(v) video.Volume = tonumber(v) or 0 end
			function obj:SetPlaying(b) video.Playing = b == true end
			function obj:Play() video.Playing = true end
			function obj:Pause() video.Playing = false end
			function obj:SetVisible(state)
				obj.Visible = state ~= false
				wrapper.Visible = obj.Visible
			end
			function obj:Destroy()
				safeDestroy(video)
				safeDestroy(wrapper)
			end
			selfLib.Options[id] = obj
			return obj
		end

		-- UIPassthrough shell
		function groupbox:AddUIPassthrough(id, info)
			info = info or {}
			local h = tonumber(info.Height) or 24
			local wrapper = createBaseElement(self.Holder, h)
			local holder = create("Frame", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Parent = wrapper,
			})
			local obj = { Instance = wrapper, Holder = holder, Height = h, Visible = info.Visible ~= false }
			wrapper.Visible = obj.Visible
			if info.Instance then
				info.Instance.Parent = holder
			end
			function obj:SetHeight(height)
				obj.Height = tonumber(height) or obj.Height
				wrapper.Size = UDim2.new(1, 0, 0, obj.Height)
				holder.Size = UDim2.new(1, 0, 0, obj.Height)
			end
			function obj:SetInstance(inst)
				if inst then
					inst.Parent = holder
				end
			end
			function obj:SetVisible(state)
				obj.Visible = state ~= false
				wrapper.Visible = obj.Visible
			end
			function obj:Destroy()
				safeDestroy(holder)
				safeDestroy(wrapper)
			end
			selfLib.Options[id] = obj
			return obj
		end

		-- Settings shell
		function groupbox:AddSettings(id, info)
			info = info or {}
			local width = tonumber(info.Width) or 200
			local wrapper = createBaseElement(self.Holder, 30)
			local btn = create("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = selfLib.Theme.Font,
				TextSize = 14,
				TextColor3 = selfLib.Theme.Text,
				Text = tostring(info.Title or info.Name or "Settings"),
				Parent = wrapper,
			})
			addCorner(btn, selfLib.Theme.CornerRadius)
			addStroke(btn, selfLib.Theme.Outline)
			local menu = create("Frame", {
				Visible = false,
				Size = UDim2.fromOffset(width, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				ZIndex = 5005,
				Parent = selfLib.OverlayFrame or selfLib.ScreenGui,
			})
			addCorner(menu, selfLib.Theme.CornerRadius)
			addStroke(menu, selfLib.Theme.Outline)
			addPadding(menu, 8)
			local obj = { Instance = wrapper, Button = btn, Menu = menu, Width = width, Visible = info.Visible ~= false }
			wrapper.Visible = obj.Visible
			function obj:Resize() end
			function obj:SetWidth(w)
				obj.Width = tonumber(w) or obj.Width
				menu.Size = UDim2.fromOffset(obj.Width, 0)
			end
			function obj:Open()
				menu.Visible = true
			end
			function obj:Close()
				menu.Visible = false
			end
			function obj:Toggle()
				menu.Visible = not menu.Visible
			end
			function obj:Update() end
			function obj:SetVisible(state)
				obj.Visible = state ~= false
				wrapper.Visible = obj.Visible
			end
			-- Obsidian KeybindMenu/Settings names
			function obj:RefreshSettings() obj:Update() end
			function obj:SetSettingsOpen(open)
				if open then
					obj:Open()
				else
					obj:Close()
				end
			end
			function obj:ToggleSettings() obj:Toggle() end
			function obj:SetVisibilityControl(enabled) end
			function obj:Destroy()
				safeDestroy(menu)
				safeDestroy(btn)
				safeDestroy(wrapper)
			end
			btn.MouseButton1Click:Connect(function()
				obj:Toggle()
			end)
			selfLib.Options[id] = obj
			return obj
		end

		local function createDependencyContainer(parentHolder)
			local depContainer = create("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent = parentHolder,
			})
			local depHolder = create("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent = depContainer,
			})
			create("UIListLayout", {
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = depHolder,
			})

			local depbox = {
				Container = depContainer,
				Holder = depHolder,
				Dependencies = {},
				_DependencyConnections = {},
			}
			attachGroupboxMethods(depbox)

			-- copy element methods from groupbox
			for k, v in pairs(groupbox) do
				if depbox[k] == nil and type(v) == "function" then
					depbox[k] = v
				end
			end

			local function getOptionValue(opt)
				if opt == nil then
					return nil
				end
				return opt.Value
			end

			local function conditionMet(dep)
				local obj = dep[1]
				local expected = dep[2]
				if type(expected) == "function" then
					local ok, res = pcall(expected, obj)
					return ok and res == true
				end
				local val = getOptionValue(obj)
				if type(val) == "table" then
					-- multi dropdown map or table value
					if val[expected] == true then
						return true
					end
					-- array contains expected
					for _, v in ipairs(val) do
						if v == expected then
							return true
						end
					end
					-- fallback direct compare
					return val == expected
				end
				return val == expected
			end

			function depbox:EvaluateDependencies()
				local visible = true
				for _, dep in ipairs(self.Dependencies or {}) do
					if not conditionMet(dep) then
						visible = false
						break
					end
				end
				if self.Container then
					self.Container.Visible = visible
				end
				return visible
			end

			function depbox:Resize() end
			function depbox:Update(cancelSearch)
				self:EvaluateDependencies()
			end
			function depbox:Destroy()
				if self.Container then safeDestroy(self.Container) end
			end
			function depbox:SetupDependencies(deps)
				self.Dependencies = deps or {}
				for _, conn in ipairs(self._DependencyConnections) do
					pcall(function() conn:Disconnect() end)
				end
				table.clear(self._DependencyConnections)

				for _, dep in ipairs(self.Dependencies) do
					local obj = dep[1]
					if obj and type(obj.OnChanged) == "function" then
						local cb = obj:OnChanged(function()
							depbox:EvaluateDependencies()
						end)
						-- OnChanged in our impl returns fn and calls immediately; no disconnect handle, but fine
					end
					if obj and type(obj.ChangedCallbacks) == "table" then
						-- already covered by OnChanged
					end
				end
				self:EvaluateDependencies()
			end

			function depbox:AddDependencyBox()
				return createDependencyContainer(depbox.Holder)
			end
			function depbox:AddDependencyGroupbox()
				return createDependencyContainer(depbox.Holder)
			end

			return depbox
		end

		function groupbox:AddDependencyBox()
			return createDependencyContainer(self.Holder)
		end
		function groupbox:AddDependencyGroupbox()
			return createDependencyContainer(self.Holder)
		end

		-- Obsidian uses Create* method names; PESUI uses Add*. Mirror the whole
		-- surface so unmodified Obsidian scripts work against a PESUI window.
		local createAliases = {
			CreateDivider = "AddDivider",
			CreateLabel = "AddLabel",
			CreateParagraph = "AddLabel",
			CreateButton = "AddButton",
			CreateToggle = "AddToggle",
			CreateSlider = "AddSlider",
			CreateInput = "AddInput",
			CreateTextbox = "AddTextbox",
			CreateDropdown = "AddDropdown",
			CreateKeyPicker = "AddKeyPicker",
			CreateColorPicker = "AddColorPicker",
			CreateCheckbox = "AddCheckbox",
			CreateViewport = "AddViewport",
			CreateImage = "AddImage",
			CreateVideo = "AddVideo",
			CreateSettings = "AddSettings",
			CreateDependencyBox = "AddDependencyBox",
			CreateDependencyGroupbox = "AddDependencyGroupbox",
		}
		for alias, target in pairs(createAliases) do
			if type(groupbox[target]) == "function" and groupbox[alias] == nil then
				groupbox[alias] = function(self, ...)
					return self[target](self, ...)
				end
			end
		end

		return groupbox
	end

	Window._CreateGroupbox = createGroupbox

	-- A page whose scroll/columns live under an arbitrary parent (used by
	-- subtabs and custom-tab children) instead of the Window-level `pages`.
	local function createEmbeddedPage(parent)
		local page = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = parent,
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
		create("UIListLayout", { Padding = UDim.new(0, 10), Parent = left })
		local right = create("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0.5, -5, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			Parent = columns,
		})
		create("UIListLayout", { Padding = UDim.new(0, 10), Parent = right })
		return page, left, right, scroll
	end

	local function createSubTabShell(tab)
		if tab._SubTabStrip then
			return
		end
		if tab.Scroll then
			tab.Scroll.Visible = false
		end
		if tab.LeftColumn then tab.LeftColumn.Visible = false end
		if tab.RightColumn then tab.RightColumn.Visible = false end
		local strip = create("Frame", {
			Name = "SubTabStrip",
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.fromOffset(10, 8),
			BackgroundTransparency = 1,
			Parent = tab.Page,
		})
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = strip,
		})
		local holder = create("Frame", {
			Name = "SubTabPages",
			Position = UDim2.fromOffset(10, 44),
			Size = UDim2.new(1, -20, 1, -52),
			BackgroundTransparency = 1,
			Parent = tab.Page,
		})
		tab._SubTabStrip = strip
		tab._SubTabHolder = holder
		tab.SubTabList = tab.SubTabList or {}
		tab._SubTabsByName = tab._SubTabsByName or {}
		tab.ActiveSubTab = nil
	end

	local function attachTabMethods(tab)
		function tab:UpdateWarningBox(info)
			if self.SubTabs == true then
				error("[PESUI] UpdateWarningBox is not available on a tab with SubTabs = true")
			end
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
			local normal = info.IsNormal == true
			self.WarningBox.BackgroundColor3 = normal and selfLib.Theme.Surface or selfLib.Theme.SurfaceAlt
			self.WarningTitle.TextColor3 = normal and selfLib.Theme.Text or selfLib.Theme.Danger
			if info.LockSize then
				self.WarningText.Size = UDim2.new(1, 0, 0, tonumber(info.LockSize) or 48)
			else
				self.WarningText.Size = UDim2.new(1, 0, 0, 0)
			end
		end

		function tab:SetVisible(state)
			if self.Button then
				self.Button.Visible = state and true or false
			end
			if state == false and Window.ActiveTab == self then
				for _, other in ipairs(Window.Tabs) do
					if other ~= self and other.Button and other.Button.Visible and other.Show then
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
		function tab:SetIcon(icon)
			self.Icon = icon
			if not self.Button then return end
			local img = self.Button:FindFirstChild("IconImage")
			if img then
				safeDestroy(img)
			end
			if createIconInstance(icon, {
				Name = "IconImage",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 8, 0.5, 0),
				Size = UDim2.fromOffset(16, 16),
				BackgroundTransparency = 1,
				Parent = self.Button,
			}) then
				if self.ButtonLabel then
					self.ButtonLabel.Position = UDim2.fromOffset(30, 0)
					self.ButtonLabel.Size = UDim2.new(1, -36, 1, 0)
				end
			elseif self.ButtonLabel then
				self.ButtonLabel.Position = UDim2.fromOffset(10, 0)
				self.ButtonLabel.Size = UDim2.new(1, -16, 1, 0)
			end
		end
		function tab:SetTooltip(text)
			if self._Tooltip then
				pcall(function() self._Tooltip:Destroy() end)
				self._Tooltip = nil
			end
			self.Tooltip = text
			if text and text ~= "" and self.Button then
				self._Tooltip = selfLib:AddTooltip(tostring(text), nil, self.Button)
			end
		end
		function tab:Hover(state) end
		function tab:UpdateTabInfo()
			if Window.TabInfo then
				local title = Window.TabInfo:FindFirstChild("Title")
				if title and self.Name then
					local active = self.ParentTab and self.ParentTab.ActiveSubTab
					title.Text = active and (tostring(self.Name) .. " / " .. tostring(active.Name)) or tostring(self.Name)
				end
			end
		end
		function tab:RefreshSides() end
		function tab:Resize() end
		function tab:SetMaxHeight(h) end
		function tab:AddSubTab(arg1, arg2, arg3, arg4)
			if self.SubTabs ~= true then
				error("[PESUI] AddSubTab requires the parent tab to be created with SubTabs = true")
			end
			local name, icon, description, order, tooltip
			if type(arg1) == "table" then
				name = arg1.Name or "SubTab"
				icon = arg1.Icon or arg1.IconName
				description = arg1.Description or self.Description
				order = arg1.Order
				tooltip = arg1.Tooltip
			else
				name = arg1 or "SubTab"
				icon = arg2
				description = arg3 or self.Description
				order = arg4
			end

			createSubTabShell(self)

			local btn = create("TextButton", {
				Size = UDim2.new(0, 0, 1, 0),
				AutomaticSize = Enum.AutomaticSize.X,
				LayoutOrder = tonumber(order) or (#self.SubTabList + 1),
				BackgroundColor3 = selfLib.Theme.SurfaceAlt,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = selfLib.Theme.Font,
				TextSize = 13,
				TextColor3 = selfLib.Theme.Text,
				Text = "  " .. tostring(name) .. "  ",
				Parent = self._SubTabStrip,
			})
			addCorner(btn, 4)
			addStroke(btn, selfLib.Theme.Outline)

			local page, left, right, scroll = createEmbeddedPage(self._SubTabHolder)
			local subtab = {
				Name = name,
				Icon = icon,
				Description = description,
				Button = btn,
				Page = page,
				Scroll = scroll,
				LeftColumn = left,
				RightColumn = right,
				Groupboxes = {},
				Tabboxes = {},
				Window = Window,
				ParentTab = self,
				Order = order,
			}
			attachTabMethods(subtab)

			function subtab:Show()
				for _, sibling in ipairs(self.ParentTab.SubTabList) do
					sibling.Page.Visible = false
					sibling.Button.BackgroundColor3 = selfLib.Theme.SurfaceAlt
				end
				self.Page.Visible = true
				self.Button.BackgroundColor3 = selfLib.Theme.AccentDark
				self.ParentTab.ActiveSubTab = self
				self.ParentTab:UpdateTabInfo()
				if selfLib.Searching then
					selfLib:UpdateSearch(selfLib.SearchText)
				end
			end
			function subtab:Hide()
				self.Page.Visible = false
			end
			function subtab:SetVisible(state)
				self.Button.Visible = state and true or false
				if state == false and self.ParentTab.ActiveSubTab == self then
					for _, sibling in ipairs(self.ParentTab.SubTabList) do
						if sibling ~= self and sibling.Button.Visible then
							sibling:Show()
							break
						end
					end
				end
			end
			if tooltip then
				subtab:SetTooltip(tooltip)
			end
			if icon then
				subtab:SetIcon(icon)
			end

			btn.MouseButton1Click:Connect(subtab.Show)
			table.insert(self.SubTabList, subtab)
			self._SubTabsByName[tostring(name)] = subtab
			if #self.SubTabList == 1 then
				subtab:Show()
			end
			return subtab
		end
		function tab:Destroy()
			if self.Destroyed then return end
			self.Destroyed = true
			if self._Tooltip then
				pcall(function() self._Tooltip:Destroy() end)
				self._Tooltip = nil
			end
			for _, box in ipairs(self.Groupboxes or {}) do
				if box.Destroy then pcall(box.Destroy, box) end
			end
			for _, box in ipairs(self.Tabboxes or {}) do
				if box.Destroy then pcall(box.Destroy, box) end
			end
			for i = #(self.SubTabList or {}), 1, -1 do
				local sub = self.SubTabList[i]
				if sub and not sub.Destroyed and sub.Destroy then
					pcall(sub.Destroy, sub)
				end
			end
			if self.ParentTab then
				local parent = self.ParentTab
				for i, sub in ipairs(parent.SubTabList or {}) do
					if sub == self then
						table.remove(parent.SubTabList, i)
						break
					end
				end
				if parent.ActiveSubTab == self then
					parent.ActiveSubTab = nil
				end
			end
			for i, other in ipairs(Window.Tabs) do
				if other == self then
					table.remove(Window.Tabs, i)
					break
				end
			end
			Window.Tabs[tostring(self.Name)] = nil
			if Window.ActiveTab == self then
				Window.ActiveTab = nil
				for _, other in ipairs(Window.Tabs) do
					if other.Button and other.Button.Visible and other.Show then
						other:Show()
						break
					end
				end
			end
			if self.Page then safeDestroy(self.Page) end
			if self.Button then safeDestroy(self.Button) end
		end

		function tab:Show()
			local closeDropdown = selfLib._OpenDropdownCloser or selfLib._OpenDropdown
			if closeDropdown then
				pcall(closeDropdown)
			end
			if selfLib._OpenColorPickerCloser then
				pcall(selfLib._OpenColorPickerCloser)
			end

			local pagesContainer = Window.Pages

			if pagesContainer then
				for _, child in ipairs(pagesContainer:GetChildren()) do
					if child:IsA("GuiObject") then
						child.Visible = false
					end
				end
			end

			local previousTab = Window.ActiveTab
			for _, other in ipairs(Window.Tabs) do
				if type(other) == "table" then
					if other.Page and other.Page:IsA("GuiObject") then
						other.Page.Visible = false
					end
					if other.Button and other.Button:IsA("GuiObject") then
						other.Button.BackgroundColor3 = selfLib.Theme.SurfaceAlt
						local ind = other.Button:FindFirstChild("Indicator")
						if ind then
							ind.Visible = false
						end
					end
				end
			end

			if self.Page then
				if pagesContainer and self.Page.Parent ~= pagesContainer then
					self.Page.Parent = pagesContainer
				end
				self.Page.Visible = true
				self.Page.ZIndex = 2

				if self._swipeTween then
					self._swipeTween:Cancel()
					self._swipeTween = nil
				end
				self.Page.Position = UDim2.new()
				if selfLib.Animations.TabSwitch and previousTab and previousTab ~= self and pagesContainer then
					local off = selfLib.TabSwipeOffset
					local dir = selfLib.TabSwipeFrom
					local from = UDim2.fromOffset(0, off)
					if dir == "top" then
						from = UDim2.fromOffset(0, -off)
					elseif dir == "left" then
						from = UDim2.fromOffset(-off, 0)
					elseif dir == "right" then
						from = UDim2.fromOffset(off, 0)
					end
					pagesContainer.ClipsDescendants = true
					self.Page.Position = from
					self._swipeTween = TweenService:Create(
						self.Page,
						TweenInfo.new(selfLib.TabTransitionTime, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
						{ Position = UDim2.new() }
					)
					self._swipeTween:Play()
				end
			end
			if self.Button then
				self.Button.BackgroundColor3 = selfLib.Theme.AccentDark
				local ind = self.Button:FindFirstChild("Indicator")
				if ind then
					ind.Visible = true
				end
			end

			Window.ActiveTab = self
			selfLib.ActiveTab = self
			self:UpdateTabInfo()
			-- Re-apply an active search to the newly selected tab.
			if selfLib.Searching then
				selfLib:UpdateSearch(selfLib.SearchText)
			end
		end

		function tab:AddGroupbox(info)
			if self.SubTabs == true then
				error("[PESUI] AddGroupbox is not available on a tab with SubTabs = true; use AddSubTab first")
			end
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
			-- SaveManager looks groupboxes up by string name
			-- (Tab.Groupboxes["Configuration"]).
			if info.Name ~= nil and info.Name ~= "" then
				self.Groupboxes[tostring(info.Name)] = box
			end
			return box
		end

		function tab:AddLeftGroupbox(name, iconName, visible, collapsed, disableCollapsing)
			return self:AddGroupbox({
				Side = 1, Name = name, IconName = iconName,
				Visible = visible ~= false,
				Collapsed = collapsed == true,
				DisableCollapsing = disableCollapsing == true,
			})
		end
		function tab:AddRightGroupbox(name, iconName, visible, collapsed, disableCollapsing)
			return self:AddGroupbox({
				Side = 2, Name = name, IconName = iconName,
				Visible = visible ~= false,
				Collapsed = collapsed == true,
				DisableCollapsing = disableCollapsing == true,
			})
		end
		function tab:AddLeftTabbox(name)
			return self:AddTabbox({ Side = 1, Name = name })
		end
		function tab:AddRightTabbox(name)
			return self:AddTabbox({ Side = 2, Name = name })
		end

		function tab:AddTabbox(info)
			if self.SubTabs == true then
				error("[PESUI] AddTabbox is not available on a tab with SubTabs = true; use AddSubTab first")
			end
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

			local container = create("ScrollingFrame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = selfLib.Theme.Outline,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = host.Holder,
			})

			local tabbox = {
				Host = host,
				Tabs = {},
				Active = nil,
				DependencyBoxes = {},
				Elements = {},
				MaxHeight = tonumber(info.MaxHeight),
				MaxPopOutHeight = tonumber(info.MaxPopOutHeight),
				PopOutWidth = tonumber(info.PopOutWidth),
				PoppedOut = false,
				PopOutEnabled = true,
			}
			function tabbox:UpdateCorners() end
			function tabbox:Resize()
				if self.Active and self.Active.Resize then
					self.Active:Resize()
				end
			end
			function tabbox:SetMaxHeight(h)
				self.MaxHeight = tonumber(h) or nil
				self:Resize()
			end
			function tabbox:Destroy()
				if self.Destroyed then return end
				self.Destroyed = true
				if self.PopOutFloat then safeDestroy(self.PopOutFloat) end
				for _, t in ipairs(self.Tabs) do
					if t.Destroy then pcall(t.Destroy, t) end
				end
				if host and host.Destroy then
					pcall(function() host:Destroy() end)
				end
			end

			function tabbox:AddTab(name, icon, maxHeight)
				local page = create("Frame", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Visible = false,
					Parent = container,
				})
				local list = create("UIListLayout", {
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

				if createIconInstance(icon, {
					Name = "IconImage",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromOffset(4, 0),
					Size = UDim2.fromOffset(14, 14),
					BackgroundTransparency = 1,
					Parent = btn,
				}) then
					btn.Text = name == nil and "  " or ("      " .. tostring(name) .. "  ")
				end

				local nested = {
					Name = name,
					Icon = icon,
					Holder = page,
					Button = btn,
					MaxHeight = tonumber(maxHeight),
					TabboxParent = tabbox,
				}
				attachGroupboxMethods(nested)
				function nested:Resize()
					local maxH = self.MaxHeight or tabbox.MaxHeight
					if not self.Page then return end
					if maxH then
						self.Page.AutomaticSize = Enum.AutomaticSize.None
						self.Page.Size = UDim2.new(1, 0, 0, maxH)
						container.AutomaticSize = Enum.AutomaticSize.None
						container.Size = UDim2.new(1, 0, 0, maxH + 6)
						container.CanvasSize = UDim2.new(0, 0, 0, math.max(maxH + 6, list.AbsoluteContentSize.Y + 6))
					else
						self.Page.AutomaticSize = Enum.AutomaticSize.Y
						self.Page.Size = UDim2.new(1, 0, 0, 0)
						container.AutomaticSize = Enum.AutomaticSize.Y
						container.Size = UDim2.new(1, 0, 0, 0)
					end
				end
				function nested:SetMaxHeight(h)
					self.MaxHeight = tonumber(h) or nil
					self:Resize()
				end

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
				function nested:AddTextbox(...)
					return host.AddTextbox({ Holder = page }, ...)
				end
				function nested:AddCheckbox(...)
					return host.AddCheckbox({ Holder = page }, ...)
				end
				function nested:AddViewport(...)
					return host.AddViewport({ Holder = page }, ...)
				end
				function nested:AddImage(...)
					return host.AddImage({ Holder = page }, ...)
				end
				function nested:AddVideo(...)
					return host.AddVideo({ Holder = page }, ...)
				end
				function nested:AddUIPassthrough(...)
					return host.AddUIPassthrough({ Holder = page }, ...)
				end
				function nested:AddSettings(...)
					return host.AddSettings({ Holder = page }, ...)
				end
				function nested:AddDependencyBox()
					return host.AddDependencyBox({ Holder = page })
				end
				function nested:AddDependencyGroupbox()
					return host.AddDependencyGroupbox({ Holder = page })
				end

				local function showThis()
					for _, t in ipairs(tabbox.Tabs) do
						t.Page.Visible = false
						t.Button.BackgroundColor3 = selfLib.Theme.SurfaceAlt
					end
					page.Visible = true
					btn.BackgroundColor3 = selfLib.Theme.AccentDark
					tabbox.Active = nested
					nested:Resize()
				end

				btn.MouseButton1Click:Connect(showThis)

				nested.Page = page
				nested.Show = showThis
				nested.Hide = function() page.Visible = false end
				nested.Destroy = function()
					safeDestroy(btn)
					safeDestroy(page)
				end
				function nested:SetName(newName)
					self.Name = newName
					btn.Text = "  " .. tostring(newName or "Tab") .. "  "
				end
				function nested:SetIcon(newIcon)
					self.Icon = newIcon
					local existing = btn:FindFirstChild("IconImage")
					if existing then safeDestroy(existing) end
					if createIconInstance(newIcon, {
						Name = "IconImage",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.fromOffset(4, 0),
						Size = UDim2.fromOffset(14, 14),
						BackgroundTransparency = 1,
						Parent = btn,
					}) then
						btn.Text = "      " .. tostring(self.Name or "Tab") .. "  "
					else
						btn.Text = "  " .. tostring(self.Name or "Tab") .. "  "
					end
				end
				list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
					if tabbox.Active == nested and not tabbox.Destroyed then
						nested:Resize()
					end
				end)
				table.insert(tabbox.Tabs, nested)
				tabbox.Tabs[tostring(name)] = nested
				if #tabbox.Tabs == 1 then
					showThis()
				end
				nested:Resize()
				return nested
			end

			-- Pop-out support mirrors the Obsidian tabbox contract so the
			-- addons and user code can call the same methods as groupboxes.
			local function attachPopOut(box, width, maxHeight)
				box.PoppedOut = false
				box.PopOutEnabled = info.PopOut ~= false
				box.PopOutWidth = width
				box.MaxPopOutHeight = maxHeight
				function box:SetPoppedOut(v, position)
					if not self.PopOutEnabled or self.Destroyed then return end
					local value = v == true
					if self.PoppedOut == value then
						if value and position and self.PopOutFloat then
							self.PopOutFloat.Position = position
						end
						return
					end
					self.PoppedOut = value
					if self.PoppedOut then
						if not self.PopOutFloat or not self.PopOutFloat.Parent then
							local float = create("Frame", {
								Name = "TabboxPopOutFloat",
								Size = UDim2.fromOffset(self.PopOutWidth or 300, self.MaxPopOutHeight or 0),
								AutomaticSize = self.MaxPopOutHeight and Enum.AutomaticSize.X or Enum.AutomaticSize.Y,
								BackgroundColor3 = selfLib.Theme.Surface,
								BorderSizePixel = 0,
								ZIndex = 6000,
								Position = position or UDim2.fromOffset(120, 120),
								Parent = selfLib.OverlayFrame or selfLib.ScreenGui,
							})
							addCorner(float, selfLib.Theme.CornerRadius)
							addStroke(float, selfLib.Theme.Outline)
							local title = create("TextLabel", {
								Name = "Title",
								Size = UDim2.new(1, -32, 0, 24),
								Position = UDim2.fromOffset(8, 4),
								BackgroundTransparency = 1,
								Font = selfLib.Theme.Font,
								TextSize = 14,
								TextXAlignment = Enum.TextXAlignment.Left,
								TextColor3 = selfLib.Theme.Text,
								Text = tostring(self.Name or "Tabbox"),
								Parent = float,
							})
							local close = create("TextButton", {
								Name = "Close",
								AnchorPoint = Vector2.new(1, 0),
								Position = UDim2.new(1, -4, 0, 4),
								Size = UDim2.fromOffset(22, 22),
								BackgroundColor3 = selfLib.Theme.SurfaceAlt,
								BorderSizePixel = 0,
								Font = selfLib.Theme.Font,
								TextSize = 14,
								TextColor3 = selfLib.Theme.Text,
								Text = "×",
								Parent = float,
							})
							addCorner(close, 4)
							addStroke(close, selfLib.Theme.Outline)
							close.MouseButton1Click:Connect(function()
								self:SetPoppedOut(false)
							end)
							local body = create("Frame", {
								Name = "Body",
								Position = UDim2.fromOffset(8, 32),
								Size = UDim2.new(1, -16, 1, -40),
								BackgroundTransparency = 1,
								Parent = float,
							})
							self.PopOutTitle = title
							self.PopOutFloat = float
							self._PopOutOriginalParent = host.Holder
							self._PopOutOriginalOrder = container.LayoutOrder
							tabStrip.Parent = body
							container.Parent = body
							makeDraggable(float, float)
						end
					elseif self.PopOutFloat then
						safeDestroy(self.PopOutFloat)
						self.PopOutFloat = nil
						tabStrip.Parent = host.Holder
						container.Parent = host.Holder
						container.LayoutOrder = self._PopOutOriginalOrder or 0
					end
				end
				function box:TogglePoppedOut()
					self:SetPoppedOut(not self.PoppedOut)
				end
				function box:SetMaxPopOutHeight(h)
					self.MaxPopOutHeight = tonumber(h) or nil
					if self.PoppedOut and self.PopOutFloat then
						self.PopOutFloat.AutomaticSize = self.MaxPopOutHeight and Enum.AutomaticSize.X or Enum.AutomaticSize.Y
						self.PopOutFloat.Size = UDim2.fromOffset(self.PopOutWidth or 300, self.MaxPopOutHeight or 0)
					end
				end
				function box:SetPopOutWidth(w)
					self.PopOutWidth = tonumber(w) or nil
					if self.PopOutFloat then
						self.PopOutFloat.Size = UDim2.fromOffset(self.PopOutWidth or 300, self.PopOutFloat.Size.Y.Offset)
					end
				end
			end
			attachPopOut(tabbox, tabbox.PopOutWidth, tabbox.MaxPopOutHeight)
			if info.PopOut then
				tabbox:SetPoppedOut(true)
			end

			if info.Name ~= nil and info.Name ~= "" then
				self.Tabboxes[tostring(info.Name)] = tabbox
			end
			return tabbox
		end
		addTabboxImpl = tab.AddTabbox
	end

	function Window:AddTab(arg1, arg2, arg3, arg4)
		local name, icon, description, configOrder, tooltip, useSubTabs
		if type(arg1) == "table" then
			name = arg1.Name or "Tab"
			icon = arg1.Icon or arg1.IconName
			description = arg1.Description
			configOrder = arg1.Order
			tooltip = arg1.Tooltip
			useSubTabs = arg1.SubTabs == true
		else
			name = arg1 or "Tab"
			icon = arg2
			description = arg3
			configOrder = arg4
		end

		local order = tonumber(configOrder) or (#self.Tabs + 1)
		local button, buttonLabel = createTabButton(name, icon, order)
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
			Tabboxes = {},
			Window = Window,
			Order = order,
			Tooltip = tooltip,
			SubTabs = useSubTabs,
		}

		attachTabMethods(tab)
		if tooltip then
			tab:SetTooltip(tooltip)
		end

		button.MouseButton1Click:Connect(function()
			if tab and tab.Show then
				tab:Show()
			end
		end)

		table.insert(self.Tabs, tab)
		self.Tabs[name] = tab
		if #self.Tabs == 1 or Window.ActiveTab == nil then
			tab:Show()
		end
		return tab
	end

	function Window:AddKeyTab(...)
		local tab = self:AddTab(...)
		-- Key tabs accept groupbox/tabbox methods directly, so forward the
		-- element builders to one full-width host groupbox.
		local host = tab:AddGroupbox({ Side = 1, Name = "KeyTabContent", IconName = "key" })
		tab.KeyBox = host
		for _, method in ipairs({
			"AddDivider", "AddLabel", "AddButton", "AddToggle", "AddSlider",
			"AddInput", "AddTextbox", "AddDropdown", "AddKeyPicker",
			"AddColorPicker", "AddCheckbox", "AddViewport", "AddImage",
			"AddVideo", "AddUIPassthrough", "AddSettings",
			"AddTabbox", "AddDependencyBox", "AddDependencyGroupbox",
		}) do
			tab[method] = function(_, ...)
				local fn = host[method]
				if fn then
					return fn(host, ...)
				end
			end
		end
		function tab:AddKeyBox(callback)
			local input = host:AddInput("KeyInput_" .. HttpService:GenerateGUID(false), {
				Text = "Key",
				Default = "",
				Placeholder = "Enter key...",
				Finished = true,
			})
			host:AddButton("Submit", function()
				selfLib:SafeCallback(callback, input.Value)
			end)
			return input
		end
		return tab
	end

	toggleButton.MouseButton1Click:Connect(function()
		Window:Toggle()
	end)

	if not selfLib.KeybindFrame then
		selfLib.KeybindFrame = create("Frame", {
			Name = "KeybindFrame",
			Size = UDim2.fromOffset(220, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(20, 20),
			BackgroundColor3 = selfLib.Theme.Surface,
			BorderSizePixel = 0,
			Visible = false,
			Parent = screenGui,
		})
		create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
			Parent = selfLib.KeybindFrame,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 2),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = selfLib.KeybindFrame,
		})
		create("TextLabel", {
			Name = "KeybindTitle",
			LayoutOrder = 0,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			Font = selfLib.Theme.Font,
			TextSize = 14,
			TextColor3 = selfLib.Theme.SubText,
			Text = "Keybinds",
			Parent = selfLib.KeybindFrame,
		})
	end
	addCorner(selfLib.KeybindFrame, selfLib.Theme.CornerRadius)
	addStroke(selfLib.KeybindFrame, selfLib.Theme.Outline)

	-- Obsidian addons (SaveManager) reach the keybind panel through
	-- Library.KeybindMenu. It exposes SettingsFrame, Collapsed,
	-- SetCollapsed() and SetSettingsOpen(). The real rows are rebuilt by
	-- _RefreshKeybindList() below, so collapsed simply toggles their
	-- visibility instead of destroying anything.
	if not selfLib.KeybindMenu then
		local settingsFrame = create("Frame", {
			Name = "SettingsFrame",
			Size = UDim2.fromOffset(240, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Position = UDim2.fromOffset(252, 20),
			BackgroundColor3 = selfLib.Theme.Surface,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 4000,
			Parent = screenGui,
		})
		addCorner(settingsFrame, selfLib.Theme.CornerRadius)
		addStroke(settingsFrame, selfLib.Theme.Outline)
		addPadding(settingsFrame, 8)

		local keybindMenu = {
			Frame = selfLib.KeybindFrame,
			SettingsFrame = settingsFrame,
			Collapsed = false,
		}
		function keybindMenu:SetCollapsed(state)
			self.Collapsed = state and true or false
			for _, child in ipairs(selfLib.KeybindFrame:GetChildren()) do
				if child.Name == "KeybindRow" then
					child.Visible = not self.Collapsed
				end
			end
		end
		function keybindMenu:SetSettingsOpen(open)
			settingsFrame.Visible = open and true or false
		end
		function keybindMenu:ToggleSettings()
			self:SetSettingsOpen(not settingsFrame.Visible)
		end
		function keybindMenu:RefreshSettings() end
		function keybindMenu:SetVisibilityControl(enabled) end
		function keybindMenu:Update() end
		function keybindMenu:SetVisible(state)
			selfLib:SetKeybindListVisible(state)
		end
		function keybindMenu:Toggle()
			selfLib:SetKeybindListVisible(not selfLib.KeybindFrame.Visible)
		end
		selfLib.KeybindMenu = keybindMenu
	end

	-- SaveManager restores this toggle when loading a config; keeping it in
	-- Options makes the keybind list's open state round-trip automatically.
	if not selfLib.Options.KeybindMenuOpen then
		local kmToggle = createOptionObject("Toggle", "KeybindMenuOpen", { Value = false })
		kmToggle.Type = "Toggle"
		kmToggle.Text = "Keybind menu"
		function kmToggle:SetValue(value)
			self.Value = value and true or false
			selfLib:SetKeybindListVisible(self.Value)
			self:RunChanged()
		end
		function kmToggle:RunChanged()
			for _, cb in ipairs(self.ChangedCallbacks or {}) do
				selfLib:SafeCallback(cb, self.Value)
			end
			if type(self.Changed) == "function" then
				selfLib:SafeCallback(self.Changed, self.Value)
			end
		end
		selfLib.Options.KeybindMenuOpen = kmToggle
	end

	-- rebuilds the rows of the keybind list from every registered KeyPicker
	function selfLib:_RefreshKeybindList()
		local frame = self.KeybindFrame
		if not frame or not frame.Parent then
			return
		end
		for _, child in ipairs(frame:GetChildren()) do
			if child.Name == "KeybindRow" then
				child:Destroy()
			end
		end
		local n = 0
		for _, kp in ipairs(self.KeyPickers or {}) do
			if not kp.NoUI and kp.MenuVisible ~= false and not kp.Destroyed and tostring(kp.Value) ~= "None" and tostring(kp.Value) ~= "" then
				n += 1
				create("TextLabel", {
					Name = "KeybindRow",
					LayoutOrder = n,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 16),
					Font = self.Theme.Font,
					TextSize = 13,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextColor3 = kp:GetState() and self.Theme.Accent or self.Theme.SubText,
					Text = string.format("[%s] %s (%s)", kp:GetDisplayText(), kp.DisplayName or tostring(kp.Idx), tostring(kp.Mode)),
					Visible = not (self.KeybindMenu and self.KeybindMenu.Collapsed),
					Parent = frame,
				})
			end
		end
	end

	function selfLib:SetKeybindListVisible(state)
		if self.KeybindFrame then
			self.KeybindFrame.Visible = state and true or false
		end
	end
	selfLib:_RefreshKeybindList()
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
		-- a keybind is being (re)bound right now: don't treat that key as the menu key
		if selfLib._ListeningKey then
			return
		end
		local tk = getToggleKey()
		if tk and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == tk then
			Window:Toggle()
			return
		end
		if gpe then
			return
		end
	end)

	-- floating buttons for touch devices: show/hide the window, lock dragging
	local showMobile = config.ShowMobileButtons
	if showMobile == nil then
		showMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	end
	if showMobile then
		local onRight = config.MobileButtonsSide == "Right"
		local holder = create("Frame", {
			Name = "MobileButtons",
			AnchorPoint = Vector2.new(onRight and 1 or 0, 0.5),
			Position = UDim2.new(onRight and 1 or 0, onRight and -10 or 10, 0.5, 0),
			Size = UDim2.fromOffset(52, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			ZIndex = 7000,
			Parent = screenGui,
		})
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = holder,
		})
		local function mobileButton(text, order, onClick)
			local btn = create("TextButton", {
				LayoutOrder = order,
				Size = UDim2.fromOffset(52, 34),
				BackgroundColor3 = selfLib.Theme.Surface,
				BorderSizePixel = 0,
				AutoButtonColor = false,
				Font = selfLib.Theme.Font,
				TextSize = 13,
				TextColor3 = selfLib.Theme.Text,
				Text = text,
				ZIndex = 7001,
				Parent = holder,
			})
			addCorner(btn, selfLib.Theme.CornerRadius)
			addStroke(btn, selfLib.Theme.Outline)
			btn.MouseButton1Click:Connect(function()
				onClick(btn)
			end)
			return btn
		end
		mobileButton("Menu", 1, function()
			Window:Toggle()
		end)
		mobileButton("Lock", 2, function(btn)
			Library.DragLocked = not Library.DragLocked
			btn.Text = Library.DragLocked and "Unlock" or "Lock"
			btn.TextColor3 = Library.DragLocked and selfLib.Theme.Accent or selfLib.Theme.Text
		end)
	end

	applySidebar()

	if config.AutoShow == false or (selfLib.ActiveLoading and not selfLib.ActiveLoading.Destroyed) then
		main.Visible = false
		Window.Visible = false
		if selfLib.ActiveLoading then
			selfLib.ActiveLoading._RestoreWindow = true
		end
	end

	selfLib.ActiveWindow = Window
	-- Obsidian addons grab the window and the tab registry straight off the
	-- Library (Library.Window:AddDialog(...), Library.Tabs[tabIdx]).
	selfLib.Window = Window
	selfLib.Tabs = Window.Tabs
	return Window
end

return Library
