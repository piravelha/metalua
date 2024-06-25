require "metalua"

local a = 5

local code = [[
    function add(x, y)
        return x + y
    end
]]

local result, env = meta(code)

print(add(1, 2))
