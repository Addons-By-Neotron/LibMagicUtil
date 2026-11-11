--[[
**********************************************************************
LibMagicUtil-1.0 is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

LibMagicUtil is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with LibMagicUtil.  If not, see <http://www.gnu.org/licenses/>.
**********************************************************************

To use this addon, embed it in your addon using the normal Ace-method
or manually like this:

  LibStub("LibMagicUtil-1.0"):Embed(MyAddon)

After embedding you will be able to use the following methods:

]]

local MAJOR = "LibMagicUtil-1.0"
local packagedMinor = tonumber("@project-date-integer@")
local MINOR = packagedMinor or tonumber(date("%Y%m%d%H%M%S"))
-- Standalone addon sets this flag via bootstrap.lua (loaded from .toc before lib.xml).
-- Embedded copies don't run bootstrap.lua, so the flag is nil for them.
-- Bumping MINOR ensures the standalone copy always wins over embedded copies.
if LIBMAGICUTIL_STANDALONE then
    -- In a dev checkout the placeholder isn't replaced and MINOR is the load
    -- time, so embedded copies loaded later (even by a second) would win.
    -- Add a year (the YYYY digits are the 1e10 place) so the standalone always wins.
    MINOR = MINOR + (packagedMinor and 1 or 10000000000)
end
local lib = LibStub:NewLibrary(MAJOR, MINOR)
local media = LibStub("LibSharedMedia-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("LibMagicUtil-1.0", false)

if not lib then return end

local embeddables = {
   "GetConfigTemplate", "_GetColorOpt", "_SetColorOpt", "_SetOption", "_GetOption",
   "_HideOption", "_DisableTiling", "FixBackdrop", "_SetBackgroundOption",
   "InterfaceOptions_AddCategory", "InterfaceOptionsFrame_OpenToCategory", "Dump",
   "GetSpellInfo", "UnitAura", "GetMailFrame",
   "StyleDialog", "CreateDialogWindow", "CreateDialogButton", "ShowConfirmDialog", "IsConfirmDialogShown"
}

lib.optionTemplates = lib.optionTemplates or {}
lib.embeddedAddons = lib.embeddedAddons or {}

local optionTemplates = lib.optionTemplates
local embeddedAddons = lib.embeddedAddons

lib.GetSpellInfo = GetSpellInfo or function(id)
    local spellInfo = C_Spell.GetSpellInfo(id)
    if spellInfo then
        -- Returning the values in the same order as the original GetSpellInfo
        return spellInfo.name, nil, spellInfo.iconID, spellInfo.castTime, spellInfo.minRange, spellInfo.maxRange, spellInfo.spellID, spellInfo.originalIconID
    else
        -- If the spell is not found, return nil
        return nil
    end
end

lib.UnitAura = UnitAura or function(unit, index, filter)
    local aura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex(unit, index)
    if not aura then return nil end

    -- Map new API fields to old UnitAura return values
    local name = aura.name
    local icon = aura.icon
    local count = aura.applications or 1
    local debuffType = aura.dispelName
    local duration = aura.duration
    local expirationTime = aura.expirationTime
    local caster = aura.sourceUnit
    local isStealable = aura.isStealable
    local nameplateShowPersonal = aura.nameplateShowPersonal
    local spellId = aura.spellId
    local canApplyAura = aura.canApplyAura
    local isBossDebuff = aura.isBossDebuff
    local isCastByPlayer = aura.isFromPlayerOrPlayerPet
    local nameplateShowAll = aura.nameplateShowAll
    local timeMod = aura.timeMod or 1
    local value1, value2, value3 = aura.points or 0, nil, nil

    return name, icon, count, debuffType, duration, expirationTime, caster,
           isStealable, nameplateShowPersonal, spellId, canApplyAura, isBossDebuff,
           isCastByPlayer, nameplateShowAll, timeMod, value1, value2, value3
  end

------------------------------------------------------------------------
-- Reputation API compat
-- Provides modern C_Reputation-style table APIs on all WoW versions.
-- On retail (11.0+), these are thin pass-throughs.
-- On classic/TBC/MoP, they wrap old tuple-returning globals.
------------------------------------------------------------------------

lib.Reputation = {}
local Rep = lib.Reputation

if C_Reputation and C_Reputation.GetFactionDataByIndex then
    -- Retail 11.0+: modern APIs exist natively
    Rep.GetFactionDataByIndex = C_Reputation.GetFactionDataByIndex
    Rep.GetFactionDataByID = C_Reputation.GetFactionDataByID
    Rep.GetNumFactions = C_Reputation.GetNumFactions
    Rep.ExpandFactionHeader = C_Reputation.ExpandFactionHeader
    Rep.CollapseFactionHeader = C_Reputation.CollapseFactionHeader
    Rep.IsFactionActive = C_Reputation.IsFactionActive
    Rep.SetFactionActive = C_Reputation.SetFactionActive
    -- 12.0: IsFactionParagon changed meaning. IsFactionParagonForCurrentPlayer
    -- is "player is at paragon", IsFactionParagon is "faction supports paragon".
    Rep.IsFactionParagon = C_Reputation.IsFactionParagonForCurrentPlayer or C_Reputation.IsFactionParagon
    Rep.GetFactionParagonInfo = C_Reputation.GetFactionParagonInfo
    Rep.IsMajorFaction = C_Reputation.IsMajorFaction
    Rep.IsAccountWideReputation = C_Reputation.IsAccountWideReputation
else
    -- Classic/TBC/MoP: wrap old globals into modern table format
    Rep.GetNumFactions = GetNumFactions or function() return 0 end

    Rep.GetFactionDataByIndex = function(factionIndex)
        if not factionIndex or not GetFactionInfo then return nil end
        local name, description, standingId, barMin, barMax, barValue,
              atWarWith, canToggleAtWar, isHeader, isCollapsed,
              hasRep, isWatched, isChild, factionID,
              hasBonusRepGain, canSetInactive = GetFactionInfo(factionIndex)
        if not name then return nil end
        return {
            factionID = factionID,
            name = name,
            description = description,
            reaction = standingId,
            currentReactionThreshold = barMin,
            nextReactionThreshold = barMax,
            currentStanding = barValue,
            atWarWith = atWarWith,
            canToggleAtWar = canToggleAtWar,
            isHeader = isHeader,
            isCollapsed = isCollapsed,
            isHeaderWithRep = hasRep,
            isWatched = isWatched,
            isChild = isChild,
            hasBonusRepGain = hasBonusRepGain,
            canSetInactive = canSetInactive,
            isAccountWide = false,
        }
    end

    -- Classic doesn't have GetFactionDataByID; return nil
    Rep.GetFactionDataByID = function(factionID)
        return nil
    end

    Rep.ExpandFactionHeader = ExpandFactionHeader or function() end
    Rep.CollapseFactionHeader = CollapseFactionHeader or function() end

    Rep.IsFactionActive = function(factionIndex)
        if IsFactionInactive then
            return not IsFactionInactive(factionIndex)
        end
        return true
    end

    Rep.SetFactionActive = function(factionIndex, setActive)
        if setActive then
            if SetFactionActive then SetFactionActive(factionIndex) end
        else
            if SetFactionInactive then SetFactionInactive(factionIndex) end
        end
    end

    -- No paragon/major faction on classic
    Rep.IsFactionParagon = function() return false end
    Rep.GetFactionParagonInfo = function() return nil end
    Rep.IsMajorFaction = function() return false end
    Rep.IsAccountWideReputation = function() return false end
end

-- Friendship reputation: C_GossipInfo on retail, global on classic
if C_GossipInfo and C_GossipInfo.GetFriendshipReputation then
    Rep.GetFriendshipReputation = function(factionID)
        if not factionID then return nil end
        local rep = C_GossipInfo.GetFriendshipReputation(factionID)
        if not rep or rep.friendshipFactionID == 0 then return nil end
        return rep
    end
else
    Rep.GetFriendshipReputation = function(factionID)
        if not factionID or not GetFriendshipReputation then return nil end
        local friendshipFactionID, standing, maxRep, name, text,
              texture, reaction, reactionThreshold, nextThreshold,
              reversedColor, overrideColor = GetFriendshipReputation(factionID)
        if not friendshipFactionID or friendshipFactionID == 0 then return nil end
        return {
            friendshipFactionID = friendshipFactionID,
            standing = standing,
            maxRep = maxRep,
            name = name,
            text = text,
            texture = texture,
            reaction = reaction,
            reactionThreshold = reactionThreshold,
            nextThreshold = nextThreshold,
            reversedColor = reversedColor,
            overrideColor = overrideColor,
        }
    end
end

if C_GossipInfo and C_GossipInfo.GetFriendshipReputationRanks then
    Rep.GetFriendshipReputationRanks = function(factionID)
        if not factionID then return nil end
        return C_GossipInfo.GetFriendshipReputationRanks(factionID)
    end
else
    Rep.GetFriendshipReputationRanks = function(factionID)
        if not factionID or not GetFriendshipReputationRanks then return nil end
        local currentLevel, maxLevel = GetFriendshipReputationRanks(factionID)
        if not currentLevel then return nil end
        return {
            currentLevel = currentLevel,
            maxLevel = maxLevel,
        }
    end
end

function lib:GetConfigTemplate(config, get, set)
   assert(self ~= lib, "GetConfigTemplate can only be called when embedded.")
   assert(optionTemplates[config] ~= nil, "Unknown config template: "..config)

   local template = {}
   for key, val in pairs(optionTemplates[config]) do
      if key == "args" then
	 local a = {}
	 for akey, aval in pairs(val) do
	    a[akey] = aval
	 end
	 template.args = a
      else
	 template[key] = val
      end
   end
   template.handler = self
   if get then template.get = get end
   if set then template.set = set end
   return template
end

function lib:Embed(addon)
   for _,key in ipairs(embeddables) do
      addon[key] = lib[key]
   end
   embeddedAddons[addon] = true
end

local function GetConfigHash(mod)
   local db = mod.db
   if db then
      if db.profile then
	 return db.profile
      else
	 return db
      end
   elseif mod.GetConfigTable then
      return mod:GetConfigTable()
   end
   assert(db ~= nil, "Couldn't find config hash.")
end

function lib:_SetColorOpt(arg, r, g, b, a)
   local color = arg[#arg]
   local data = GetConfigHash(self).backdropColors
   assert(data ~= nil, "Didn't find the required config data: self.db.profile.backdropColors")
   data[color][1] = r
   data[color][2] = g
   data[color][3] = b
   data[color][4] = a
   if self.OnOptionChanged then
      self:OnOptionChanged(color, data[color], info)
   end
   self:FixBackdrop()
end

function lib:_GetColorOpt(arg)
   local color = arg[#arg]
   return unpack(GetConfigHash(self).backdropColors[color])
end

-- If the current database has 'nil' for this option, hide it
-- All options need to have a default even if it's false 
function lib:_HideOption(info)
   return GetConfigHash(self)[info[#info]] == nil
end


function lib:_SetOption(info, val)
   local var = info[#info]
   GetConfigHash(self)[info[#info]] = val
   if self.OnOptionChanged then
      self:OnOptionChanged(var, val, info)
   end
end

function lib:_GetOption(info)
   return GetConfigHash(self)[info[#info]]
end

function lib:_DisableTiling(info)
   return not GetConfigHash(self).tile 
end

function lib:FixBackdrop()   
   local bgFrame = self.frame:GetBackdrop()
   local db = GetConfigHash(self)
   if not bgFrame then
      bgFrame = {
	 insets = {left = 1, right = 1, top = 1, bottom = 1}
      }
   end

   local edge = 0
   local inset = 0
   if db.border ~= "None" then
      edge = db.edgeSize
      inset = db.edgeSize / 4
   end
   bgFrame.edgeSize = edge
   bgFrame.insets.left   = inset
   bgFrame.insets.right  = inset
   bgFrame.insets.top    = inset
   bgFrame.insets.bottom = inset

   bgFrame.tile = db.tile
   bgFrame.tileSize = db.tileSize

   bgFrame.edgeFile = media:Fetch("border", db.border)
   bgFrame.bgFile = media:Fetch("background", db.background)

   self.frame:SetBackdrop(bgFrame)
   self.frame:SetBackdropColor(unpack(db.backdropColors.backgroundColor))
   self.frame:SetBackdropBorderColor(unpack(db.backdropColors.borderColor))
end

function lib:_SetBackgroundOption(...)
   self:_SetOption(...)
   self:FixBackdrop()
end

function lib:Dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. lib:Dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end




function lib:InterfaceOptions_AddCategory(frame, addOn, position)
    if InterfaceOptions_AddCategory then
        return InterfaceOptions_AddCategory(frame, addon, position)
    end
	-- cancel is no longer a default option. May add menu extension for this.
	frame.OnCommit = frame.okay;
	frame.OnDefault = frame.default;
	frame.OnRefresh = frame.refresh;

	if frame.parent then
		local category = Settings.GetCategory(frame.parent)
		local subcategory = Settings.RegisterCanvasLayoutSubcategory(category, frame, frame.name, frame.name)
		subcategory.ID = frame.name;
		return subcategory, category;
	else
		local category = Settings.RegisterCanvasLayoutCategory(frame, frame.name, frame.name);
		category.ID = frame.name;
		Settings.RegisterAddOnCategory(category);
		return category;
	end
end

-- Deprecated. Use Settings.OpenToCategory().
function lib:InterfaceOptionsFrame_OpenToCategory(categoryIDOrFrame)
    if InCombatLockdown() then
        return
    end
    if InterfaceOptionsFrame_OpenToCategory then
        return InterfaceOptionsFrame_OpenToCategory(categoryIDOrFrame)
    end
	if type(categoryIDOrFrame) == "table" then
		local categoryID = categoryIDOrFrame.name;
		return Settings.OpenToCategory(categoryID);
	else
		return Settings.OpenToCategory(categoryIDOrFrame);
	end
end

-- Returns the active mail frame and whether it's TSM.
-- Second return value is true if the returned frame is TSM's mail frame.
-- Finds TSM's mail window by looking for the MailsScrollTable element
-- (unique to TSM's mail UI) and walking up to the top-level parent.
local cachedTSMMailFrame
local tsmScanComplete = false
local lastTSMScan = 0

local function AtMailbox()
    if C_PlayerInteractionManager and C_PlayerInteractionManager.IsInteractingWithNpcOfType
        and Enum and Enum.PlayerInteractionType then
        local ok, r = pcall(C_PlayerInteractionManager.IsInteractingWithNpcOfType, Enum.PlayerInteractionType.MailInfo)
        if ok and r then return true end
    end
    local ok, shown = pcall(function() return MailFrame and MailFrame:IsShown() and true or false end)
    return ok and shown
end

local function IsTSMMailingVisible()
    if TSM_API and TSM_API.IsUIVisible then
        local ok, visible = pcall(TSM_API.IsUIVisible, "MAILING")
        if ok and visible == true then
            return true
        end
    end
    return false
end

-- Release builds of TSM don't name their frames (names are dev/test only), so
-- first try the named lookup, then fall back to finding TSM's top-level
-- application frame: every TSM widget carries a "__debug" table, and the
-- application frame is the large shown child of UIParent.
-- Examine one frame. Returns "named", "tsm" or "loose" (see ScanForTSMFrame),
-- or nil. Runs under pcall: some frames return secret values that error when
-- tested from addon code.
local function ClassifyFrame(frame)
    if frame:IsForbidden() then return nil end
    local name = frame:GetName()
    if name and type(name) == "string" then
        if name:match("^TSM_FRAME:MailsScrollTable:") then
            local parent = frame:GetParent()
            while parent and parent ~= UIParent and not parent:IsForbidden() do
                local parentName = parent:GetName()
                if parentName and type(parentName) == "string" and parentName:match("^TSM_FRAME:LargeApplicationFrame:") then
                    return "named", parent
                end
                parent = parent:GetParent()
            end
        end
        return nil
    end
    if frame:GetParent() == UIParent and frame:IsShown() then
        local w, h = frame:GetWidth() or 0, frame:GetHeight() or 0
        if w >= 300 and h >= 200 then
            return frame.__debug and "tsm" or "loose", frame
        end
    end
    return nil
end

local function ScanForTSMFrame()
    local fallback, loose
    local frame = EnumerateFrames()
    while frame do
        local ok, kind, found = pcall(ClassifyFrame, frame)
        if ok and kind then
            if kind == "named" then
                return found
            elseif kind == "tsm" then
                fallback = fallback or found
            else
                loose = loose or found
            end
        end
        frame = EnumerateFrames(frame)
    end
    return fallback or loose
end

local function FindTSMMailFrame()
    -- TSM tells us whether its mailing UI is showing. If that call is
    -- unavailable or unreliable, infer it: at the mailbox with the default
    -- MailFrame hidden and a TSM application frame on screen.
    local tsmVisible = IsTSMMailingVisible()
    if not tsmVisible and AtMailbox() then
        local okShown, mfShown = pcall(function() return MailFrame and MailFrame:IsShown() and true or false end)
        if okShown and not mfShown then
            if not (cachedTSMMailFrame and cachedTSMMailFrame:IsShown()) then
                local now = GetTime()
                if now - lastTSMScan >= 1 then
                    lastTSMScan = now
                    local f = ScanForTSMFrame()
                    cachedTSMMailFrame = f
                end
            end
            if cachedTSMMailFrame and cachedTSMMailFrame:IsShown() and cachedTSMMailFrame.__debug then
                return cachedTSMMailFrame, true
            end
        end
    end
    if not tsmVisible then
        cachedTSMMailFrame = nil
        return nil, false
    end
    if cachedTSMMailFrame and cachedTSMMailFrame:IsShown() then
        return cachedTSMMailFrame, true
    end
    local now = GetTime()
    if now - lastTSMScan >= 1 then
        lastTSMScan = now
        cachedTSMMailFrame = ScanForTSMFrame()
    end
    return cachedTSMMailFrame, true
end

-- Kept for API compatibility; detection no longer relies on a one-shot scan.
function lib:ResetTSMFrameCache()
    tsmScanComplete = false
    lastTSMScan = 0
end

function lib:GetMailFrame()
    local tsmFrame, tsmVisible = FindTSMMailFrame()
    if tsmVisible then
        -- If the frame couldn't be located, fall back to the (hidden) default
        -- MailFrame for anchoring but still report TSM as active.
        return tsmFrame or MailFrame, true
    end
    return MailFrame, false
end

-- Config template for a frame background
optionTemplates.background = {
   type = "group",
   name = L["Background Frame"],
   set = "_SetOption",
   get = "_GetOption",
   args = {
      background = {
	 type = "select",
	 dialogControl = "LSM30_Background",
	 name = L["Background Texture"],
	 desc = L["The background texture used for the background frame."], 
	 order = 20,
	 values = AceGUIWidgetLSMlists.background,
	 set = "_SetBackgroundOption", 
      },
      backgroundColor = {
	 type = "color",
	 name = L["Background Color"],
	 hasAlpha = true,
	 set = "_SetColorOpt",
	 get = "_GetColorOpt",
	 order = 30,
      },
      spacer1 = {
	 type = "description",
	 width = "full",
	 name = "",
	 order = 35,
	 set = "_SetBackgroundOption", 
      },
      border = {
	 type = "select",
	 dialogControl = "LSM30_Border",
	 name = L["Border Texture"],
	 desc = L["The border texture used for the background frame."],
	 order = 40,
	 values = AceGUIWidgetLSMlists.border, 
	 set = "_SetBackgroundOption", 
      },
      borderColor = {
	 type = "color",
	 name = L["Border color"],
	 hasAlpha = true,
	 set = "_SetColorOpt",
	 get = "_GetColorOpt",
	 order = 50,
      },
      spacer2 = {
	 type = "description",
	 width = "full",
	 name = "",
	 order = 55,
      },
      edgeSize = {
	 type = "range",
	 name = L["Edge size"],
	 desc = L["Width of the border."],
	 min = 1, max = 50, step = 0.1,
	 set = "_SetBackgroundOption",
	 order = 60, 
      },
      padding = {
	 type = "range",
	 name = L["Padding"],
	 desc = L["Number of pixels to insert between the background frame edge and the content."],
	 min = 0, max = 50, step = 0.1,
	 order = 70, 
      },
      tile = {
	 type = "toggle",
	 name = L["Tile Background"],
	 desc = L["Whether or not to tile the background texture."],
	 order = 100,
	 set = "_SetBackgroundOption", 
	 order = 90, 
      },
      tileSize = {
	 type = "range",
	 name = L["Tile Size"],
	 desc = L["The size in pixels of the background tiles."],
	 min = 1, max = 200, step = 0.1, 
	 order = 110,
	 disabled = "_DisableTiling",
	 set = "_SetBackgroundOption", 
	 order = 100,
      },
   }
}

optionTemplates.barsize = {
   type = "group",
   name = L["Bar Size"],
   get = "_GetOption",
   set = "_SetOption",
   args = {
      maxbars  = {
	 type = "range",
	 min = 1, max = 100, step = 1,
	 name = L["Maximum number of bars"],
	 width="full",
	 order = 0,
	 hidden = "_HideOption", 
      },
      height = {
	 type = "range",
	 name = L["Bar Height"],
	 width = "full",
	 min = 1, max = 50, step = 1,
      }, 
      width = {
	 type = "range",
	 name = L["Bar Width"],
	 width = "full",
	 min = 1, max = 500, step = 1,
      }, 
      scale = {
	 type = "range",
	 name = L["Bar Scale"],
	 width = "full",
	 min = 0.01, max = 5, step = 0.005,
      }, 
      spacing = {
	 type = "range",
	 name = L["Bar Spacing"],
	 desc = L["The space in pixels between each bar."],
	 width = "full",
	 min = 0, max = 40, step = 0.05,
	 hidden = "_HideOption", 
      }, 
   }
}

----------------------------------------------------------------
-- Dialog windows
--
-- Shared building blocks for addon windows: a framed dialog window and a
-- yes/no confirmation with an optional checkbox. No strings live here;
-- callers pass their own localized text.
----------------------------------------------------------------

local DIALOG_BACKDROP = {
   bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
   edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
   tile = true, tileSize = 32, edgeSize = 32,
   insets = { left = 11, right = 12, top = 12, bottom = 11 },
}
local BACKDROP_TEMPLATE = BackdropTemplateMixin and "BackdropTemplate" or nil

--- Gives frame the standard dialog border. opaque adds a dark backing,
--- since the dialog background alone is see-through enough to make text
--- hard to read over the game world.
function lib:StyleDialog(frame, opaque)
   if frame.SetBackdrop then
      frame:SetBackdrop(DIALOG_BACKDROP)
   end
   if opaque and not frame.dialogBacking then
      local backing = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
      backing:SetPoint("TOPLEFT", 11, -11)
      backing:SetPoint("BOTTOMRIGHT", -11, 11)
      backing:SetColorTexture(0.04, 0.04, 0.06, 0.96)
      frame.dialogBacking = backing
   end
end

-- The header plate is one stretched texture whose middle ~60% holds the
-- text, so it is sized to the title.
local function SetDialogTitle(frame, text)
   frame.title:SetText(text or "")
   if frame.headerPlate then
      local textWidth = frame.title:GetStringWidth() or 0
      local plateWidth = math.max(256, (textWidth + 24) / 0.6)
      frame.headerPlate:SetWidth(math.min(plateWidth, frame:GetWidth() - 40))
   end
end

--- Creates a hidden, movable dialog window.
---   name    global frame name (needed for escape)
---   options (all optional):
---     title       text for the title
---     header      true: title on the classic dialog header plate,
---                 otherwise a large title inside the top edge
---     closeButton true: an X button in the corner that hides the window
---     escape      false: don't close on escape (default closes)
---     opaque      true: dark backing behind the content
---     strata      frame strata (default "DIALOG")
---     point       { point, relativeTo, relativePoint, x, y } (default centered)
--- Returns the frame; frame.title and frame.closeButton when created, and
--- frame:SetTitle(text) to change the title later.
function lib:CreateDialogWindow(name, width, height, options)
   options = options or {}
   local frame = CreateFrame("Frame", name, UIParent, BACKDROP_TEMPLATE)
   frame:SetSize(width, height)
   if options.point then
      frame:SetPoint(unpack(options.point))
   else
      frame:SetPoint("CENTER")
   end
   frame:SetFrameStrata(options.strata or "DIALOG")
   frame:SetToplevel(true)
   frame:SetClampedToScreen(true)
   frame:EnableMouse(true)
   frame:SetMovable(true)
   frame:RegisterForDrag("LeftButton")
   frame:SetScript("OnDragStart", frame.StartMoving)
   frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
   lib:StyleDialog(frame, options.opaque)
   if name and options.escape ~= false then
      tinsert(UISpecialFrames, name)
   end

   if options.title then
      local title
      if options.header then
         local plate = frame:CreateTexture(nil, "ARTWORK")
         plate:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
         plate:SetHeight(64)
         plate:SetPoint("TOP", frame, "TOP", 0, 12)
         title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
         title:SetPoint("TOP", plate, "TOP", 0, -14)
         frame.headerPlate = plate
      else
         title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
         title:SetPoint("TOP", frame, "TOP", 0, -18)
      end
      frame.title = title
      frame.SetTitle = SetDialogTitle
      frame:SetTitle(options.title)
   end

   if options.closeButton then
      local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
      close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
      close:SetScript("OnClick", function() frame:Hide() end)
      frame.closeButton = close
   end

   frame:Hide()
   return frame
end

--- A standard push button. height defaults to 24.
function lib:CreateDialogButton(parent, text, width, onClick, height)
   local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
   button:SetSize(width or 130, height or 24)
   button:SetText(text)
   if onClick then button:SetScript("OnClick", onClick) end
   return button
end

----------------------------------------------------------------
-- Confirmation dialog
----------------------------------------------------------------

local confirmFrame

local function FinishConfirm(accepted)
   local request = confirmFrame.request
   confirmFrame.request = nil
   confirmFrame:Hide()
   if not request then return end
   if accepted then
      if request.onAccept then request.onAccept(confirmFrame.checkbox:GetChecked() and true or false) end
   elseif request.onCancel then
      request.onCancel()
   end
end

local function CreateConfirmFrame()
   local frame = lib:CreateDialogWindow("LibMagicUtilConfirmDialog", 360, 140,
      { point = { "TOP", UIParent, "TOP", 0, -135 } })

   frame.icon = frame:CreateTexture(nil, "ARTWORK")
   frame.icon:SetSize(36, 36)
   frame.icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -18)

   frame.text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
   frame.text:SetJustifyH("LEFT")
   frame.text:SetJustifyV("TOP")

   frame.checkbox = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
   frame.checkbox:SetSize(24, 24)
   frame.checkbox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 46)
   local label = frame.checkbox.Text or frame.checkbox.text
   if not label then
      label = frame.checkbox:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
      label:SetPoint("LEFT", frame.checkbox, "RIGHT", 2, 0)
   end
   label:SetFontObject("GameFontHighlightSmall")
   frame.checkboxLabel = label

   frame.accept = lib:CreateDialogButton(frame, ACCEPT, 120, function() FinishConfirm(true) end, 22)
   frame.accept:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -4, 18)
   frame.cancel = lib:CreateDialogButton(frame, CANCEL, 120, function() FinishConfirm(false) end, 22)
   frame.cancel:SetPoint("BOTTOMLEFT", frame, "BOTTOM", 4, 18)

   -- Escape, or anything else hiding it, counts as cancel. Set after the
   -- initial Hide so creating the frame doesn't cancel anything.
   frame:SetScript("OnHide", function() if frame.request then FinishConfirm(false) end end)
   return frame
end

--- Asks a yes/no question. Only one is shown at a time; a new one cancels
--- the one already showing.
---   options:
---     text          the question
---     acceptText    accept button label (default ACCEPT)
---     cancelText    cancel button label (default CANCEL)
---     checkboxText  shows a checkbox with this label (e.g. "Don't ask again")
---     icon          texture path, or false for none (default alert icon)
---     onAccept      function(checked) when accepted
---     onCancel      function() when cancelled, escaped or replaced
---     sound         false to stay silent
function lib:ShowConfirmDialog(options)
   confirmFrame = confirmFrame or lib.confirmFrame or CreateConfirmFrame()
   lib.confirmFrame = confirmFrame
   if confirmFrame.request then FinishConfirm(false) end

   local frame = confirmFrame
   local icon = options.icon
   if icon == nil then icon = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew" end
   frame.text:ClearAllPoints()
   if icon then
      frame.icon:SetTexture(icon)
      frame.icon:Show()
      frame.text:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -2)
   else
      frame.icon:Hide()
      frame.text:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -22)
   end
   frame.text:SetPoint("RIGHT", frame, "RIGHT", -22, 0)
   frame.text:SetText(options.text or "")

   frame.checkbox:SetChecked(false)
   frame.checkbox:SetShown(options.checkboxText ~= nil)
   frame.checkboxLabel:SetText(options.checkboxText or "")

   frame.accept:SetText(options.acceptText or ACCEPT)
   frame.cancel:SetText(options.cancelText or CANCEL)

   -- grow to fit longer questions
   local textHeight = frame.text:GetStringHeight() or 0
   local extra = options.checkboxText and 28 or 0
   frame:SetHeight(math.max(112, textHeight + 84 + extra))
   frame.checkbox:ClearAllPoints()
   frame.checkbox:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 46)

   frame.request = {
      onAccept = options.onAccept,
      onCancel = options.onCancel,
   }
   frame:Show()
   frame:Raise()
   if options.sound ~= false and PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN then
      PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
   end
end

--- True while a confirmation is waiting for an answer.
function lib:IsConfirmDialogShown()
   return confirmFrame ~= nil and confirmFrame.request ~= nil
end

-- upgrade
for addon in pairs(embeddedAddons) do
   lib:Embed(addon)
end
