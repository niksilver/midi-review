-- Representation of a softcut recording, which may have looped.
-- To be used in conjunction with `idx_ndata` to track MIDI notes.
--

local C = {}

-- Create a new recording representation.
-- @param buffer_start    Where the loop starts in the buffer.
-- @param buffer_duration    Duration of the loop in the buffer.
-- @param idx_nd    Our `idx_ndata` structure with the MIDI note data.
--
function C.new(buffer_start, buffer_duration)
    local obj = {}
    setmetatable(obj, {__index = C})

    obj.start_pos = nil    -- Position in the buffer of the start of our recording

    obj.buffer_start = buffer_start
    obj.buffer_duration = buffer_duration
    obj.buffer_end = buffer_start + buffer_duration

    obj.idx_nd = idx_nd
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
