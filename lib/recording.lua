-- Representation of a softcut recording, which may have looped.
-- To be used in conjunction with `idx_ndata` to track MIDI notes.
--
-- This class mainly tracks the start and end of a recording.
-- When a recording starts it will begin at the start of the softcut
-- buffer. However, it should have a maximum length, which will be
-- slightly less than the full length of the softcut buffer.
-- Meanwhile, MIDI note data will be recorded against the audio.
--
-- Audio may continue to be recorded beyond the duration of the
-- softcut buffer, in which case it loops round to the start and
-- continues.
--
-- We distinguish between time and position. Time is the clock time
-- of MIDI note data coming in. Position is the position in the
-- softcut buffer of something. We will know the position of the
-- start of the recording (because we set that) but it's difficult to
-- know the position of any MIDI note data. That's because when MIDI
-- note data comes in we can only ask for the clock time (so we record
-- that). Asking for the record head position is an asychronous call,
-- so can't be relied upon for accuracy. So to work out the position
-- of any MIDI note data we make a calculation based on the position of
-- the start of the recording, the clock time of the start of the recording,
-- and the clock time of the MIDI event.
--
-- As the recording continues earlier note data and audio may need
-- to be deleted from the front of the recording, to keep it to the
-- maximum length. The way this works is that the sequence of note
-- data will be deleted from the front (where the oldest data is)
-- as the recording lengthens. When this happens we still keep the
-- time and position of the original start of the recording. Once
-- recording stops we call the cut method. This updates the (new) start
-- of the recording to align with the (new) first MIDI note data.

local C = {}

-- Create a new recording representation.
-- @param buffer_start    Where the loop starts in the buffer.
-- @param buffer_duration    Duration of the loop in the buffer.
-- @param idx_nd    Our `idx_ndata` structure with the MIDI note data.
--
function C.new(buffer_start, buffer_duration, idx_nd)
    local obj = {}
    setmetatable(obj, {__index = C})

    obj.buffer_start = buffer_start
    obj.buffer_duration = buffer_duration
    obj.buffer_end = buffer_start + buffer_duration

    obj.start_pos = buffer_start    -- Buffer position of the start of our recording

    obj.idx_nd = idx_nd

    return obj
end

-- Get the buffer position given the note data index.
-- @param i    Index of the note data.
--
function C:position(i)
    -- Time the recording starts
    local start_time = self.idx_nd.time1

    -- Duration from recording start to note data i
    local clock_gap = self.idx_nd:time(i) - start_time

    -- Position of note data i, but not accounting for possible looping
    local pos_unlooped = self.start_pos + clock_gap

    -- Duration of note data i from the start of the buffer
    local gap_unlooped = pos_unlooped - self.buffer_start

    -- This gap may be over the buffer duration any number of times,
    -- so remove those "whole" gaps, ensuring the position is in the buffer.

    local whole_gaps = (gap_unlooped // self.buffer_duration) * self.buffer_duration
    local pos = self.buffer_start + gap_unlooped - whole_gaps

    return pos
end

-- Is the given position at or after a given index?
-- @param pos   The position we want to test.
-- @param i  The index we want to test the position against.
--
function C:position_at_or_beyond(pos, i)
    local start_pos = self:position(self.idx_nd.first_index)
    local end_pos = self:position(self.idx_nd.last_index)
    local i_pos = self:position(i)

    if start_pos < end_pos then
        -- Not a loop
        return pos >= i_pos
    end

    -- There is a loop

    -- If pos is in the upper end of the buffer (earlier in recording)...
    if start_pos <= pos then
        return start_pos <= i_pos and i_pos <= pos
    end

    -- pos is in the lower end of the buffer (later in the recording)
    return start_pos <= i_pos or i_pos <= pos
end

-- Is our audio position beyond the end of the recording?
-- This isn't so straightforward, as the recording may have looped.
-- @param pos    The position to test.
--
function C:beyond_end(pos)
    local start_pos = self:position(self.idx_nd.first_index)
    local end_pos = self:position(self.idx_nd.last_index)

    if start_pos <= end_pos then
        -- The start and end of the recording haven't looped
        return pos < start_pos or pos > end_pos
    end

    -- The start and end of the recording have looped
    return end_pos < pos and pos < start_pos
end

-- Calculate the duration of the recording from the first MIDI note data
-- to the given position.
-- @param pos    The position in the buffer of the end of the period
-- @return    Duration of the recording in seconds, or 0 if there is
--     nothing recorded.
--
function C:duration(pos)
    if self.idx_nd.first_index == nil then
        return 0
    end

    local start_pos = self:position(self.idx_nd.first_index)

    -- We may have an easy calculation
    if start_pos <= pos then
        return pos - start_pos
    end

    -- We've looped round the buffer loop, so it's more complicated
    return pos - start_pos + self.buffer_duration
end

-- Cut the recording to start from wherever the note data starts from.
-- The note data will be reindexed.
-- @return    The offset from the reindex.
--     Ie how many places the indices have moved back following the reindex.
--     Will be nil if there was no note data.
--
function C:cut()
    local first_index = self.idx_nd.first_index
    if first_index == nil then
        return nil
    end

    local pos = self:position(first_index)

    self.start_pos = pos
    return self.idx_nd:reindex()
end

-- From the period from note data at i to note data of i+1, return the
-- relative time of position pos.
-- For example, note data i is at position 101.0 and i+1 is at position 105.0
-- then pos 101.0 is at relative time 0 (right at the start),
-- pos 105.0 is at relative time 1.0 (right at the end),
-- and pos 103.0 is at relative time 0.5 (half way between).
-- Assumes pos is between i and i+1, otherwise the result may be wrong
-- @param i    Index of the note data at the start of the period.
-- @param pos    Position for which we want the answer.
--
function C:relative_time(i, pos)
    local i_pos = self:position(i)
    local j_pos = self:position(i+1)

    if i_pos < j_pos then
        -- i and i+1 don't loop
        return (pos - i_pos) / (j_pos - i_pos)
    end

    -- We have a loop; we'll rework the numbers as if the buffer
    -- just continued, and didn't loop

    if j_pos < i_pos then
        j_pos = self.buffer_end + (j_pos - self.buffer_start)
    end
    if pos < i_pos then
        pos = self.buffer_end + (pos - self.buffer_start)
    end

    return (pos - i_pos) / (j_pos - i_pos)
end

-- Where the loop starts in the buffer.
--
C.buffer_start = nil

-- Where the loop ends in the buffer.
--
C.buffer_end = nil

-- Duration of the loop in the buffer
--
C.buffer_duration = nil

return C
