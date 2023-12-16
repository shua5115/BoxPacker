-- local ui = require "suit"

local unit_to_mm = {
    ["mm"] = 1,
    ["cm"] = 10,
    ["m"] = 1000,
    ["in"] = 25.4,
    ["ft"] = 25.4*12,
    ["yd"] = 25.4*12*3,
}

local function alias(a, b)
    unit_to_mm[b] = unit_to_mm[a]
end
alias("mm", "millimeter")
alias("mm", "millimeters")
alias("cm", "centimeter")
alias("cm", "centimeters")
alias("m", "meter")
alias("m", "meters")
alias("in", "inch")
alias("in", "inches")
alias("ft", "foot")
alias("ft", "feet")
alias("yd", "yard")
alias("yd", "yards")

local uinput = function (ui, state, ...)
    state.value = state.value or 0
    local opt = ui.getOptionsAndSize(...)
    local default_unit = opt.default_unit or "in"
    local min_val = state.min
    local max_val = state.max
    local result = ui.Input(state, ...)
    result.valid = false
    result.changed = false
    local num_start, num_end = string.find(state.text, "%s*%-?%s-%d*%.?%d*%s-e?%-?%d*")
    if num_start and num_end then
        local value = tonumber(string.sub(state.text, num_start, num_end))
        if value then
            local unit = string.match(string.lower(string.sub(state.text, num_end+1)), "%a+")
            if unit == nil or string.len(unit) == 0 then unit = default_unit end
            local conv = unit_to_mm[unit]
            if conv then
                value = value * conv -- convert from the unit to mm
                if value ~= state.value then
                    result.changed = true
                end
                state.value = value
                result.valid = true
            end
        end
    end
    -- filter value
    if min_val then
        state.value = math.max(min_val, state.value)
    end
    if max_val then
        state.value = math.min(max_val, state.value)
    end
    result.value = state.value
    return result
end

return uinput