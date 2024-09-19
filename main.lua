-- Import modules
local menu = require("menu")
menu.plugin_enabled:set(false)
local menu_renderer = require("graphics.menu_renderer")
local revive = require("data.revive")
local explorer = require("data.explorer")
local automindcage = require("data.automindcage")
local actors = require("data.actors")
local waypoint_loader = require("functions.waypoint_loader")
local Movement = require("functions.movement")
local ChestsInteractor = require("functions.chests_interactor")
local teleport = require("data.teleport")
local GameStateChecker = require("functions.game_state_checker")

-- Initialize variables
local plugin_enabled = false
local doorsEnabled = false
local loopEnabled = false
local revive_enabled = false
local profane_mindcage_enabled = false
local profane_mindcage_count = 0
local graphics_enabled = false
local was_in_helltide = false
local last_cleanup_time = 0
local cleanup_interval = 300 -- 5 minutos

local function periodic_cleanup()
    local current_time = os.clock()
    if current_time - last_cleanup_time > cleanup_interval then
        collectgarbage("collect")
        ChestsInteractor.clearInteractedObjects()
        waypoint_loader.clear_cached_waypoints()
        last_cleanup_time = current_time
        console.print("Periodic cleanup performed")
    end
end

-- Function to update menu states
local function update_menu_states()
    local new_plugin_enabled = menu.plugin_enabled:get()
    if new_plugin_enabled ~= plugin_enabled then
        plugin_enabled = new_plugin_enabled
        console.print("Movement Plugin " .. (plugin_enabled and "enabled" or "disabled"))
        if plugin_enabled then
            local waypoints, _ = waypoint_loader.check_and_load_waypoints()
            Movement.set_waypoints(waypoints)
        else
            Movement.save_last_index()
         end
    end

    doorsEnabled = menu.main_openDoors_enabled:get()
    loopEnabled = menu.loop_enabled:get()
    revive_enabled = menu.revive_enabled:get()
    profane_mindcage_enabled = menu.profane_mindcage_toggle:get()
    profane_mindcage_count = menu.profane_mindcage_slider:get()
end

-- Main update function
on_update(function()
    local current_time = os.clock()
    update_menu_states()
    periodic_cleanup()

    -- Adicione esta linha para verificar o resultado da interação
    ChestsInteractor.checkInteractionResult()

    if plugin_enabled then
        local local_player = get_local_player()
        if not local_player then return end

        local world_instance = world.get_current_world()
        if not world_instance then return end

        local teleport_state = teleport.get_teleport_state()

        if teleport_state ~= "idle" then
            if teleport.tp_to_next(ChestsInteractor, Movement) then
                console.print("Teleport completed. Loading new waypoints...")
                local waypoints, _ = waypoint_loader.check_and_load_waypoints()
                Movement.set_waypoints(waypoints)
            end
        else
            local current_in_helltide = GameStateChecker.is_in_helltide(local_player)
            
            if was_in_helltide and not current_in_helltide then
                console.print("Helltide ended. Performing cleanup.")
                Movement.reset()
                ChestsInteractor.clearInteractedObjects()
                ChestsInteractor.clearBlacklist()  -- Adicione esta linha para limpar a blacklist
                was_in_helltide = false
            end

            if current_in_helltide then
                was_in_helltide = true
                if profane_mindcage_enabled then
                    automindcage.update()
                end
                -- Atualize esta linha para remover o parâmetro interactive_patterns
                ChestsInteractor.interactWithObjects(doorsEnabled)
                Movement.set_moving(true)
                Movement.pulse(plugin_enabled, loopEnabled, teleport)
                if revive_enabled then
                    revive.check_and_revive()
                end
                actors.update()
            else
                console.print("Not in the Helltide zone. Attempting to teleport...")
                if teleport.tp_to_next(ChestsInteractor, Movement) then
                    console.print("Teleported successfully. Loading new waypoints...")
                    local waypoints, _ = waypoint_loader.check_and_load_waypoints()
                    Movement.set_waypoints(waypoints)
                else
                    local state = teleport.get_teleport_state()
                    console.print("Teleport in progress. Current state: " .. state)
                end
            end
        end
    end
end)

-- Render menu function
on_render_menu(function()
    menu_renderer.render_menu(plugin_enabled, doorsEnabled, loopEnabled, revive_enabled, profane_mindcage_enabled, profane_mindcage_count)
end)