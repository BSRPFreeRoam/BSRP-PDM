--[[
    BSRP PDM â€” standalone vehicle shop
    - No SQL / framework
    - Free claim by default
    - Futuristic NUI (BS Race theme)
]]

local menuOpen = false
local shopIndex = nil
local previewVeh = nil
local cam = nil
local spinning = false
local testing = false
local returnCoords = nil
local returnHeading = 0.0
local selectedModel = nil
local selectedName = nil
local selectedPrice = 0
local selectedCategory = nil
local pedHandles = {}
local blipHandles = {}

local function notify(msg, ntype, length)
    local ok = pcall(function()
        exports['thommie-notify']:notify(tostring(msg or ''), ntype or 'info', length or 3500)
    end)
    if not ok then
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(tostring(msg or ''))
        EndTextCommandThefeedPostTicker(false, true)
    end
end

local function destroyCam()
    if cam and DoesCamExist(cam) then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
end

local function deletePreview()
    spinning = false
    if previewVeh and DoesEntityExist(previewVeh) then
        SetEntityAsMissionEntity(previewVeh, true, true)
        DeleteVehicle(previewVeh)
    end
    previewVeh = nil
end

local function getShop()
    return shopIndex and Config.VehicleShops[shopIndex] or nil
end

local function createPreviewCam(shop)
    destroyCam()
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local c = shop.viewVehicleCamCoords
    SetCamCoord(cam, c.x, c.y, c.z)
    PointCamAtCoord(cam, shop.viewVehicleSpawnCoords.x, shop.viewVehicleSpawnCoords.y, shop.viewVehicleSpawnCoords.z + 0.4)
    SetCamRot(cam, 0.0, 0.0, c.w, 2)
    SetCamFov(cam, 48.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then
        return nil
    end
    RequestModel(hash)
    local timeout = GetGameTimer() + 8000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not HasModelLoaded(hash) then
        return nil
    end
    return hash
end

local function spawnPreview(model)
    local shop = getShop()
    if not shop then
        return false
    end

    local hash = loadModel(model)
    if not hash then
        notify('Failed to load vehicle model.')
        return false
    end

    deletePreview()
    local coords = shop.viewVehicleSpawnCoords
    previewVeh = CreateVehicle(hash, coords.x, coords.y, coords.z, coords.w, false, false)
    SetEntityAsMissionEntity(previewVeh, true, true)
    SetVehicleOnGroundProperly(previewVeh)
    SetEntityInvincible(previewVeh, true)
    SetVehicleDoorsLocked(previewVeh, 2)
    FreezeEntityPosition(previewVeh, true)
    SetVehicleDirtLevel(previewVeh, 0.0)
    SetVehicleModKit(previewVeh, 0)
    SetModelAsNoLongerNeeded(hash)

    if not cam then
        createPreviewCam(shop)
    end

    return true
end

local function vehicleStats(veh)
    if not veh or not DoesEntityExist(veh) then
        return {
            engine = 'â€”',
            brakes = 'â€”',
            suspension = 'â€”',
            transmission = 'â€”',
            armor = 'â€”',
            seats = 0,
            class = 'â€”',
        }
    end
    return {
        engine = 'Lvl ' .. tostring(GetNumVehicleMods(veh, 11)),
        brakes = 'Lvl ' .. tostring(GetNumVehicleMods(veh, 12)),
        suspension = 'Lvl ' .. tostring(GetNumVehicleMods(veh, 15)),
        transmission = 'Lvl ' .. tostring(GetNumVehicleMods(veh, 13)),
        armor = 'Lvl ' .. tostring(GetNumVehicleMods(veh, 16)),
        seats = GetVehicleModelNumberOfSeats(GetEntityModel(veh)),
        class = GetVehicleClass(veh),
    }
end

local function buildCategories()
    local cats = {}
    for name, list in pairs(Config.Vehicles or {}) do
        cats[#cats + 1] = {
            key = name,
            label = name,
            count = type(list) == 'table' and #list or 0,
        }
    end
    table.sort(cats, function(a, b)
        return a.label < b.label
    end)
    return cats
end

local function slimVehicles()
    -- Send full catalog once (name/model/price/stat only)
    local out = {}
    for cat, list in pairs(Config.Vehicles or {}) do
        out[cat] = {}
        if type(list) == 'table' then
            for i = 1, #list do
                local v = list[i]
                out[cat][#out[cat] + 1] = {
                    model = v.vehicleModel,
                    name = v.vehicleName or v.vehicleModel,
                    price = v.vehiclePrice or 0,
                    stat = v.vehicleStat or 'â€”',
                }
            end
        end
    end
    return out
end

local function openMenu(index)
    if menuOpen or testing then
        return
    end
    shopIndex = index
    menuOpen = true
    selectedModel = nil
    selectedName = nil
    selectedPrice = 0
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = {
            shopName = Config.ShopName or 'PDM',
            subtitle = Config.Subtitle or 'SHOWROOM',
            free = Config.FreeVehicles ~= false,
            categories = buildCategories(),
            vehicles = slimVehicles(),
        },
    })
    notify('PDM â€” browse and claim a vehicle (FREE).')
