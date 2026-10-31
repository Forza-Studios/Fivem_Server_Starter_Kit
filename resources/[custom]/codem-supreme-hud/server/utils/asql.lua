local MySQL = MySQL
local sqlFilePath = "sql/hud.sql"
local debugEnabled = false
local dbReady = false

function debugLog(...)
    if debugEnabled then
        print("[ASQL]", ...)
    end
end

function readSqlFile()
    local fileContent = LoadResourceFile(GetCurrentResourceName(), sqlFilePath)
    if not fileContent then
        print("^1[ASQL] ERROR: Could not read SQL file: " .. sqlFilePath .. "^0")
        return nil
    end
    return fileContent
end

function stripComments(sqlContent)
    local lines = {}
    for line in sqlContent:gmatch("[^\r\n]+") do
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed ~= "" and not trimmed:match("^%-%-") then
            lines[#lines + 1] = line
        end
    end
    local result = table.concat(lines, "\n")
    result = result:gsub("/%*.-%*/", "")
    return result
end

function extractTableName(createStmt)
    local tableName = createStmt.match(createStmt, "CREATE%s+TABLE%s+IF%s+NOT%s+EXISTS%s+`([^`]+)`")
    if not tableName then
        tableName = createStmt.match(createStmt, "CREATE%s+TABLE%s+`([^`]+)`")
    end
    return tableName
end

function extractForeignKeys(createStmt)
    local foreignKeys = {}
    for refTable in createStmt.gmatch(createStmt, "REFERENCES%s+`([^`]+)`") do
        foreignKeys[#foreignKeys + 1] = refTable
    end
    return foreignKeys
end

function parseCreateStatements(sqlContent)
    local tables = {}
    local sortedOrder = {}
    local dependencies = {}

    for createStmt in sqlContent.gmatch(sqlContent, "(CREATE%s+TABLE[^;]+);") do
        local tableName = extractTableName(createStmt)
        if tableName then
            tables[tableName] = createStmt
            dependencies[tableName] = extractForeignKeys(createStmt)
            debugLog("Found table:", tableName, "deps:", json.encode(dependencies[tableName]))
        end
    end

    local visited = {}
    local visiting = {}

    function resolveOrder(tableName)
        if visiting[tableName] then
            print("^1[ASQL] Circular dependency detected for table: " .. tableName .. "^0")
            return
        end
        if visited[tableName] then
            return
        end
        visiting[tableName] = true

        local deps = dependencies[tableName]
        if not deps then
            deps = {}
        end
        for _, depTable in ipairs(deps) do
            if tables[depTable] then
                resolveOrder(depTable)
            end
        end

        visiting[tableName] = nil
        visited[tableName] = true
        sortedOrder[#sortedOrder + 1] = tableName
    end

    for tableName in pairs(tables) do
        if not visited[tableName] then
            resolveOrder(tableName)
        end
    end

    return tables, sortedOrder
end

function parseInsertStatements(sqlContent)
    local inserts = {}
    for insertStmt in sqlContent.gmatch(sqlContent, "(INSERT%s+INTO[^;]+);") do
        local tableName = insertStmt.match(insertStmt, "INSERT%s+INTO%s+`([^`]+)`")
        if tableName then
            if not inserts[tableName] then
                inserts[tableName] = {}
            end
            inserts[tableName][#inserts[tableName] + 1] = insertStmt
            debugLog("Found INSERT for table:", tableName)
        end
    end
    return inserts
end

function checkTableHasData(tableName)
    local count = MySQL.Sync.fetchScalar(("SELECT COUNT(*) FROM `%s`"):format(tableName))
    return count and count > 0
end

function checkTableExists(tableName)
    local ok, result = pcall(function()
        return MySQL.Sync.fetchScalar(("SELECT 1 FROM `%s` LIMIT 1"):format(tableName))
    end)
    if not ok then
        return false
    end
    return result ~= nil
end

function getTableColumns(tableName)
    local columns = {}
    local ok, rows = pcall(function()
        return MySQL.Sync.fetchAll(("SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE, COLUMN_DEFAULT, COLUMN_KEY, EXTRA FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = '%s'"):format(tableName))
    end)
    if not ok or not rows then
        return columns
    end
    if not rows then
        rows = {}
    end
    for _, row in ipairs(rows) do
        local colName = row.COLUMN_NAME
        local colInfo = {}
        colInfo.type = row.DATA_TYPE
        colInfo.nullable = "YES" == row.IS_NULLABLE
        colInfo.default = row.COLUMN_DEFAULT
        colInfo.key = row.COLUMN_KEY
        colInfo.extra = row.EXTRA
        columns[colName] = colInfo
    end
    return columns
end

function parseColumnDefinitions(createStmt)
    local columns = {}
    local body = createStmt.match(createStmt, "%((.+)%)")
    if not body then
        return columns
    end

    local parenDepth = 0
    local currentPart = ""
    local parts = {}

    for i = 1, #body do
        local char = body.sub(body, i, i)
        if "(" == char then
            parenDepth = parenDepth + 1
            currentPart = currentPart .. char
        elseif ")" == char then
            parenDepth = parenDepth - 1
            currentPart = currentPart .. char
        elseif "," == char and 0 == parenDepth then
            parts[#parts + 1] = currentPart.match(currentPart, "^%s*(.-)%s*$")
            currentPart = ""
        else
            currentPart = currentPart .. char
        end
    end

    if #currentPart > 0 then
        parts[#parts + 1] = currentPart.match(currentPart, "^%s*(.-)%s*$")
    end

    for _, part in ipairs(parts) do
        local isSkip = false
        if part.match(part, "^PRIMARY%s+KEY") then
            isSkip = true
        elseif part.match(part, "^INDEX%s+") then
            isSkip = true
        elseif part.match(part, "^KEY%s+") then
            isSkip = true
        elseif part.match(part, "^UNIQUE%s+") then
            isSkip = true
        elseif part.match(part, "^CONSTRAINT%s+") then
            isSkip = true
        elseif part.match(part, "^FOREIGN%s+KEY") then
            isSkip = true
        end

        if not isSkip then
            local colName = part.match(part, "^`([^`]+)`")
            if colName then
                columns[colName] = part
            end
        end
    end

    return columns
end

function executeSql(query)
    local ok, err = pcall(function()
        return MySQL.Sync.execute(query)
    end)
    if not ok then
        print("^1[ASQL] SQL Error: " .. tostring(err) .. "^0")
        return false
    end
    return true
end

local AutoSQL = {}

function initializeDatabase()
    print("^3[ASQL] Initializing database...^0")

    local fileContent = readSqlFile()
    if not fileContent then
        return false
    end

    fileContent = stripComments(fileContent)
    local tables, sortedOrder = parseCreateStatements(fileContent)
    local insertStatements = parseInsertStatements(fileContent)

    local tablesCreated = 0
    local columnsAdded = 0
    local seedsExecuted = 0
    local newlyCreatedTables = {}

    for _, tableName in ipairs(sortedOrder) do
        local createSql = tables[tableName]
        if not checkTableExists(tableName) then
            debugLog("Creating table:", tableName)
            if executeSql(createSql) then
                print("^2[ASQL] Created table: " .. tableName .. "^0")
                tablesCreated = tablesCreated + 1
                newlyCreatedTables[tableName] = true
            end
        else
            local existingColumns = getTableColumns(tableName)
            local definedColumns = parseColumnDefinitions(createSql)
            for colName, colDef in pairs(definedColumns) do
                if not existingColumns[colName] then
                    local alterSql = ("ALTER TABLE `%s` ADD COLUMN %s"):format(tableName, colDef)
                    debugLog("Adding column:", colName, "to", tableName)
                    if executeSql(alterSql) then
                        print("^2[ASQL] Added column: " .. tableName .. "." .. colName .. "^0")
                        columnsAdded = columnsAdded + 1
                    end
                end
            end
        end
    end

    for _, tableName in ipairs(sortedOrder) do
        local inserts = insertStatements[tableName]
        if inserts then
            local shouldSeed = newlyCreatedTables[tableName]
            if not shouldSeed then
                if checkTableExists(tableName) then
                    shouldSeed = not checkTableHasData(tableName)
                end
            end
            if shouldSeed then
                for _, insertSql in ipairs(inserts) do
                    if executeSql(insertSql) then
                        seedsExecuted = seedsExecuted + 1
                        debugLog("Seeded data into:", tableName)
                    end
                end
                if #inserts > 0 then
                    print("^2[ASQL] Seeded " .. #inserts .. " record(s) into: " .. tableName .. "^0")
                end
            end
        end
    end

    if tablesCreated > 0 or columnsAdded > 0 or seedsExecuted > 0 then
        print("^2[ASQL] Database initialized: " .. tablesCreated .. " tables created, " .. columnsAdded .. " columns added, " .. seedsExecuted .. " seed queries executed^0")
    else
        print("^2[ASQL] Database up to date^0")
    end

    return true
end
AutoSQL.initialize = initializeDatabase

function dropAllTables()
    print("^3[ASQL] WARNING: Dropping all HUD tables...^0")

    local fileContent = readSqlFile()
    if not fileContent then
        return false
    end

    fileContent = stripComments(fileContent)
    local _, sortedOrder = parseCreateStatements(fileContent)

    MySQL.Sync.execute("SET FOREIGN_KEY_CHECKS = 0")

    for i = #sortedOrder, 1, -1 do
        local tableName = sortedOrder[i]
        executeSql("DROP TABLE IF EXISTS `" .. tableName .. "`")
        print("^1[ASQL] Dropped table: " .. tableName .. "^0")
    end

    MySQL.Sync.execute("SET FOREIGN_KEY_CHECKS = 1")
    print("^2[ASQL] All HUD tables dropped^0")

    return true
end
AutoSQL.dropAllTables = dropAllTables

function resetDatabase()
    AutoSQL.dropAllTables()
    AutoSQL.initialize()
end
AutoSQL.resetDatabase = resetDatabase

RegisterCommand("hud:db:init", function(source)
    if 0 ~= source then
        print("[ASQL] This command can only be run from console")
        return
    end
    AutoSQL.initialize()
end, true)

RegisterCommand("hud:db:reset", function(source)
    if 0 ~= source then
        print("[ASQL] This command can only be run from console")
        return
    end
    print("[ASQL] Are you sure? This will delete ALL HUD data!")
    print("[ASQL] Run \"hud:db:reset:confirm\" to confirm")
end, true)

RegisterCommand("hud:db:reset:confirm", function(source)
    if 0 ~= source then
        print("[ASQL] This command can only be run from console")
        return
    end
    AutoSQL.resetDatabase()
end, true)

function isReady()
    return dbReady
end
AutoSQL.isReady = isReady

function waitForReady()
    if dbReady then
        return true
    end
    local timeout = 10000
    local elapsed = 0
    while true do
        if not (not dbReady and timeout > elapsed) then
            break
        end
        Wait(100)
        elapsed = elapsed + 100
    end
    return dbReady
end
AutoSQL.waitForReady = waitForReady

function WaitForDatabase()
    return AutoSQL.waitForReady()
end

CreateThread(function()
    if not Config.AutoSql then
        print("^5[ASQL] AutoSql disabled - Please import sql/hud.sql manually^0")
        dbReady = true
        return
    end
    Wait(500)
    AutoSQL.initialize()
    dbReady = true
    print("^2[ASQL] Ready for queries^0")
end)

rawset(_G, "AutoSQL", AutoSQL)
