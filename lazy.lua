require "metalua"

LAZY = macro(function(tokens)
    return meta(getenv(1), [[
        local value, evaluated = nil, false
        return function()
            if not evaluated then
                value = %s
                evaluated = true
            end
            return value
        end
    ]], tokens)
end)

LAZYBLOCK = macro(function(tokens)
    return meta(getenv(1), [[
        local value, evaluated = nil, false
        return function()
            if not evaluated then
                value = (function()
                    %s
                end)()
                evaluated = true
            end
            return value
        end
    ]], tokens)
end)

local lazy_value = LAZYBLOCK[[
    print("Evaluating...")
    return 10
]]

print(lazy_value())
print(lazy_value())