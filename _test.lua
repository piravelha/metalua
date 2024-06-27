require "metalua"

INCREMENT = macro(function(tokens)
    return "(%s) + 1", tokens 
end);

print(INCREMENT[[10 + 2]])

generate()