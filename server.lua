local playerCache = {}
local apiReady = false

local function extractPlayerIdentifiers(player)
    if not player or not GetPlayerName(player) then return end
    local ids = {}
    for _, identifier in ipairs(GetPlayerIdentifiers(player)) do
        local key, value = table.unpack(string.split(identifier, ':'))
        ids[key] = value
    end
    return ids
end

local function sanitizeText(text)
    return text:gsub("[%z\1-\127\194-\244][\128-\191]*", function(c)
        return (c:byte() > 127 and c:byte() <= 244) and '' or c
    end)
end

local function isNonEmpty(str)
    return str:match("%S") ~= nil
end

local function getDiscordMember(player, rolesOnly)
    local ids = extractPlayerIdentifiers(player)
    if not ids or not ids.discord then return end

    local p = promise.new()
    local discordId = ids.discord
    local url = ('https://discord.com/api/guilds/%s/members/%s'):format(Config.DiscordServerId, discordId)
    local headers = {
        ['Authorization'] = ('Bot %s'):format(Config.BotToken),
        ['Content-Type'] = 'application/json'
    }

    PerformHttpRequest(url, function(code, body)
        local memberInfo = {}
        local exists = body and true or false
        body = json.decode(body)

        if body then
            local roleList = {}
            if type(body?.roles) == 'table' then
                for i, r in ipairs(body.roles) do
                    roleList[i] = tonumber(r)
                end
            end

            if rolesOnly then
                memberInfo = roleList
            else
                if body?.user then
                    local u = body.user
                    memberInfo.name = (u.username and u.discriminator) and ('%s#%s'):format(u.username, u.discriminator) or nil
                    if u.avatar then
                        local ext = u.avatar:sub(1,1) == '_' and 'gif' or 'png'
                        memberInfo.avatar = ('https://cdn.discordapp.com/avatars/%s/%s.%s'):format(discordId, u.avatar, ext)
                    end
                end
                memberInfo.roles = roleList
            end
        end

        p:resolve(exists and {memberInfo} or {false})
    end, 'GET', '', headers)

    return table.unpack(Citizen.Await(p))
end

local function validateServer(cb)
    local url = ('https://discord.com/api/guilds/%s'):format(Config.DiscordServerId)
    local headers = {
        ['Authorization'] = ('Bot %s'):format(Config.BotToken),
        ['Content-Type'] = 'application/json'
    }

    PerformHttpRequest(url, function(code, body)
        if code == 200 then
            apiReady = true
            cb(json.decode(body).name)
        else
            cb(false)
        end
    end, 'GET', '', headers)
end

RegisterNetEvent('mvp_discordapi:verify_player', function()
    if not apiReady then return end
    local src = source
    local memberData = getDiscordMember(src)

    if not memberData then
        print(('[MVP API] %s (ID: %s) connected but not in Discord.'):format(GetPlayerName(src), src))
    else
        playerCache[src] = memberData
        print(('[MVP API] %s (ID: %s) connected with %s Discord roles.'):format(GetPlayerName(src), src, #memberData.roles))
    end
end)

local function getPlayerRoles(player) return playerCache[player] and playerCache[player].roles or false end
local function getPlayerName(player) return playerCache[player] and playerCache[player].name or false end
local function getPlayerAvatar(player) return playerCache[player] and playerCache[player].avatar or false end
local function getPlayerInfo(player) return playerCache[player] or false end

local function hasDiscordRole(player, roleCheck, stack)
    local roles = getPlayerRoles(player)
    if not roles then return false end
    local found = {}
    if type(roleCheck) == 'table' then
        for _, r in ipairs(roles) do
            if table.contains(roleCheck, tonumber(r)) then
                if stack then table.insert(found, r) else return true, r end
            end
        end
    else
        for _, r in ipairs(roles) do
            if tonumber(r) == tonumber(roleCheck) then return true end
        end
    end
    return stack and #found > 0 and found or false
end

exports('getPlayerRoles', getPlayerRoles)
exports('getPlayerName', getPlayerName)
exports('getPlayerAvatar', getPlayerAvatar)
exports('getPlayerInfo', getPlayerInfo)
exports('hasDiscordRole', hasDiscordRole)

CreateThread(function()
    if not (Config.BotToken and isNonEmpty(Config.BotToken)) then
        return print('[MVP API] ERROR: Bot token missing or invalid.')
    end
    if not (Config.DiscordServerId and isNonEmpty(Config.DiscordServerId)) then
        return print('[MVP API] ERROR: DiscordServerId missing or invalid.')
    end

    validateServer(function(name)
        if name then
            print(('[MVP API] SUCCESS: Connected to Discord server: %s'):format(sanitizeText(name)))
        else
            print('[MVP API] ERROR: Invalid DiscordServerId or bot token.')
        end
    end)
end)