-- SPDX-License-Identifier: GPL-3.0-or-later
-- Run from the repository root with a Lua 5.1-compatible interpreter.
local source = (arg and arg[1]) or 'SecureTabs-2.0.lua'
local passed = 0

local function equal(actual, expected)
	assert(actual == expected, 'Expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end

local function setup(style, registry, path, retail, arrayOnly, projectID)
	local state = {created = {}, hooks = {}, sounds = 0}
	local lib = {}
	local env = setmetatable({
		WOW_PROJECT_ID = projectID or (retail and 1 or 2), WOW_PROJECT_MAINLINE = 1,
		tinsert = table.insert, SOUNDKIT = {IG_CHARACTER_INFO_TAB = 1},
		PlaySound = function() state.sounds = state.sounds + 1 end,
		CallErrorHandler = function(err) error(err) end,
		xpcall = function(fn, _, ...) return pcall(fn, ...) end,
	}, {__index = _G})
	env._G = env
	env.LibStub = {NewLibrary = function(_, name, version)
		equal(name, 'SecureTabs-2.0')
		state.version = version
		return lib
	end}
	env.hooksecurefunc = function(name, callback) state.hooks[name] = callback end
	local templates = {PanelTabButtonTemplate = true}
	if style == 'legacy' then templates.CharacterFrameTabButtonTemplate = true end
	if registry == 'full' then
		env.C_XMLUtil = {GetTemplateInfo = function(name) return templates[name] and {type = 'Button'} end}
	elseif registry == 'empty' then
		env.C_XMLUtil = {}
	end
	local function texture()
		return {SetShown = function(self, shown) self.shown = not not shown end}
	end
	local function frame(name, parent)
		local f = {name = name, parent = parent, level = 10, enabled = true}
		function f:GetName() return self.name end
		function f:GetParent() return self.parent end
		function f:SetParent(newParent) self.parent = newParent end
		function f:GetFrameLevel() return self.level end
		function f:SetFrameLevel(level) self.level = level end
		function f:SetPoint(...) self.anchor = {...} end
		function f:SetScript(event, callback) self[event] = callback end
		function f:SetText(text) self.text = text end
		function f:GetText() return self.text end
		function f:SetShown(shown) self.shown = not not shown end
		function f:SetAllPoints(target) self.allPoints = target end
		function f:IsEnabled() return self.enabled end
		function f:EnableMouse(enabled) self.mouse = enabled end
		if style == 'modern' then
			f.LeftActive, f.MiddleActive, f.RightActive = texture(), texture(), texture()
		elseif name then
			env[name .. 'LeftDisabled'] = texture()
			env[name .. 'MiddleDisabled'] = texture()
			env[name .. 'RightDisabled'] = texture()
		end
		if name then env[name] = f end
		return f
	end
	env.CreateFrame = function(kind, name, parent, template)
		assert(templates[template], "CreateFrame(): Couldn't find inherited node '" .. template .. "'")
		local f = frame(name:gsub('%$parent', parent:GetName()), parent)
		f.template = template
		if template == 'PanelTabButtonTemplate' then
			parent.Tabs = parent.Tabs or {}
			table.insert(parent.Tabs, f)
		end
		table.insert(state.created, f)
		return f
	end
	env.PanelTemplates_DeselectTab = function(tab) tab.enabled = true end
	env.PanelTemplates_SelectTab = function(tab) tab.enabled = false end
	env.PanelTemplates_TabResize = function(tab, ...) tab.resize = {...} end
	local panel = frame('MerchantFrame')
	panel.numTabs, panel.selectedTab, panel.maxTabWidth = 2, 1, 88
	panel.CloseButton = frame('MerchantFrameCloseButton', panel)
	local nativeTabs = {
		frame(not arrayOnly and 'MerchantFrameTab1' or nil, panel),
		frame(not arrayOnly and 'MerchantFrameTab2' or nil, panel),
	}
	nativeTabs[1]:SetText('Merchant')
	nativeTabs[2]:SetText('Buyback')
	if style == 'modern' then panel.Tabs = nativeTabs end
	local overlay = frame('ScrapVisualizer', panel)
	overlay.CloseButton = frame('ScrapVisualizerCloseButton', overlay)
	setfenv(assert(loadfile(path or source)), env)()
	return env, lib, state, panel, nativeTabs, overlay
end

local function test(name, fn)
	fn()
	passed = passed + 1
	print('PASS: ' .. name)
end

test('Regression: opening Scrap on WoW Forever without the legacy tab template', function()
	-- The reported Classic beta uses project ID 18 and has only the modern template.
	local env, lib, state, panel, nativeTabs, overlay = setup('modern', 'full', nil, false, false, 18)
	equal(env.C_XMLUtil.GetTemplateInfo('CharacterFrameTabButtonTemplate'), nil)
	assert(env.C_XMLUtil.GetTemplateInfo('PanelTabButtonTemplate'))

	-- This call raised "Couldn't find inherited node 'CharacterFrameTabButtonTemplate'".
	local tab = lib:Add(panel, overlay, 'Scrap')
	equal(#state.created, 2)
	equal(tab.template, 'PanelTabButtonTemplate')
	equal(lib.covers[panel].template, 'PanelTabButtonTemplate')

	-- Opening and closing Scrap must leave the native merchant tab usable.
	tab.OnClick(tab)
	equal(overlay.shown, true)
	equal(tab.enabled, false)
	equal(lib.covers[panel].shown, true)
	equal(lib.covers[panel].parent, nativeTabs[1])
	equal(nativeTabs[1].LeftActive.shown, false)
	lib.covers[panel].OnClick()
	equal(overlay.shown, false)
	equal(tab.enabled, true)
	equal(lib.covers[panel].shown, false)
	equal(nativeTabs[1].LeftActive.shown, true)
end)

test('Classic beta uses available template for tab and cover with modern spacing', function()
	local _, lib, state, panel, nativeTabs = setup('modern', 'full')
	local tab = lib:Add(panel, nil, 'Scrap')
	equal(state.version, 16)
	equal(#state.created, 2)
	equal(tab.template, 'PanelTabButtonTemplate')
	equal(lib.covers[panel].template, 'PanelTabButtonTemplate')
	equal(tab.anchor[2], nativeTabs[2])
	equal(tab.anchor[4], 3)
	equal(tab.text, 'Scrap')
	equal(panel.numTabs, 2)
end)

test('Array-only native tabs can be selected without global frame names', function()
	local _, lib, _, panel, nativeTabs, overlay = setup('modern', 'full', nil, false, true)
	local tab = lib:Add(panel, overlay, 'Scrap')
	equal(tab.anchor[2], nativeTabs[2])
	lib:Select(tab)
	equal(overlay.shown, true)
	equal(overlay.parent, panel)
	equal(overlay.mouse, true)
	equal(tab.enabled, false)
	equal(lib.covers[panel].shown, true)
	equal(lib.covers[panel].parent, nativeTabs[1])
	equal(nativeTabs[1].LeftActive.shown, false)
	lib.covers[panel].OnClick()
	equal(overlay.shown, false)
	equal(tab.enabled, true)
	equal(lib.covers[panel].shown, false)
	equal(nativeTabs[1].LeftActive.shown, true)
end)

test('Second addon tab anchors to the previous secure tab and reuses the cover', function()
	local _, lib, state, panel = setup('modern', 'full')
	local first = lib:Add(panel, nil, 'Scrap')
	local second = lib:Add(panel, nil, 'Second')
	equal(second.anchor[2], first)
	equal(second.name, 'MerchantFrameSecureTab1')
	equal(#state.created, 3)
end)

test('Native tab changes restore the merchant panel', function()
	local _, lib, state, panel, nativeTabs, overlay = setup('modern', 'full')
	local tab = lib:Add(panel, overlay, 'Scrap')
	lib:Select(tab)
	panel.selectedTab = 2
	state.hooks.PanelTemplates_SetTab(panel, 2)
	equal(overlay.shown, false)
	equal(lib.covers[panel].shown, false)
	equal(nativeTabs[2].LeftActive.shown, true)
end)

for _, registry in ipairs({'full', 'none', 'empty'}) do
	test('Older Classic preserves legacy template and spacing with registry ' .. registry, function()
		local env, lib, _, panel, nativeTabs, overlay = setup('legacy', registry)
		local tab = lib:Add(panel, overlay, 'Scrap')
		equal(tab.template, 'CharacterFrameTabButtonTemplate')
		equal(tab.anchor[4], -16)
		equal(tab.anchor[2], nativeTabs[2])
		lib:Select(tab)
		equal(overlay.shown, true)
		equal(env.MerchantFrameTab1LeftDisabled.shown, false)
		lib:Update(panel)
		equal(env.MerchantFrameTab1LeftDisabled.shown, true)
	end)
end

test('Retail still selects modern tabs without needing the template registry', function()
	local _, lib, _, panel = setup('modern', 'none', nil, true)
	local tab = lib:Add(panel, nil, 'Scrap')
	equal(tab.template, 'PanelTabButtonTemplate')
	equal(tab.anchor[4], 3)
end)

print(string.format('All %d tab compatibility checks passed.', passed))
