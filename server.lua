local VORPCore = exports.vorp_core:GetCore()

-- simple cache for server-side plant tracking
local ServerPlants = {} 

-- Initialize and Load Plants
Citizen.CreateThread(function()
    MySQL.query('SELECT * FROM devchacha_farming', {}, function(result)
        if result and #result > 0 then
            for i = 1, #result do
                local data = json.decode(result[i].data)
                data.id = result[i].id
                ServerPlants[result[i].id] = data
            end
        end
    end)
end)

-- MAINTENANCE LOOP: Health, Water, Growth
CreateThread(function()
    while true do
        Wait(60000) -- Run every 1 minute
        local updated = false
        local batchUpdates = {}
        
        for id, plant in pairs(ServerPlants) do
            local changed = false
            
            -- Get plant data for calculations
            local plantType = plant.type or plant.plantname
            local seedData = Config.Seeds[plantType]
            local growthTimeMinutes = 5 -- Default 5 min local
            if seedData and seedData.totaltime then
                growthTimeMinutes = seedData.totaltime
            end

            -- 1. Water Decay
            local decayRate = 300 / growthTimeMinutes
            decayRate = math.max(2, math.min(50, decayRate))

            if plant.water and plant.water > 0 then
                plant.water = math.max(0, plant.water - decayRate)
                changed = true
            end
            
            -- 2. Growth Logic (Server Side)
			if not plant.growth then 
                plant.growth = 0 
                changed = true 
            end

            if plant.water and plant.water > 0 and plant.growth < 100 then
                 local increment = 100 / growthTimeMinutes
                 
                 -- Fertilizer Bonus (35% faster)
                 if plant.fertilized then
                     increment = increment * 1.35
                 end
                 
                 plant.growth = math.min(100, plant.growth + increment)
                 changed = true
            end
            
            -- 3. Health Decay logic
            if not plant.health then plant.health = 100 end
            
            -- If water < 20, damage health
            if plant.water and plant.water < 20 then
                 plant.health = math.max(0, plant.health - 5)
                 changed = true
            end
            
            -- 4. Check Death
            if plant.health <= 0 then
                if ServerPlants[id] then
                    ServerPlants[id] = nil
                    MySQL.query('DELETE FROM devchacha_farming WHERE id = ?', {id})
                    TriggerClientEvent('devchacha-farming:client:removePlant', -1, id)
                end
                changed = false
            end

            if changed and ServerPlants[id] then
                ServerPlants[id] = plant
                MySQL.update('UPDATE devchacha_farming SET data = ? WHERE id = ?', {json.encode(plant), id})
                batchUpdates[id] = plant
                updated = true
            end
        end
        
        if updated then
            TriggerClientEvent('devchacha-farming:client:syncPlantsBatch', -1, batchUpdates)
        end
    end
end)

-- Helper: Add elapsed time to plant data for client sync
function PreparePlantForClient(plant)
    return plant
end

-- Event: Player Requests Plant Data
RegisterNetEvent('devchacha-farming:server:requestPlants', function()
    local src = source
    local clientPlants = {}
    for id, plant in pairs(ServerPlants) do
        clientPlants[id] = PreparePlantForClient(plant)
    end
    TriggerClientEvent('devchacha-farming:client:syncPlants', src, clientPlants)
end)

-- Event: Player Plants a Seed
RegisterNetEvent('devchacha-farming:server:plantSeed', function(plantData)
    local src = source
    local Character = VORPCore.getUser(src).getUsedCharacter
    if not Character then return end

    -- Initialize Stats
    plantData.health = 100
    plantData.weed = 0
    plantData.water = 0 
    plantData.growth = 0
    plantData.fertilized = false

    MySQL.insert('INSERT INTO devchacha_farming (citizenid, plantname, data) VALUES (?, ?, ?)',
        {Character.identifier, plantData.type, json.encode(plantData)}, function(id)
        
        plantData.id = id
        ServerPlants[id] = plantData
        TriggerClientEvent('devchacha-farming:client:addPlant', -1, plantData) -- Sync to all
    end)
end)

-- Event: Update Plant Status (Water/Fertilize/Growth)
RegisterNetEvent('devchacha-farming:server:updatePlant', function(plantId, newData)
    if ServerPlants[plantId] then
        ServerPlants[plantId] = newData
        MySQL.update('UPDATE devchacha_farming SET data = ? WHERE id = ?', {json.encode(newData), plantId})
        TriggerClientEvent('devchacha-farming:client:updatePlant', -1, plantId, newData)
    end
end)

