lu = require('luaunit')

recording = require('recording')
idx_ndata = require('idx_ndata')

function dummy_time()
    lu.fail("dummy_time() should not have been called")
end

function test_new()
    local idx_nd = idx_ndata.new(dummy_time)
    local rec = recording.new(1, 4, idx_nd)
end

function test_position_no_looping()
    local idx_nd = idx_ndata.new(dummy_time)

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

function test_position_with_looping()
    local idx_nd = idx_ndata.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, idx_nd)

    -- Put some dummy data into the note data sequence

    idx_nd:append({}, 1000.0)    -- 1, position 10.0
    idx_nd:append({}, 1000.3)
    idx_nd:append({}, 1001.0)    -- 3, position 11.0
    idx_nd:append({}, 1001.2)
    idx_nd:append({}, 1002.4)    -- 5, should loop to position 10.4
    idx_nd:append({}, 1003.5)    -- 6, should be position 11.5
    idx_nd:append({}, 1004.6)    -- 7, should loop to position 10.6

    lu.assertAlmostEquals(rec:position(5), 10.4, 0.001)
    lu.assertAlmostEquals(rec:position(6), 11.5, 0.001)
    lu.assertAlmostEquals(rec:position(7), 10.6, 0.001)
end

function test_cut_simple_case()
    local idx_nd = idx_ndata.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, idx_nd)

    -- Put some dummy data into the note data sequence

    idx_nd:append({}, 1000.0)    -- 1, position 10.0
    idx_nd:append({}, 1000.3)
    idx_nd:append({}, 1001.0)    -- 3, position 11.0
    idx_nd:append({}, 1001.2)
    idx_nd:append({}, 1001.4)    -- 5, position 11.4

    lu.assertAlmostEquals(idx_nd:time(1), 1000.0, 0.001)
    lu.assertAlmostEquals(idx_nd:time(2), 1000.3, 0.001)
    lu.assertAlmostEquals(idx_nd:time(3), 1001.0, 0.001)
    lu.assertAlmostEquals(idx_nd:time(4), 1001.2, 0.001)
    lu.assertAlmostEquals(idx_nd:time(5), 1001.4, 0.001)

    -- We'll cut after deleting the first two MIDI data items.
    -- This should give us note data from time 1001.0 onwards

    idx_nd:delete_from_front()
    idx_nd:delete_from_front()
    local offset = rec:cut()

    lu.assertEquals(offset, 2)
    lu.assertEquals(idx_nd:length(), 3)
    lu.assertEquals(idx_nd.first_index, 1)
    lu.assertEquals(idx_nd.last_index, 3)

    lu.assertAlmostEquals(idx_nd:time(1), 1001.0, 0.001)
    lu.assertAlmostEquals(idx_nd:time(2), 1001.2, 0.001)
    lu.assertAlmostEquals(idx_nd:time(3), 1001.4, 0.001)

    lu.assertAlmostEquals(rec:position(1), 11.0, 0.001)
    lu.assertAlmostEquals(rec:position(2), 11.2, 0.001)
    lu.assertAlmostEquals(rec:position(3), 11.4, 0.001)
end
