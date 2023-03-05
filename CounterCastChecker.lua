CCcheckerDB = CCcheckerDB or {lock = false}
local ParentFrame = CreateFrame("Frame", nil, UIParent)
local bar
local BaseFrame = {}
local session = {}
local interrupted_enemies = {}
local currentEnemyStopCast = {}
local frames = {}


local interrupts_durations = {
		[2139] = {["trueId"] = 2139, ["duration"] = 8}, -- 2139  Counterspell MAGE
		[19647] = {["trueId"] = 19647, ["duration"] = 6}, -- 19647 Spell Lock WARLOCK
		[1766] = {["trueId"] = 1766, ["duration"] = 5}, -- 1766  Kick ROGUE
		[57994] = {["trueId"] = 57994, ["duration"] = 2}, -- 57994 Wind SHAMAN
		[19675] = {["trueId"] = 16979, ["duration"] = 4}, -- 16979 Feral Charge DRUIDE effect
		[32747] = {["trueId"] = 8983, ["duration"] = 3}, -- bear stun druide
		[49802] = {["trueId"] = 49802, ["duration"] = 3}, -- cat stun druide
		[47528] = {["trueId"] = 47528, ["duration"] = 6}, -- 47528 Mind Freeze DEATHKNIGHT
		[6552] = {["trueId"] = 6552, ["duration"] = 4}, -- 6552 Pummel WARRIOR
		[72] = {["trueId"] = 72, ["duration"] = 6}, -- 1672 Shield bash WARRIOR
		} 



----------------------------------------------------LOAD FUNCTIONS------------------------------------------------------------------------------------
local function loadPosition(frame, texture)
	if frame.name == "target" then
		if not CCcheckerDB.position or not CCcheckerDB.position.target then 
			local name,_,spellicon = GetSpellInfo(2139)
			texture:SetTexture(spellicon)
			frame:SetPoint("CENTER",bar,"CENTER",x,0)
			frame:Show()
		else 
			frame:SetPoint(CCcheckerDB.position.target.point, UIParent, CCcheckerDB.position.target.relativePoint,
																					 CCcheckerDB.position.target.xOfs,CCcheckerDB.position.target.yOfs) 
		end	
	else
		if not CCcheckerDB.position or not CCcheckerDB.position.focus then 
			local name,_,spellicon = GetSpellInfo(2139)
			texture:SetTexture(spellicon)
			frame:SetPoint("CENTER",bar,"CENTER",100,0)
			frame:Show()
		else 
			frame:SetPoint(CCcheckerDB.position.focus.point, UIParent, CCcheckerDB.position.focus.relativePoint, 
																				CCcheckerDB.position.focus.xOfs, CCcheckerDB.position.focus.yOfs) 
		end	
	end	
end

local function OnLoad_session()
	
end

----------------------------------------------------SAVE/UPDATE FUNCTIONS---------------------------------------------------------------------------------

local function savePosition(frame)

	local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
	if not CCcheckerDB.position then 
		CCcheckerDB.position = {["target"] = {}, ["focus"] = {}}
	end
	if frame.name == "target" then
		if not CCcheckerDB.position.target then CCcheckerDB.position.target = {} end
		CCcheckerDB.position.target.point = point
		CCcheckerDB.position.target.relativePoint = relativePoint
		CCcheckerDB.position.target.xOfs = xOfs
		CCcheckerDB.position.target.yOfs = yOfs
	else
		if not CCcheckerDB.position.focus then CCcheckerDB.position.focus = {} end
		CCcheckerDB.position.focus.point = point
		CCcheckerDB.position.focus.relativePoint = relativePoint
		CCcheckerDB.position.focus.xOfs = xOfs
		CCcheckerDB.position.focus.yOfs = yOfs
	end	
end	

local function addonUpdate(self, elapsed)
	for dstName, value in pairs(interrupted_enemies) do
		
		if value.endTime - GetTime() <= elapsed then 
			interrupted_enemies[dstName] = nil
			self:Hide()
			self:SetScript("OnUpdate", nil)
		end

		for k, v in pairs(interrupted_enemies) do -- fixing buffer overflow in duelzones
			if GetTime() >= v.endTime then
			interrupted_enemies[k] = nil 
			end
		end
	end		
end	

----------------------------------------------------MIDDLEWARE FUNCTIONS----------------------------------------------------------------------------------

local function show_interrupted(frame, spellId)
	local name,_,spellicon = GetSpellInfo(interrupts_durations[spellId].trueId)
	frame.texture:SetTexture(spellicon)
	frame:Show()
	frame.cd:Show()
	frame.cd:SetCooldown(GetTime()-0.40, interrupts_durations[spellId].duration)
				
	frame:SetScript("OnUpdate", addonUpdate) 							
end		

