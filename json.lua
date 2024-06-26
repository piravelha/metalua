require "metalua"

JSON_NUMBER = function(tokens, env)
    if tokens[1].type == "number" then
        return {
            success = true,
            value = tonumber(first(tokens)),
            rest = slice(tokens, 2),
        }
    end
    if tokens[1].type == "name" then
        local result = template(env, "%s", tokens[1])
        if tonumber(result) then
            return {
                success = true,
                value = tonumber(result),
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
            value = first(tokens),
            rest = slice(tokens, 2),
        }
    end
    if tokens[1].type == "name" then
        local result = template(env, "%s", tokens[1])
        if type(result) == "string" then
            return {
                success = true,
                value = "\"" .. result .. "\"",
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
            value = true,
            rest = slice(tokens, 2)
        }
    elseif first(tokens) == "false" then
        return {
            success = false,
            value = false,
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
    pop(tokens)
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
    pop(tokens)
    return {
        success = true,
        value = values,
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
        value = {key.value, value.value},
        rest = tokens,
    }
end

JSON_OBJECT = function(tokens, env)
    if first(tokens) ~= "{" then
        return {
            success = false,
        }
    end
    pop(tokens)
    local values = {}
    while true do
        if first(tokens) == "}" then
            break
        end
        local result = JSON_FIELD(tokens, env)
        if not result.success then
            return result
        end
        local key, value = result.value[1], result.value[2]
        values[key:sub(2, -2)] = value
        tokens = result.rest
        if first(tokens) == "}" then
            break
        end
        expect(tokens, ",")
    end
    pop(tokens)
    return {
        success = true,
        value = values,
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
        "age": age,
        "hobbies": ["programming", second_hobby]
    }
]]

print(person.name)
print(person.age)
print(person.hobbies[1])
print(person.hobbies[2])