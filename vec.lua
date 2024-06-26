require "metalua"

VEC = macro(function(tokens)
    return meta(
        [[return setmetatable({%s}, {
            __tostring = function(self)
                local str = "["
                for i, v in pairs(self) do
                    if i > 1 then
                        str = str .. ", "
                    end
                    str = str .. tostring(v)
                end
                return str .. "]"
            end,
        })]],
        tokens
    )
end)

local my_vec = VEC[[ 1, 2, 3, 4, VEC[[ 5, 6, 7, 8 ]\] ]]
