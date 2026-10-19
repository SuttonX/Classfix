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
