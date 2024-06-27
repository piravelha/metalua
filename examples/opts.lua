require "metalua"

OPTS = macro(function(tokens)
    local func_name = expect_type(tokens, "name")
    expect(tokens, "(")
    local params = token_stream()
    local defaults = {}
    while true do
        local param = expect_type(tokens, "name")
        push(params, param)
        push(params, ",")
        if first(tokens) == "=" then
            pop(tokens)
            local default, rest = expr(tokens)
            tokens = rest
            defaults[param.value] = default
        end
        if first(tokens) == ")" then break end
        expect(tokens, ",")
        if first(tokens) == ")" then break end
    end
    pop(tokens)
    params = slice(params, 1, #params - 1)
    local body = token_stream()
    while true do
        if #tokens == 0 then
            error("Expected function body, got nothing", 2)
        end
        if #tokens == 1 and first(tokens) == "end" then
            pop(tokens)
            break
        end
        push(body, pop(tokens))
    end
    local default_impls = token_stream()
    for p, d in pairs(defaults) do
        extend(default_impls, tokenizer(string.format([[
            %s = %s or %s
        ]], p, p, d)))
    end
    return meta([[
        function %s(%s)
            %s
            %s
        end
    ]], func_name, params, default_impls, body)
end)

OPTS[[ factorial(x, acc = 1)
    if x <= 1 then
        return acc
    end
    return factorial(x - 1, acc * x)
end ]]

print(factorial(5))
