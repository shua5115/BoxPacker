--[[
   Save Table to File
   Load Table from File
   v 1.0
   
   Lua 5.2 compatible
   
   Only Saves Tables, Numbers and Strings
   Insides Table References are saved
   Does not save Userdata, Metatables, Functions and indices of these
   ----------------------------------------------------
   table.save( table , filename )
   
   on failure: returns an error msg
   
   ----------------------------------------------------
   table.load( filename or stringtable )
   
   Loads a table that has been saved via the table.save function
   
   on success: returns a previously saved table
   on failure: returns as second argument an error msg
   ----------------------------------------------------
   
   Licensed under the same terms as Lua itself.
]] --
do
    local load_env = {}
    -- declare local variables
    --// exportstring( string )
    --// returns a "Lua" portable version of the string
    local function exportstring(s)
        return string.format("%q", s)
    end

    local function loadchunk(chunk)
        local ftables = chunk
        if ftables == nil then return nil, "table load chunk is nil" end
        local success, tables = pcall(ftables)
        if not success then return nil, tables end
        for idx = 1, #tables do
            local tolinki = {}
            for i, v in pairs(tables[idx]) do
                if type(v) == "table" then
                    tables[idx][i] = tables[v[1]]
                end
                if type(i) == "table" and tables[i[1]] then
                    table.insert(tolinki, { i, tables[i[1]] })
                end
            end
            -- link indices
            for _, v in ipairs(tolinki) do
                tables[idx][v[2]], tables[idx][v[1]] = tables[idx][v[1]], nil
            end
        end
        return tables[1]
    end

    local nop = function (...) end
    local function stringwriter()
        return {
            data = {};
            write = function(self, ...)
                local arg = {...}
                local i = #self.data
                for _, s in ipairs(arg) do
                    i = i + 1
                    self.data[i] = tostring(s)
                end
            end;
            close = function(self)
                self.write = nop
                self.close = nop
                self.output = table.concat(self.data)
            end;
        }
    end

    --// The Save Function
    function table.write(tbl, file)
        local charS, charE = "   ", "\n"
        --local file, err = io.open(filename, "wb")
        if file == nil or file.write == nil then return nil, "file is not writable" end
        local ignore = tbl._volatile or {} -- set of keys marked to not be saved
        -- initiate variables for save procedure
        local tables, lookup = { tbl }, { [tbl] = 1 }
        file:write("return {" .. charE)

        for idx, t in ipairs(tables) do
            file:write("-- Table: {" .. idx .. "}" .. charE)
            file:write("{" .. charE)
            local thandled = {}

            for i, v in ipairs(t) do
                if not ignore[i] then
                    thandled[i] = true
                    local stype = type(v)
                    -- only handle value
                    if stype == "table" then
                        if not lookup[v] then
                            table.insert(tables, v)
                            lookup[v] = #tables
                        end
                        file:write(charS .. "{" .. lookup[v] .. "}," .. charE)
                    elseif stype == "string" then
                        file:write(charS .. exportstring(v) .. "," .. charE)
                    elseif stype == "number" then
                        file:write(charS .. tostring(v) .. "," .. charE)
                    end
                end
            end

            for i, v in pairs(t) do
                -- escape handled values
                if (not ignore[i] and not thandled[i]) then

                    local str = ""
                    local stype = type(i)
                    -- handle index
                    if stype == "table" then
                        if not lookup[i] then
                            table.insert(tables, i)
                            lookup[i] = #tables
                        end
                        str = charS .. "[{" .. lookup[i] .. "}]="
                    elseif stype == "string" then
                        str = charS .. "[" .. exportstring(i) .. "]="
                    elseif stype == "number" or stype == "boolean" then
                        str = charS .. "[" .. tostring(i) .. "]="
                    end

                    if str ~= "" then
                        stype = type(v)
                        -- handle value
                        if stype == "table" then
                            if not lookup[v] then
                                table.insert(tables, v)
                                lookup[v] = #tables
                            end
                            file:write(str .. "{" .. lookup[v] .. "}," .. charE)
                        elseif stype == "string" then
                            file:write(str .. exportstring(v) .. "," .. charE)
                        elseif stype == "number" or stype == "boolean" then
                            file:write(str .. tostring(v) .. "," .. charE)
                        end
                    end
                end
            end
            file:write("}," .. charE)
        end
        file:write("}")
    end

    function table.save(t, filename)
        local file, err = io.open(filename, "wb")
        if file == nil then return nil, err end
        table.write(t, file)
        file:close()
        return true
    end

    function table.savestring(t)
        local writer = stringwriter()
        table.write(t, writer)
        writer:close()
        return writer.output
    end

    --// The Load Function
    function table.loadfile(sfile)
        local chunk, err = loadfile(sfile, "t", load_env)
        if chunk == nil then return nil, err end
        return loadchunk(chunk)
    end

    function table.loadstring(str)
        if str == nil then return end
        local chunk, err = loadstring(str, "table_load")
        if chunk == nil then return nil, err end
        chunk = setfenv(chunk, load_env)
        return loadchunk(chunk)
    end

    -- close do
end
