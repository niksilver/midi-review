lu = require('luaunit')

recording = require('recording')
idx_ndata = require('idx_ndata')

function test_new()
    local idx_nd = idx_ndata.new(os.clock)
    local rec = recording.new(1, 4, idx_nd)
end

function test_position_no_looping()
    local idx_nd = idx_ndata.new(os.clock)

    -- Our recording loop runs from positions 10 to 14 in the buffer
    local rec = recording.new(10, 4, idx_nd)

    -- Put some dummy data into the note data sequence

    idx_nd:append({}, 1000.0)
    idx_nd:append({}, 1000.3)
    idx_nd:append({}, 1001.0)
    idx_nd:append({}, 1001.2)

    lu.assertAlmostEquals(rec:position(1), 10.0, 0.001)
    lu.assertAlmostEquals(rec:position(2), 10.3, 0.001)
    lu.assertAlmostEquals(rec:position(3), 11.0, 0.001)
    lu.assertAlmostEquals(rec:position(4), 11.2, 0.001)
end
