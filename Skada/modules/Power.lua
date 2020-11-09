local Skada = Skada
if not Skada then
    return
end

local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)

local tostring, tonumber = tostring, tonumber
local pairs, ipairs, select = pairs, ipairs, select
local format = string.format
local GetSpellInfo = GetSpellInfo

local mod = Skada:NewModule(L["Power gained"])
local _playermod = {}

local locales = {
    mana = MANA,
    energy = ENERGY,
    rage = RAGE,
    runicpower = RUNIC_POWER
}

-- returns the proper power type
local function fix_power_type(t)
    local p

    if t == 0 then
        p = "mana"
    elseif t == 1 then
        p = "rage"
    elseif t == 3 then
        p = "energy"
    elseif t == 6 then
        p = "runicpower"
    end

    return p
end

local function log_gain(set, gain)
    -- if we don't have a type then we don't proceed
    if not gain.type then
        return
    end

    -- Get the player from set.
    local player = Skada:get_player(set, gain.playerid, gain.playername)
    if not player then
        return
    end

    player.power = player.power or {}

    -- Make sure power type exists.
    if not player.power[gain.type] then
        player.power[gain.type] = {spells = {}, amount = 0}
    end

    -- Add to player total.
    player.power[gain.type].amount = player.power[gain.type].amount + gain.amount

    if not player.power[gain.type].spells[gain.spellid] then
        player.power[gain.type].spells[gain.spellid] = 0
    end
    player.power[gain.type].spells[gain.spellid] = player.power[gain.type].spells[gain.spellid] + gain.amount

    set.power = set.power or {}
    -- Make sure set power type exists.
    if not set.power[gain.type] then
        set.power[gain.type] = 0
    end

    -- Also add to set total gain.
    set.power[gain.type] = set.power[gain.type] + gain.amount
end

local gain = {}

