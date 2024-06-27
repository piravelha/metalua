require "metalua"

ADD3 = macro(function(tokens)
    tokens = split_by(tokens, ",")
    local x, y, z = unpack(tokens)
    return meta("%s + %s + %s", x, y, z)
end)

print(ADD3[[1, 2, 3]])