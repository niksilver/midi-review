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
    -- We can't use util.clamp or math.clamp due to library and Lua version
    -- discrepancies between a norns and what's likely to be on our
    -- local development box.

    self.current_index = self.current_index + d

    if self.current_index < 1 then
        self.current_index = 1
    elseif self.current_index > #self.sizes then
        self.current_index = #self.sizes
    end
end

-- A text string to describe the size of our current window.
--
function C:text()
    return period_to_text(self:size())
end

-- Describe a number of seconds as text
-- @param t    The time period to describe.
--
function period_to_text(t)
    local about_part = ""
    local min_part = ""
    local sec_part = ""

    if t > 120 then
        -- Round to the nearest 10 seconds
        t = math.floor((t + 5) / 10) * 10
        about_part = "about"
    end

    if t >= 60 then
        min_part = math.floor(t / 60) .. " min"
    end

    if t % 60 > 0 then
        sec_part = (t % 60) .. " sec"
    end

    return join({about_part, min_part, sec_part}, " ")
end

-- Join some strings with a separator.
-- We should ignore empty strings, but it's assumed there are no nils.
-- @param array    Array of strings to join.
-- @param sep    Separator between strings.
--
function join(array, sep)
    local out = ""

    for i = 1, #array do
        out = out .. array[i]
        if array[i] ~= "" and some_non_empty_due(array, i) then
            out = out .. " "
        end
    end

    return out
end

-- Is there some non-empty string expected after the current index?
-- @param array    Array of strings.
-- @param i    Index to look beyond.
function some_non_empty_due(array, i)
    if i >= #array then
        return false
    end

    for j = i+1, #array do
        if array[j] ~= "" then
            return true
        end
    end

    return false
end

-- Get the length of the longest text message from all the size options.
-- @param f    A function that takes a string and returns its length.
--     This is useful for testing this method off the norns hardware..
--
function C:max_text_length(f)
    local max = 0

    for _, t in pairs(self.sizes) do
        max = math.max( max, f(period_to_text(t)) )
    end

    return max
end

-- Index of the current windows size.
--
C.current_index = nil

return C
