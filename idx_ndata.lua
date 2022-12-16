-- A sequence of note data.
-- Each note data (MIDI notes) will have an index.
--
-- At each index we will have:
--     - time - Clock time in fractional seconds.
--     - note_vel - Map from a MIDI note number to its velocity.
--
-- Indices should be contiguous, but may not start at 1.

C = {}

-- Create a new sequence.
-- @param fn    The function to call to get the current time.
--     We don't use a default to force the programmer to be explicit.
--
function C.new(fn)
    local obj = {}
    setmetatable(obj, {__index = C})

    obj.timefn = fn
    obj.ndata = {}

    return obj
end

-- How many items of note data do we have?
--
function C:length()
    return #self.ndata
end

-- Append some note data, together with the current clock time.
-- @param data    A map from MIDI note values (0-127) to velocity.
--
function C:append(data)
    local last_index = self:length()
    self.ndata[last_index+1] = {
        time = self:timefn(),
        note_vel = data,
    }
end

-- Get the note data at a given index.
-- @param i    Index of the data.
-- @return    A table with keys `time` and `note_vel`.
function C:get(i)
    return self.ndata[i]
end

-- The function used to get the time when we append data.
-- Nil by default
--
C.timefn = nil

-- The map from index to time/note_vel
--
C.ndata = {}

return C
