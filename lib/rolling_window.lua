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

-- Get the size of the rolling window.
--
function C:size()
    return self.sizes[self.current_index]
end

-- Change the current index by some delta. Any attempt to go beyond
-- the bounds of the size array will just keep us within the bounds.
-- @param d    Amount to adjust the current index.
--
function C:delta(d)
    -- We can't use util.clamp or math.clamp due to version and library
    -- discrepancies between a norns any our local development box.

    self.current_index = self.current_index + d

    if self.current_index < 1 then
        self.current_index = 1
    elseif self.current_index > #self.sizes then
        self.current_index = #self.sizes
    end
end

-- Index of the current windows size.
--
C.current_index = nil

return C
