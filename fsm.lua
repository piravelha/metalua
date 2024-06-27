require "metalua"
require "fstring"

STATEMACHINE = macro(function(tokens)
    local stream = token_stream()
    local name = expect_type(tokens, "name")
    expect(tokens, "(")
    local default = expect_type(tokens, "name")
    expect(tokens, ")")
    extend(stream, tostring(name) .. [[ = function()
            local fsm = setmetatable({
                set_state = function(self, state)
                    self.state = function(self)
                        return state(self)
                    end
                end,
        ]])
    while true do
        if #tokens <= 1 then
            break
        end
        if tokens[1].value == "method" then
            pop(tokens)
            local method = expect_type(tokens, "name")
            local params = balanced(tokens, "(", ")")
            if #params > 0 then
              prepend(params, ",")
            end
            pop(tokens)
            local body = token_stream()
            while true do
                if tokens[1].value == "end" and #tokens == 2 then
                    break
                end
                if tokens[1].value == "end" and tokens[2].value == "state" or tokens[2].value == "method" then
                    break
                end
                push(body, pop(tokens))
            end
            pop(tokens)
            extend(stream, string.format([[
                %s = function(self %s)
                    %s
                end,
            ]], method, params, body))
        elseif tokens[1].value == "state" then
            expect(tokens, "state")
            local state = expect_type(tokens, "name")
            extend(stream, tostring(state) .. [[ = function(self)]])
            local body = token_stream()
            while true do
                if tokens[1].value == "state" or tokens[1].value == "method" and tokens[2].type == "name" then
                    extend(body, "self:set_state(self."
                        .. tostring(tokens[2]) .. ")")
                    tokens = slice(tokens, 3)
                    expect(tokens, "end")
                    break
                end
                push(body, pop(tokens))
            end
            extend(stream, body)
            extend(stream, "end,")
        end
    end
    extend(stream, [[ }, { ]]
        .. [[
            __call = function(self)
                self:state()
            end,
        })
        fsm:set_state(fsm. ]] .. tostring(default) .. ")"
        .. [[ return fsm
    end ]]
    )
    return meta(getenv(1), stream)
end)

local counter = 0

STATEMACHINE[[ LightSwitch (Off)
    method square(x)
        return x * x
    end
    state On
        print("The light is On")
        self:log_counter()
        state Off
    end
    state Off
        print("The light is Off")
        self:log_counter()
        state On
    end
    method log_counter()
        print(F"Counter: {counter}")
        local squared = self:square(counter)
        print(F"Squared: {squared}")
        counter = counter + 1
    end
end ]]

local switch = LightSwitch()
switch()
switch()
switch()
switch()
