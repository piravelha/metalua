require "metalua"

STATEMACHINE = macro(function(tokens)
    local stream = token_stream()
    local name = expect_type(tokens, "name")
    extend(stream, tostring(name) .. " = function() return {"
        .. [[set_state = function(self, state)
            self.state = function(self)
                return state(self)
            end
        end,]])
    while true do
        if #tokens == 1 and first(tokens) == "end" then
            break
        end
        expect(tokens, "state")
        local state = expect_type(tokens, "name")
        extend(stream, tostring(state) .. [[ = function(self)]])
        local body = token_stream()
        while true do
            if tokens[1].value == "state" and tokens[2].type == "name" then
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
    extend(stream, "} end")
    return meta(getenv(1), stream)
end)


--> DEMO

STATEMACHINE[[ LightSwitch
    state on
        print("The light is on")
        state off
    end
    state off
        print("The light is off")
        state on
    end
end ]]

local switch = LightSwitch()
switch:set_state(switch.off)
switch:state()
switch:state()

STATEMACHINE[[ TrafficLight
    state Red
        print("Light is Red")
        state Green
    end
    state Green
        print("Light is Green")
        state Yellow
    end
    state Yellow
        print("Light is Yellow")
        state Red
    end
end ]]

local light = TrafficLight()
light:set_state(light.Red)
light:state()
light:state()
light:state()