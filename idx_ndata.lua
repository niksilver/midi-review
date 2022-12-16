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

    -- Index of the first and last items
    obj.first_index = nil
    obj.last_index = nil

    return obj
end

-- How many items of note data do we have?
--
function C:length()
    if self.first_index == nil then
        return 0
    end

    return self.last_index - self.first_index + 1
end

-- Append some note data, together with the current clock time.
-- @param data    A map from MIDI note values (0-127) to velocity.
--
function C:append(data)
    if self.last_index == nil then
        self.last_index = 1
    else
        self.last_index = self.last_index + 1
    end

    self.ndata[self.last_index] = {
        time = self:timefn(),
        note_vel = shallow_copy(data),
    }

    if self.first_index == nil then
        self.first_index = 1
    end
end

-- Return a shallow copy of a table
--
function shallow_copy(tab)
    local copy = {}
    for k, v in pairs(tab) do
        copy[k] = v
    end
    return copy
end

-- Get the note data at a given index.
-- @param i    Index of the data.
-- @return    A table with keys `time` and `note_vel`.
function C:get(i)
    return self.ndata[i]
end

-- Get the time at a given index.
-- Shortcut for `obj.get(i).time`
-- @param i    Index of the data.
function C:time(i)
    return self.ndata[i].time
end

-- Get the note_vel table at a given index.
-- Shortcut for `obj.get(i).note_vel`
-- @param i    Index of the data.
function C:note_vel(i)
    return self.ndata[i].note_vel
end

-- Delete the note data at the front of the sequence.
--
function C:delete_from_front()
    self.ndata[self.first_index] = nil

    if self.first_index == self.last_index then
        self.first_index = nil
        self.last_index = nil
    else
        self.first_index = self.first_index + 1
    end
end

-- Reindex the note data so that the sequence starts from index 1
--
function C:reindex()
    if self.first_index == nil or self.first_index == 1 then
        return
    end

    local offset = self.first_index - 1
    local ndata2 = {}

    for src, d in pairs(self.ndata) do
        local dst = src - offset
        ndata2[src - offset] = {
            time = d.time,
            note_vel = d.note_vel
        }
    end

    self.ndata = ndata2
    self.first_index = 1
    self.last_index = self.last_index - offset
end

-- The function used to get the time when we append data.
-- Nil by default
--
C.timefn = nil

-- The map from index to time/note_vel
--
C.ndata = {}

-- Index of the first item in the sequence, or nil.
--
C.first_index = nil

-- Index of the last item in the sequence, or nil.
--
C.last_index = nil

return C