end

local function closeMenu(keepVehicle)
    if not menuOpen and not keepVehicle then
        return
    end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    destroyCam()
    if not keepVehicle then
        deletePreview()
    end
    spinning = false
    shopIndex = nil
    selectedModel = nil
end

local function claimVehicle()
    if not selectedModel then
        notify('Select a vehicle first.')
        return
    end
    local shop = getShop()
    if not shop then
        return
    end

    local hash = loadModel(selectedModel)
    if not hash then
        notify('Failed to load vehicle.')
        return
    end

    local buy = shop.buyCoords
    local veh = CreateVehicle(hash, buy.x, buy.y, buy.z, buy.w, true, false)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    SetVehicleDirtLevel(veh, 0.0)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetPedIntoVehicle(PlayerPedId(), veh, -1)
    SetModelAsNoLongerNeeded(hash)

    -- apply last preview color if possible
    if previewVeh and DoesEntityExist(previewVeh) then
        local r, g, b = GetVehicleCustomPrimaryColour(previewVeh)
        SetVehicleCustomPrimaryColour(veh, r, g, b)
        SetVehicleCustomSecondaryColour(veh, r, g, b)
    end

    -- Unique plate so garage can store / retrieve reliably
    local plate = ('BS%05d'):format(math.random(0, 99999))
    SetVehicleNumberPlateText(veh, plate)

    local r, g, b = GetVehicleCustomPrimaryColour(veh)
    local props = {
        model = hash,
        modelName = selectedModel,
        plate = plate,
        customPrimary = { r, g, b },
        customSecondary = { r, g, b },
        bodyHealth = 1000.0,
        engineHealth = 1000.0,
        fuelLevel = 100.0,
        dirtLevel = 0.0,
    }

    -- SQL: garage ownership + PDM purchase log
    TriggerServerEvent('bsrp-garage:addOwned', props, selectedName or selectedModel, 'PDM')
    TriggerServerEvent('bsrp-pdm:claim', {
        model = selectedModel,
        label = selectedName or selectedModel,
        plate = plate,
        price = selectedPrice or 0,
        shopId = shopIndex,
        category = selectedCategory,
        props = props,
    })

    deletePreview()
    closeMenu(true)
    notify(('Claimed %s - saved to garage (SQL). Park at a garage to store.'):format(selectedName or selectedModel), 'garage')
end

local function endTestDrive()
    if not testing then
        return
    end
    testing = false
    TriggerServerEvent('bsrp-pdm:setBucket', 'main')

    if previewVeh and DoesEntityExist(previewVeh) then
        TaskLeaveVehicle(PlayerPedId(), previewVeh, 16)
        Wait(400)
        FreezeEntityPosition(previewVeh, true)
        SetEntityInvincible(previewVeh, true)
        SetVehicleDoorsLocked(previewVeh, 2)
        local shop = getShop()
        if shop then
            local c = shop.viewVehicleSpawnCoords
            SetEntityCoords(previewVeh, c.x, c.y, c.z, false, false, false, false)
            SetEntityHeading(previewVeh, c.w)
            createPreviewCam(shop)
        end
    end

    if returnCoords then
        SetEntityCoords(PlayerPedId(), returnCoords.x, returnCoords.y, returnCoords.z, false, false, false, false)
        SetEntityHeading(PlayerPedId(), returnHeading or 0.0)
    end

    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'resume' })
    notify('Test drive ended.')
