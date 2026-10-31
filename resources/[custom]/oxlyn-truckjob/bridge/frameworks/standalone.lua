local Standalone_Bridge = {}

-- In-memory wallets per player source (lost on resource restart / disconnect).
local wallets = {}

-- No setup needed for standalone mode.
function Standalone_Bridge.init()
end

if IsDuplicityVersion() then
    -----------------------------------------------------------------------
    -- SERVER
    -----------------------------------------------------------------------

    -- Gets (or creates, with starting balances) the wallet for a player.
    local function getWallet(source)
        wallets[source] = wallets[source] or {
            cash = 500,
            bank = 1500,
            black_money = 0,
        }
        return wallets[source]
    end

    AddEventHandler("playerDropped", function()
        wallets[source] = nil
    end)

    local function pushWallet(source, wallet)
        TriggerClientEvent("oxlyn-truckjob:client:walletUpdate", source, wallet)
    end

    -- "money" is treated as "cash".
    local function walletAccount(account)
        return account == "money" and "cash" or account
    end

    function Standalone_Bridge.GetPlayer(source)
        return { source = source }
    end

    function Standalone_Bridge.GetIdentifier(source)
        return ("standalone:%s"):format(GetPlayerIdentifierByType(source, "license") or source)
    end

    function Standalone_Bridge.GetJob()
        return Config.JobName
    end

    -- Everyone is considered to have the job in standalone mode.
    function Standalone_Bridge.HasJob()
        return true
    end

    function Standalone_Bridge.GetName(source)
        return GetPlayerName(source) or ("Player#" .. source)
    end

    function Standalone_Bridge.AddMoney(source, account, amount)
        local wallet = getWallet(source)
        account = walletAccount(account)

        wallet[account] = (wallet[account] or 0) + amount
        pushWallet(source, wallet)
        return true
    end

    function Standalone_Bridge.RemoveMoney(source, account, amount)
        local wallet = getWallet(source)
        account = walletAccount(account)

        if amount > (wallet[account] or 0) then
            return false
        end

        wallet[account] = wallet[account] - amount
        pushWallet(source, wallet)
        return true
    end

    -- Items are not tracked in standalone mode: always succeed.
    function Standalone_Bridge.HasItem()
        return true
    end

    function Standalone_Bridge.RemoveItem()
        return true
    end

    -- No inventory to register with.
    function Standalone_Bridge.RegisterUsableItem()
    end
else
    -----------------------------------------------------------------------
    -- CLIENT
    -----------------------------------------------------------------------

    function Standalone_Bridge.GetJob()
        return Config.JobName
    end

    function Standalone_Bridge.HasJob()
        return true
    end

    function Standalone_Bridge.HasItem()
        return true
    end
end

Bridge.Register("standalone", Standalone_Bridge)