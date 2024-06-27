require "metalua"

TYPECHECK = macro(function(tokens)
    local value = token_stream()
    local type
    while true do
        local got = pop(tokens)
        if got.value == ":" and #tokens == 1 then
            type = pop(tokens)
            break
        end
        push(value, got)
    end
    return meta([[
        if type(%s) ~= "%s" then
            error("Expected type %s, but got "
                .. type(%s) .. " instead", 2)
        end
    ]], value, type, type, value)
end)

TYPECHECK[[ 1 : number ]]
TYPECHECK[[ "str" : string ]]
TYPECHECK[[ true : boolean ]]
TYPECHECK[[ {1, 2, 3} : table ]]

local unknown = "secret"
TYPECHECK[[ unknown : number ]] -- Throws an error here