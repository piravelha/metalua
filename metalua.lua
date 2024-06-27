function token_stream()
    return setmetatable({}, {
        __tostring = function(self)
            local str = ""
            for i, v in pairs(self) do
                if i > 1 then
                    str = str .. " "
                end
                str = str .. tostring(v)
            end
            return str
        end,
    })
end

function tokenizer(input)
    local keywords = {
        ["local"] = true, ["function"] = true, ["return"] = true,
        ["break"] = true, ["meta!"] = true, ["true"] = true,
        ["false"] = true, ["and"] = true, ["or"] = true,
        ["not"] = true, ["nil"] = true, ["quote"] = true,
        ["eval"] = true, ["token"] = true, ["if"] = true,
        ["then"] = true, ["do"] = true, ["elseif"] = true,
        ["else"] = true
    }

    local tokens = token_stream()
    local i = 1
    local len = #input

    local function add_token(type, value)
        table.insert(tokens, setmetatable({
            type = type,
            value = value
        }, {
            __tostring = function(_)
                return tostring(value)
            end,
        }))
    end

    while i <= len do
        local char = input:sub(i, i)

        if char:match("%s") then
            i = i + 1
        elseif char == "-" and input:sub(i + 1, i + 1) == "-" then
            i = i + 2
            while i <= len and input:sub(i, i) ~= "\n" do
                i = i + 1
            end
        elseif char:match("[a-zA-Z_]") then
            local start = i
            while i <= len and input:sub(i, i):match("[a-zA-Z_0-9]") do
                i = i + 1
            end
            local word = input:sub(start, i - 1)
            if keywords[word] then
                add_token("keyword", word)
            elseif word == "..." then
                add_token("name", word)
            else
                add_token("name", word)
            end
        elseif char:match("[+%-%*/!@#$%%&|:.><=~%^%[%]\\]") then
            local start = i
            while i <= len and input:sub(i, i):match("[+%-%*/!@#$%%&|:.><=~%^%[%]\\]") do
                i = i + 1
            end
            add_token("operator", input:sub(start, i - 1):gsub("\\%[", "["):gsub("\\%]", "]"))
        elseif char:match("[;,]") then
            i = i + 1
            add_token("delimiter", char)
        elseif char:match("[()]") then
            i = i + 1
            add_token("paren", char)
        elseif char:match("[{}]") then
            i = i + 1
            add_token("brace", char)
        elseif char == "n" and input:sub(i, i + 2) == "nil" then
            add_token("nil", "nil")
            i = i + 3
        elseif char == "t" and input:sub(i, i + 3) == "true" then
            add_token("boolean", "true")
            i = i + 4
        elseif char == "f" and input:sub(i, i + 4) == "false" then
            add_token("boolean", "false")
            i = i + 5
        elseif char == "\"" then
            local start = i
            i = i + 1
            while i <= len and (input:sub(i, i) ~= "\"" or input:sub(i - 1, i - 1) == "\\") do
                i = i + 1
            end
            i = i + 1
            add_token("string", input:sub(start, i - 1))
        elseif char:match("%d") then
            local start = i
            while i <= len and input:sub(i, i):match("%d") do
                i = i + 1
            end
            if input:sub(i, i) == "." then
                i = i + 1
                while i <= len and input:sub(i, i):match("%d") do
                    i = i + 1
                end
            end
            add_token("number", input:sub(start, i - 1))
        else
            i = i + 1
        end
    end

    return tokens
end

function clone(tokens)
    local new = token_stream()
    for i, v in pairs(tokens) do
        table.insert(new, v)
    end
    return new
end

function macro(impl)
    local function wrapper(code)
        depth = depth or 1
        local tokens = tokenizer(code)
        return impl(clone(tokens))
    end
    return wrapper
end

function getenv(depth)
    if type(depth) == "function" then
        local env = {}
        local i = 1
        while true do
            local name, value = debug.getlocal(depth, i)
            if not name then
              break
            end

            env[name] = value
            i = i + 1
        end
        return env
    end
    local env = {}
    for i = 1, debug.getinfo(1, "l").currentline do
        local name, value = debug.getlocal(depth + 2, i)
        if not name then
            break
        end
        env[name] = value
    end
    local old_index = _G["#index"]
    local new_env = {}
    for k, v in pairs(env) do
        new_env[k] = v
    end
    if old_index then
        for k, v in pairs(old_index) do
            new_env[k] = v
        end
    end
    _G["#index"] = new_env
    return setmetatable(_G, { __index = function(self, key)
        if rawget(self, key) then
            return rawget(self, key)
        end
        if env[key] then
            return env[key]
        end
        if old_index and old_index[key] then
            return old_index[key]
        end
    end})
