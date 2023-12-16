local max = math.max
local min = math.min
local abs = math.abs
local floor = math.floor
local ceil = math.ceil
local sort = table.sort

---@class BoxSolver
local BoxSolver = {}
local box_solver_mt = {__index=BoxSolver}

---@alias BoxPriority "biggest_area"|"longest_side"|"longest_perimeter"|"most_oblong"
---@alias PackingStrategy "first_fit"|"next_fit"

local function rect_collide(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2+w2 and y1 < y2+h2 and x2 < x1+w1 and y2 < y1+h1
end

---Returns true if b1 has bigger area than b2
---@param b1 Box
---@param b2 Box
---@return boolean
function BoxSolver.biggest_area(b1, b2)
    return b1.area > b2.area
end

---Returns true if b1 has a longer side than b2
---@param b1 Box
---@param b2 Box
---@return boolean
function BoxSolver.longest_side(b1, b2)
    local max1 = max(b1.w, b1.h)
    local max2 = max(b2.w, b2.h)
    return max1 > max2
end

---Returns true if b1 has a longer perimeter than b2
---@param b1 Box
---@param b2 Box
---@return boolean
function BoxSolver.longest_perimeter(b1, b2)
    return b1.w+b1.h > b2.w+b2.h
end

---Returns true if b1 is more oblong than b2.
---This is calculated as having a bigger ratio of perimeter to area.
---@param b1 Box
---@param b2 Box
---@return boolean
function BoxSolver.most_oblong(b1, b2)
    local o1 = (b1.w+b1.h)/b1.area
    local o2 = (b2.w+b2.h)/b2.area
    return o1 > o2
end

---@param b Box
---@return Box
local function copy_box(b)
    local c = {}
    for k, v in pairs(b) do
        c[k] = v
    end
    return c
end

---Creates a new solver, or returns nil in case of failure.
---@param boxes table<Box>
---@param bound_w number
---@param bound_h number
---@param cells_x integer
---@param cells_y integer
---@param margin number? Adds to the width and height of every element
---@return BoxSolver?
---@return string? errmsg
function BoxSolver.new(boxes, bound_w, bound_h, cells_x, cells_y, margin)
    if bound_w < 0 or bound_h < 0 then
        return nil, "Size of bounds must be greater than zero!"
    end
    if cells_x < 1 or cells_y < 1 then
        return nil, "Grid size must be at least 1x1!"
    end
    if #boxes < 1 then
        return nil, "Must be at least one box in the list!"
    end
    margin = margin or 0
    margin = margin - 0.1 -- account for floating point errors
    cells_x = floor(cells_x)
    cells_y = floor(cells_y)
    ---@class BoxSolver
    local self = {
        w = bound_w;
        h = bound_h;
        grid_w = cells_x;
        grid_h = cells_y;
        boxes = {}; -- List AND map of all boxes present for this solution. Does not change after construction.
        orders = {}; -- List of orderings (lists) of boxes to place. This is used instead of traversing a decision tree.
        -- Orders contains copies of Boxes from the "boxes" list, which may be rotated compared to their original.
        -- In addition, the solver will modify the copy's x and y position to create the packing.
        margin = margin;
    }
    -- Split the bounds into a grid
    local cell_w = bound_w/cells_x
    local cell_h = bound_h/cells_y
    self.cell_w = cell_w
    self.cell_h = cell_h
    -- Resize all input boxes to their grid size instead of their actual size.
    -- The grid size is always bigger than the actual size.
    for i, v in ipairs(boxes) do
        ---@class Box
        local b = {
            ---@type integer
            x = -1;
            ---@type integer
            y = -1;
            og_w = v.w;
            og_h = v.h;
            w = ceil((v.w+margin) / cell_w);
            h = ceil((v.h+margin) / cell_h);
            can_rot = true;
            flipped = false;
            ---@type string
            name = v.name
        }
        if b.name == nil or b.name == "" then
            b.name = "#"..i
        end
        b.area = b.w*b.h
        if v.can_rot == false then
            b.can_rot = false
        end
        if b.can_rot == true and b.w == b.h then
            b.can_rot = false
        end
        self.boxes[i] = b
        -- self.boxes[b.name] = b
        if b.w > self.grid_w or b.h > self.grid_h then
            return nil, "Item " .. i .. " is larger than the bounds!"
        end
    end
    setmetatable(self, box_solver_mt)

    return self
end

---Generates different orderings of boxes based on the priority function.
---@param priority BoxPriority The kind of box priority to use when sorting.
---@param n integer? How many orders to generate. If nil or <=0, then all possible orders are generated.
function BoxSolver:generate_orderings(priority, n)
    if n ~= nil and n <= 0 then
        n = nil
    end
    self.orders = {}
    sort(self.boxes, BoxSolver[priority])
    -- Generate all combinations of box rotations by treating boxes as a sort of "binary function"
    for i, b in ipairs(self.boxes) do
        b.flipped = false -- Reset flipped condition for all boxes
    end
    ---Geneates the next ordering, or nil if finished
    ---@return table?
    local function genNextOrder()
        local changed = false
        for i, v in ipairs(self.boxes) do
            if (not v.flipped) and v.can_rot then
                v.flipped = true
                changed = true
                break
            elseif v.flipped then
                v.flipped = false
            end
        end
        local ord = {}
        for i, v in ipairs(self.boxes) do
            local b = copy_box(v)
            if b.flipped then
                b.og_w, b.og_h = b.og_h, b.og_w
                b.w = ceil((b.og_w+self.margin) / self.cell_w);
                b.h = ceil((b.og_h+self.margin) / self.cell_h);
            end
            ord[i] = b
        end
        if not changed then
            return nil
        end
        return ord
    end

    local default_ord = {}
    for i, v in ipairs(self.boxes) do
        default_ord[i] = copy_box(v)
    end
    self.orders[1] = default_ord

    local ord_count = 1
    while (n == nil) or (ord_count < n) do
        local ord = genNextOrder()
        if not ord then break end
        ord_count = ord_count + 1
        self.orders[ord_count] = ord
    end
    return ord_count
end

---Generates a packing for an order, specified by the order_id
---@param order_id integer
---@return boolean success
function BoxSolver:pack(order_id)
    local ord = self.orders[order_id]
    if not ord then return false end
    local N = #ord
    -- Place the first box in the top-left
    ord[1].x = 0
    ord[1].y = 0
    local cur_idx = 2
    
    while cur_idx <= N do
        ---@type Box
        local cur = ord[cur_idx]
        -- local failed = true
        -- Check the right and bottom of every placed box.
        -- Rules for placing
        -- 1. Place at the first available position. A position is actually a position relative to some previous box.
        -- 2. A position of a new box box is relative the previous box as either (x+w, y) or (x, y+h),
        --    where x, y, w, h are properties of the previous box
        -- 3. A position is available if the box will not collide with any previously placed boxes
        -- 4. A position that only expands the bounding box in one axis is preferred, if both are available at the same step.
        --    a. This is preferred first because "expanding in one direction" means that it is less likely to cut off space for future boxes
        -- 5. If both positions expand the bounding box in both axes, then an area-based criterion is used:
        --    a. Both positions have a "bounding box" that surrounds the cur and prev boxes.
        --    b. The bounding box with less area is preferred
        -- 6. If both positions also expand the bounding box area by the same amount, then the one with less bounding box perimeter is preferred
        -- 7. If the bounding box has the same area and perimeter, then the decision is made based on how much space is left in the direction of expansion.
        --    This means, if expanding to the right, the remaining distance is (enclosure width - (position x + box width))
        --    And in the vertical direction, the remaining distance is (enclosure height - (position y + box height))
        -- 8. If those values are the same, then just pick horizontal by default. Congratulations.
        -- Implementation
        -- * Storing the right and bottom adjacent boxes in the [1] and [2] indices of a box
        local i = 1
        local options = {}
        while i < cur_idx do
            ---@type Box
            local prev = ord[i]
            local x1, y1 = floor(prev.x+prev.w), prev.y
            local x2, y2 = prev.x, floor(prev.y+prev.h)
            -- print(string.format("Checking cur %d against %d\n", cur_idx, i))
            local avail1 = prev[1] == nil and floor(x1+cur.w) <= self.grid_w and floor(y1+cur.h) <= self.grid_h
            local avail2 = prev[2] == nil and floor(x2+cur.w) <= self.grid_w and floor(y2+cur.h) <= self.grid_h
            
            -- Check collisions
            local marg = 0.001
            local marg2 = 2*marg
            if avail1 then
                for j = 1, cur_idx-1 do
                    local chk = ord[j]
                    if rect_collide(x1+marg, y1+marg, cur.w - marg2, cur.h - marg2, chk.x + marg, chk.y + marg, chk.w - marg2, chk.h - marg2) then
                        avail1 = false
                        break
                    end
                end
            end
            if avail2 then
                for j = 1, cur_idx-1 do
                    local chk = ord[j]
                    if rect_collide(x2+marg, y2+marg, cur.w - marg2, cur.h - marg2, chk.x + marg, chk.y + marg, chk.w - marg2, chk.h - marg2) then
                        avail2 = false
                        break
                    end
                end
            end
            if avail1 then
                ---@class BoxOption
                local o = {prev=prev, idx=1, x=x1, y=y1, bound_w = prev.w+cur.w, bound_h = max(prev.h, cur.h)}
                o.area = o.bound_w*o.bound_h
                o.perim = o.bound_w+o.bound_h
                o.exp = o.bound_h == prev.h
                o.rem = self.grid_w - (o.x + cur.w)
                options[#options+1] = o
            end
            if avail2 then
                ---@class BoxOption
                local o = {prev=prev, idx=2, x=x2, y=y2, bound_w = max(prev.w, cur.w), bound_h = prev.h+cur.h}
                o.area = o.bound_w*o.bound_h
                o.perim = o.bound_w+o.bound_h
                o.exp = o.bound_w == prev.w
                o.rem = self.grid_h - (o.y + cur.h)
                options[#options+1] = o
            end
            i = i + 1
        end

        -- loop through all available options to find the best fit
        ---@type BoxOption
        local best_opt
        local best_area = self.grid_w*self.grid_h
        local best_perim = self.grid_w+self.grid_h
        local best_exp = false
        local best_rem = max(self.grid_w or self.grid_h)

        ---@param opt BoxOption
        local function replace_best(opt)
            best_opt = opt
            best_area = opt.area
            best_perim = opt.perim
            best_exp = opt.exp
            best_rem = opt.rem
        end

        for _, opt in ipairs(options) do
            if opt.area < best_area then
                replace_best(opt)
            elseif opt.area > best_area then -- ignore
            elseif opt.perim < best_perim then
                replace_best(opt)
            elseif opt.perim > best_perim then -- ignore
            elseif opt.exp and not best_exp then
                replace_best(opt)
            elseif opt.rem < best_rem then
                replace_best(opt)
            end
        end
        
        if best_opt then
            cur.x = best_opt.x
            cur.y = best_opt.y
            best_opt.prev[best_opt.idx] = cur
        else
            -- print("Failed on index", cur_idx)
            break
        end
        cur_idx = cur_idx + 1
    end
    local success = cur_idx > N
    ord.success = success
    return success
end

function BoxSolver:pack_all()
    local n_suc = 0
    for i=1, #self.orders do
        if self:pack(i) then
            n_suc = n_suc + 1
        end
    end
    return n_suc
end

---Packs all generated orders, returning the one with the best packing.
---The best packing is one that has the smallest bounding area around all its placed boxes.
---@return table? ordering
---@return integer? order_id
function BoxSolver:most_compact()
    local good = {}
    for i, ord in ipairs(self.orders) do
        if ord.success then
            good[#good+1] = ord
            -- Find bounding box around all items
            local max_x = 0
            local max_y = 0
            for j, b in ipairs(ord) do
                max_x = max(max_x, b.x+b.w)
                max_y = max(max_y, b.y+b.h)
            end
            ord.bound_w = max_x
            ord.bound_h = max_y
            ord.bound_area = max_x*max_y
            ord.bound_perim = 2*(max_x + max_y)
        end
    end
    local best = nil
    local best_area = self.grid_w*self.grid_h
    local best_perim = 2*(self.grid_w + self.grid_h)
    for i, ord in ipairs(good) do
        if ord.bound_area < best_area then
            best_area = ord.bound_area
            best_perim = ord.bound_perim
            best = ord
        elseif ord.bound_area == best_area and ord.bound_perim < best_perim then
            best_area = ord.bound_area
            best_perim = ord.bound_perim
            best = ord
        end
    end

    local best_idx = nil
    for i, o in ipairs(self.orders) do
        if o == best then
            best_idx = i
            break
        end
    end

    return best, best_idx
end

function BoxSolver:ungrid_packing(ord)
    if ord == nil then return nil end
    local t = {}
    for i, v in ipairs(ord) do
        local b = copy_box(v)
        local gw = b.w*self.cell_w
        local gh = b.h*self.cell_h
        b.x = b.x*self.cell_w + (gw - b.og_w)*0.5
        b.y = b.y*self.cell_h + (gh - b.og_h)*0.5
        t[i] = b
    end

    return t
end

return BoxSolver