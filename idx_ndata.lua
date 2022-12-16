-- A sequence of note data.
-- Each note data (MIDI notes) will have an index.
--
-- At each index we will have:
--     - time - Clock time in fractional seconds.
--     - note_vel - Map from a MIDI note number to its velocity.
--
-- Indices should be contiguous, but may not start at 1.

C = {}

-- Create a new mapping
--
function C.new()
    local obj = {}
    setmetatable(obj, {__index = C})

    return obj
end

-- How many items of note data do we have?
--
function C:length()
    return #self.ndata
end

-- The map from index to time/note_vel
--
C.ndata = {}

return C
