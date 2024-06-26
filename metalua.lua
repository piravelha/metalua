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
        elseif char:match("[+%-%*/!@#$%%&|:;,.><=~%^%[%]\\]") then
            local start = i
            while i <= len and input:sub(i, i):match("[+%-%*/!@#$%%&|:;,.><=~%^%[%]\\]") do
                i = i + 1
            end
            add_token("operator", input:sub(start, i - 1):gsub("\\%[", "["):gsub("\\%]", "]"))
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

function _parse_number(tokens)
    if tokens[1].type == "number" then
        return {
            success = true,
            values = slice(tokens, 1, 1),
            rest = slice(tokens, 2),
        }
    end
    return {
        success = false,
    }
end

function _parse_string(tokens)
    if tokens[1].type == "string" then
        return {
            success = true,
            values = slice(tokens, 1, 1),
            rest = slice(tokens, 2),
        }
    end
    return {
        success = false,
    }
end

function _parse_boolean(tokens)
    if tokens[1].type == "boolean" then
        return {
            success = true,
            values = slice(tokens, 1, 1),
            rest = slice(tokens, 2),
        }
    end
    return {
        success = false,
    }
end

function _parse_nil(tokens)
    if tokens[1].type == "nil" then
        return {
            success = true,
            values = slice(tokens, 1, 1),
            rest = slice(tokens, 2),
        }
    end
    return {
        success = false,
    }
end

function _parse_unop(tokens)
    local success = tokens[1].value == "-"
        or tokens[1].value == "#"
        or tokens[1].type == "name" and tokens[1].value == "not"
    if success then
        return {
            success = true,
            values = slice(tokens, 1, 1),
            rest = slice(tokens, 2),
        }
    end
    return {
        success = false,
    }
end

function _parse_binop(tokens)
    local success = tokens[1].value == "+"
        or tokens[1].value == "-"
        or tokens[1].value == "*"
        or tokens[1].value == "/"
        or tokens[1].value == "^"
        or tokens[1].value == "%"
        or tokens[1].value == ".."
        or tokens[1].value == "<"
        or tokens[1].value == "<="
        or tokens[1].value == ">"
        or tokens[1].value == ">"
        or tokens[1].value == "=="
        or tokens[1].value == "~="
        or tokens[1].value == "and"
        or tokens[1].value == "or"
    if success then
        return {
            success = true,
            values = slice(tokens, 1, 1),
            rest = slice(tokens, 2),
        }
    end
    return {
        success = false,
    }
end

function _parse_sep(tokens)
    local success = tokens[1].value == ","
        or tokens[1].value == ";"
    if success then
        return {
            success = true,
            values = slice(tokens, 1, 1),
            rest = slice(tokens, 2),
        }
    end
    return {
        success = false,
    }
end

function _parse_field(tokens)
    if tokens[1].value == "[" then
        local result = _parse_expr(slice(tokens, 2))
        if not result.success then return result end
        tokens = result.rest
        if tokens[1].value ~= "]" then
            return {
                success = false
            }
        end
        local key = result.values
        local result = _parse_expr(slice(tokens, 2))
        if not result.success then return result end
        tokens = result.rest
        value = result.values
        local new_tokens = token_stream()
        push(new_tokens, "[")
        extend(new_tokens, key)
        push(new_tokens, "]")
        extend(new_tokens, value)
        push(new_tokens, "=")
        return {
            success = true,
            values = new_tokens,
            rest = tokens,
        }
    end
    if tokens[1].type == "name" and tokens[2].value == "=" then
        local key = slice(tokens, 1, 1)
        local result = _parse_expr(slice(tokens, 3))
        if not result.success then return result end
        tokens = result.rest
        value = result.values
        local new_tokens = token_stream()
        extend(new_tokens, key)
        push(new_tokens, "=")
        extend(new_tokens, value)
        return {
            success = true,
            values = new_tokens,
            rest = tokens,
        }
    end
    return _parse_expr(tokens)
end

function _parse_fieldlist(tokens)
    local result = _parse_field(tokens)
    if not result.success then return result end
    local first = result.values
    tokens = result.rest
    local tail = token_stream()
    local new_tokens = token_stream()
    while true do
        local result = _parse_sep(tokens)
        if not result.success then break end
        local sep = result.values
        tokens = result.rest
        local result = _parse_field(tokens)
        if not result.success then
            extend(new_tokens, first)
            extend(new_tokens, tail)
            extend(new_tokens, sep)
            return {
                success = true,
                values = new_tokens,
                rest = tokens,
            }
        end
        local field = result.values
        tokens = result.rest
        extend(tail, sep)
        extend(tail, field)
    end
    extend(new_tokens, first)
    extend(new_tokens, tail)
    local result = _parse_sep(tokens)
    if not result.success then
        return {
            success = true,
            values = new_tokens,
            rest = tokens,
        }
    end
    local sep = result.values
    tokens = result.rest
    return {
        success = true,
        values = new_tokens,
        rest = tokens,
    }
