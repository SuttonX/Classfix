local _, ns = ...
if ns.alreadyLoaded then return end
local overrides = {ROGUE="808588", PALADIN="f5b000"}

local function SetHex(picker, hex)
    local r,g,b=tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255
    picker:SetValue(r,g,b)
    picker.swatch:SetVertexColor(r,g,b)
end

local function ApplyDefaults(blizzard)
    for _,picker in ipairs(ns.Pickers) do
        local color=ns.BlizzardDefaults[picker.class]
        local hex=not blizzard and overrides[picker.class]
        if hex then SetHex(picker,hex)
        else
            picker:SetValue(color.r,color.g,color.b)
            picker.swatch:SetVertexColor(color.r,color.g,color.b)
        end
    end
    ns.Dispatch()
    print("Classfix: "..(blizzard and "Blizzard" or "Classfix").." defaults applied. Use /reload to refresh cached addon colors.")
end

local function Status()
    local _,class=UnitClass("player")
    local function rgb(c)
        if type(c)~="table" then return "unavailable" end
        return string.format("%.3f / %.3f / %.3f",c.r or c[1] or 0,c.g or c[2] or 0,c.b or c[3] or 0)
    end
    print("Classfix build 1.0.0 | ElvUI bridge: "..tostring(ns.ElvUIIntegrationLoaded).." | SUF bridge: "..tostring(ns.ShadowUFIntegrationLoaded))
    print("Palette "..tostring(class)..": "..rgb(CUSTOM_CLASS_COLORS[class]))
    local E=type(ElvUI)=="table" and ElvUI[1]
    print("ElvUI accent: "..rgb(E and E.media and E.media.rgbvaluecolor))
    local S=ShadowUF
    print("SUF class color: "..rgb(S and S.db and S.db.profile and S.db.profile.classColors and S.db.profile.classColors[class]))
end

SLASH_CLASSFIX1="/classfix"
SlashCmdList.CLASSFIX=function(message)
    local command=(message or ""):lower():match("^%s*(.-)%s*$")
    if command=="default" or command=="defaults" then ApplyDefaults(false)
    elseif command=="blizzard" then ApplyDefaults(true)
    elseif command=="status" then Status()
    elseif command:match("^set%s") then
        local class,hex=command:match("^set%s+([a-z]+)%s+#?([a-f0-9]+)$")
        if class and hex and #hex==6 then
            class=class:upper()
            for _,picker in ipairs(ns.Pickers) do
                if picker.class==class then
                    SetHex(picker,hex);ns.Dispatch()
                    print("Classfix: "..class.." set to #"..hex:upper()..". Use /reload to refresh cached addon colors.")
                    return
                end
            end
        end
        print("Classfix: use /classfix set CLASS RRGGBB (example: /classfix set rogue 808588).")
    else
        InterfaceOptionsFrame_OpenToCategory(ClassfixOptions)
        InterfaceOptionsFrame_OpenToCategory(ClassfixOptions)
    end
end

function ns.InitializeDefaults()
    ClassfixOptions.defaults=function() ApplyDefaults(false) end
    if not ClassfixDB.initialized then
        ApplyDefaults(false)
        ClassfixDB.initialized=true
    elseif (ClassfixDB.defaultsRevision or 1) < 3 then
        local previous={ROGUE="6b6b6b",PALADIN="efbf04"}
        for _,picker in ipairs(ns.Pickers) do
            local old=previous[picker.class]
            if old then
                local r,g,b=picker:GetValue()
                if ns.Hex(r,g,b):sub(3)==old then SetHex(picker,overrides[picker.class]) end
            end
        end
        ns.Dispatch()
    end
    ClassfixDB.defaultsRevision=3
end
