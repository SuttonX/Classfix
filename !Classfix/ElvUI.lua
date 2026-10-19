local _, ns = ...
if ns.ElvUIIntegrationLoaded then return end
ns.ElvUIIntegrationLoaded = true

-- Keep original RGBs even though the shared table is updated in place.
local history = {}
for class, color in pairs(RAID_CLASS_COLORS) do
    history[class] = {{r=color.r, g=color.g, b=color.b}}
end
local hooked = setmetatable({}, {__mode="k"})
local auraFrames = setmetatable({}, {__mode="k"})
local function Same(a,b)
    local tolerance = 0.5/255 + 0.00001
    return a and b and type(a.r)=="number" and type(a.g)=="number" and type(a.b)=="number"
        and math.abs(a.r-b.r)<tolerance and math.abs(a.g-b.g)<tolerance and math.abs(a.b-b.b)<tolerance
end

local function Resolve(color, E)
    if type(color) ~= "table" then return end
    -- ElvUI has a special priest tint in addition to Blizzard's white.
    if E.myclass == "PRIEST" and Same(color, E.PriestColors) then
        return CUSTOM_CLASS_COLORS.PRIEST
    end
    for class, oldColors in pairs(history) do
        for _, old in ipairs(oldColors) do
            if Same(color, old) then return CUSTOM_CLASS_COLORS[class] end
        end
    end
end

local function UpdateMedia(E)
    if not E.db or not E.db.general or type(E.media) ~= "table" then return end
    local color = CUSTOM_CLASS_COLORS[E.myclass] or Resolve(E.db.general.valuecolor, E)
    if not color then return end
    E.media.hexvaluecolor = "|c" .. color.colorStr
    E.media.rgbvaluecolor = {color.r, color.g, color.b}
    if type(E.ValueFuncCall)=="function" then E:ValueFuncCall() end
end

local function UpdateAuraFrame(E, UF, frame)
    if not frame or not frame.AuraBars or not frame.db or not frame.db.aurabar or not frame.db.aurabar.enable then return end
    local colors = UF.db and UF.db.colors
    if not colors then return end
    local element = frame.AuraBars
    local buff = CUSTOM_CLASS_COLORS[E.myclass] or Resolve(colors.auraBarBuff,E)
    local debuff = Resolve(colors.auraBarDebuff,E)
    if buff then element.buffColor = {buff.r,buff.g,buff.b} end
    if debuff then
        local field = colors.auraBarByType and "defaultDebuffColor" or "debuffColor"
        element[field] = {debuff.r,debuff.g,debuff.b}
    end
    -- Existing bars already have RGBs baked into their status bars.
    -- Refresh helpful auras now, while retaining per-spell and Turtle overrides.
    if buff and type(element.bars)=="table" then
        local global = E.global and E.global.unitframe
        local overrides = global and global.AuraBarColors
        local turtle = global and global.aurafilters and global.aurafilters.TurtleBuffs
        local turtleSpells = turtle and turtle.spells
        for _, barFrame in ipairs(element.bars) do
            local bar = barFrame.statusBar
            local aura = bar and bar.aura
            if aura and aura.filter=="HELPFUL" then
                local id,name=aura.spellID,aura.name
                local special = overrides and (overrides[id] or overrides[tostring(id)] or overrides[name])
                local turtleOverride = colors.auraBarTurtle and turtleSpells and (turtleSpells[id] or turtleSpells[name])
                if not special and not turtleOverride and type(bar.SetStatusBarColor)=="function" then
                    bar:SetStatusBarColor(buff.r,buff.g,buff.b)
                end
            end
        end
    end
end

function ns.ApplyElvUI(E)
    if not CUSTOM_CLASS_COLORS or type(hooksecurefunc) ~= "function" then return end
    local state = hooked[E]
    if not state then state={}; hooked[E]=state end
    if not state.media and type(E.UpdateMedia)=="function" then
        hooksecurefunc(E,"UpdateMedia",function(self) UpdateMedia(self) end)
        state.media=true
    end
    local UF = type(E.GetModule)=="function" and E:GetModule("UnitFrames",true)
    if UF and not state.auras and type(UF.Configure_AuraBars)=="function" then
        hooksecurefunc(UF,"Configure_AuraBars",function(self, frame)
            if frame then auraFrames[frame]=self; UpdateAuraFrame(E,self,frame) end
        end)
        state.auras=true
        -- Include frames created before these hooks were installed.
        if E.oUF and type(E.oUF.objects)=="table" then
            for _, frame in pairs(E.oUF.objects) do
                if frame.AuraBars then auraFrames[frame]=UF end
            end
        end
    end
    UpdateMedia(E)
    for frame, owner in pairs(auraFrames) do UpdateAuraFrame(E,owner,frame) end
    -- Remember custom palettes too, so subsequent edits refresh cached values.
    for class, color in pairs(CUSTOM_CLASS_COLORS) do
        if type(color)=="table" and type(color.r)=="number" then
            local list=history[class]
            if not list then list={}; history[class]=list end
            local found=false
            for _, old in ipairs(list) do if Same(old,color) then found=true; break end end
            if not found then list[#list+1]={r=color.r,g=color.g,b=color.b} end
        end
    end
end
