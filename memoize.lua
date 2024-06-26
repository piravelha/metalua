require "metalua"

MEMOIZE = macro(function(tokens)
    local name = expect_type(tokens, "name")
    expect(tokens, "(")
    local param = expect_type(tokens, "name")
    expect(tokens, ")")
    local body = token_stream()
    while true do
        if #tokens == 1 and first(tokens) == "end" then
            break
        end
        push(body, pop(tokens))
    end
    return meta([[
        local cache = {}
        function %s(%s)
            if cache[%s] ~= nil then
                return cache[%s]
            end
            local result = (function()
                %s
            end)()
            cache[%s] = result
            return result
        end
    ]], name, param, param, param, body, param)
end)

MEMOIZE[[ expensive(x)
    os.execute("sleep 1")
    print("expensive called with argument " .. tostring(x))
    return x + 1
end ]]

print(expensive(1))
print(expensive(1))
print(expensive(2))
print(expensive(1))