end

function setvar(name, value, depth)
    depth = depth or 2
    local i = 1
    while true do
        local var_name = debug.getlocal(depth, i)
        if not var_name then
            break
        end
        if var_name == name then
            debug.setlocal(depth, i, value)
            return true
        end
        i = i + 1
    end
    _G[name] = value
    return false
end

function format(code, ...)
    return string.format(tostring(code), ...)
end

function meta(env, code, ...)
    local formats = {...}

    if type(env) ~= "table" or not getmetatable(env) or not getmetatable(env).__tostring then
        formats = {code, ...}
        code = env
        env = getenv(2)
    end

    code = string.format("return " .. tostring(code), table.unpack(formats))

    local chunk, err = load(code, "chunk", "t", setmetatable({}, {
        __index = env,
        __newindex = function(_, name, value)
            if not setvar(name, value, 4) then
                rawset(_G, name, value)
            end
        end
    }))
    
    if chunk then
        return chunk()
    end
    
    print("DEBUG: syntax error detected in chunk: [[\n" .. tostring(code) .. "\n]]")
    error(err)
end

function slice(tbl, min, max)
    max = max or #tbl
    if max < 0 then
        max = #tbl - max
    end
    local new = token_stream()
    for i, v in pairs(tbl) do
        if i >= min and i <= max then
            table.insert(new, v)
        end
    end
    return new
end

function new_token(value)
    local tokens = tokenizer(tostring(value))
    return tokens[1]
end

function template(env, format_str, ...)
    return meta(env, string.format(
        "return " .. format_str, ...
    ))
end

function pop(token_stream)
    return table.remove(token_stream, 1)
end

function push(token_stream, token)
    if type(token) ~= "table" then
        token = new_token(token)
    end
    table.insert(token_stream, token)
end

function prepend(token_stream, token)
    if type(token) ~= "table" then
        token = new_token(token)
    end
    table.insert(token_stream, 1, token)
end

function extend(token_stream, tokens)
    if type(tokens) ~= "table" then
        tokens = tokenizer(tokens)
    end
    for i, tok in pairs(tokens) do
        table.insert(token_stream, tok)
    end
end

function expect(token_stream, expected)
    assert(token_stream[1].value == expected, "SYNTAX ERROR: Expected " .. tostring(expected) .. ", but got " .. tostring(token_stream[1]) .. " instead")
    return pop(token_stream)
end

function expect_type(token_stream, expected)
    assert(token_stream[1].type == expected)
    return pop(token_stream)
end

function first(token_stream)
    return token_stream[1].value
end

function balanced(tokens, open, close)
    expect(tokens, open)
    local new_tokens = token_stream()
    local counter = 1
    while true do
        local token = pop(tokens)
        if token.value == open then
            counter = counter + 1
        end
        if token.value == close then
            counter = counter - 1
            if open == close then counter = counter - 1 end
        end
        if counter < 1 then
            prepend(tokens, new_token(close))
            break
        end
        push(new_tokens, token)
    end
    return new_tokens
end

function is_balanced(tokens, open, close)
    if tokens[1].value ~= open then
        return false
    end
    local counter = 1
    local i = 2
    while true do
        local token = tokens[i]
        if not token then
            return false
        end
        if token.value == open then
            counter = counter + 1
        end
        if token.value == close then
            counter = counter - 1
        end
        if counter < 1 then
            return true
        end
        i = i + 1
    end
    return new_tokens
end

function stop_at(tokens, pattern)
    local match = token_stream()
    while true do
        local token = pop(tokens)
        if token.value == pattern then
            prepend(tokens, token)
            break
        end
        push(match, token)
    end
    return match
end

local function split_str(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function split_by(tokens, separator, ignores)
    ignores = ignores or {"{ }", "[ ]", "( )"}
    local groups = {}
    local current_group = token_stream()
    while true do
        if #tokens == 0 then
            table.insert(groups, current_group)
            break
        end
        local token = pop(tokens)
        local open, close
        for _, ignore in pairs(ignores) do
            ignore = split_str(ignore)
            local cur_open, cur_close = ignore[1], ignore[2]
            if token.value == cur_open then
                open = cur_open
                close = cur_close
            end
        end
        if open and close then
            prepend(tokens, token)
            local capture = balanced(tokens, open, close)
            push(current_group, token)
            extend(current_group, capture)
            push(current_group, pop(tokens))
        elseif token.value == separator then
            table.insert(groups, current_group)
            current_group = token_stream()
        else
            push(current_group, token)
        end
    end
    return groups
end

unpack = table.unpack