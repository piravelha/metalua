require "metalua"

local json_number = function(value)
    return setmetatable({
        type = "number",
        value = value,
    }, {
        __tostring = function(_)
            return tostring(value)
        end,
    })
end

local json_string = function(value)
    return setmetatable({
        type = "string",
        value = value,
    }, {
        __tostring = function(_)
            return tostring(value)
        end,
    })
end

local json_bool = function(value)
    return setmetatable({
        type = "boolean",
        value = value,
    }, {
        __tostring = function(_)
            return tostring(value)
        end,
    })
end

local json_array = function(values)
    return setmetatable({
        type = "array",
        value = values,
    }, {
        __tostring = function(_)
            local str = "["
            for i, v in pairs(values) do
                if i > 1 then
                    str = str .. ", "
                end
                str = str .. tostring(v)
            end
            return str .. "]"
        end,
    })
end

local json_field = function(key, value)
    return setmetatable({
        type = "field",
        value = {key, value},
    }, {
        __tostring = function(_)
            return tostring(key) .. ": " .. tostring(value)
        end,
    })
end

local json_object = function(values)
    return setmetatable({
        type = "object",
        value = values,
    }, {
        __tostring = function(_)
            local str = "{\n"
            for i, v in pairs(values) do
                v = tostring(v)
                local new_v = ""
                for line in v:gmatch("[^\r\n]+") do
                    new_v = new_v .. "    " .. line .. "\n"
                end
                str = str .. new_v:sub(1, -2)
                str = str .. ",\n"
            end
            return str .. "}"
        end,
    })
end

JSON_NUMBER = function(tokens, env)
    if tokens[1].type == "number" then
        return {
            success = true,
            value = json_number(tonumber(first(tokens))),
            rest = slice(tokens, 2),
        }
    end
    if tokens[1].type == "name" then
        local result = template(env, "%s", tokens[1])
        if tonumber(result) then
            return {
                success = true,
                value = json_number(tonumber(result)),
                rest = slice(tokens, 2),
            }
        end
    end
    return {
        success = false,
    }
end

JSON_STRING = function(tokens, env)
    if tokens[1].type == "string" then
        return {
            success = true,
            value = json_string(first(tokens)),
            rest = slice(tokens, 2),
        }
    end
    if tokens[1].type == "name" then
        local result = template(env, "%s", tokens[1])
        if type(result) == "string" then
            return {
                success = true,
                value = json_string(result),
                rest = slice(tokens, 2),
            }
        end
    end
    return {
        success = false,
    }
end

JSON_BOOL = function(tokens, env)
    if first(tokens) == "true" then
        return {
            success = true,
            value = json_bool(true),
            rest = slice(tokens, 2)
        }
    elseif first(tokens) == "false" then
        return {
            success = false,
            value = json_bool(false),
            rest = slice(tokens, 2),
        }
    end
    return {
        success = false,
    }
end

JSON_ARRAY = function(tokens, env)
    if first(tokens) ~= "[" then
        return {
            success = false,
        }
    end
    drop(tokens)
    local values = {}
    while true do
        if first(tokens) == "]" then
            break
        end
        local result = JSON_VALUE(tokens, env)
        if not result.success then
            return result
        end
        push(values, result.value)
        tokens = result.rest
        if first(tokens) == "]" then
            break
        end
        expect(tokens, ",")
    end
    drop(tokens)
    return {
        success = true,
        value = json_array(values),
        rest = tokens,
    }
end

JSON_FIELD = function(tokens, env)
    local key = JSON_STRING(tokens)
    if not key.success then
        return key
    end
    tokens = key.rest
    expect(tokens, ":")
    local value = JSON_VALUE(tokens, env)
    if not value.success then
        return value
    end
    tokens = value.rest
    return {
        success = true,
        value = json_field(key.value, value.value),
        rest = tokens,
    }
end

JSON_OBJECT = function(tokens, env)
    if first(tokens) ~= "{" then
        return {
            success = false,
        }
    end
    drop(tokens)
    local values = {}
    while true do
        if first(tokens) == "}" then
            break
        end
        local result = JSON_FIELD(tokens, env)
        if not result.success then
            return result
        end
        push(values, result.value)
        tokens = result.rest
        if first(tokens) == "}" then
            break
        end
        expect(tokens, ",")
    end
    drop(tokens)
    return {
        success = true,
        value = json_object(values),
        rest = tokens,
    }
end

JSON_VALUE = function(tokens, env)
    local num = JSON_NUMBER(tokens, env)
    if num.success then
        return num
    end
    local str = JSON_STRING(tokens, env)
    if str.success then
        return str
    end
    local bool = JSON_BOOL(tokens, env)
    if bool.success then
        return bool
    end
    local arr = JSON_ARRAY(tokens, env)
    if arr.success then
        return arr
    end
    local obj = JSON_OBJECT(tokens, env)
    if obj.success then
        return obj
    end
    return {
        success = false,
    }
end

local json = macro(function(tokens)
    local env = getenv(1)
    local result = JSON_VALUE(tokens, env)
    if result.success then
        return result.value
    end
    error("PARSE ERROR")
end)

local name = "Ian"
local age = 15
local second_hobby = "that's it"

local person = json[[
    {
        "name": name,
        "age": {
            "value": age
        },
        "hobbies": ["programming", second_hobby]
    }
]]

print(person)

-- This prints out:
--[[
{
    "name": Ian,
    "age": {
        "value": 15,
    },
    "hobbies": ["programming", that's it],
}
]]
-- NOTE: 'person' is a nested table-tree structure, it is not just
-- string replacement, i literally made a json parser just to show
-- this, it just shows up pretty because of fancy __tostring metamethods