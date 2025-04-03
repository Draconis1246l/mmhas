local HttpService = game:GetService("HttpService")
local replicatedStorage = game:GetService("ReplicatedStorage")

-- Configura tu URL base de Firebase
local firebaseBase = "https://dataruns-1a46d-default-rtdb.firebaseio.com"

-- Configura tu webhook de Discord
local webhookUrl = "https://discord.com/api/webhooks/1351710923936628889/ndpfKfLQfsM1AyJCMbS5tkDmPQ8h9kN2902x3KppzrGCXPXL_dr3oOydL0jjzRit4u95"

-- Lista de bosses a detectar
local targetBosses = {
    ["Elder Treant"] = true,
    ["Mother Spider"] = true,
    ["Dire Bear"] = true
}

local gameId = game.PlaceId
local serverId = game.JobId

-- Función para enviar mensajes al webhook de Discord
local function sendWebhookMessage(message)
    local data = { content = message }
    local requestFunction = (syn and syn.request) or (http and http.request) or request
    if requestFunction then
        requestFunction({
            Url = webhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end
end

-- Función para obtener la información del servidor
local function getServerInfo()
    local info = {
        serverAge = "Desconocido",
        serverRegion = "Desconocida",
        serverName = "Desconocido"
    }
    local globalSettings = replicatedStorage:FindFirstChild("GlobalSettings")
    if globalSettings then
        local ageObj = globalSettings:FindFirstChild("ServerAge")
        local regionObj = globalSettings:FindFirstChild("ServerRegion")
        local nameObj = globalSettings:FindFirstChild("ServerName")
        if ageObj and ageObj:IsA("StringValue") then info.serverAge = ageObj.Value end
        if regionObj and regionObj:IsA("StringValue") then info.serverRegion = regionObj.Value end
        if nameObj and nameObj:IsA("StringValue") then info.serverName = nameObj.Value end
    end
    return info
end

-- Función para registrar en Firebase la detección de un boss
local function logBossDetection(bossName)
    local serverInfo = getServerInfo()
    local report = {
        boss = bossName,
        serverId = serverId,
        gameId = gameId,
        serverName = serverInfo.serverName,
        serverRegion = serverInfo.serverRegion,
        serverAge = serverInfo.serverAge,
        timestamp = os.time()
    }
    
    local key = serverId .. "_" .. bossName .. "_" .. tostring(os.time())
    local url = firebaseBase .. "/bossreports/" .. key .. ".json"
    local jsonData = HttpService:JSONEncode(report)

    local requestFunction = (syn and syn.request) or (http and http.request) or request
    if requestFunction then
        local response = requestFunction({
            Url = url,
            Method = "PUT",
            Headers = { ["Content-Type"] = "application/json" },
            Body = jsonData
        })

        if response and response.StatusCode == 200 then
            print("✅ Boss reportado correctamente: " .. bossName)
        else
            warn("❌ Error reportando boss: " .. bossName)
        end
    end
end

-- Función para detectar bosses en la carpeta "Alive"
local function detectBossesLocal()
    local found = {}
    local aliveFolder = game.Workspace:FindFirstChild("Alive")
    if aliveFolder then
        for _, obj in pairs(aliveFolder:GetChildren()) do
            if obj:IsA("Model") then
                local nameLower = obj.Name:lower()
                for boss, _ in pairs(targetBosses) do
                    if string.find(nameLower, boss:lower()) then
                        table.insert(found, boss)
                    end
                end
            end
        end
    end
    return found
end

-- Función para registrar bosses locales en Firebase
local function logLocalBosses()
    local bosses = detectBossesLocal()
    for _, boss in ipairs(bosses) do
        logBossDetection(boss)
    end
end

-- Función para obtener reports globales desde Firebase
local function getGlobalBossReports()
    local url = firebaseBase .. "/bossreports.json"
    local requestFunction = (syn and syn.request) or (http and http.request) or request

    if requestFunction then
        local response = requestFunction({
            Url = url,
            Method = "GET",
            Headers = { ["Content-Type"] = "application/json" }
        })

        if response and response.StatusCode == 200 then
            local data = HttpService:JSONDecode(response.Body)
            return data or {}
        else
            warn("❌ Error obteniendo reports globales")
            return {}
        end
    end
end

-- Función para compilar los reports globales y enviarlos a Discord
local function reportGlobalBosses()
    local reports = getGlobalBossReports()
    local message = "**🌍 Global Boss Report:**\n"

    if next(reports) then
        for key, report in pairs(reports) do
            message = message .. "⚔️ **" .. report.boss .. "** en servidor **" .. report.serverName .. "** (" .. report.serverRegion .. "), Edad: " .. report.serverAge .. " - [JobID: " .. report.serverId .. "]\n"
        end
    else
        message = message .. "No se encontraron reports globales."
    end

    sendWebhookMessage(message)
end

-- 🏁 Ejecutar funciones principales
logLocalBosses()
reportGlobalBosses()
