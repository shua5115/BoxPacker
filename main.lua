local g = love.graphics
local ui = require "suit"
local box_solver = require "box"
local test = require "test"
local serde = require "serializetable"
local LenInput = require "len_input"

local SAVE_DIR = love.filesystem.getSaveDirectory()
local SAVE_FILE = "save.txt"

local solver
local solver_errmsg
local solution

local ui_boxes = {}
local BOX_LIST_W = 500
local bw_data = { text = "10in", min = 0 }
local bh_data = { text = "10in", min = 0 }
local gridw_data = { value = 10, step = 1, min = 1, max = 256 }
local gridh_data = { value = 10, step = 1, min = 1, max = 256 }
local margin_data = { text = "0", min = 0 }
local items_scroll_data = { value = 0, step = 1, min = 0 }
local items_scroll_options = { id = items_scroll_data, vertical = true }
local active_box = nil

local function load_save_file()
    local save_file, errmsg = love.filesystem.read(SAVE_FILE)
    if save_file then
        local save_table = table.loadstring(save_file)
        if save_table then
            ui_boxes = save_table
        end
    else
        print(errmsg)
    end
end

local function save_save_file()
    local savestr = table.savestring(ui_boxes)
    local _, err = love.filesystem.write(SAVE_FILE, savestr)
    if err then
        print(err)
    end
end

function love.load()
    g.setBackgroundColor(1, 1, 1)
    love.keyboard.setKeyRepeat(true)
    load_save_file()
end

---@param name string?
---@return UIBox
local function new_ui_box(name)
    ---@class UIBox
    local b = {
        name = name or "",
        text = name or "",
        w = 1,
        h = 1,
        w_data = { text = "1 in", min=0 },
        h_data = { text = "1 in", min=0 },
        can_rot_data = { text = "Can rotate?", checked = false },
    }
    return b
end

local x_color = {
    normal  = { bg = { 0.8, 0, 0 }, fg = { 0.1, 0.1, 0.1 } },
    hovered = { bg = { 1, 0, 0 }, fg = { 0.1, 0.1, 0.1 } },
    active  = { bg = { 0.69, 0, 0 }, fg = { 0.1, 0.1, 0.1 } }
}
---@param uibox UIBox
local function boxInput(uibox)
    local is_focused = false
    local og_w, og_h = ui.layout:size()
    ui.Input(uibox, ui.layout:row(og_w / 4, 20))
    if ui.hasKeyboardFocus(uibox) then
        is_focused = true
    end
    uibox.name = uibox.text
    ui.layout:push(ui.layout:nextCol())

    local len_result
    local w_data = uibox.w_data
    w_data.min = 0
    -- w_data.max = bw_data.value
    len_result = LenInput(ui, uibox.w_data, ui.layout:col(og_w / 6, 20))
    if ui.hasKeyboardFocus(uibox.w_data) then
        is_focused = true
    end
    ui.Label("x", ui.layout:col(og_w / 12, 20))
    local h_data = uibox.h_data
    h_data.min = 0
    -- h_data.max = bh_data.value
    len_result = LenInput(ui, uibox.h_data, ui.layout:col(og_w / 6, 20))
    if ui.hasKeyboardFocus(uibox.h_data) then
        is_focused = true
    end

    -- ui.Label(string.format("(%.2f x %.2f)", uibox.w, uibox.h), ui.layout:col(og_w / 3, 20))
    ui.Checkbox(uibox.can_rot_data, ui.layout:col(og_w / 4, 25))
    if ui.Button("x", { id = tostring(uibox) .. "close", color = x_color }, ui.layout:col(og_w / 12, 20)).hit then
        for i, v in ipairs(ui_boxes) do
            if v == uibox then
                table.remove(ui_boxes, i)
                break
            end
        end
    end
    ui.layout:pop()
    uibox.w = w_data.value
    uibox.h = h_data.value
    uibox.can_rot = uibox.can_rot_data.checked
    ui.layout:size(og_w, og_h)
    return is_focused
end

