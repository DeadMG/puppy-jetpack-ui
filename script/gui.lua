local gui = require("__flib__.gui")

local windowName = "jetpack_ui"

function toolbarHeight(scale)
    return scale * 135
end

function renderTime(seconds)
    seconds = math.floor(seconds)
    
    if seconds < 60 then
        return {"time-symbol-seconds-short", seconds }
    end

    local minutes = math.floor(seconds / 60)
    if minutes < 60 then
        return {"",  {"time-symbol-minutes-short", minutes }, " ", {"time-symbol-seconds-short", seconds % 60 } }
    end
    
    local hours = math.floor(seconds / 3600)
    return {"",  {"time-symbol-hours-short", hours }, " ", {"time-symbol-minutes-short", minutes % 60 }, " ", {"time-symbol-seconds-short", seconds % 60 } }
end

function syncDataToUI(player_index)
    local player = game.get_player(player_index)    
    local ui_state = storage.ui_state[player_index]
    
    if not ui_state.dialog then return end
    
    local fuels = remote.call('jetpack', 'get_fuels', {})    
    local total = ui_state.remaining_energy
    for _, fuel in pairs(fuels) do
        local fuelType = fuel.fuel_name
        local proto = prototypes.item[fuelType]
        if proto then
            total = total + player.get_item_count(fuelType) * proto.fuel_value
        end
    end
    
    ui_state.dialog.fuel_remaining.value = ui_state.remaining_energy / prototypes.item[ui_state.item_name].fuel_value
    ui_state.dialog.item_icon.sprite = "item/" .. ui_state.item_name
    ui_state.dialog.item_count.caption = player.get_item_count(ui_state.item_name)
    
    if ui_state.estimated_consumption then
        ui_state.dialog.estimated_time.caption = {"jetpack-ui.estimated-remaining", renderTime(total / ui_state.estimated_consumption) }
    end
end

local function is_position_off_screen(position, resolution)
    return position.x < 0 or position.y < 0 or
           position.x > (resolution.width - 20) or
           position.y > (resolution.height - 20)
end

function ensureWindow(player_index)
    local player = game.get_player(player_index)

    local rootgui = player.gui.screen
    
    if rootgui[windowName] then return end
    
    local dialog = gui.add(rootgui, {
        {type="frame", direction="vertical", name=windowName, style_mods={left_padding=0,left_margin=0, bottom_margin=0}, children={
            {type="flow", style_mods={left_padding=0,left_margin=-6}, children={
                {type = "empty-widget", style="draggable_space",  style_mods={left_padding=0, left_margin=0}, name="drag_handle", drag_target=windowName, style_mods={width=8, height=45} },
                {type="flow", direction="vertical", children = {
                    {type="flow", name="main_container", style_mods= {vertical_align="center", left_margin=0}, children={
                        {type="sprite", elem_type="item", sprite=nil, name="item_icon", resize_to_sprite=false, style_mods= { height = 16, width = 16 } },
                        {type="label", name="item_count" },
                        {type="progressbar", name="fuel_remaining", style_mods= { color={r=1, g=0.667, b=0.2}, vertical_align="center", width="120" } }}},
                    {type="label", name="estimated_time", caption=nil },
                }}
            }}}}})
            
    storage.ui_state[player_index].dialog = dialog
    
    local ui_state = storage.ui_state[player_index]
    if ui_state.location and not is_position_off_screen(ui_state.location, player.display_resolution) then
        dialog[windowName].location = storage.ui_state[player_index].location
    else
        dialog[windowName].location = { 0, player.display_resolution.height - toolbarHeight(player.display_scale) }
    end
end

function openGui(player_index)
    local player = game.get_player(player_index)
    local rootgui = player.gui.screen
    if not rootgui[windowName] then createWindow(player_index) end
end

function closeGui(player_index)
    local player = game.get_player(player_index)
    local rootgui = player.gui.screen
    if rootgui[windowName] then
        rootgui[windowName].destroy()	
        if storage.ui_state and storage.ui_state[player_index] then
            storage.ui_state[player_index].dialog = nil
        end
    end
end

function any(table, filter)
    for _, value in pairs(table) do
        if filter(value) then return true end
    end
    return false
end

function syncData()
    storage.ui_state = storage.ui_state or {}
    
    local fuels = remote.call("jetpack", "get_current_fuels");
    for k, player in pairs(game.players) do
        local character = player.character
        if character and character.valid then
            local is_jetpacking = remote.call("jetpack", "is_jetpacking", {character=character})
            local fuel = fuels[character.unit_number]
            
            if not is_jetpacking or not fuel then
                closeGui(player.index)
            else
                storage.ui_state[player.index] = storage.ui_state[player.index] or {}
                
                local ui_state = storage.ui_state[player.index]
                
                if ui_state.remaining_energy then         
                    local consumption = ui_state.remaining_energy - fuel.energy
                    local timeTaken = game.tick - ui_state.synced_tick
                    ui_state.estimated_consumption = consumption * (60 / timeTaken)
                end
                
                ui_state.synced_tick = game.tick
                ui_state.remaining_energy = fuel.energy
                ui_state.item_name = fuel.name
                
                if ui_state.estimated_consumption == 0 then
                    closeGui(player.index)
                else
                    if ui_state.estimated_consumption then
                        ensureWindow(player.index)
                        syncDataToUI(player.index)
                    end
                end
            end
        end
    end
end

gui.add_handlers({
    jetpack_ui_handlers = {
        close_button = {
            on_gui_click = function(e)
                closeGui(e.player_index)
            end -- on_gui_click
        }
    }
});
    
script.on_event(defines.events.on_gui_location_changed, function(e)
    if not e.element or e.element.name ~= windowName then return end
    
    storage.ui_state = storage.ui_state or {}
    storage.ui_state[e.player_index] = storage.ui_state[e.player_index] or {}
    storage.ui_state[e.player_index].location = e.element.location
end)

script.on_nth_tick(5, syncData)

script.on_init(function()
  storage.ui_state = {}
end)
