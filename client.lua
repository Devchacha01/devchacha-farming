local VORPCore = exports.vorp_core:GetCore()
local progressbar = exports.vorp_progressbar:initiate()
local isLoggedIn = false
local Plants = {}
local RenderedPlants = {}

local activeProp = nil

local function PlayFarmingAnimation(animType)
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    Wait(100)
    
    if animType == 'plant' then
        local dict = "amb_work@world_human_gravedig@working@male_b@base"
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Wait(10)
        end
        
        local model = GetHashKey('p_shovel02x')
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(10)
        end
        
        local boneIndex = GetEntityBoneIndexByName(ped, 'SKEL_R_Hand')
        activeProp = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(activeProp, ped, boneIndex, 0.0, -0.09, -0.09, 250.2899, 579.19, 373.3, true, true, false, true, 1, true)
        
        TaskPlayAnim(ped, dict, "base", 8.0, -8.0, -1, 1, 0.0, false, false, false)
        RemoveAnimDict(dict)
        
    elseif animType == 'harvest' or animType == 'weed' then
        local dict = "mech_pickup@plant@gold_currant"
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do
            Wait(10)
        end
        
        TaskPlayAnim(ped, dict, "enter_rf", 8.0, -8.0, -1, 1, 0.0, false, false, false)
        RemoveAnimDict(dict)
        
    elseif animType == 'water' then
        TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_BUCKET_POUR_LOW'), -1, true, 0, 0.0, false)
        
    elseif animType == 'fertilize' then
        TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_FEED_CHICKEN'), -1, true, 0, 0.0, false)
        
    elseif animType == 'destroy' then
        TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, 0, 0.0, false)
    end
end

local function StopFarmingAnimation()
    local ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    if activeProp and DoesEntityExist(activeProp) then
        DeleteObject(activeProp)
        activeProp = nil
    end
end

local function CleanupScenario(ped)
    StopFarmingAnimation()
end

-- Ghost Placement Variables
local isPlacing = false
local ghostObject = nil
local currentPlantType = nil
local placementCoords = nil
local placementHeading = 0.0

-- Growth time in seconds (5 minutes)
local GROWTH_TIME = 300

--------------------------------------------------------------------------------
-- PLAYER LOAD/UNLOAD
--------------------------------------------------------------------------------
RegisterNetEvent("vorp:SelectedCharacter", function(charid)
    isLoggedIn = true
    TriggerServerEvent('devchacha-farming:server:requestPlants')
end)

-- Backup if resource restarted
AddEventHandler('onClientResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        TriggerServerEvent('devchacha-farming:server:requestPlants')
        isLoggedIn = true
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    for k, v in pairs(RenderedPlants) do
        if DoesEntityExist(v) then DeleteObject(v) end
    end
    RenderedPlants = {}
    Plants = {}
end)

--------------------------------------------------------------------------------
-- NUI FUNCTIONS
--------------------------------------------------------------------------------
local menuOpen = false
local currentMenuPlantId = nil

function ShowPlantMenu(plantId)
    local plant = Plants[plantId]
    if not plant then return end
    
    menuOpen = true
    currentMenuPlantId = plantId
    SetNuiFocus(true, true)
    
    local waterPercent = plant.water or 0
    local healthPercent = plant.health or 100
    local weedPercent = plant.weed or 0
    local growthPercent = CalculateGrowth(plant)
    local timeRemaining = CalculateTimeRemaining(plant)
    
    SendNUIMessage({
        action = 'openPlantMenu',
        plantData = {
            id = plantId,
            type = plant.type,
            water = waterPercent,
            health = healthPercent,
            weed = weedPercent,
            fertilized = plant.fertilized,
            growth = growthPercent,
            timeRemaining = timeRemaining
        }
    })
end

function ShowProgress(title, duration)
    progressbar.start(title, duration, function() end)
end

function HideProgress()
    exports.vorp_progressbar:CancelAll()
end

function ShowPopup(text, duration)
    if duration == 0 then
        TriggerEvent('vorp:TipBottom', text, 30000)
    else
        TriggerEvent('vorp:TipRight', text, duration or 3000)
    end
end

function HidePopup()
    TriggerEvent('vorp:TipBottom', '', 1)
end

local function StartProgressBar(label, duration, cb)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    progressbar.start(label, duration, function()
        FreezeEntityPosition(ped, false)
        if cb then cb() end
    end)
end

-- Get current unix timestamp
function GetCurrentTime()
    return GetNetworkTimeAccurate() / 1000
end

-- Calculate growth
function CalculateGrowth(plant)
    return math.floor(plant.growth or 0)
end

-- Calculate time remaining
function CalculateTimeRemaining(plant)
    local seedData = Config.Seeds[plant.type]
    local totalTimeSeconds = (seedData and seedData.totaltime and seedData.totaltime * 60) or 300
    
    local effectiveGrowthTime = totalTimeSeconds
    if plant.fertilized then
        effectiveGrowthTime = math.floor(totalTimeSeconds / 1.35)
    end

    local growth = plant.growth or 0
    if growth >= 100 then return 0 end
    
    local remainingPercent = 100 - growth
    local remainingSeconds = effectiveGrowthTime * (remainingPercent / 100)
    
    return math.ceil(remainingSeconds)
