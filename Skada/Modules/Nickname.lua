assert(Skada, "Skada not found!")
Skada:AddLoadableModule("Nickname", function(Skada, L)
    if Skada:IsDisabled("Nickname") then return end

    local mod = Skada:NewModule(L["Nickname"], "AceHook-3.0")
    local unitName, unitGUID
    local CheckNickname

    do
        local function trim(str)
            local from = str:match("^%s*()")
            return from > #str and "" or str:match(".*%S", from)
        end

        local function titlecase(first, rest)
            return first:upper() .. rest:lower()
        end

        local have_repeated = false
        local count_spaces = 0

        local function check_repeated(char)
            if char == "  " then
                have_repeated = true
            elseif string.len(char) > 2 then
                have_repeated = true
            elseif char == " " then
                count_spaces = count_spaces + 1
            end
        end

        function CheckNickname(name)
            if type(name) ~= "string" then
                return false, L["Nickname isn't a valid string."]
            end

            name = trim(name)

            local len = string.len(name)
            if len > 12 then
                return false, L["Your nickname is too long, max of 12 characters is allowed."]
            end

            local notallow = string.find(name, "[^a-zA-Z�������%s]")
            if notallow then
                return false, L["Only letters and two spaces are allowed."]
            end

            have_repeated = false
            count_spaces = 0
            string.gsub(name, ".", "\0%0%0"):gsub("(.)%z%1", "%1"):gsub("%z.([^%z]+)", check_repeated)
            if count_spaces > 2 then
                have_repeated = true
            end
            if have_repeated then
                return false, L["You can't use the same letter three times consecutively, two spaces consecutively or more then two spaces."]
            end

            return true, name:gsub("(%a)([%w_']*)", titlecase)
        end
    end

    -- module options
    local options = {
        type = "group",
        name = L["Nickname"],
        get = function(i)
            return Skada.db.profile[i[#i]]
        end,
        set = function(i, val)
            Skada.db.profile[i[#i]] = val
            Skada:ApplySettings()
        end,
        args = {
            nickname = {
                type = "input",
                name = L["Nickname"],
                desc = L["Set a nickname for you.\nNicknames are sent to group members and Skada can use them instead of your character name."],
                order = 1,
                get = function()
                    return Skada.db.profile.nickname or UnitName("player")
                end,
                set = function(_, val)
                    local okey, nickname = CheckNickname(val)
                    if okey == true then
                        Skada.db.profile.nickname = nickname
                        mod:SetNickname(unitGUID, nickname, true)
                        Skada:ApplySettings()
                    else
                        Skada:Print(nickname)
                    end
                end
            },
            namedisplay = {
                type = "select",
                name = L["Name display"],
                desc = L["Choose how names are shown on your bars."],
                order = 2,
                values = {
                    [1] = NAME,
                    [2] = L["Nickname"],
                    [3] = NAME .. " (" .. L["Nickname"] .. ")",
                    [4] = L["Nickname"] .. " (" .. NAME .. ")"
                }
            },
            ignorenicknames = {
                type = "toggle",
                name = L["Ignore Nicknames"],
                desc = L["When enabled, nicknames set by Skada users are ignored."],
                order = 3,
                width = "full"
            }
        }
    }

    function mod:OnInitialize()
        unitName = select(1, UnitName("player"))
        unitGUID = UnitGUID("player")
        Skada.options.args.modules.args.nickname = options
        if Skada.db.profile.namedisplay == nil then
            Skada.db.profile.namedisplay = 1
        end
    end

    function mod:OnEnable()
        self:SetCacheTable()

        Skada.RegisterCallback(self, "OnCommNicknameRequest")
        Skada.RegisterCallback(self, "OnCommNicknameResponse")
        Skada.RegisterCallback(self, "OnCommNicknameChange")
        Skada.RegisterCallback(self, "FixPlayer")
        Skada.RegisterCallback(self, "BarUpdate")
        self:Hook(Skada, "find_player")
    end

    function mod:OnDisable()
        Skada.db.global.nicknames = nil
        self.db = nil
        self:UnHook(Skada, "find_player")
    end

    -----------------------------------------------------------
    -- hooked functions

    -- this function only laters the data.label according to our settings.
    function mod:BarUpdate(_, win, data)
        if Skada.db.profile.ignorenicknames then
            return
        end
        if not win or not data or not data.label then
            return
        end

        if (data.class or data.role) and (Skada.db.profile.namedisplay or 0) > 1 then
            local player = Skada:find_player(win:get_selected_set(), data.id)
            if player and player.nickname and player.nickname ~= "" and player.nickname ~= player.name then
                if Skada.db.profile.namedisplay == 2 then
                    data.label = player.nickname
                elseif Skada.db.profile.namedisplay == 3 then
                    data.label = player.name .. " (" .. player.nickname .. ")"
                elseif Skada.db.profile.namedisplay == 4 then
                    data.label = player.nickname .. " (" .. player.name .. ")"
                end
            end
        end
    end

    -- we make sure to add the player's nickname if not set.
    -- if it's the player themselves, we use what's stored.
    -- otherwise we requrest the nickname from the other skada user.
    function mod:FixPlayer(_, player)
        if not Skada.db.profile.ignorenicknames and player.id and player.name then
            if not player.nickname then
                if player.id == unitGUID then
                    if Skada.db.profile.nickname and Skada.db.profile.nickname ~= "" then
                        player.nickname = Skada.db.profile.nickname
                    else
                        player.nickname = unitName
                    end
                elseif self.db and self.db.nicknames[player.id] then
                    player.nickname = self.db.nicknames[player.id]
                else
                    Skada:SendComm("WHISPER", player.name, "NicknameRequest")
                end
            end
        end
    end

    -- this function is called only once in case we don't receive
    -- a response from the player, it will simply set his/her name
    -- as the nickname to avoid further check.
    function mod:find_player(_, set, guid)
        if not Skada.db.profile.ignorenicknames and set and guid then
            for _, player in ipairs(set.players) do
                if player.id == guid then
                    if not player.nickname then -- we update only if needed.
                        if self.db.nicknames[guid] then
                            player.nickname = self.db.nicknames[guid]
                        else
                            player.nickname = player.name
                            self.db.nicknames[guid] = player.nickname
                        end
                        -- update cached
                        if set._playeridx and set._playeridx[guid] then
                            set._playeridx[guid].nickname = player.nickname
                        end
                    end
                    break -- no need to go further
                end
            end
        end
    end

    -----------------------------------------------------------
    -- sync functions

    -- called whenever we receive a nickname request.
    function mod:OnCommNicknameRequest(_, sender)
        if not Skada.db.profile.ignorenicknames then
            Skada:SendComm("WHISPER", sender, "NicknameResponse", unitGUID, Skada.db.profile.nickname)
        end
    end

    -- called whenever we receive a nickname response
    function mod:OnCommNicknameResponse(_, sender, playerid, nickname)
        if not Skada.db.profile.ignorenicknames then
            -- the player didn't send us the nickname or doesn't
            -- have a nickname set? Set it to his/her name anyways.
            if not nickname or nickname == "" then
                nickname = sender
            end
            self:SetNickname(playerid, nickname, false)
        end
    end

    -- if someone in our group changes the nickname, we update the cache
    function mod:OnCommNicknameChange(_, sender, playerid, nickname)
        if not Skada.db.profile.ignorenicknames then
            if not nickname or nickname == "" then
                nickname = sender
            end
            if not self.db then
                self:SetCacheTable()
            end
            self.db.nicknames[playerid] = nickname
        end
    end

    -----------------------------------------------------------

    function mod:SetNickname(guid, nickname, sync)
        self.db.nicknames[guid] = nickname
        if guid == unitGUID and sync then
            Skada:SendComm(nil, nil, "NicknameChange", guid, nickname)
        end
    end

    -----------------------------------------------------------
    -- cache table functions

    function mod:SetCacheTable()
        self.db = Skada.db.global.nicknames or {nicknames = {}}
        Skada.db.global.nicknames = self.db
        self:CheckForReset()
    end

    function mod:CheckForReset()
        if not self.db then
            self.db = Skada.db.global.nicknames or {nicknames = {}}
            Skada.db.global.nicknames = self.db
        end

        if not self.db.nextreset then
            self.db.nextreset = time() + (60 * 60 * 24 * 15)
            self.db.nicknames = {}
        elseif time() > self.db.nextreset then
            self.db.nextreset = time() + (60 * 60 * 24 * 15)
            self.db.nicknames = {}
        end
    end
end)