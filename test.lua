local box_solver = require "box"

return function()
    local boxes = {
        {name="a",w=2,h=4},
        {name="b",w=4,h=4},
        {name="c",w=3,h=1},
        {name="d",w=5,h=1},
    }
    local solver = box_solver.new(boxes, 10, 10, 10, 10)
    if not solver then
        love.event.push("quit")
        return
    end
    local n_orders = solver:generate_orderings(0, "longest_side")
    print("Orders:", n_orders)
    for i, ord in ipairs(solver.orders) do
        io.write(i, ": [")
        for j, b in ipairs(ord) do
            if b.flipped then
                io.write("!")
            end
            io.write(b.name, ",")
        end
        io.write("]\n")
    end
    local n_success = solver:pack_all()
    print("Successes:", n_success)
    local best, best_idx = solver:most_compact()
    assert(best and best_idx, "No successful packings found")
    for i, o in ipairs(solver.orders) do
        print(i, o.success == true, o.bound_area)
        for _, v in ipairs(o) do
            io.write(string.format("%d, %d, %d, %d\n", v.x, v.y, v.w, v.h))
        end
    end
    
    print("Best:", best_idx)
end