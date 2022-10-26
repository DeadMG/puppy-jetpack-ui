local gui = require("lib.gui")
local event = require("__flib__.event")

local windowName = "jetpack-ui"

function toolbarHeight(scale)
    return scale * 135
end

function syncDataToUI(player_index)
    local player = game.get_player(player_index)    
    local ui_state = global.ui_state[player_index]
    
    if not ui_state.dialog then return end
    
    ui_state.dialog.fuel_remaining.value = ui_state.fuel_remaining
    ui_state.dialog.item_icon.sprite = "item/" .. ui_state.item_name
    ui_state.dialog.item_count.caption = player.get_item_count(ui_state.item_name)
end

function ensureWindow(player_index)
    local player = game.get_player(player_index)

    local rootgui = player.gui.screen
    
    if rootgui[windowName] then return end
    
    local dialog = gui.build(rootgui, {
        {type="frame", direction="vertical", save_as="main_window", name=windowName, children={
            {type="flow", save_as="main_container", style_mods= {vertical_align="center"}, children={
                {type="sprite", elem_type="item", sprite=nil, save_as="item_icon", style_mods= { height = 14, width = 14 } },
                {type="label", save_as="item_count" },
                {type="progressbar", save_as="fuel_remaining", style_mods= { color={r=1, g=0.667, b=0.2}, vertical_align="center", width="134" } }}},
            }}})
            
    dialog.main_container.drag_target = dialog.main_window
    global.ui_state[player_index].dialog = dialog    
    
    local ui_state = global.ui_state[player_index]
    if ui_state.location then
        dialog.main_window.location = global.ui_state[player_index].location
    else
        dialog.main_window.location = { 0, player.display_resolution.height - toolbarHeight(player.display_scale) }
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
        if global.ui_state and global.ui_state[player_index] then
            global.ui_state[player_index].dialog = nil
        end
    end
end

function registerHandlers()
    gui.add_handlers({
        jetpack_ui_handlers = {
            close_button = {
                on_gui_click = function(e)
                    closeGui(e.player_index)
                end -- on_gui_click
            }
        }
    })
    gui.register_handlers()
end

function registerTemplates() 
  gui.add_templates{
    frame_action_button = {type="sprite-button", style="frame_action_button", mouse_button_filter={"left"}},
    drag_handle = {type="empty-widget", style="flib_titlebar_drag_handle", elem_mods={ignored_by_interaction=true}},
  }
end

registerHandlers()
registerTemplates()

function any(table, filter)
    for _, value in pairs(table) do
        if filter(value) then return true end
    end
    return false
end

function syncData()
    global.ui_state = global.ui_state or {}
    
    local jetpacks = remote.call('jetpack', 'get_jetpacks', {})

    for _, jetpack in pairs(jetpacks) do
        if jetpack.status == 'stopping' then
            closeGui(jetpack.player_index)
        else
            global.ui_state[jetpack.player_index] = global.ui_state[jetpack.player_index] or {}
            
            local ui_state = global.ui_state[jetpack.player_index]
            ui_state.fuel_remaining = jetpack.fuel.energy / game.item_prototypes[jetpack.fuel.name].fuel_value
            ui_state.item_name = jetpack.fuel.name
            
            ensureWindow(jetpack.player_index)
            syncDataToUI(jetpack.player_index)
        end
    end    
    
    for player_index, ui_state in pairs(global.ui_state) do
        if not any(jetpacks, function(jetpack) return jetpack and jetpack.player_index == player_index end) then
            closeGui(player_index)
        end
    end
end

event.register(defines.events.on_gui_location_changed, function(e)
    if not e.element or e.element.name ~= windowName then return end
    
    global.ui_state = global.ui_state or {}
    global.ui_state[e.player_index] = global.ui_state[e.player_index] or {}
    global.ui_state[e.player_index].location = e.element.location
end)

script.on_nth_tick(60, syncData)

event.register('jetpack', syncData)

event.on_load(function()
  gui.build_lookup_tables()
end)

event.on_init(function()
  gui.init()
  gui.build_lookup_tables()
  global.ui_state = {}
end)
