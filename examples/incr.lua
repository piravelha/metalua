require "metalua"

INCR = macro(function(tokens))
    local var = expect_type(tokens, "name")
    local op = expect_type(tokens, "operator")
    if op.value == "++" then
        return meta(getenv(1), [[
            %s = %s + 1
        ]], var, var)
    elseif op.value == "--" then
        return meta(getenv(1), [[
            %s = %s - 1
        ]], var, var)
    end
end)