local function COMBAT_LOG_FILTER(frames, ...)
	local timestamp, eventtype, enemyCaster, srcName, srcFlags, _, dstName, dstFlags, spellId = ...
	local frame
	local unit_view
	for unit_name, value in pairs(interrupted_enemies) do

	end
	if eventtype == "SPELL_INTERRUPT" and spellId ~=nil then
		interrupted_enemies[dstName] = {["startTime"] = GetTime(), ["endTime"] = GetTime() 
															+ interrupts_durations[spellId].duration, ["spellId"]=spellId}
		
		for _, obj in ipairs(frames) do
			frame = obj.frame
			unit_view = UnitName(frame.name) -- means where unit shows whether in target or in focusTarget. Right part returns a names of ur focus and target
			for unit_name, value in pairs(interrupted_enemies) do
				
				if unit_view == unit_name then
					show_interrupted(frame, value.spellId)	
				end
			end	
		end
	end	
end

		

----------------------------------------------------CONSTRUCTOR CLASS------------------------------------------------------------------------------------
function BaseFrame:new(frameName)

	local object = {}
		object.frame = CreateFrame("Frame", nil, ParentFrame) --WoW API doesn't allow to define frame object as pure self
		object.frame.name = frameName
	
	function object:createFrame()
		self.frame:RegisterEvent("VARIABLES_LOADED")
		self.frame:RegisterEvent("PLAYER_TARGET_CHANGED")
		self.frame:SetMovable(true)
		self.frame:EnableMouse(true)
		self.frame:SetWidth(40)
		self.frame:SetHeight(40)
		self.frame:SetClampedToScreen(true) 
		self.frame:SetScript("OnMouseDown",function(self,button) if button == "LeftButton" then self:StartMoving() end end)
		self.frame:SetScript("OnMouseUp",function(self,button) if button == "LeftButton" then self:StopMovingOrSizing() message(self.name) savePosition(self)  end end)
		self.frame:SetFrameStrata("LOW")
		self.frame:Hide()
	
		
		local cd = CreateFrame("Cooldown",nil, self.frame)
		cd:SetAllPoints(true)
		cd:SetWidth(40)
		cd:SetHeight(40)
		cd:SetFrameStrata("LOW")
		cd:Hide()

		local texture = self.frame:CreateTexture(nil,"BACKGROUND")
		texture:SetAllPoints(true)
		texture:SetTexCoord(0.07,0.9,0.07,0.90)
		loadPosition(self.frame, texture)
		self.frame.texture = texture
		self.frame.cd = cd

	end	

	
	
	function object:targetChanged()
	
		local target = UnitName(self.frame.name)
		local remainingTime 
		if target == nil then 
			self.frame:Hide()
			self.frame:SetScript("OnUpdate", nil)
		else 
			if next(interrupted_enemies) ~= nil then
				for interruptedEnemy, value in pairs(interrupted_enemies) do
					if target == interruptedEnemy then
						remainingTime = value.endTime -- GetTime()  -- remainingTime-0.40
						local _,_,spellicon = GetSpellInfo(interrupts_durations[value.spellId].trueId)
						self.frame.texture:SetTexture(spellicon)
						self.frame:Show()
						self.frame.cd:Show()
						self.frame.cd:SetCooldown(GetTime() - (GetTime() - value.startTime), interrupts_durations[value.spellId].duration)
						self.frame:SetScript("OnUpdate", addonUpdate) 
					else
						self.frame:Hide()
						self.frame:SetScript("OnUpdate", nil)	
					end
				end	
			end	
		end
	end

	setmetatable(object, self)
	self.__index = self; return object
end
	

----------------------------------------------------EVENTS FILTERS and commands---------------------------------------------------------------------------
for _, frame in ipairs({"target", "focus"}) do
	table.insert(frames, BaseFrame:new(frame))
end	

local events_map = {
	["COMBAT_LOG_EVENT_UNFILTERED"] = function(self,...) COMBAT_LOG_FILTER(frames, ...) end,
	["VARIABLES_LOADED"] = function(self) OnLoad_session() frames[1]:createFrame() frames[2]:createFrame() end,
	["PLAYER_TARGET_CHANGED"] = function(self) frames[1]:targetChanged() end,
	["PLAYER_FOCUS_CHANGED"] = function(self) frames[2]:targetChanged() end,
}

local function CCchecker_event_handler(self,event,...)
	if event ~= nil then events_map[event](self,...) end
end



local function cmdHandlershow()
	local name,_,spellicon = GetSpellInfo(2139)
	for _,obj in ipairs(frames) do
		obj.frame:Show()
		obj.frame.texture:SetTexture(spellicon)
		obj.frame:SetMovable(true)
		obj.frame:EnableMouse(true)
		ParentFrame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end	

local function cmdHandlerhide()
	for _,obj in ipairs(frames) do
		obj.frame:Hide()
		obj.frame:SetMovable(false)
		obj.frame:EnableMouse(false)
		ParentFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	end
end	

SLASH_CCs1 = "/CCshow"
SlashCmdList["CCs"] = cmdHandlershow
SLASH_CCh1 = "/CChide"
SlashCmdList["CCh"] = cmdHandlerhide


ParentFrame:RegisterEvent("VARIABLES_LOADED")
ParentFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
ParentFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
ParentFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
ParentFrame:SetScript("OnEvent", CCchecker_event_handler)
ParentFrame:SetScript("OnDragStart", BaseFrame.StartMoving)