end

function _parse_table(tokens)
    if tokens[1].value ~= "{" then
        return {
            success = false,
        }
    end
    local result = _parse_fieldlist(slice(tokens, 2))
    if not result.success then
        if tokens[2].value == "}" then
            return {
                success = true,
                values = tokenizer("{}"),
                rest = slice(tokens, 3),
            }
        end
        return {
            success = false,
        }
    end
    local fields = result.values
    prepend(fields, "{")
    tokens = result.rest
    if tokens[1].value ~= "}" then
        return {
            success = false,
        }
    end
    push(fields, "}")
    return {
        success = true,
        values = fields,
        rest = tokens,
    }
end

function _parse_atom(tokens)
    local result = _parse_nil(tokens)
    if result.success then return result end
    local result = _parse_boolean(tokens)
    if result.success then return result end
    local result = _parse_number(tokens)
    if result.success then return result end
    local result = _parse_string(tokens)
    if result.success then return result end
    local result = _parse_table(tokens)
    if result.success then return result end
    if tokens[1].value == "..." then
        return {
            success = true,
            values = slice(tokens, 1, 1),
            rest = slice(tokens, 2),
        }
    end
    local result = _parse_func(tokens)
    if result.success then return result end
    local result = _parse_prefixexpr(tokens)
    if result.success then return result end
    local result = _parse_unop(tokens)
    local new_tokens = token_stream()
    if not result.success then
        return {
            success = false,
        }
    end
    local op = result.values
    tokens = result.rest
    extend(new_tokens, op)
    local result = _parse_expr(tokens)
    if not result.success then
        return {
            success = false,
        }
    end
    local value = result.values
    tokens = result.rest
    extend(new_tokens, value)
    return {
        success = true,
        values = new_tokens,
        rest = tokens,
    }
end

function _parse_expr(tokens)
    local new_tokens = token_stream()
    local result = _parse_atom(tokens)
    if not result.success then return result end
    local first = result.values
    extend(new_tokens, first)
    tokens = result.rest
    while true do
        local old_result = clone(new_tokens)
        local old_tokens = clone(tokens)
        local result = _parse_binop(tokens)
        if not result.success then
            return {
                success = true,
                values = old_result,
                rest = old_tokens,
            }
        end
        local binop = result.values
        tokens = result.rest
        extend(new_tokens, binop)
        local result = _parse_atom(tokens)
        if not result.success then
            return {
                success = true,
                values = old_result,
                rest = old_tokens,
            }
        end
        local value = result.values
        tokens = result.rest
        extend(new_tokens, value)
    end
    return {
        success = true,
        values = new_tokens,
        rest = tokens,
    }
end

function _parse_params(tokens)
    local result = _parse_names(tokens)
    if not result.success then
        if tokens[1].value == "..." then
            return {
                success = true,
                values = slice(tokens, 1, 1),
                rest = slice(tokens, 2),
            }
        end
        return {
            success = false,
        }
    end
    local new_tokens = token_stream()
    local names = result.values
    extend(new_tokens, names)
    tokens = result.rest
    if #tokens >= 2 and tokens[1].value == "," and tokens[2].value == "..." then
        extend(new_tokens, ", ...")
        return {
            success = true,
            values = new_tokens,
            rest = slice(tokens, 3),
        }
    end
    return {
        success = true,
        values = new_tokens,
        rest = tokens,
    }
end

function _parse_names(tokens)
    local result = _parse_name(tokens)
    if not result.success then return result end
    local new_tokens = token_stream()
    local first = result.values
    tokens = result.rest
    extend(new_tokens, first)
    while true do
        local old_result = clone(new_tokens)
        local old_tokens = clone(tokens)
        if #tokens == 0 or tokens[1].value ~= "," then
            return {
                success = true,
                values = old_result,
                rest = old_tokens,
            }
        end
        push(new_tokens, ",")
        local result = _parse_name(slice(tokens, 2))
        if not result.success then
            return {
                success = true,
                values = old_result,
                rest = old_tokens,
            }
        end
        local name = result.values
        tokens = result.rest
        extend(new_tokens, name)
    end
    return {
        success = true,
        values = new_tokens,
        rest = tokens,
    }
