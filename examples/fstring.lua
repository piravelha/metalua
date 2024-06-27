require "metalua"

F = function(str)
    local stream = token_stream()
    local new_str = str:gsub("{%w+}", "%%s")
    for name in str:gmatch("{(%w+)}") do
        push(stream, ",")
        push(stream, name)
    end
    return meta(getenv(1), [[
        return string.format("%s" %s)
    ]], new_str, stream)
end

M = function(mstr)
    mstr = mstr:gsub("\\%s-\\", "")
    return mstr
end