-- auth.lua
package.path = "/etc/haproxy/lua/?.lua;" .. package.path

local loader = require("users_loader")

local PATH_USERS = "/etc/haproxy/data/users.csv"
local TROJAN_MIN_LEN = 66
local TROJAN_HASH_LEN = 56
local VLESS_MIN_LEN = 17
-- AnyTLS auth packet: sha256(password) [32 raw bytes] + padding0 length (uint16 BE) [2 bytes] + padding0.
-- Мы читаем только первые 32 байта (сам хэш), поэтому 32 — это и необходимый,
-- и достаточный порог. Ставить его больше (например, 64, под дефолтный padding0=30)
-- нельзя: если сервер/клиент используют padding_scheme с paddingом короче дефолта
-- (или cmdUpdatePaddingScheme его уменьшит), пакет легитимного клиента окажется
-- короче завышенного порога, и мы ошибочно не распознаем anytls (false negative).
local ANYTLS_HASH_LEN = 32
local MUX_PATTERN = "sp%.mux"
local MUX_OFFSET = 59
local SHOW_USERS_MAX_DEFAULT = 200

local users_db = {
    vless = {},
    trojan = {},
    anytls = {}
}

local users_cache_meta = {
    reload_count = 0,
    last_reload_epoch = 0,
    last_error = "",
    vless_count = 0,
    trojan_count = 0,
    anytls_count = 0,
    usernames = {}
}

local function table_count(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

local function build_usernames(db)
    local dedup = {}
    for _, username in pairs(db.vless) do
        dedup[username] = true
    end
    for _, username in pairs(db.trojan) do
        dedup[username] = true
    end
    for _, username in pairs(db.anytls) do
        dedup[username] = true
    end

    local usernames = {}
    for username in pairs(dedup) do
        usernames[#usernames + 1] = username
    end
    table.sort(usernames)
    return usernames
end

local function format_epoch(epoch)
    if not epoch or epoch <= 0 then
        return "n/a"
    end
    return os.date("!%Y-%m-%dT%H:%M:%SZ", epoch)
end

local function reload_users_cache()
    local loaded = loader.load_users_file(PATH_USERS)
    users_db = loaded

    users_cache_meta.reload_count = users_cache_meta.reload_count + 1
    users_cache_meta.last_reload_epoch = os.time()
    users_cache_meta.last_error = ""
    users_cache_meta.vless_count = table_count(loaded.vless)
    users_cache_meta.trojan_count = table_count(loaded.trojan)
    users_cache_meta.anytls_count = table_count(loaded.anytls)
    users_cache_meta.usernames = build_usernames(loaded)
end

local function safe_reload_users_cache()
    local ok, err = pcall(reload_users_cache)
    if not ok then
        users_cache_meta.last_error = tostring(err)
        return false, tostring(err)
    end
    return true, ""
end

local function parse_positive_int(value, fallback, max_value)
    if value == nil or value == "" then
        return fallback
    end

    local num = tonumber(value)
    if not num then
        return fallback
    end

    num = math.floor(num)
    if num <= 0 then
        return fallback
    end

    if num > max_value then
        return max_value
    end

    return num
end

local function cli_reload_users(applet)
    local ok, err = safe_reload_users_cache()
    if not ok then
        applet:send("ERR reload users failed: " .. err .. "\n")
        return
    end

    applet:send(string.format(
        "OK reload users: users=%d vless=%d trojan=%d anytls=%d updated_at=%s reloads=%d\n",
        #users_cache_meta.usernames,
        users_cache_meta.vless_count,
        users_cache_meta.trojan_count,
        users_cache_meta.anytls_count,
        format_epoch(users_cache_meta.last_reload_epoch),
        users_cache_meta.reload_count
    ))
end

local function cli_show_users_cache(applet, arg1, arg2, arg3, arg4)
    local limit = parse_positive_int(arg4, SHOW_USERS_MAX_DEFAULT, 10000)
    local total = #users_cache_meta.usernames
    local shown = math.min(limit, total)

    applet:send(string.format(
        "users=%d vless=%d trojan=%d anytls=%d reloads=%d updated_at=%s\n",
        total,
        users_cache_meta.vless_count,
        users_cache_meta.trojan_count,
        users_cache_meta.anytls_count,
        users_cache_meta.reload_count,
        format_epoch(users_cache_meta.last_reload_epoch)
    ))

    if users_cache_meta.last_error ~= "" then
        applet:send("last_error=" .. users_cache_meta.last_error .. "\n")
    end

    for i = 1, shown do
        applet:send("user " .. users_cache_meta.usernames[i] .. "\n")
    end

    if shown < total then
        applet:send(string.format("... truncated: %d not shown\n", total - shown))
    end
end

local hex_table = {}
for i = 0, 255 do
    hex_table[i] = string.format("%02x", i)
end

local function tohex(str)
    local result = {}
    for i = 1, #str do
        result[i] = hex_table[string.byte(str, i)]
    end
    return table.concat(result)
end

local function check_trojan_mux(data)
    if data:find(MUX_PATTERN, MUX_OFFSET) then
        return true
    end
    return false
end

local function identify_protocol(txn)
    local status, data = pcall(function() return txn.req:dup() end)

    if not status or not data then
        return
    end

    local data_len = #data

    if data_len >= TROJAN_MIN_LEN then
        local text_hash = data:sub(1, TROJAN_HASH_LEN)
        local user = users_db.trojan[text_hash]

        if user then
            local is_mux = check_trojan_mux(data)
            local isMultiplex = is_mux and "trojan" or "trojan-nomux"
            txn:Info(string.format("Trojan login: %s; ip: %s", user, txn.sf:src()))
            return isMultiplex
        end
    end

    if data_len >= VLESS_MIN_LEN then
        local raw_uuid = data:sub(2, 17)
        local uuid_hex = tohex(raw_uuid)
        local user = users_db.vless[uuid_hex]

        if user then
            txn:Info(string.format("VLESS login: %s; ip: %s", user, txn.sf:src()))
            return "vless"
        end
    end

    if data_len >= ANYTLS_HASH_LEN then
        local raw_hash = data:sub(1, ANYTLS_HASH_LEN)
        -- Оптимизация: принудительно нижний регистр для точного совпадения с базой
        local hash_hex = tohex(raw_hash):lower()
        local user = users_db.anytls[hash_hex]

        if user then
            txn:Info(string.format("AnyTLS login: %s; ip: %s", user, txn.sf:src()))
            return "anytls"
        end
    end
end

do
    local ok, err = safe_reload_users_cache()
    if not ok and core and core.Warning then
        core.Warning("Lua: initial users cache load failed: " .. err)
    end
end

core.register_fetches("identify_protocol", identify_protocol)
core.register_cli({"lua", "reload", "users"}, "lua reload users", cli_reload_users)
core.register_cli({"lua", "show", "users", "cache"}, "lua show users cache [limit]", cli_show_users_cache)