end

function _parse_name(tokens)
    if tokens[1].type == "name" then
        return {
            success = true,
            values = slice(tokens, 1, 1),
            rest = slice(tokens, 2),
        }
    end
    return {
        success = false,
    }
end

function _parse_funcbody(tokens)
    local new_tokens = token_stream()
    if tokens[1].value ~= "(" then
        return {
            success = false,
        }
    end
    push(new_tokens, "(")
    tokens = slice(tokens, 2)
    local result = _parse_params(tokens)
    if result.success then
        local params = result.values
        tokens = params.rest
        extend(new_tokens, params)
    end
    if tokens[1].value ~= ")" then
        return {
            success = false,
        }
    end
    push(new_tokens, ")")
    local result = _parse_block(tokens)
    if not result then return result end
    local block = result.values
    tokens = result.rest
    extend(new_tokens, block)
    if tokens[1].value ~= "end" then
        return {
            success = false,
        }
    end
    push(new_tokens, "end")
    tokens = slice(tokens, 2)
    return {
        success = true,
        values = new_tokens,
        rest = tokens,
    }
end

function _parse_func(tokens)
    local new_tokens = token_stream()
    if tokens[1].value ~= "function" then
        return {
            success = false,
        }
    end
    push(new_tokens, "function")
    tokens = slice(tokens, 2)
    local result = _parse_funcbody(tokens)
    if not result then return result end
    local body = result.values
    tokens = result.rest
    return {
        success = false,
        values = new_tokens,
        rest = tokens,
    }
end

function _parse_args(tokens)
    local result = _parse_string(tokens)
    if result.success then return result end
    local result = _parse_table(tokens)
    if result.success then return result end
    if tokens[1].value ~= "(" then
        return {
            success = false,
        }
    end
    tokens = slice(tokens, 2)
    local result = _parse_exprs(tokens)
    if not result.success then
        if tokens[1].value ~= ")" then
            return {
                success = false,
            }
        end
        tokens = slice(tokens, 2)
        return {
            success = true,
            values = tokenizer("()"),
            rest = tokens,
        }
    end
    local exprs = result.values
    tokens = result.rest
    prepend(exprs, "(")
    push(exprs, ")")
    return {
        success = true,
        values = exprs,
        rest = tokens,
    }
end

function _parse_funccall(tokens)
    local result = _parse_prefixexpr(tokens)
    if not result.success then return result end
    local prefixexpr = result.values
    tokens = result.rest
    local result = _parse_args(tokens)
    if not result.success then return result end
    local args = result.values
    tokens = result.rest
    extend(prefixexpr, args)
    return {
        success = true,
        values = prefixexpr,
        rest = tokens,
    }
end

function _parse_prefixexpr(tokens)
    local result = _parse_var(tokens)
    if result.success then return result end
    local result = _parse_funccall(tokens)
    if result.success then return result end
    local new_tokens = token_stream()
    if tokens[1].value ~= "(" then
        return {
            success = false,
        }
    end
    push(new_tokens, "(")
    local result = _parse_expr(tokens)
    if not result.success then return result end
    local expr = result.values
    tokens = result.rest
    if tokens[1].value ~= ")" then
        return {
            success = false,
        }
    end
    return {
        success = true,
        values = new_tokens,
        rest = tokens,
    }
end

function _parse_exprs(tokens)
    local new_tokens = token_stream()
    local result = _parse_expr(tokens)
    if result.success then return result end
    local first = result.values
    extend(new_tokens, first)
    tokens = result.rest
    while true do
        if tokens[1].value ~= "," then
            return {
                success = true,
                values = new_tokens,
                rest = tokens,
            }
        end
        extend(new_tokens, ",")
        tokens = slice(tokens, 2)
        local result = _parse_expr(tokens)
        if not result.success then return result end
        local expr = result.values
        tokens = result.rest
        extend(new_tokens, expr)
    end
    return {
        success = true,
        values = new_tokens,
        rest = tokens,
    }
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

function format(code, ...)
    return string.format(tostring(code), ...)
end

function meta(code, ...)
    code = string.format(tostring(code), ...)
    local env = getenv(1)
    local chunk = load(code, "chunk", "t", env)
    return chunk()
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
    return meta(string.format(
        "return " .. format_str, ...
    ), env)
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
    assert(token_stream[1].value == expected)
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

local tokens = tokenizer("name, age, ...")
print(_parse_params(tokens).values)