-- Event: Remove Weeds
RegisterNetEvent('devchacha-farming:server:removeWeeds', function(plantId)
    local src = source
    if ServerPlants[plantId] then
        ServerPlants[plantId].weed = 0
        MySQL.update('UPDATE devchacha_farming SET data = ? WHERE id = ?', {json.encode(ServerPlants[plantId]), plantId})
        TriggerClientEvent('devchacha-farming:client:updatePlant', -1, plantId, PreparePlantForClient(ServerPlants[plantId]))
        TriggerClientEvent('vorp:TipRight', src, 'Weeds removed!', 4000)
    end
end)

-- Event: Remove Plant (Harvest/Death)
RegisterNetEvent('devchacha-farming:server:removePlant', function(plantId)
    if ServerPlants[plantId] then
        ServerPlants[plantId] = nil
        MySQL.query('DELETE FROM devchacha_farming WHERE id = ?', {plantId})
        TriggerClientEvent('devchacha-farming:client:removePlant', -1, plantId)
    end
end)

-- Event: Harvest Reward
RegisterNetEvent('devchacha-farming:server:harvest', function(plantId)
    local src = source
    local Character = VORPCore.getUser(src).getUsedCharacter
    local plant = ServerPlants[plantId]
    
    if plant and Character then
        -- Health Check: Cannot harvest if too unhealthy
        if plant.health and plant.health < 20 then
            TriggerClientEvent('vorp:TipRight', src, 'Plant is too unhealthy to harvest!', 4000)
            return
        end
        
        -- Check if plant is fully grown
        if plant.growth < 100 then
            TriggerClientEvent('vorp:TipRight', src, string.format('Crop is at %d%% growth', math.floor(plant.growth or 0)), 4000)
            return
        end
        
        local seedData = Config.Seeds[plant.type]
        if seedData then
            local finalCount = math.random(7, 8)
            if plant.fertilized then
                finalCount = math.random(12, 14)
            end
            
            local healthFactor = (plant.health or 100) / 100
            finalCount = math.max(1, math.floor(finalCount * healthFactor))
            
            exports.vorp_inventory:addItem(src, seedData.rewarditem, finalCount)
            TriggerClientEvent('vorp:TipRight', src, 'You harvested ' .. finalCount .. 'x ' .. seedData.rewarditem .. ' (Quality: ' .. math.floor(healthFactor * 100) .. '%)', 4000)
            
            -- Remove plant after harvest
            ServerPlants[plantId] = nil
            MySQL.query('DELETE FROM devchacha_farming WHERE id = ?', {plantId})
            TriggerClientEvent('devchacha-farming:client:removePlant', -1, plantId)
        end
    end
end)

-- Event: Fertilize Plant
RegisterNetEvent('devchacha-farming:server:fertilizePlant', function(plantId)
    local src = source
    local Character = VORPCore.getUser(src).getUsedCharacter
    local plant = ServerPlants[plantId]

    if plant and Character then
        local count = exports.vorp_inventory:getItemCount(src, nil, 'fertilizer')
        if count and count >= 1 then
            exports.vorp_inventory:subItem(src, 'fertilizer', 1)
            plant.fertilized = true
            
            ServerPlants[plantId] = plant
            MySQL.update('UPDATE devchacha_farming SET data = ? WHERE id = ?', {json.encode(plant), plantId})
            TriggerClientEvent('devchacha-farming:client:updatePlant', -1, plantId, PreparePlantForClient(plant))
            TriggerClientEvent('vorp:TipRight', src, 'Plant fertilized! Growth speed +35%, Yield +50%', 4000)
        else
            TriggerClientEvent('vorp:TipRight', src, 'You need fertilizer', 4000)
        end
    end
end)

-- Event: Give Water (Called from Client when filling bucket)
RegisterNetEvent('devchacha-farming:server:fillBucket', function()
    local src = source
    local Character = VORPCore.getUser(src).getUsedCharacter
    if Character then
        local count = exports.vorp_inventory:getItemCount(src, nil, 'emptybucket')
        if count and count >= 1 then
            exports.vorp_inventory:subItem(src, 'emptybucket', 1)
            exports.vorp_inventory:addItem(src, 'fullbucket', 1, { uses = 10 })
            TriggerClientEvent('vorp:TipRight', src, 'Bucket filled with water (10 uses)', 4000)
        else
            TriggerClientEvent('vorp:TipRight', src, 'You need an empty bucket', 4000)
        end
    end
end)

