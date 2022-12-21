-- Representation of a rolling window of audio data in a softcut buffer.
-- This only tracks the options for the window size, and which is current;
-- it doesn't hold any info about the position or contents of the
-- window in softcut.
--

local C = {}

-- Create a new rolling window tracker.
-- @param sizes    An array of sizes that the window might be, in seconds.
-- @param default    The index of which is the initial size.
--
function C.new(sizes, default)
    local obj = {}
    setmetatable(obj, {__index = C})

    obj.sizes = sizes
    obj.current_index = default or 1

    return obj
end

-- Index of the current windows size.
--
C.current_index = nil

return C
