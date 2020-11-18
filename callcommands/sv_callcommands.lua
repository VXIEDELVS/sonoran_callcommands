--[[
    Sonaran CAD Plugins

    Plugin Name: callcommands
    Creator: SonoranCAD
    Description: Implements 311/511/911 commands
]]

local pluginConfig = Config.GetPluginConfig("callcommands")

if pluginConfig.enabled then
    -- 911/311 Handler
    function HandleCivilianCall(type, source, args, rawCommand)
        -- Getting the user's Steam Hexidecimal and getting their location from the table.
        local isEmergency = type == "911" and true or false
        local identifier = GetIdentifiers(source)[Config.primaryIdentifier]
        local index = findIndex(identifier)
        local callLocation = LocationCache[source] ~= nil and LocationCache[source].location or 'Unknown'
        -- Checking if there are any description arguments.
        if args[1] then
            local description = table.concat(args, " ")
            if type == "511" then
                description = "(511 CALL) "..description
            end
            local caller = nil
            if isPluginLoaded("esxsupport") then
                -- Getting the ESX Identity Name
                GetIdentity(source, function(identity)
                    if identity.name ~= nil then
                        caller = identity.name
                    else
                        caller = GetPlayerName(source)
                        debugLog("Unable to get player name from ESX. Falled back to in-game name.")
                    end
                end)
                while caller == nil do
                    Wait(10)
                end
            else
                caller = GetPlayerName(source) 
            end
            -- Sending the API event
            TriggerEvent('SonoranCAD::callcommands:SendCallApi', isEmergency, caller, callLocation, description, source)
            -- Sending the user a message stating the call has been sent
            TriggerClientEvent("chat:addMessage", source, {args = {"^0^5^*[SonoranCAD]^r ", "^7Your call has been sent to dispatch. Help is on the way!"}})
        else
            -- Throwing an error message due to now call description stated
            TriggerClientEvent("chat:addMessage", source, {args = {"^0[ ^1Error ^0] ", "You need to specify a call description."}})
        end
    end

    CreateThread(function()
        if pluginConfig.enable911 then
            RegisterCommand('911', function(source, args, rawCommand)
                HandleCivilianCall("911", source, args, rawCommand)
            end, false)
        end
        if pluginConfig.enable511 then
            RegisterCommand('511', function(source, args, rawCommand)
                HandleCivilianCall("511", source, args, rawCommand)
            end, false)
        end
        if pluginConfig.enable311 then
            RegisterCommand('311', function(source, args, rawCommand)
                HandleCivilianCall("311", source, args, rawCommand)
            end, false)
        end
        if pluginConfig.enablePanic then
            RegisterCommand('panic', function(source, args, rawCommand)
                sendPanic(source)
            end, false)
            -- Client Panic request (to be used by other resources)
            RegisterNetEvent('SonoranCAD::callcommands:SendPanicApi')
            AddEventHandler('SonoranCAD::callcommands:SendPanicApi', function(source)
                sendPanic(source)
            end)
        end

    end)

    -- Client Call request
    RegisterServerEvent('SonoranCAD::callcommands:SendCallApi')
    AddEventHandler('SonoranCAD::callcommands:SendCallApi', function(emergency, caller, location, description, source)
        -- send an event to be consumed by other resources
        TriggerEvent("SonoranCAD::callcommands:cadIncomingCall", emergency, caller, location, description, source)
        if Config.apiSendEnabled then
            local data = {['serverId'] = Config.serverId, ['isEmergency'] = emergency, ['caller'] = caller, ['location'] = location, ['description'] = description}
            debugLog("sending call!")
            performApiRequest({data}, 'CALL_911', function() end)
        else
            debugPrint("[SonoranCAD] API sending is disabled. Incoming call ignored.")
        end
    end)

    ---------------------------------
    -- Unit Panic
    ---------------------------------
    -- shared function to send panic signals
    function sendPanic(source)
        -- Determine identifier
        local identifier = GetIdentifiers(source)[Config.primaryIdentifier]
        -- Process panic POST request
        performApiRequest({{['isPanic'] = true, ['apiId'] = identifier}}, 'UNIT_PANIC', function() end)
    end

end