require "metalua"

SWITCH = macro(function(tokens)
    local value = stop_at(tokens, "on")
    pop(tokens)
    local cases = token_stream()
    local i = 1
    while true do
        if first(tokens) == "end" then
            break
        end
        if tokens[1].value == "default" then
            local body = balanced(tokens, "default", "end")
            extend(cases, format([[
                else
                    %s
            ]], body))
            break
        end
        expect(tokens, "case")
        local pattern = stop_at(tokens, "do")
        local body
        if is_balanced(tokens, "do", "case") then
            body = balanced(tokens, "do", "case")
        elseif is_balanced(tokens, "do", "default") then
            body = balanced(tokens, "do", "default")
        else
            body = balanced(tokens, "do", "end")
        end
        if i == 1 then
            push(cases, "if")
        else
            push(cases, "elseif")
        end
        extend(cases, format([[
            %s == %s then
                %s
        ]], value, pattern, body))
        i = i + 1
    end
    push(cases, expect(tokens, "end"))
    return meta("%s", cases)
end)

local function compute(x)
    SWITCH[[ x on
        case 1 do
            print("One")
        case 2 do
            print("Two")
        case 3 do
            print("Three")
        default
            print("Unknown")
    end ]]
end

compute(4)