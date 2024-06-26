require "metalua"

RETRY = macro(function(tokens)
    local func = expect_type(tokens, "name")
    local amount = expect_type(tokens, "number")

    local result = meta(getenv(1), [[
        return function(...)
            for i = 1, %s do
                local success, result = pcall(%s, ...)
                if success then
                    return result
                end
                if i == %s then
                    error("Function %s failed after %s attempts")
                end
            end
        end
    ]], amount, func, amount, func, amount)
    return result
end)

function flaky()
    if math.random() < 0.5 then
        error("Failed")
    end
    return "Success"
end

local flaky_3 = RETRY[[ flaky 3 ]]

print(flaky_3())