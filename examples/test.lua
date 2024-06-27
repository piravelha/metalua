require "metalua"

local function _enum_field(name, value)
    return string.format([[
        setmetatable({
            name = "%s",
            value = %s,
        }, {
            __tostring = function(self)
                return "<%s: " .. tostring(%s) .. ">"
            end,
        })
    ]], name, value, name, value)
end

local ENUM = macro(function(tokens)
    local new_tokens = token_stream()
    push(new_tokens, "{")
    local iota = 1
    while true do
        local token = expect_type(tokens, "name")
        push(new_tokens, token)
        push(new_tokens, "=")
        extend(new_tokens, _enum_field(token, iota))
        if #tokens == 0 then
            break
        end
        expect(tokens, ",")
        push(new_tokens, ",")
        if #tokens == 0 then
            break
        end
        iota = iota + 1
    end
    push(new_tokens, "}")
    return meta("return %s", new_tokens)
end)

Fruit = ENUM[[
    apple,
    banana,
    grape,
]]

print(Fruit.grape)