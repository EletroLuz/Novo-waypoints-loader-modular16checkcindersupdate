-- functions/nearest_waypoint.lua

local nearest_waypoint = {}

-- Função para calcular a distância entre dois pontos
local function calculate_distance(point1, point2)
    return ((point1.x - point2.x)^2 + (point1.y - point2.y)^2 + (point1.z - point2.z)^2)^0.5
end

-- Função principal para encontrar o waypoint mais próximo
function nearest_waypoint.find_nearest(waypoints, player_position)
    if not waypoints or #waypoints == 0 then
        console.print("Error: No waypoints available")
        return nil, nil
    end

    local nearest = waypoints[1]
    local nearest_index = 1
    local min_distance = calculate_distance(player_position, nearest)

    for i = 2, #waypoints do
        local distance = calculate_distance(player_position, waypoints[i])
        if distance < min_distance then
            min_distance = distance
            nearest = waypoints[i]
            nearest_index = i
        end
    end

    return nearest, nearest_index
end

return nearest_waypoint