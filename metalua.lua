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
        elseif char:match("[+%-%*/!@#$%%&|:;,><=~%^%[%]]") then
            local start = i
            while i <= len and input:sub(i, i):match("[+%-%*/!@#$%%&|:;,><=~%^%[%]]") do
                i = i + 1
            end
            add_token("operator", input:sub(start, i - 1))
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
    return setmetatable(_G, { __index = env })
end

function meta(code, env)
    local env = getenv(1)
    local chunk = load(code, "chunk", "t", env)
    return chunk(), env
end

function slice(tbl, min, max)
    max = max or #tbl
    local new = token_stream()
    for i, v in pairs(tbl) do
        if i >= min and i <= max then
            table.insert(new, v)
        end
    end
    return new
end

function template(env, format_str, ...)
    return meta(string.format(
        "return " .. format_str, ...
    ), env)
end

function drop(token_stream)
    table.remove(token_stream, 1)
end

function push(token_stream, token)
    table.insert(token_stream, token)
end

function expect(token_stream, expected)
    assert(token_stream[1].value == expected)
    drop(token_stream)
end

function first(token_stream)
    return token_stream[1].value
end
