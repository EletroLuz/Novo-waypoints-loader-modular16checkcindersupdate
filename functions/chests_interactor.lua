local Movement = require("functions.movement")
local menu = require("menu")
local interactive_patterns = require("enums.interactive_patterns")

local ChestsInteractor = {}

-- Initialize variables
local interactedObjects = {}
local blacklist = {}
local expiration_time = 10 -- Time to stop when interacting with a chest

-- Function to get player's cinders
local function get_player_cinders()
    return get_helltide_coin_cinders()
end

-- Function to check if player has enough cinders
local function has_enough_cinders(obj_name)
    local player_cinders = get_player_cinders()
    local required_cinders = interactive_patterns[obj_name]
    
    if type(required_cinders) == "table" then
        for _, cinders in ipairs(required_cinders) do
            if player_cinders >= cinders then
                return true
            end
        end
    elseif type(required_cinders) == "number" then
        return player_cinders >= required_cinders
    end
    
    return false
end

-- Function to check if object is in blacklist
local function is_blacklisted(obj)
    local obj_name = obj:get_skin_name()
    local obj_pos = obj:get_position()
    
    for _, blacklisted_obj in ipairs(blacklist) do
        -- Check if position and name are the same (accounting for small distance difference)
        if blacklisted_obj.name == obj_name and blacklisted_obj.position:dist_to(obj_pos) < 0.1 then
            return true
        end
    end
    
    return false
end

-- Function to add object to blacklist
local function add_to_blacklist(obj)
    local obj_name = obj:get_skin_name()
    local obj_pos = obj:get_position()

    local pos_string = "unknown position"
    if obj_pos then
        -- Usar os métodos x(), y(), e z() para acessar as coordenadas
        pos_string = string.format("(%.2f, %.2f, %.2f)", obj_pos:x(), obj_pos:y(), obj_pos:z())
    end

    table.insert(blacklist, {name = obj_name, position = obj_pos})
    console.print("Added " .. obj_name .. " to blacklist at position: " .. pos_string)
end

-- Function to move to and interact with an object
local function moveToAndInteract(obj)
    local player_pos = get_player_position()
    local obj_pos = obj:get_position()
    local distanceThreshold = 2.0
    local moveThreshold = menu.move_threshold_slider:get()
    local distance = obj_pos:dist_to(player_pos)
    
    if distance < distanceThreshold then
        Movement.set_interacting(true)
        local obj_name = obj:get_skin_name()
        interactedObjects[obj_name] = os.clock() + expiration_time
        interact_object(obj)
        console.print("Interacting with " .. obj_name)
        
        -- Check if cinders decreased after interaction
        local initial_cinders = get_player_cinders()
        local interaction_start_time = os.clock()
        local check_duration = 5 -- Check for 5 seconds
        
        -- Set a flag to check in the next frame
        ChestsInteractor.checking_interaction = {
            obj = obj,
            initial_cinders = initial_cinders,
            start_time = interaction_start_time,
            duration = check_duration
        }
        
        Movement.set_interaction_end_time(os.clock() + 5) -- 5 seconds interaction, adjust as needed
        return true
    elseif distance < moveThreshold then
        pathfinder.request_move(obj_pos)
        return false
    end
end

-- Function to check interaction result
function ChestsInteractor.checkInteractionResult()
    if ChestsInteractor.checking_interaction then
        local check = ChestsInteractor.checking_interaction
        local current_time = os.clock()
        
        -- Check if the current time is still within the duration
        if current_time - check.start_time < check.duration then
            local current_cinders = get_player_cinders()
            
            -- Check if the cinders have decreased
            if current_cinders < check.initial_cinders then
                if check.obj then
                    add_to_blacklist(check.obj)
                    console.print("Cinders decreased. Object added to blacklist.")
                else
                    console.print("Error: Object is nil, cannot add to blacklist.")
                end
                ChestsInteractor.checking_interaction = nil
            end
        else
            console.print("Interaction check timed out. No cinder decrease detected.")
            ChestsInteractor.checking_interaction = nil
        end
    else
        --console.print("No interaction to check.")
    end
end

-- Function to interact with objects
function ChestsInteractor.interactWithObjects(doorsEnabled)
    local local_player = get_local_player()
    if not local_player then return end
    
    local objects = actors_manager.get_ally_actors()
    if not objects then return end
    
    for _, obj in ipairs(objects) do
        if obj then
            local obj_name = obj:get_skin_name()
            if obj_name and interactive_patterns[obj_name] then
                if doorsEnabled and (not interactedObjects[obj_name] or os.clock() > interactedObjects[obj_name]) then
                    if not is_blacklisted(obj) and has_enough_cinders(obj_name) then
                        console.print("Attempting to interact with " .. obj_name)
                        if moveToAndInteract(obj) then
                            return
                        end
                    else
                        console.print("Skipping " .. obj_name .. ": blacklisted or not enough cinders")
                    end
                end
            end
        end
    end
end

-- Function to clear interacted objects
function ChestsInteractor.clearInteractedObjects()
    interactedObjects = {}
    console.print("Cleared interacted objects list")
end

-- Function to clear blacklist
function ChestsInteractor.clearBlacklist()
    blacklist = {}
    console.print("Cleared blacklist")
end

-- Debug function to print blacklist
function ChestsInteractor.printBlacklist()
    console.print("Current Blacklist:")
    for i, item in ipairs(blacklist) do
        -- Usa to_string() para garantir que o vec3 seja convertido corretamente
        if item.position and item.position.to_string then
            console.print(i .. ": " .. item.name .. " at position: " .. item.position:to_string())
        else
            console.print(i .. ": " .. item.name .. " has an invalid position")
        end
    end
end

return ChestsInteractor
