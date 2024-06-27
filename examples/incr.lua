require "metalua"

REL = macro(function(tokens)
    local var = expect_type(tokens, "name")
    local op = expect_type(tokens, "operator")
    op = tostring(op):sub(1, -2)
    return meta(getenv(1), [[
        %s = %s %s %s
        return %s
    ]], var, var, op, tokens, var)
end)

local x = 5
local y = 7

REL[[ x += 5 ]]
REL[[ y *= 20 ]]

print(x, y)