function love.update(dt)
    ui.layout:reset()
    if ui.Button("Save", ui.layout:col(250, 25)).hit then
        save_save_file()
    end
    if ui.Button("Load", ui.layout:col(250, 25)).hit then
        load_save_file()
    end
    ui.layout:reset(0, 25)
    ui.Label("Setup", ui.layout:row(475, 25))
    local og_w = ui.layout:size(500, 25)

    ui.layout:push(ui.layout:nextRow())
    ui.Label("Bounds", ui.layout:row(og_w / 4, 20))
    -- ui.Slider(bw_data, ui.layout:col(og_w / 2, 20))
    LenInput(ui, bw_data, ui.layout:col(og_w / 4, 20))
    ui.Label("x", ui.layout:col(og_w / 12, 20))
    LenInput(ui, bh_data, ui.layout:col(og_w / 4, 20))
    ui.layout:pop()
    ui.layout:row()
    -- ui.layout:push(ui.layout:nextRow())
    -- ui.Label(string.format("Height: %.2f", bh_data.value), ui.layout:row(og_w / 2, 20))
    -- ui.Slider(bh_data, ui.layout:col(og_w / 2, 20))
    -- ui.layout:pop()
    -- ui.layout:row()
    ui.layout:push(ui.layout:nextRow())
    ui.Label(string.format("Grid width: %d", gridw_data.value), ui.layout:row(og_w / 3, 20))
    ui.Slider(gridw_data, ui.layout:col(og_w * 2 / 3, 20))
    ui.layout:pop()
    ui.layout:row()
    ui.layout:push(ui.layout:nextRow())
    ui.Label(string.format("Grid height: %d", gridh_data.value), ui.layout:row(og_w / 3, 20))
    ui.Slider(gridh_data, ui.layout:col(og_w * 2 / 3, 20))
    ui.layout:pop()
    ui.layout:row()
    ui.layout:push(ui.layout:nextRow())
    ui.Label("Contact Margin", ui.layout:row(og_w / 4, 20))
    LenInput(ui, margin_data, ui.layout:col(og_w / 4, 20))
    -- ui.Slider(margin_data, ui.layout:col(og_w / 2, 20))
    ui.layout:pop()
    gridw_data.value = math.floor(gridw_data.value)
    gridh_data.value = math.floor(gridh_data.value)


    ui.layout:row(500, 25)

    ui.layout:push(475, ui.layout._y + 2 * (ui.layout._h + ui.layout._pady))
    local n_items = #ui_boxes
    local h_per_item = 27.5
    local view_h = g.getHeight() - ui.layout._y
    local n_can_see = math.floor(view_h / h_per_item)
    local scroll_steps = math.max(n_items - n_can_see, 0)
    local n_can_actually_see = math.min(n_items, n_can_see)
    items_scroll_data.max = scroll_steps
    local items_scroll = ui.Slider(items_scroll_data, items_scroll_options, ui.layout:col(30, view_h - h_per_item))
    items_scroll_data.value = math.floor(items_scroll_data.value + 0.5)
    items_scroll_data.value = math.min(items_scroll_data.value, items_scroll_data.max)
    items_scroll_data.value = math.max(items_scroll_data.value, items_scroll_data.min)
    ui.layout:pop()
    local nx, ny, nw, nh = ui.layout:row(500, 25)
    if n_items > 0 then
        if ui.Button("Solve!", nx + nw * 0.125, ny, nw * 0.75, nh).hit then
            ui.keyboardFocus = nil
            solver, solver_errmsg = box_solver.new(
                ui_boxes,
                bw_data.value, bh_data.value,
                gridw_data.value, gridh_data.value,
                margin_data.value)
            if solver then
                solver:generate_orderings("biggest_area")
                solver:pack_all()
                solution = solver:most_compact()
                -- if solution then
                --     for _, v in ipairs(solution) do
                --         io.write(string.format("%d, %d, %d, %d\n", v.x, v.y, v.w, v.h))
                --     end
                -- end
                solution = solver:ungrid_packing(solution)
            end
        end
        if solver_errmsg then
            ui.Label(solver_errmsg, ui.layout:row(nil, 15))
        end
    end

    ui.Label("Items", ui.layout:row(475, 25))
    active_box = nil
    ui.layout._x = 25
    ui.layout:size(450, 25)
    for i = 1, n_can_actually_see do
        i = math.max(1, i + (n_items - n_can_actually_see) - items_scroll_data.value)
        local _, num_y = ui.layout:nextRow()
        ui.Label(i..".", 0, num_y, 25, 25)
        local b = ui_boxes[i]
        if b and boxInput(b) then
            active_box = b
        end
    end

    if ui.Button("+", ui.layout:row(nil, 35)).hit then
        local idx = #ui_boxes + 1
        local b = new_ui_box()
        ui_boxes[idx] = b
    end
end

function love.draw()
    local view_aspect = bw_data.value / bh_data.value
    local view_w = g.getWidth() - 520
    local view_h = view_w / view_aspect
    if view_h > g.getHeight() - 10 then
        view_h = g.getHeight() - 10
        view_w = view_h * view_aspect
    end
    g.setColor(0, 0, 0)
    g.line(510, 0, 510, g.getHeight())
    if view_w > 0 and view_h > 0 then
        local bounds_scale = view_w / bw_data.value
        g.push()
        g.translate((g.getWidth() + 510 - view_w) * 0.5, (g.getHeight() - view_h) * 0.5)
        g.setColor(0.5, 0.5, 0.5)
        g.rectangle("line", 0, 0, view_w, view_h)
        for i = 1, gridw_data.value do
            local x = i * view_w / (gridw_data.value)
            g.line(x, 0, x, view_h)
        end
        for i = 1, gridh_data.value do
            local y = i * view_h / (gridh_data.value)
            g.line(0, y, view_w, y)
        end
        
        local function draw_box(b, with_grid)
            local bx = (b.x or 0) * bounds_scale
            local by = (b.y or 0) * bounds_scale
            local bw = (b.og_w or b.w) * bounds_scale
            local bh = (b.og_h or b.h) * bounds_scale
            local cell_w = bw_data.value / gridw_data.value
            local cell_h = bh_data.value / gridh_data.value
            local gw = math.ceil((b.w + margin_data.value) / cell_w) * cell_w * bounds_scale;
            local gh = math.ceil((b.h + margin_data.value) / cell_h) * cell_h * bounds_scale;
            g.push("all")
            g.translate(bx, by)
            if with_grid then
                g.setColor(1, 0, 0)
                g.rectangle("fill", 0, 0, gw, gh)
            end
            g.setColor(0, 0.4, 0.75)
            g.rectangle("fill", 0, 0, bw, bh)
            g.setColor(0, 0, 0)
            g.rectangle("line", 0, 0, bw, bh)
            g.printf(b.name, 0, math.floor(bh * 0.5) - 8, bw, "center")
            g.pop()
        end

        if active_box then
            draw_box(active_box, true)
        elseif solution then
            for i, b in ipairs(solution) do
                draw_box(b)
            end
        end

        g.pop()
    end
    ui.draw()
end

-- forward keyboard events
function love.textinput(t)
    ui.textinput(t)
end

function love.keypressed(key)
    ui.keypressed(key)
end
