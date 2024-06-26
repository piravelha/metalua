require "metalua"

local L = macro(function(tokens)
    local function run(tokens)
        if tokens[1].type == "name" then
            if #tokens >= 2 and tokens[2].value == "=>" then
                local name = pop(tokens)
                drop(tokens)
                local body = run(tokens)
                return string.format(
                    "return function(%s) %s end",
                    name, body
                )
            end
        end
        return string.format("return %s", tokens)
    end
    local result = run(tokens)
    return meta(result, getenv(1))
end)

local add = L[[a => b => a + b]]
local sub = L[[a => b => a - b]]
local nested = L[[a => b => L("x => x")(a) + b]]
print(nested(1)(2))
