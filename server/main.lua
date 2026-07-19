--[[
    BSRP PDM — server
    Routing buckets + MySQL purchase log (bsrp_pdm_purchases)
    Vehicles registered via bsrp-garage (SQL owned vehicles)
]]

local function getIdentifier(src)
    if GetResourceState('bsrp') == 'started' then
        local id = exports.bsrp:GetIdentifier(src)
        if id then return id end
    end
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:find('license:') == 1 then return id end
    end
    return 'src:' .. tostring(src)
end

CreateThread(function()
    MySQL.ready(function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `bsrp_pdm_purchases` (
              `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
              `identifier` VARCHAR(64) NOT NULL,
              `player_name` VARCHAR(64) NULL,
              `model` VARCHAR(64) NOT NULL,
              `label` VARCHAR(64) NULL,
              `plate` VARCHAR(16) NULL,
              `price` INT NOT NULL DEFAULT 0,
              `shop_id` INT NULL DEFAULT NULL,
              `category` VARCHAR(48) NULL,
              `vehicle_uid` VARCHAR(32) NULL,
              `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
              PRIMARY KEY (`id`),
              KEY `idx_identifier` (`identifier`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]])
        print('^2[bsrp-pdm]^7 MySQL ready (bsrp_pdm_purchases)')
    end)
end)

RegisterNetEvent('bsrp-pdm:setBucket', function(mode)
    local src = source
    if mode == 'test' then
        SetPlayerRoutingBucket(src, 1000 + src)
    else
        SetPlayerRoutingBucket(src, 0)
    end
end)

--- Log a claim/purchase and ensure garage has the vehicle (SQL)
RegisterNetEvent('bsrp-pdm:claim', function(data)
    local src = source
    if type(data) ~= 'table' or not data.model then return end

    local identifier = getIdentifier(src)
    local plate = tostring(data.plate or ''):gsub('%s+', ''):upper()
    local label = data.label or data.model
    local price = math.floor(tonumber(data.price) or 0)
    local free = Config and Config.FreeVehicles

    -- Optional paid mode via BSRP money
    if not free and price > 0 and GetResourceState('bsrp') == 'started' then
        if not exports.bsrp:RemoveMoney(src, 'bank', price, 'pdm_purchase') then
            if not exports.bsrp:RemoveMoney(src, 'cash', price, 'pdm_purchase') then
                TriggerClientEvent('bsrp:client:notify', src, 'Not enough money for this vehicle', 'error')
                return
            end
        end
    else
        price = 0
    end

    -- Garage ownership is registered by client via bsrp-garage:addOwned first.
    -- Look up vehicle uid for the log (optional).
    local vehicleUid = data.vehicle_uid
    if not vehicleUid and plate ~= '' then
        local row = MySQL.single.await(
            'SELECT uid FROM bsrp_player_vehicles WHERE identifier = ? AND plate = ? LIMIT 1',
            { identifier, plate }
        )
        if row then vehicleUid = row.uid end
    end

    MySQL.insert.await(
        [[INSERT INTO bsrp_pdm_purchases
          (identifier, player_name, model, label, plate, price, shop_id, category, vehicle_uid)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            identifier,
            GetPlayerName(src),
            data.model,
            label,
            plate,
            price,
            tonumber(data.shopId),
            data.category,
            vehicleUid,
        }
    )

    TriggerClientEvent('bsrp-pdm:claimOk', src, {
        model = data.model,
        label = label,
        plate = plate,
        price = price,
        uid = vehicleUid,
    })
end)

print('^2[bsrp-pdm]^7 Loaded (MySQL purchase log + garage SQL)')
