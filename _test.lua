function get_caller_code()
    -- Get information about the caller of the function
    local info = debug.getinfo(3, "S")
    if info and info.source then
        -- Open the source file
        local file = io.open(info.source:sub(2), "r")
        if file then
            -- Read the file contents
            local code = file:read("*all")
            file:close()
            -- Return the code
            return code
        end
    end
    return nil
end

function caller_function()
    print(get_caller_code())
end

function test_function()
    caller_function()
end

test_function()