local function SpellEnergize(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    -- Healing
    local spellid, spellname, spellschool, amount, powertype = ...

    gain.playerid = srcGUID
    gain.playername = srcName
    gain.playerflags = srcFlags
    gain.spellid = spellid
    gain.spellname = spellname
    gain.amount = amount
    gain.type = fix_power_type(tonumber(powertype))

    -- no need to record anything if the module is disabled or invalid gain type
    if
        (gain.type == "mana" and Skada:IsDisabled("Power gained: Mana")) or
            (gain.type == "energy" and Skada:IsDisabled("Power gained: Energy")) or
            (gain.type == "rage" and Skada:IsDisabled("Power gained: Rage")) or
            (gain.type == "runicpower" and Skada:IsDisabled("Power gained: Runic Power")) or
            (not locales[gain.type])
     then
        return
    end

    Skada:FixPets(gain)
    log_gain(Skada.current, gain)
    log_gain(Skada.total, gain)
end

local function SpellLeech(timestamp, eventtype, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, ...)
    local spellid, spellname, spellschool, amount, powertype, extraamount = ...
    SpellEnergize(
        timestamp,
        eventtype,
        dstGUID,
        dstName,
        dstFlags,
        srcGUID,
        srcName,
        srcFlags,
        spellid,
        spellname,
        spellschool,
        extraamount,
        powertype
    )
end

function _playermod:Enter(win, id, label)
    self.playerid = id
    self.title = format(L["%s's gained %s"], label, locales[self.power])
end

-- Detail view of a player.
function _playermod:Update(win, set)
    local player = Skada:find_player(set, self.playerid)
    local power = self.power
    local max = 0

    if player and power and player.power[power] then
        local nr = 1

        for spellid, amount in pairs(player.power[power].spells) do
            local d = win.dataset[nr] or {}
            win.dataset[nr] = d

            local name, _, icon = GetSpellInfo(spellid)

            d.id = spellid
            d.spellid = spellid
            d.label = name
            d.icon = icon

            d.value = amount
            if power == "mana" then
                d.valuetext =
                    Skada:FormatValueText(
                    Skada:FormatNumber(amount),
                    mod.metadata.columns.Power,
                    format("%02.1f%%", amount / player.power[power].amount * 100),
                    mod.metadata.columns.Percent
                )
            else
                d.valuetext =
                    Skada:FormatValueText(
                    amount,
                    mod.metadata.columns.Power,
                    format("%02.1f%%", amount / player.power[power].amount * 100),
                    mod.metadata.columns.Percent
                )
            end

            if amount > max then
                max = amount
            end

            nr = nr + 1
        end
    end

    win.metadata.maxvalue = max
end

function mod:OnEnable()
    mod.metadata = {columns = {Power = true, Percent = true}}
    Skada:RegisterForCL(SpellEnergize, "SPELL_ENERGIZE", {src_is_interesting = true})
    Skada:RegisterForCL(SpellEnergize, "SPELL_PERIODIC_ENERGIZE", {src_is_interesting = true})
    Skada:RegisterForCL(SpellEnergize, "SPELL_LEECH", {src_is_interesting = true})
    Skada:RegisterForCL(SpellEnergize, "SPELL_PERIODIC_LEECH", {dst_is_interesting = true})
    Skada:AddColumnOptions(self)
end

-- Called by Skada when a new player is added to a set.
function mod:AddPlayerAttributes(player)
    if not player.power then
        player.power = {}
    end
end

-- Called by Skada when a new set is created.
function mod:AddSetAttributes(set)
    if not set.power then
        set.power = {}
    end
end

-- ================== --
-- Power gained: Mana --
-- ================== --
Skada:AddLoadableModule(
    "Power gained: Mana",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Power gained", "Power gained: Mana") then
            return
        end

        local manamod = mod:NewModule(L["Power gained: Mana"])

        local playermod = manamod:NewModule(L["Mana gained spell list"])
        playermod.Enter = _playermod.Enter
        playermod.Update = _playermod.Update

        function manamod:Update(win, set)
            local nr, max = 1, 0
            local power = "mana"
            playermod.power = power

            for i, player in pairs(set.players) do
                if player.power and player.power[power] then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec
                    d.power = power

                    d.value = player.power[power].amount
                    d.valuetext =
                        Skada:FormatValueText(
                        Skada:FormatNumber(d.value),
                        mod.metadata.columns.Power,
                        format("%02.1f%%", d.value / math.max(1, set.power[power]) * 100),
                        mod.metadata.columns.Percent
                    )

                    if d.value > max then
                        max = d.value
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function manamod:OnEnable()
            playermod.metadata = {}
            manamod.metadata = {showspots = true, click1 = playermod}
            Skada:AddMode(self, L["Power gained"])
        end

        function manamod:OnDisable()
            Skada:RemoveMode(self)
        end

        function manamod:GetSetSummary(set)
            return Skada:FormatNumber(set.power and set.power.mana or 0)
        end
    end
)

-- ================== --
-- Power gained: Rage --
-- ================== --
Skada:AddLoadableModule(
    "Power gained: Rage",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Power gained", "Power gained: Rage") then
            return
        end

        local ragemod = mod:NewModule(L["Power gained: Rage"])

        local playermod = ragemod:NewModule(L["Rage gained spell list"])
        playermod.Enter = _playermod.Enter
        playermod.Update = _playermod.Update

        function ragemod:Update(win, set)
            local nr, max = 1, 0
            local power = "rage"
            playermod.power = power

            for i, player in pairs(set.players) do
                if player.power and player.power[power] then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec
                    d.power = power

                    d.value = player.power[power].amount
                    d.valuetext =
                        Skada:FormatValueText(
                        d.value,
                        mod.metadata.columns.Power,
                        format("%02.1f%%", d.value / math.max(1, set.power[power]) * 100),
                        mod.metadata.columns.Percent
                    )

                    if d.value > max then
                        max = d.value
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function ragemod:OnEnable()
            playermod.metadata = {}
            ragemod.metadata = {showspots = true, click1 = playermod}
            Skada:AddMode(self, L["Power gained"])
        end

        function ragemod:OnDisable()
            Skada:RemoveMode(self)
        end

        function ragemod:GetSetSummary(set)
            return set.power and set.power.rage or 0
        end
    end
)
-- ==================== --
-- Power gained: Energy --
-- ==================== --
Skada:AddLoadableModule(
    "Power gained: Energy",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Power gained", "Power gained: Energy") then
            return
        end

        local energymod = mod:NewModule(L["Power gained: Energy"])

        local playermod = energymod:NewModule(L["Energy gained spell list"])
        playermod.Enter = _playermod.Enter
        playermod.Update = _playermod.Update

        function energymod:Update(win, set)
            local nr, max = 1, 0
            local power = "energy"
            playermod.power = power

            for i, player in pairs(set.players) do
                if player.power and player.power[power] then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec
                    d.power = power

                    d.value = player.power[power].amount
                    d.valuetext =
                        Skada:FormatValueText(
                        d.value,
                        mod.metadata.columns.Power,
                        format("%02.1f%%", d.value / math.max(1, set.power[power]) * 100),
                        mod.metadata.columns.Percent
                    )

                    if d.value > max then
                        max = d.value
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function energymod:OnEnable()
            playermod.metadata = {}
            energymod.metadata = {showspots = true, click1 = playermod}
            Skada:AddMode(self, L["Power gained"])
        end

        function energymod:OnDisable()
            Skada:RemoveMode(self)
        end

        function energymod:GetSetSummary(set)
            return set.power and set.power.energy or 0
        end
    end
)

-- ========================= --
-- Power gained: Runic Power --
-- ========================= --
Skada:AddLoadableModule(
    "Power gained: Runic Power",
    nil,
    function(Skada, L)
        if Skada:IsDisabled("Power gained", "Power gained: Runic Power") then
            return
        end

        local runicmod = mod:NewModule(L["Power gained: Runic Power"])

        local playermod = runicmod:NewModule(L["Runic Power gained spell list"])
        playermod.Enter = _playermod.Enter
        playermod.Update = _playermod.Update

        function runicmod:Update(win, set)
            local nr, max = 1, 0
            local power = "runicpower"
            playermod.power = power

            for i, player in pairs(set.players) do
                if player.power and player.power[power] then
                    local d = win.dataset[nr] or {}
                    win.dataset[nr] = d

                    d.id = player.id
                    d.label = player.name
                    d.class = player.class
                    d.role = player.role
                    d.spec = player.spec
                    d.power = power

                    d.value = player.power[power].amount
                    d.valuetext =
                        Skada:FormatValueText(
                        d.value,
                        mod.metadata.columns.Power,
                        format("%02.1f%%", d.value / math.max(1, set.power[power]) * 100),
                        mod.metadata.columns.Percent
                    )

                    if d.value > max then
                        max = d.value
                    end

                    nr = nr + 1
                end
            end

            win.metadata.maxvalue = max
        end

        function runicmod:OnEnable()
            playermod.metadata = {}
            runicmod.metadata = {showspots = true, click1 = playermod}
            Skada:AddMode(self, L["Power gained"])
        end

        function runicmod:OnDisable()
            Skada:RemoveMode(self)
        end

        function runicmod:GetSetSummary(set)
            return set.power and set.power.runicpower or 0
        end
    end
)