end

local function startTestDrive()
    if not previewVeh or not DoesEntityExist(previewVeh) then
        notify('Select a vehicle to test drive first.')
        return
    end
    local shop = getShop()
    if not shop then
        return
    end

    local ped = PlayerPedId()
    returnCoords = GetEntityCoords(ped)
    returnHeading = GetEntityHeading(ped)

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    destroyCam()

    TriggerServerEvent('bsrp-pdm:setBucket', 'test')
    local t = shop.testDriveCoords
    FreezeEntityPosition(previewVeh, false)
    SetEntityInvincible(previewVeh, true)
    SetVehicleDoorsLocked(previewVeh, 1)
    SetEntityCoords(previewVeh, t.x, t.y, t.z, false, false, false, false)
    SetEntityHeading(previewVeh, t.w)
    SetPedIntoVehicle(ped, previewVeh, -1)
    SetVehicleEngineOn(previewVeh, true, true, false)

    testing = true
    local duration = (shop.testDriveDuration or Config.TestDriveSeconds or 45) * 1000
    local start = GetGameTimer()

    CreateThread(function()
        while testing do
            DisableControlAction(0, 75, true) -- exit
            local left = math.ceil((duration - (GetGameTimer() - start)) / 1000)
            if left < 0 then
                left = 0
            end
            SetTextFont(4)
            SetTextScale(0.45, 0.45)
            SetTextColour(0, 229, 255, 220)
            SetTextCentre(true)
            SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(('TEST DRIVE  %ss  Â·  press F to end'):format(left))
            EndTextCommandDisplayText(0.5, 0.90)

            if IsDisabledControlJustPressed(0, 75)
                or IsControlJustPressed(0, 23) -- F
                or GetGameTimer() - start >= duration
                or not DoesEntityExist(previewVeh)
                or IsEntityDead(PlayerPedId()) then
                endTestDrive()
                break
            end
            Wait(0)
        end
    end)
end

-- NUI
RegisterNUICallback('close', function(_, cb)
    closeMenu(false)
    cb({ ok = true })
end)

RegisterNUICallback('select', function(data, cb)
    local model = data and data.model
    if not model then
        cb({ ok = false })
        return
    end
    selectedModel = model
    selectedName = data.name or model
    selectedPrice = tonumber(data.price) or 0
    selectedCategory = data.category

    if not spawnPreview(model) then
        cb({ ok = false })
        return
    end

    local stats = vehicleStats(previewVeh)
    cb({
        ok = true,
        stats = stats,
        name = selectedName,
        model = selectedModel,
        price = selectedPrice,
    })
end)

RegisterNUICallback('color', function(data, cb)
    if previewVeh and DoesEntityExist(previewVeh) and data then
        local r = tonumber(data.r) or 255
        local g = tonumber(data.g) or 255
        local b = tonumber(data.b) or 255
        SetVehicleCustomPrimaryColour(previewVeh, r, g, b)
        SetVehicleCustomSecondaryColour(previewVeh, r, g, b)
    end
    cb({ ok = true })
end)

RegisterNUICallback('spin', function(_, cb)
    spinning = not spinning
    if spinning and previewVeh and DoesEntityExist(previewVeh) then
        CreateThread(function()
            while spinning and previewVeh and DoesEntityExist(previewVeh) do
                local h = GetEntityHeading(previewVeh) + 0.35
                if h >= 360.0 then
                    h = 0.0
                end
                SetEntityHeading(previewVeh, h)
                Wait(0)
            end
        end)
    end
    cb({ ok = true, spinning = spinning })
end)

