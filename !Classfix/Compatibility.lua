local _, ns = ...

function ns.Hex(r,g,b)
    return string.format("ff%02x%02x%02x",math.floor(r*255+0.5),math.floor(g*255+0.5),math.floor(b*255+0.5))
end

-- Local compatibility objects; do not replace the client's global APIs.
local methods = {}
function methods:GetRGB() return self.r, self.g, self.b end
function methods:GetRGBA() return self.r, self.g, self.b, self.a end
function methods:SetRGB(r, g, b) self.r, self.g, self.b = r, g, b end
function methods:SetRGBA(r, g, b, a) self:SetRGB(r, g, b); self.a = a end
function methods:GenerateHexColor()
    return string.format("%02x%02x%02x%02x", (self.a or 1)*255, self.r*255, self.g*255, self.b*255)
end
function methods:WrapTextInColorCode(text)
    return "|c" .. self:GenerateHexColor() .. tostring(text) .. "|r"
end
function ns.CreateColor(r, g, b, a)
    return setmetatable({r=r, g=g, b=b, a=a or 1}, {__index=methods})
end

local function CopyPalette(target)
    if type(target) ~= "table" or not CUSTOM_CLASS_COLORS then return end
    for class, color in pairs(CUSTOM_CLASS_COLORS) do
        if type(color) == "table" and type(color.r) == "number" then
            local dst = target[class]
            if type(dst) ~= "table" then dst = {}; target[class] = dst end
            dst.r, dst.g, dst.b, dst.colorStr = color.r, color.g, color.b, color.colorStr
            if dst[1] ~= nil then dst[1], dst[2], dst[3] = color.r, color.g, color.b end
        end
    end
end

function ns.Apply()
    if ns.alreadyLoaded then return end
    -- Preserve existing table identities for consumers holding local references.
    CopyPalette(RAID_CLASS_COLORS)
    if ns.ApplyShadowUF then ns.ApplyShadowUF() end
    local E = type(ElvUI) == "table" and ElvUI[1]
    if type(E) == "table" then
        if E.colors then CopyPalette(E.colors.class) end
        if E.oUF and E.oUF.colors then CopyPalette(E.oUF.colors.class) end
        if ns.ApplyElvUI then ns.ApplyElvUI(E) end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function() ns.Apply() end)

-- Bundled integrations: also load when the client retains an older TOC list.
do
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

end
do
local _, ns = ...
if ns.ShadowUFIntegrationLoaded then return end
ns.ShadowUFIntegrationLoaded = true
local profiles = setmetatable({}, {__mode="k"})
local hooked = setmetatable({}, {__mode="k"})
local loggingOut, updating = false, false

local function Refresh(S)
    local frames = S.Units and S.Units.frameList
    if type(frames) ~= "table" then return end
    for frame in pairs(frames) do
        if frame.unit and type(frame.FullUpdate)=="function" then frame:FullUpdate() end
    end
end

function ns.ApplyShadowUF()
    if loggingOut or updating or ns.alreadyLoaded then return end
    local S = ShadowUF
    if type(S) ~= "table" or not CUSTOM_CLASS_COLORS then return end
    if not hooked[S] and type(hooksecurefunc)=="function" then
        hooked[S]=true
        for _, method in ipairs({"OnInitialize", "ProfilesChanged", "LoadDefaultLayout"}) do
            if type(S[method])=="function" then hooksecurefunc(S,method,ns.ApplyShadowUF) end
        end
    end
    local profile = S.db and S.db.profile
    local colors = profile and profile.classColors
    if type(colors) ~= "table" then return end
    updating=true
    local record=profiles[profile]
    local changed=false
    if not record or colors ~= record.overlay then
        record={original=colors, overlay={}}
        for key,value in pairs(colors) do record.overlay[key]=value end
        profiles[profile]=record
        profile.classColors=record.overlay
        changed=true
    end
    for class,color in pairs(CUSTOM_CLASS_COLORS) do
        if type(color)=="table" and type(color.r)=="number" and RAID_CLASS_COLORS[class] then
            local dst=record.overlay[class]
            if dst==record.original[class] then
                dst={}
                if type(record.original[class])=="table" then
                    for key,value in pairs(record.original[class]) do dst[key]=value end
                end
                record.overlay[class]=dst
            elseif type(dst) ~= "table" then dst={}; record.overlay[class]=dst end
            if dst.r~=color.r or dst.g~=color.g or dst.b~=color.b then changed=true end
            dst.r,dst.g,dst.b,dst.colorStr=color.r,color.g,color.b,color.colorStr
        end
    end
    if changed then Refresh(S) end
    updating=false
end

-- The override is for this session. Restore original profile tables before save.
local f=CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGOUT")
f:SetScript("OnEvent",function()
    loggingOut=true
    for profile,record in pairs(profiles) do
        if profile.classColors==record.overlay then profile.classColors=record.original end
    end
end)

end
