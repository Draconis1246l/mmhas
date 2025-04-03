local HttpService = game:GetService("HttpService")
local replicatedStorage = game:GetService("ReplicatedStorage")

-- Configura tu URL base de Firebase (reemplaza TU_PROYECTO por el identificador de tu proyecto)
local firebaseBase = "https://dataruns-1a46d-default-rtdb.firebaseio.com/"

-- Endpoint para los reports de bosses (se almacenarán en la colección "bossreports")
local firebaseBossEndpoint = firebaseBase .. "/bossreports.json"

-- Configura tu webhook de Discord
local webhookUrl = "https://discord.com/api/webhooks/1351710923936628889/ndpfKfLQfsM1AyJCMbS5tkDmPQ8h9kN2902x3KppzrGCXPXL_dr3oOydL0jjzRit4u95"

-- Lista de bosses a detectar (solo se reportan estos)
local targetBosses = {
    ["Elder Treant"] = true,
    ["Mother Spider"] = true,
    ["Dire Bear"] = true
}

-- Obtiene información del juego y del servidor actual
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

-- Función para obtener la información del servidor desde ReplicatedStorage.GlobalSettings
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

-- Función para registrar en Firebase la detección de un boss en el servidor actual
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
    -- Generamos una clave única combinando el serverId, el boss y la hora
    local key = serverId .. "_" .. bossName .. "_" .. tostring(os.time())
    local url = firebaseBase .. "/bossreports/" .. key .. ".json"
    local jsonData = HttpService:JSONEncode(report)
    local success, result = pcall(function()
        return HttpService:RequestAsync({
            Url = url,
            Method = "PUT",
            Headers = { ["Content-Type"] = "application/json" },
            Body = jsonData
        })
    end)
    if success then
        print("Reportado boss: " .. bossName)
    else
        warn("Error reportando boss: " .. bossName)
    end
end

-- Función para detectar bosses en la carpeta "Alive" del servidor actual
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

-- Función para que el servidor actual registre localmente sus bosses en Firebase
local function logLocalBosses()
    local bosses = detectBossesLocal()
    for _, boss in ipairs(bosses) do
        logBossDetection(boss)
    end
end

-- Función para obtener de Firebase los reports globales de bosses (de todos los servidores)
local function getGlobalBossReports()
    local success, response = pcall(function()
        return HttpService:GetAsync(firebaseBossEndpoint)
    end)
    if success then
        local data = HttpService:JSONDecode(response)
        return data
    else
        warn("Error obteniendo reports globales")
        return {}
    end
end

-- Función para compilar los reports globales y enviarlos a Discord
local function reportGlobalBosses()
    local reports = getGlobalBossReports()
    local message = "**Global Boss Report:**\n"
    if reports then
        for key, report in pairs(reports) do
            message = message .. "⚔️ **" .. report.boss .. "** en servidor **" .. report.serverName .. "** (" .. report.serverRegion .. "), Edad: " .. report.serverAge .. " - [JobID: " .. report.serverId .. "]\n"
        end
    else
        message = message .. "No se encontraron reports."
    end
    sendWebhookMessage(message)
end

--[[
  ► EJECUCIÓN:
  1. Se registran (si hay bosses) los bosses del servidor actual en Firebase.
  2. Se consulta Firebase para obtener los reports de todos los servidores y se envía el reporte global a Discord.
  
  Nota: Si otros servidores ya han ejecutado scripts similares, sus reports estarán disponibles en Firebase.
--]]

-- Registra los bosses del servidor actual en Firebase (si se detectan)
logLocalBosses()

-- Envía el reporte global (agregando los reports de todos los servidores)
reportGlobalBosses()