RegisterNUICallback('zoom', function(data, cb)
    if cam and DoesCamExist(cam) then
        local fov = GetCamFov(cam)
        if data and data.dir == 'in' then
            fov = math.max(20.0, fov - 3.0)
        else
            fov = math.min(70.0, fov + 3.0)
        end
        SetCamFov(cam, fov)
    end
    cb({ ok = true })
end)

RegisterNUICallback('claim', function(_, cb)
    if Config.FreeVehicles == false then
        -- no money system â€” still free for this standalone pack
        notify('Money system disabled â€” claiming free.')
    end
    claimVehicle()
    cb({ ok = true })
end)

RegisterNUICallback('testDrive', function(_, cb)
    startTestDrive()
    cb({ ok = true })
end)

-- Blips / peds / interaction
CreateThread(function()
    for i, shop in pairs(Config.VehicleShops or {}) do
        local npc = shop.npcSettings
        if npc then
            local hash = loadModel(npc.model)
            if hash then
                local ped = CreatePed(0, hash, npc.coords.x, npc.coords.y, npc.coords.z - 1.0, npc.coords.w, false, true)
                SetEntityAsMissionEntity(ped, true, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetEntityInvincible(ped, true)
                FreezeEntityPosition(ped, true)
                SetPedCanRagdoll(ped, false)
                pedHandles[#pedHandles + 1] = ped
                SetModelAsNoLongerNeeded(hash)
            end
        end

        if Config.Blip and Config.Blip.enabled ~= false then
            local c = shop.npcSettings and shop.npcSettings.coords or shop.buyCoords
            local blipCfg = shop.blipSettings or Config.Blip
            local blip = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(blip, blipCfg.id or Config.Blip.sprite or 326)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, blipCfg.scale or Config.Blip.scale or 0.8)
            SetBlipColour(blip, blipCfg.colour or Config.Blip.color or 3)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(blipCfg.displayName or Config.Blip.label or 'PDM')
            EndTextCommandSetBlipName(blip)
            blipHandles[#blipHandles + 1] = blip
        end
    end
end)

local zoneHint = false
CreateThread(function()
    while true do
        local sleep = 500
        if not menuOpen and not testing then
            local coords = GetEntityCoords(PlayerPedId())
            local near = false
            for i, shop in pairs(Config.VehicleShops or {}) do
                local c = shop.npcSettings and shop.npcSettings.coords
                if c then
                    local dist = #(coords - vector3(c.x, c.y, c.z))
                    if dist < (Config.MarkerDistance or 25.0) then
                        sleep = 0
                        if Config.DrawMarker then
                            local m = Config.Marker
                            DrawMarker(
                                m.type,
                                c.x, c.y, c.z - 0.95,
                                0.0, 0.0, 0.0,
                                0.0, 0.0, 0.0,
                                m.scale.x, m.scale.y, m.scale.z,
                                m.color.r, m.color.g, m.color.b, m.color.a,
                                m.bob, m.rotate, 2, false, nil, nil, false
                            )
                        end
                    end
                    if dist < (Config.InteractDistance or 2.2) then
                        near = true
                        sleep = 0
                        if not zoneHint then
                            zoneHint = true
                            notify('PDM â€” press E to open showroom (FREE).')
                        end
                        if IsControlJustReleased(0, Config.InteractKey or 38) then
                            openMenu(i)
                        end
                    end
                end
            end
            if not near then
                zoneHint = false
            end
        else
            sleep = 250
        end
        Wait(sleep)
    end
end)

RegisterCommand('pdm', function()
    if menuOpen or testing then
        return
    end
    -- open first shop from anywhere (dev / convenience)
    local first = next(Config.VehicleShops or {})
    if first then
        openMenu(first)
    end
end, false)

TriggerEvent('chat:addSuggestion', '/pdm', 'Open Premium Deluxe Motorsport menu')

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then
        return
    end
    closeMenu(false)
    deletePreview()
    destroyCam()
    for _, ped in ipairs(pedHandles) do
        if DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    for _, blip in ipairs(blipHandles) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    if testing then
        TriggerServerEvent('bsrp-pdm:setBucket', 'main')
    end
end)