end

-- NUI Callbacks
RegisterNUICallback('plantAction', function(data, cb)
    cb('ok')
    menuOpen = false
    SetNuiFocus(false, false)
    
    local action = data.action
    local plantId = data.plantId
    
    if action == 'water' then
        WaterPlant(plantId)
    elseif action == 'harvest' then
        HarvestPlant(plantId)
    elseif action == 'destroy' then
        DestroyPlant(plantId)
    elseif action == 'removeWeeds' then
        RemoveWeeds(plantId)
    elseif action == 'fertilize' then
        FertilizePlant(plantId)
    end
end)

RegisterNUICallback('closeMenu', function(data, cb)
    cb('ok')
    menuOpen = false
    currentMenuPlantId = nil
    SetNuiFocus(false, false)
end)

-- ESC Key Handler Thread
CreateThread(function()
    while true do
        Wait(0)
        if menuOpen then
            if IsControlJustPressed(0, 0x156F7119) then -- BACKSPACE/ESC
                SetNuiFocus(false, false)
                SendNUIMessage({ action = 'closeMenu' })
                menuOpen = false
            end
        else
            Wait(500)
        end
    end
end)

--------------------------------------------------------------------------------
-- GHOST OBJECT PLACEMENT SYSTEM
--------------------------------------------------------------------------------
local function GetGroundZ(x, y, z)
    local found, groundZ = GetGroundZFor_3dCoord(x, y, z + 5.0, false)
    if found then
        return groundZ
    end
    return z
end

-- Forward declarations
local FinalizePlacement
local CancelPlacement

CancelPlacement = function()
    if DoesEntityExist(ghostObject) then
        DeleteObject(ghostObject)
        ghostObject = nil
    end
    isPlacing = false
    currentPlantType = nil
    placementCoords = nil
    HidePopup()
    TriggerEvent('vorp:TipRight', 'Planting cancelled', 4000)
end

FinalizePlacement = function()
    if not isPlacing or not placementCoords then return end
    
    if DoesEntityExist(ghostObject) then
        DeleteObject(ghostObject)
        ghostObject = nil
    end
    
    HidePopup()
    
    local ped = PlayerPedId()
    PlayFarmingAnimation('plant')
    Wait(300)
    FreezeEntityPosition(ped, true)
    
    local coords = placementCoords
    local heading = placementHeading
    local plantType = currentPlantType
    
    isPlacing = false
    currentPlantType = nil
    placementCoords = nil
    
    progressbar.start('Planting ' .. plantType .. '...', 5000, function()
        StopFarmingAnimation()
        FreezeEntityPosition(ped, false)
        
        local plantData = {
            type = plantType,
            coords = { x = coords.x, y = coords.y, z = coords.z },
            heading = heading,
            water = 0,
            growth = 0,
            stage = 1,
            plantedTime = GetGameTimer()
        }
        TriggerServerEvent('devchacha-farming:server:plantSeed', plantData)
        ShowPopup('Seeds Planted!', 2000)
    end)
end

