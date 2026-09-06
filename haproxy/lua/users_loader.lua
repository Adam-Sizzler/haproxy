local M = {}

local CSV_PATTERN = "^([^,]+),(.+)$"

function M.load_users_file(path)
    local users = {
        vless = {},   -- map: clean_uuid (32 chars) -> username
        trojan = {},  -- map: sha224 (56 chars) -> username
        anytls = {},  -- map: sha256 hex (64 chars) -> username
        naive = {}    -- map: base64_token -> username
    }

    local f = io.open(path, "r")
    if not f then
        if core and core.Warning then
            core.Warning("Lua: cannot open users file: " .. path)
        end
        return users
    end

    for line in f:lines() do
        -- Пропускаем пустые строки
        if line ~= "" then
            local username, cred = line:match(CSV_PATTERN)

            if username and cred then
                username = username:match("^%s*(.-)%s*$")
                cred = cred:match("^%s*(.-)%s*$")

                -- Проверяем NaiveProxy токен (basic:<token> или Basic <token>)
                local naive_token = cred:match("^[Bb][Aa][Ss][Ii][Cc]:%s*(.+)$")
                                 or cred:match("^[Bb][Aa][Ss][Ii][Cc]%s+(.+)$")

                if naive_token then
                    naive_token = naive_token:match("^%s*(.-)%s*$")
                    if #naive_token > 0 then
                        users.naive[naive_token] = username
                    end
                else
                    local len = #cred
                    if len == 64 then
                        -- SHA256 hex (AnyTLS)
                        users.anytls[cred] = username
                    elseif len == 56 then
                        -- SHA224 (Trojan)
                        users.trojan[cred] = username
                    elseif len == 32 then
                        -- UUID (VLESS) - убираем дефисы только если длина похожа на UUID с дефисами (36) или без (32)
                        -- Но в твоем коде логика была на 32. Если в файле UUID без дефисов:
                        users.vless[cred] = username
                    elseif len == 36 then
                        -- Если в файле UUID с дефисами (стандарт), убираем их "на лету"
                        local clean = cred:gsub("-", "")
                        if #clean == 32 then
                            users.vless[clean] = username
                        end
                    end
                end
            end
        end
    end

    f:close()
    return users
end

return M