-- Event: Water Plant
local BUCKET_MAX_USES = 10

RegisterNetEvent('devchacha-farming:server:waterPlant', function(plantId)
    local src = source
    local Character = VORPCore.getUser(src).getUsedCharacter
    local plant = ServerPlants[plantId]
    
    if plant and Character then
        local bucket = exports.vorp_inventory:getItemByName(src, 'fullbucket')
        local wateringCan = not bucket and exports.vorp_inventory:getItemByName(src, 'wateringcan')
        
        if bucket or wateringCan then
            if bucket then
                local metadata = bucket.metadata or {}
                local uses = metadata.uses or BUCKET_MAX_USES
                uses = uses - 1
                
                exports.vorp_inventory:subItem(src, 'fullbucket', 1, metadata)
                
                if uses <= 0 then
                    exports.vorp_inventory:addItem(src, 'emptybucket', 1)
                    TriggerClientEvent('vorp:TipRight', src, 'Bucket is now empty!', 4000)
                else
                    exports.vorp_inventory:addItem(src, 'fullbucket', 1, { uses = uses })
                    TriggerClientEvent('vorp:TipRight', src, 'Bucket uses remaining: ' .. uses, 4000)
                end
            elseif wateringCan then
                exports.vorp_inventory:subItem(src, 'wateringcan', 1)
                exports.vorp_inventory:addItem(src, 'wateringcan_empty', 1)
            end
            
            plant.water = 100
            
            ServerPlants[plantId] = plant
            MySQL.update('UPDATE devchacha_farming SET data = ? WHERE id = ?', {json.encode(plant), plantId})
            TriggerClientEvent('devchacha-farming:client:updatePlant', -1, plantId, plant)
            TriggerClientEvent('vorp:TipRight', src, 'Plant watered! Growth has started.', 4000)
        else
            TriggerClientEvent('vorp:TipRight', src, 'You need a full bucket or watering can', 4000)
        end
    end
end)

-- Event: Destroy Plant
RegisterNetEvent('devchacha-farming:server:destroyPlant', function(plantId)
    local src = source
    local Character = VORPCore.getUser(src).getUsedCharacter
    
    if ServerPlants[plantId] and Character then
        ServerPlants[plantId] = nil
        MySQL.query('DELETE FROM devchacha_farming WHERE id = ?', {plantId})
        TriggerClientEvent('devchacha-farming:client:removePlant', -1, plantId)
        TriggerClientEvent('vorp:TipRight', src, 'Plant destroyed', 4000)
    end
end)

-- Usable Items
exports.vorp_inventory:registerUsableItem('fullbucket', function(data)
    exports.vorp_inventory:closeInventory(data.source)
    TriggerClientEvent('devchacha-farming:client:useWater', data.source)
end)

exports.vorp_inventory:registerUsableItem('wateringcan', function(data)
    exports.vorp_inventory:closeInventory(data.source)
    TriggerClientEvent('devchacha-farming:client:useWater', data.source)
end)

for plantName, data in pairs(Config.Seeds) do
    exports.vorp_inventory:registerUsableItem(data.seedname, function(data2)
        local src = data2.source
        local count = exports.vorp_inventory:getItemCount(src, nil, data.seedname)
        if count and count >= (data.seedreq or 1) then
            exports.vorp_inventory:closeInventory(src)
            exports.vorp_inventory:subItem(src, data.seedname, data.seedreq or 1)
            TriggerClientEvent('devchacha-farming:client:useSeed', src, plantName)
        else
            VORPCore.NotifyRightTip(src, 'Not enough seeds', 4000)
        end
    end)
end

-- VORP Shop buying server callback
RegisterNetEvent('devchacha-farming:server:buyItem', function(itemName, price, count)
    local src = source
    local Character = VORPCore.getUser(src).getUsedCharacter
    if not Character then return end

    local finalPrice = price * count
    if Character.money >= finalPrice then
        Character.removeCurrency(0, finalPrice)
        exports.vorp_inventory:addItem(src, itemName, count)
        VORPCore.NotifyRightTip(src, 'Bought ' .. count .. 'x ' .. itemName, 4000)
    else
        VORPCore.NotifyRightTip(src, 'Not enough money', 4000)
    end
end)

-- Callback to check if player has item (e.g. shovel, fertilizer)
VORPCore.Callback.Register('devchacha-farming:server:hasItem', function(source, cb, data)
    local count = exports.vorp_inventory:getItemCount(source, nil, data.item)
    cb(count and count >= (data.count or 1))
end)
