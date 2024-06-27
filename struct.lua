require "metalua"

STRUCT = macro(function(tokens)
    local struct_name = expect_type(tokens, "name")
    expect(tokens, "{")
    local field_names = token_stream()
    push(field_names, "{")
    while true do
        local name = expect_type(tokens, "name")
        push(field_names, "\"" .. tostring(name) .. "\"")
        if first(tokens) == "}" then break end
        push(field_names, expect(tokens, ","))
        if first(tokens) == "}" then break end
    end
    push(field_names, "}")
    expect(tokens, "}")
    return meta(getenv(1), [[
        local fields = %s
        function %s(values)
            local struct = {}
            for i, val in pairs(values) do
                local field = fields[i]
                struct[field] = val
            end
            return setmetatable(struct, {
                __tostring = function(self)
                    local str = "%s {"
                    for i, field in pairs(fields) do
                        if i > 1 then
                            str = str .. ", "
                        end
                        local val = self[field]
                        str = str .. tostring(val)
                    end
                    return str .. "}"
                end,
            })
        end
    ]], field_names, struct_name, struct_name)
end)

STRUCT[[ Person {
    name,
    age,
    email,
} ]]

print(Person {
    "Ian",
    15,
    "piralocojacavelha@gmail.com",
})
