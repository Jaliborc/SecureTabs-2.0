--[[
Copyright 2013 João Cardoso
SecureTabs is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of SecureTabs.

SecureTabs is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

SecureTabs is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with SecureTabs. If not, see <http://www.gnu.org/licenses/>.
--]]

local Lib, Old = LibStub:NewLibrary('SecureTabs-1.0', 3)
if not Lib then
	return
elseif not Old then
	hooksecurefunc('PanelTemplates_SetTab', function(parent)
		Lib:Update(parent)
	end)
end

function Lib:Startup(parent, ...)
	if parent.secureTabs then
		return
	end

	local secure = CreateFrame('Frame', '$parentSecureTabs', parent, 'SecureHandlerAttributeTemplate')
	for i = 1, select('#', ...) do
		secure:SetFrameRef('panel' .. i, select(i, ...))
	end

	secure:SetAttribute('_onattributechanged', [[
		if name == 'selected' then
			for i = 1, self:GetAttribute('numTabs') do
				local panel = self:GetFrameRef('panel' .. i)
				if panel then
					if i == value then
						panel:Show()
					else
						panel:Hide()
					end
				end
			end
		end
	]])

	parent.secureTabs = secure
end

function Lib:Add(parent, panel, label)
	local id = (parent.numTabs or 0) + 1
	local tab = CreateFrame('Button', '$parentTab' .. id, parent, 'CharacterFrameTabButtonTemplate', id)
	tab:SetText(label)
	tab:SetScript('OnClick', function(self)
		PanelTemplates_SetTab(parent, id)
	end)

	if id > 1 then
		tab:SetPoint('LEFT', parent:GetName() .. 'Tab' .. parent.numTabs, 'RIGHT', -16, 0)
	else
		tab:SetPoint('TOPLEFT', parent, 'BOTTOMLEFT', 11, 2)
	end

	parent.numTabs = id
	parent.secureTabs:SetFrameRef('panel' .. id, panel)
	parent.secureTabs:SetAttribute('numTabs', parent.numTabs)
	PanelTemplates_UpdateTabs(parent)

	return tab
end

function Lib:Update(parent)
	if parent.secureTabs then
		parent.secureTabs:SetAttribute('selected', parent.selectedTab)
	end
end