local function StartPlacement(plantType)
    if isPlacing then return end
    
    VORPCore.Callback.TriggerAsync('devchacha-farming:server:hasItem', function(hasShovel)
        if not hasShovel then
            TriggerEvent('vorp:TipRight', 'You need a shovel to plant seeds!', 4000)
            return
        end

        if Config.EnableBannedZones and Config.BannedZones then
            local pCoords = GetEntityCoords(PlayerPedId())
            for _, zone in pairs(Config.BannedZones) do
                if #(pCoords - zone.coords) < zone.radius then
                    TriggerEvent('vorp:TipRight', 'Farming is not allowed in ' .. zone.name, 4000)
                    return
                end
            end
        end
        
        local seedData = Config.Seeds[plantType]
        if not seedData then
            TriggerEvent('vorp:TipRight', 'Invalid seed type', 4000)
            return
        end
        
        isPlacing = true
        currentPlantType = plantType
        placementHeading = 0.0
        
        local propName = seedData.prop
        if seedData.stages and #seedData.stages > 0 then
            propName = seedData.stages[#seedData.stages].prop
        end

        local model = GetHashKey(propName)
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end
        
        local playerCoords = GetEntityCoords(PlayerPedId())
        local groundZ = GetGroundZ(playerCoords.x, playerCoords.y, playerCoords.z)
        
        ghostObject = CreateObject(model, playerCoords.x, playerCoords.y + 2.0, groundZ - (seedData.offset or 0.0), false, false, false)
        SetEntityAlpha(ghostObject, 150, false)
        SetEntityCollision(ghostObject, false, false)
        FreezeEntityPosition(ghostObject, true)
        
        ShowPopup('PLACE ' .. string.upper(plantType) .. ' • [Q/E] ROTATE • ENTER to Plant • BACKSPACE to Cancel', 0)
        
        CreateThread(function()
            while isPlacing do
                Wait(0)
                
                local playerCoords = GetEntityCoords(PlayerPedId())
                local camRot = GetGameplayCamRot(2)
                local forward = vector3(
                    -math.sin(math.rad(camRot.z)) * math.cos(math.rad(camRot.x)),
                    math.cos(math.rad(camRot.z)) * math.cos(math.rad(camRot.x)),
                    0.0
                )
                local right = vector3(
                    math.cos(math.rad(camRot.z)),
                    math.sin(math.rad(camRot.z)),
                    0.0
                )
                
                local offset = 2.5
                local ghostPos = playerCoords + (forward * offset)
                
                if IsControlPressed(0, 0x7065027D) then -- W
                    ghostPos = ghostPos + (forward * 0.05)
                end
                if IsControlPressed(0, 0xD27782E3) then -- S
                    ghostPos = ghostPos - (forward * 0.05)
                end
                if IsControlPressed(0, 0x05CA7C52) then -- A
                    ghostPos = ghostPos - (right * 0.05)
                end
                if IsControlPressed(0, 0x6319DB71) then -- D
                    ghostPos = ghostPos + (right * 0.05)
                end
                
                if IsControlPressed(0, 0xDE794E3E) then -- Q
                    placementHeading = placementHeading + 1.0
                end
                if IsControlPressed(0, 0xCEFD9220) then -- E
                    placementHeading = placementHeading - 1.0
                end
                
                local groundZ = GetGroundZ(ghostPos.x, ghostPos.y, ghostPos.z)
                placementCoords = vector3(ghostPos.x, ghostPos.y, groundZ)
                
                if DoesEntityExist(ghostObject) then
                    SetEntityCoords(ghostObject, placementCoords.x, placementCoords.y, placementCoords.z - (seedData.offset or 0.0), false, false, false, false)
                    SetEntityHeading(ghostObject, placementHeading)
                end
                
                if IsControlJustPressed(0, 0xC7B5340A) then -- ENTER
                    FinalizePlacement()
                end
                
                if IsControlJustPressed(0, 0x156F7119) then -- BACKSPACE
                    CancelPlacement()
                end
            end
        end)
    end, { item = 'shovel', count = 1 })
end

--------------------------------------------------------------------------------
-- PLANT SYNC EVENTS
--------------------------------------------------------------------------------
RegisterNetEvent('devchacha-farming:client:syncPlants', function(serverPlants)
    Plants = serverPlants or {}
end)

RegisterNetEvent('devchacha-farming:client:syncPlantsBatch', function(batchUpdates)
    for id, plant in pairs(batchUpdates) do
        local oldModel = Plants[id] and Plants[id].currentModel
        Plants[id] = plant
        if oldModel then Plants[id].currentModel = oldModel end

        if menuOpen and currentMenuPlantId == id then
            ShowPlantMenu(id)
        end
    end
end)

RegisterNetEvent('devchacha-farming:client:addPlant', function(plantData)
    Plants[plantData.id] = plantData
    SpawnPlantProp(plantData.id, plantData)
end)

RegisterNetEvent('devchacha-farming:client:updatePlant', function(plantId, newData)
    Plants[plantId] = newData
    if menuOpen and currentMenuPlantId == plantId then
        ShowPlantMenu(plantId)
    end
end)

RegisterNetEvent('devchacha-farming:client:removePlant', function(plantId)
    if RenderedPlants[plantId] then
        DeleteObject(RenderedPlants[plantId])
        RenderedPlants[plantId] = nil
    end
    Plants[plantId] = nil
end)

--------------------------------------------------------------------------------
-- SPAWN PLANT PROP
--------------------------------------------------------------------------------
local function GetPlantModel(plantType, growthPercent)
    local seedData = Config.Seeds[plantType]
    if not seedData then return nil, nil end
    
    local modelName = seedData.prop
    local activeStage = nil
    
    if seedData.stages then
        for _, stage in ipairs(seedData.stages) do
            if growthPercent >= stage.minGrowth then
                modelName = stage.prop
                activeStage = stage
            end
        end
    end
    
    return GetHashKey(modelName), activeStage
end

function SpawnPlantProp(id, plant)
    local growth = CalculateGrowth(plant)
    local model, stageData = GetPlantModel(plant.type, growth)
    if not model then return end

    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Wait(10)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(model) then return end
    
    local coords = vector3(plant.coords.x, plant.coords.y, plant.coords.z)
    local seedData = Config.Seeds[plant.type]
    local groundZ = GetGroundZ(coords.x, coords.y, coords.z)
    
    if RenderedPlants[id] then
        if plant.currentModel == model then
             return 
        else
             DeleteObject(RenderedPlants[id])
             RenderedPlants[id] = nil
        end
    end

    local obj = CreateObject(model, coords.x, coords.y, groundZ, false, false, false)
    SetEntityAsMissionEntity(obj, true, true)
    
    local finalOffset = seedData.offset or 0.0
    if stageData and stageData.offset then
        finalOffset = stageData.offset
    end

    SetEntityCoords(obj, coords.x, coords.y, groundZ - finalOffset, false, false, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityHeading(obj, plant.heading or 0.0)
    SetEntityCollision(obj, true, true)
    
    RenderedPlants[id] = obj
    plant.currentModel = model 
end

--------------------------------------------------------------------------------
-- PLANT INTERACTION FUNCTIONS
--------------------------------------------------------------------------------
local function CleanupScenario(ped)
    ClearPedTasksImmediately(ped)
    local coords = GetEntityCoords(ped)
    local objects = GetGamePool('CObject')
    for _, obj in pairs(objects) do
        if DoesEntityExist(obj) then
            local objCoords = GetEntityCoords(obj)
            local dist = #(coords - objCoords)
            if dist < 2.0 and IsEntityAttachedToEntity(obj, ped) then
                DeleteEntity(obj)
            end
        end
    end
end

function WaterPlant(plantId)
    local plant = Plants[plantId]
    if not plant then return end
    
    VORPCore.Callback.TriggerAsync('devchacha-farming:server:hasItem', function(hasWater)
        if not hasWater then
            TriggerEvent('vorp:TipRight', 'You need a full bucket of water', 4000)
            return
        end
        
        local ped = PlayerPedId()
        PlayFarmingAnimation('water')
        Wait(300)
        FreezeEntityPosition(ped, true)
        
        progressbar.start('Watering...', 4000, function()
            CleanupScenario(ped)
            FreezeEntityPosition(ped, false)
            TriggerServerEvent('devchacha-farming:server:waterPlant', plantId)
            ShowPopup('Crop Watered!', 2000)
        end)
    end, { item = 'fullbucket', count = 1 })
end

function RemoveWeeds(plantId)
    local plant = Plants[plantId]
    if not plant then return end
    
    local ped = PlayerPedId()
    PlayFarmingAnimation('weed')
    Wait(300)
    FreezeEntityPosition(ped, true)
    
    progressbar.start('Removing Weeds...', 5000, function()
        CleanupScenario(ped)
        FreezeEntityPosition(ped, false)
        TriggerServerEvent('devchacha-farming:server:removeWeeds', plantId)
        ShowPopup('Weeds Removed!', 2000)
    end)
end

function FertilizePlant(plantId)
    local plant = Plants[plantId]
    if not plant then return end
    
    VORPCore.Callback.TriggerAsync('devchacha-farming:server:hasItem', function(hasItem)
        if not hasItem then
            TriggerEvent('vorp:TipRight', 'You need fertilizer', 4000)
            return
        end

        local ped = PlayerPedId()
        PlayFarmingAnimation('fertilize')
        Wait(300)
        FreezeEntityPosition(ped, true)
        
        progressbar.start('Fertilizing...', 4000, function()
            CleanupScenario(ped)
            FreezeEntityPosition(ped, false)
            TriggerServerEvent('devchacha-farming:server:fertilizePlant', plantId)
            ShowPopup('Crop Fertilized!', 2000)
        end)
    end, { item = 'fertilizer', count = 1 })
end

function HarvestPlant(plantId)
    local plant = Plants[plantId]
    if not plant then return end
    
    local growthPercent = CalculateGrowth(plant)
    if growthPercent < 100 then
        TriggerEvent('vorp:TipRight', 'Crop is not ready to harvest yet', 4000)
        return
    end
    
    local ped = PlayerPedId()
    PlayFarmingAnimation('harvest')
    Wait(300)
    FreezeEntityPosition(ped, true)
    
    progressbar.start('Harvesting...', 8000, function()
        CleanupScenario(ped)
        FreezeEntityPosition(ped, false)
        TriggerServerEvent('devchacha-farming:server:harvest', plantId)
        ShowPopup('Crop Harvested!', 2000)
    end)
end

function DestroyPlant(plantId)
    local plant = Plants[plantId]
    if not plant then return end

    local ped = PlayerPedId()
    PlayFarmingAnimation('destroy')
    Wait(300)
    FreezeEntityPosition(ped, true)
    
    local plantCoords = vector3(plant.coords.x, plant.coords.y, plant.coords.z)
    local fire = StartScriptFire(plantCoords.x, plantCoords.y, plantCoords.z, 25, false, false, false, 0)
    
    progressbar.start('Setting Fire...', 3000, function()
        RemoveScriptFire(fire)
        CleanupScenario(ped)
        FreezeEntityPosition(ped, false)
        TriggerServerEvent('devchacha-farming:server:destroyPlant', plantId)
        ShowPopup('Crop Destroyed', 2000)
    end)
end

RegisterNetEvent('devchacha-farming:client:useSeed', function(plantType)
    StartPlacement(plantType)
end)

--------------------------------------------------------------------------------
-- WATER INTERACTION
--------------------------------------------------------------------------------
RegisterNetEvent('devchacha-farming:client:waterAction', function(action)
    local ped = PlayerPedId()
    
    if action == 'fillBucket' then
        VORPCore.Callback.TriggerAsync('devchacha-farming:server:hasItem', function(hasBucket)
            if not hasBucket then
                 TriggerEvent('vorp:TipRight', 'You need an empty bucket!', 4000)
                 return
            end
            TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_BUCKET_POUR_LOW'), -1, true, 0, 0.0, false)
            Wait(300)
            StartProgressBar('Filling Bucket...', 4000, function()
                CleanupScenario(ped)
                TriggerServerEvent('devchacha-farming:server:fillBucket')
            end)
        end, { item = 'emptybucket', count = 1 })
        
    elseif action == 'drink' then
        TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_DRINKING'), -1, true, 0, 0.0, false)
        Wait(300)
        StartProgressBar('Drinking...', 5000, function()
            CleanupScenario(ped)
        end)
        
    elseif action == 'wash' then
        TaskStartScenarioInPlaceHash(ped, GetHashKey('WORLD_HUMAN_WASH_FACE_BUCKET_GROUND'), -1, true, 0, 0.0, false)
        Wait(300)
        StartProgressBar('Washing...', 5000, function()
            CleanupScenario(ped)
        end)
    end
end)

-- Main Render/Update Loop
CreateThread(function()
    while true do
        Wait(2000)
        local pCoords = GetEntityCoords(PlayerPedId())
        
        for id, plant in pairs(Plants) do
            local dist = #(pCoords - vector3(plant.coords.x, plant.coords.y, plant.coords.z))
            
            if dist < Config.RenderDistance then
                if not RenderedPlants[id] then
                    SpawnPlantProp(id, plant)
                else
                    local growth = CalculateGrowth(plant)
                    local expectedModel, _ = GetPlantModel(plant.type, growth)
                    if expectedModel and plant.currentModel ~= expectedModel then
                        SpawnPlantProp(id, plant)
                    end
                end
            else
                if RenderedPlants[id] then
                    if DoesEntityExist(RenderedPlants[id]) then
                        DeleteObject(RenderedPlants[id])
                    end
                    RenderedPlants[id] = nil
                end
            end
        end
    end
end)

-- Helper for 3D Text
local function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = GetScreenCoordFromWorldCoord(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFontForCurrentCommand(1)
        SetTextColor(255, 255, 255, 215)
        local str = CreateVarString(10, "LITERAL_STRING", text)
        SetTextCentre(1)
        DisplayText(str, _x, _y)
    end
end

-- Natural Water Interaction handled in the Proximity thread

-- Distance Culling Loop
CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        for id, plant in pairs(Plants) do
            local plantCoords = vector3(plant.coords.x, plant.coords.y, plant.coords.z)
            local dist = #(playerCoords - plantCoords)
            
            if dist < 50.0 then
                if not RenderedPlants[id] then
                    SpawnPlantProp(id, plant)
                end
            else
                if RenderedPlants[id] then
                     DeleteObject(RenderedPlants[id])
                     RenderedPlants[id] = nil
                     if plant.currentModel then plant.currentModel = nil end
                end
            end
        end
        Wait(1000)
    end
end)

-- Growth Stage Update Loop
CreateThread(function()
    while true do
        Wait(5000)
        for id, obj in pairs(RenderedPlants) do
            local plant = Plants[id]
            if plant and DoesEntityExist(obj) then
                local growth = CalculateGrowth(plant)
                local expectedModel = GetPlantModel(plant.type, growth)
                
                if expectedModel and plant.currentModel ~= expectedModel then
                    DeleteObject(obj)
                    RenderedPlants[id] = nil
                    SpawnPlantProp(id, plant)
                end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- PROMPT SYSTEM
--------------------------------------------------------------------------------
local FarmingPromptGroup = GetRandomIntInRange(0, 0xffffff)
local InspectPlantPrompt, OpenShopPrompt, FillBucketPrompt, DrinkWaterPrompt, WashFacePrompt
local WaterPlantPrompt, FertilizePlantPrompt, HarvestPlantPrompt, RemoveWeedsPrompt, DestroyPlantPrompt

local function SetUpFarmingPrompts()
    InspectPlantPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(InspectPlantPrompt, 0x760A9C6F) -- G key
    UiPromptSetText(InspectPlantPrompt, CreateVarString(10, 'LITERAL_STRING', 'Inspect Crop'))
    UiPromptSetEnabled(InspectPlantPrompt, false)
    UiPromptSetVisible(InspectPlantPrompt, false)
    UiPromptSetHoldMode(InspectPlantPrompt, true)
    UiPromptRegisterEnd(InspectPlantPrompt)
    UiPromptSetGroup(InspectPlantPrompt, FarmingPromptGroup, 0)

    OpenShopPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(OpenShopPrompt, 0x760A9C6F) -- G key
    UiPromptSetText(OpenShopPrompt, CreateVarString(10, 'LITERAL_STRING', 'Open Shop'))
    UiPromptSetEnabled(OpenShopPrompt, false)
    UiPromptSetVisible(OpenShopPrompt, false)
    UiPromptSetHoldMode(OpenShopPrompt, true)
    UiPromptRegisterEnd(OpenShopPrompt)
    UiPromptSetGroup(OpenShopPrompt, FarmingPromptGroup, 0)

    FillBucketPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(FillBucketPrompt, 0xE30CD707) -- R key
    UiPromptSetText(FillBucketPrompt, CreateVarString(10, 'LITERAL_STRING', 'Fill Bucket'))
    UiPromptSetEnabled(FillBucketPrompt, false)
    UiPromptSetVisible(FillBucketPrompt, false)
    UiPromptSetHoldMode(FillBucketPrompt, true)
    UiPromptRegisterEnd(FillBucketPrompt)
    UiPromptSetGroup(FillBucketPrompt, FarmingPromptGroup, 0)

    DrinkWaterPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(DrinkWaterPrompt, 0xD9D0E1C0) -- E key
    UiPromptSetText(DrinkWaterPrompt, CreateVarString(10, 'LITERAL_STRING', 'Drink Water'))
    UiPromptSetEnabled(DrinkWaterPrompt, false)
    UiPromptSetVisible(DrinkWaterPrompt, false)
    UiPromptSetHoldMode(DrinkWaterPrompt, true)
    UiPromptRegisterEnd(DrinkWaterPrompt)
    UiPromptSetGroup(DrinkWaterPrompt, FarmingPromptGroup, 0)

    WashFacePrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(WashFacePrompt, 0x760A9C6F) -- G key
    UiPromptSetText(WashFacePrompt, CreateVarString(10, 'LITERAL_STRING', 'Wash Face'))
    UiPromptSetEnabled(WashFacePrompt, false)
    UiPromptSetVisible(WashFacePrompt, false)
    UiPromptRegisterEnd(WashFacePrompt)
    UiPromptSetGroup(WashFacePrompt, FarmingPromptGroup, 0)
 
    -- Direct Crop Action Prompts
    WaterPlantPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(WaterPlantPrompt, 0xE30CD707) -- R key
    UiPromptSetText(WaterPlantPrompt, CreateVarString(10, 'LITERAL_STRING', 'Water Crop'))
    UiPromptSetEnabled(WaterPlantPrompt, false)
    UiPromptSetVisible(WaterPlantPrompt, false)
    UiPromptSetHoldMode(WaterPlantPrompt, true)
    UiPromptRegisterEnd(WaterPlantPrompt)
    UiPromptSetGroup(WaterPlantPrompt, FarmingPromptGroup, 0)

    FertilizePlantPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(FertilizePlantPrompt, 0xD9D0E1C0) -- E key
    UiPromptSetText(FertilizePlantPrompt, CreateVarString(10, 'LITERAL_STRING', 'Fertilize Crop'))
    UiPromptSetEnabled(FertilizePlantPrompt, false)
    UiPromptSetVisible(FertilizePlantPrompt, false)
    UiPromptSetHoldMode(FertilizePlantPrompt, true)
    UiPromptRegisterEnd(FertilizePlantPrompt)
    UiPromptSetGroup(FertilizePlantPrompt, FarmingPromptGroup, 0)

    HarvestPlantPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(HarvestPlantPrompt, 0xD51A84F2) -- F key
    UiPromptSetText(HarvestPlantPrompt, CreateVarString(10, 'LITERAL_STRING', 'Harvest Crop'))
    UiPromptSetEnabled(HarvestPlantPrompt, false)
    UiPromptSetVisible(HarvestPlantPrompt, false)
    UiPromptSetHoldMode(HarvestPlantPrompt, true)
    UiPromptRegisterEnd(HarvestPlantPrompt)
    UiPromptSetGroup(HarvestPlantPrompt, FarmingPromptGroup, 0)

    RemoveWeedsPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(RemoveWeedsPrompt, 0x8FD4EBBA) -- H key
    UiPromptSetText(RemoveWeedsPrompt, CreateVarString(10, 'LITERAL_STRING', 'Remove Weeds'))
    UiPromptSetEnabled(RemoveWeedsPrompt, false)
    UiPromptSetVisible(RemoveWeedsPrompt, false)
    UiPromptSetHoldMode(RemoveWeedsPrompt, true)
    UiPromptRegisterEnd(RemoveWeedsPrompt)
    UiPromptSetGroup(RemoveWeedsPrompt, FarmingPromptGroup, 0)

    DestroyPlantPrompt = UiPromptRegisterBegin()
    UiPromptSetControlAction(DestroyPlantPrompt, 0xB2F377E8) -- L key
    UiPromptSetText(DestroyPlantPrompt, CreateVarString(10, 'LITERAL_STRING', 'Destroy Crop'))
    UiPromptSetEnabled(DestroyPlantPrompt, false)
    UiPromptSetVisible(DestroyPlantPrompt, false)
    UiPromptSetHoldMode(DestroyPlantPrompt, true)
    UiPromptRegisterEnd(DestroyPlantPrompt)
    UiPromptSetGroup(DestroyPlantPrompt, FarmingPromptGroup, 0)
end

-- Open Shop Menu using vorp_menu
local function OpenFarmingShop()
    local MenuData = exports.vorp_menu:GetMenuData()
    MenuData.CloseAll()
    local elements = {}

    for _, item in ipairs(Config.ShopItems) do
        local label = item.name:gsub("_", " "):gsub("^%l", string.upper)
        if item.name == 'emptybucket' then label = 'Empty Bucket'
        elseif item.name == 'fertilizer' then label = 'Fertilizer'
        elseif item.name == 'shovel' then label = 'Shovel'
        end

        elements[#elements + 1] = {
            label = label .. " - $" .. item.price,
            value = item.name,
            price = item.price,
            desc = "Buy " .. label
        }
    end

    MenuData.Open('default', GetCurrentResourceName(), 'farming_shop_menu', {
        title = "Farming Supplies",
        subtext = "Purchase Tools and Seeds",
        align = "top-left",
        elements = elements
    }, function(data, menu)
        if data.current.value then
            local itemSelected = data.current.value
            local itemPrice = data.current.price
            local itemLabel = data.current.label

            local quantityElements = {
                { label = "Buy 1x", value = 1 },
                { label = "Buy 5x", value = 5 },
                { label = "Buy 10x", value = 10 },
                { label = "Buy 50x", value = 50 }
            }

            MenuData.Open('default', GetCurrentResourceName(), 'farming_quantity_menu', {
                title = itemLabel,
                subtext = "Select Quantity",
                align = "top-left",
                elements = quantityElements
            }, function(qData, qMenu)
                if qData.current.value then
                    TriggerServerEvent('devchacha-farming:server:buyItem', itemSelected, itemPrice, qData.current.value)
                    qMenu.close()
                end
            end, function(qData, qMenu)
                qMenu.close()
            end)
        end
    end, function(data, menu)
        menu.close()
    end)
end

-- Proximity thread for native prompts & 3D text overlays
CreateThread(function()
    SetUpFarmingPrompts()
    
    -- Spawn Shop NPCs
    local ShopEntities = {}
    if Config.ShopNPCs then
        for i, shop in pairs(Config.ShopNPCs) do
            local model = GetHashKey(shop.model)
            RequestModel(model)
            while not HasModelLoaded(model) do Wait(10) end
            
            local ped = CreatePed(model, shop.coords.x, shop.coords.y, shop.coords.z - 1.0, shop.heading, false, false, false, false)
            Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
            SetEntityAsMissionEntity(ped, true, true)
            SetEntityInvincible(ped, true)
            FreezeEntityPosition(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            
            local blip = nil
            if shop.blip and shop.blip.enabled then
                blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, shop.coords.x, shop.coords.y, shop.coords.z)
                local spriteHash = shop.blip.sprite
                if type(spriteHash) == 'string' then spriteHash = GetHashKey(spriteHash) end
                SetBlipSprite(blip, spriteHash, true)
                Citizen.InvokeNative(0xD38744167B2FA257, blip, 0.5)
                local blipName = CreateVarString(10, 'LITERAL_STRING', shop.blip.label)
                Citizen.InvokeNative(0x9CB1A1623062F402, blip, blipName)
            end
            
            table.insert(ShopEntities, { ped = ped, blip = blip })
        end
    end

    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        
        -- 1. Check Shop NPCs
        local nearShop = false
        local shopIndex = nil
        if Config.ShopNPCs then
            for i, shop in ipairs(Config.ShopNPCs) do
                local dist = #(coords - shop.coords)
                if dist < 2.0 then
                    nearShop = true
                    shopIndex = i
                    break
                end
            end
        end

        -- 2. Check Water Pumps & Natural Water Sources
        local nearPump = false
        local waterPumps = Config.Pumps or {'p_waterpump01x', 'p_waterpump01x_high'}
        for _, modelName in ipairs(waterPumps) do
            local modelHash = GetHashKey(modelName)
            local pumpObj = GetClosestObjectOfType(coords.x, coords.y, coords.z, 2.0, modelHash, false, false, false)
            if DoesEntityExist(pumpObj) then
                nearPump = true
                break
            end
        end
        local nearWater = IsEntityInWater(ped) and not IsPedInAnyVehicle(ped, true)

        -- 3. Check Plants
        local nearPlant = false
        local nearPlantId = nil
        local minDist = 2.0
        for id, plant in pairs(Plants) do
            local dist = #(coords - vector3(plant.coords.x, plant.coords.y, plant.coords.z))
            if dist < minDist then
                minDist = dist
                nearPlant = true
                nearPlantId = id
            end
        end

        -- Handle Prompt Visibility
        if nearShop then
            sleep = 0
            UiPromptSetEnabled(OpenShopPrompt, true)
            UiPromptSetVisible(OpenShopPrompt, true)
            local groupLabel = CreateVarString(10, 'LITERAL_STRING', "Farming Merchant")
            UiPromptSetActiveGroupThisFrame(FarmingPromptGroup, groupLabel, 0, 0, 0, 0)
            
            if UiPromptHasHoldModeCompleted(OpenShopPrompt) then
                OpenFarmingShop()
                Wait(1000)
            end
        else
            UiPromptSetEnabled(OpenShopPrompt, false)
            UiPromptSetVisible(OpenShopPrompt, false)
        end

        if nearPump or nearWater then
            sleep = 0
            UiPromptSetEnabled(FillBucketPrompt, true)
            UiPromptSetVisible(FillBucketPrompt, true)
            UiPromptSetEnabled(DrinkWaterPrompt, true)
            UiPromptSetVisible(DrinkWaterPrompt, true)
            UiPromptSetEnabled(WashFacePrompt, true)
            UiPromptSetVisible(WashFacePrompt, true)
            
            local groupName = nearPump and "Water Pump" or "Water Source"
            local groupLabel = CreateVarString(10, 'LITERAL_STRING', groupName)
            UiPromptSetActiveGroupThisFrame(FarmingPromptGroup, groupLabel, 0, 0, 0, 0)
            
            if UiPromptHasHoldModeCompleted(FillBucketPrompt) then
                TriggerEvent('devchacha-farming:client:waterAction', 'fillBucket')
                Wait(1000)
            elseif UiPromptHasHoldModeCompleted(DrinkWaterPrompt) then
                TriggerEvent('devchacha-farming:client:waterAction', 'drink')
                Wait(1000)
            elseif UiPromptHasHoldModeCompleted(WashFacePrompt) then
                TriggerEvent('devchacha-farming:client:waterAction', 'wash')
                Wait(1000)
            end
        else
            UiPromptSetEnabled(FillBucketPrompt, false)
            UiPromptSetVisible(FillBucketPrompt, false)
            UiPromptSetEnabled(DrinkWaterPrompt, false)
            UiPromptSetVisible(DrinkWaterPrompt, false)
            UiPromptSetEnabled(WashFacePrompt, false)
            UiPromptSetVisible(WashFacePrompt, false)
        end

        if nearPlant and not nearShop and not nearPump and not nearWater then
            sleep = 0
            local plant = Plants[nearPlantId]
            local growth = CalculateGrowth(plant)
            
            -- Safely parse fields to prevent type comparison thread crashes
            local waterVal = tonumber(plant.water) or 0.0
            local healthVal = tonumber(plant.health) or 100.0
            local weedVal = tonumber(plant.weed) or 0.0
            local fertilizedVal = (plant.fertilized == true or tonumber(plant.fertilized) == 1)
            
            -- Display plant status HUD using 3D Text
            local hudText = string.format("~COLOR_WHITE~%s\n~COLOR_GREEN~Growth: %d%%\n~COLOR_BLUE~Water: %d%%\n~COLOR_RED~Health: %d%%\n~COLOR_YELLOW~Fertilized: %s",
                plant.type,
                growth,
                math.floor(waterVal),
                math.floor(healthVal),
                fertilizedVal and "Yes" or "No"
            )
            DrawText3D(plant.coords.x, plant.coords.y, plant.coords.z + 0.8, hudText)
            
            -- Inspect Prompt (Always available)
            UiPromptSetEnabled(InspectPlantPrompt, true)
            UiPromptSetVisible(InspectPlantPrompt, true)
            
            -- Water Crop Prompt (Available if water < 100)
            local needsWater = waterVal < 100
            UiPromptSetEnabled(WaterPlantPrompt, needsWater)
            UiPromptSetVisible(WaterPlantPrompt, needsWater)
            
            -- Fertilize Crop Prompt (Available if not fertilized)
            local canFertilize = not fertilizedVal
            UiPromptSetEnabled(FertilizePlantPrompt, canFertilize)
            UiPromptSetVisible(FertilizePlantPrompt, canFertilize)
            
            -- Harvest Crop Prompt (Available if growth >= 100)
            local canHarvest = growth >= 100
            UiPromptSetEnabled(HarvestPlantPrompt, canHarvest)
            UiPromptSetVisible(HarvestPlantPrompt, canHarvest)
            
            -- Remove Weeds Prompt (Available if weeds > 0)
            local hasWeeds = weedVal > 0
            UiPromptSetEnabled(RemoveWeedsPrompt, hasWeeds)
            UiPromptSetVisible(RemoveWeedsPrompt, hasWeeds)
            
            -- Destroy Crop Prompt (Always available)
            UiPromptSetEnabled(DestroyPlantPrompt, true)
            UiPromptSetVisible(DestroyPlantPrompt, true)
            
            local groupLabel = CreateVarString(10, 'LITERAL_STRING', plant.type)
            UiPromptSetActiveGroupThisFrame(FarmingPromptGroup, groupLabel, 0, 0, 0, 0)
            
            if UiPromptHasHoldModeCompleted(InspectPlantPrompt) then
                ShowPlantMenu(nearPlantId)
                Wait(1000)
            elseif UiPromptHasHoldModeCompleted(WaterPlantPrompt) then
                WaterPlant(nearPlantId)
                Wait(1000)
            elseif UiPromptHasHoldModeCompleted(FertilizePlantPrompt) then
                FertilizePlant(nearPlantId)
                Wait(1000)
            elseif UiPromptHasHoldModeCompleted(HarvestPlantPrompt) then
                HarvestPlant(nearPlantId)
                Wait(1000)
            elseif UiPromptHasHoldModeCompleted(RemoveWeedsPrompt) then
                RemoveWeeds(nearPlantId)
                Wait(1000)
            elseif UiPromptHasHoldModeCompleted(DestroyPlantPrompt) then
                DestroyPlant(nearPlantId)
                Wait(1000)
            end
        else
            UiPromptSetEnabled(InspectPlantPrompt, false)
            UiPromptSetVisible(InspectPlantPrompt, false)
            UiPromptSetEnabled(WaterPlantPrompt, false)
            UiPromptSetVisible(WaterPlantPrompt, false)
            UiPromptSetEnabled(FertilizePlantPrompt, false)
            UiPromptSetVisible(FertilizePlantPrompt, false)
            UiPromptSetEnabled(HarvestPlantPrompt, false)
            UiPromptSetVisible(HarvestPlantPrompt, false)
            UiPromptSetEnabled(RemoveWeedsPrompt, false)
            UiPromptSetVisible(RemoveWeedsPrompt, false)
            UiPromptSetEnabled(DestroyPlantPrompt, false)
            UiPromptSetVisible(DestroyPlantPrompt, false)
        end

        Wait(sleep)
    end
end)
