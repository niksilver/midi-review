lu = require('luaunit')

recording = require('recording')
MidiSeq = require('midi_sequence')

function dummy_time()
    lu.fail("dummy_time() should not have been called")
end

function test_new()
    local mseq = MidiSeq.new(dummy_time)
    local rec = recording.new(1, 4, mseq)
end

function test_position_no_looping()
    local mseq = MidiSeq.new(dummy_time)

    -- Our recording loop runs from positions 10 to 14 in the buffer
    local rec = recording.new(10, 4, mseq)

    -- Put some dummy data into the note data sequence

    mseq:append({}, 1000.0)
    mseq:append({}, 1000.3)
    mseq:append({}, 1001.0)
    mseq:append({}, 1001.2)

    lu.assertAlmostEquals(rec:position(1), 10.0, 0.001)
    lu.assertAlmostEquals(rec:position(2), 10.3, 0.001)
    lu.assertAlmostEquals(rec:position(3), 11.0, 0.001)
    lu.assertAlmostEquals(rec:position(4), 11.2, 0.001)
end

function test_position_with_looping()
    local mseq = MidiSeq.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, mseq)

    -- Put some dummy data into the note data sequence

    mseq:append({}, 1000.0)    -- 1, position 10.0
    mseq:append({}, 1000.3)
    mseq:append({}, 1001.0)    -- 3, position 11.0
    mseq:append({}, 1001.2)
    mseq:append({}, 1002.4)    -- 5, should loop to position 10.4
    mseq:append({}, 1003.5)    -- 6, should be position 11.5
    mseq:append({}, 1004.6)    -- 7, should loop to position 10.6

    lu.assertAlmostEquals(rec:position(5), 10.4, 0.001)
    lu.assertAlmostEquals(rec:position(6), 11.5, 0.001)
    lu.assertAlmostEquals(rec:position(7), 10.6, 0.001)
end

function test_cut_simple_case()
    local mseq = MidiSeq.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, mseq)

    -- Put some dummy data into the note data sequence

    mseq:append({}, 1000.0)    -- 1, position 10.0
    mseq:append({}, 1000.3)
    mseq:append({}, 1001.0)    -- 3, position 11.0
    mseq:append({}, 1001.2)
    mseq:append({}, 1001.4)    -- 5, position 11.4

    lu.assertAlmostEquals(mseq:time(1), 1000.0, 0.001)
    lu.assertAlmostEquals(mseq:time(2), 1000.3, 0.001)
    lu.assertAlmostEquals(mseq:time(3), 1001.0, 0.001)
    lu.assertAlmostEquals(mseq:time(4), 1001.2, 0.001)
    lu.assertAlmostEquals(mseq:time(5), 1001.4, 0.001)

    -- We'll cut after deleting the first two MIDI data items.
    -- This should give us note data from time 1001.0 onwards

    mseq:delete_from_front()
    mseq:delete_from_front()
    local offset = rec:cut()

    lu.assertEquals(offset, 2)
    lu.assertEquals(mseq:length(), 3)
    lu.assertEquals(mseq.first_index, 1)
    lu.assertEquals(mseq.last_index, 3)

    lu.assertAlmostEquals(mseq:time(1), 1001.0, 0.001)
    lu.assertAlmostEquals(mseq:time(2), 1001.2, 0.001)
    lu.assertAlmostEquals(mseq:time(3), 1001.4, 0.001)

    lu.assertAlmostEquals(rec:position(1), 11.0, 0.001)
    lu.assertAlmostEquals(rec:position(2), 11.2, 0.001)
    lu.assertAlmostEquals(rec:position(3), 11.4, 0.001)
end

function test_cut_after_looping()
    local mseq = MidiSeq.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, mseq)

    -- Put some dummy data into the note data sequence

    mseq:append({}, 1000.0)    -- 1, position 10.0
    mseq:append({}, 1000.3)
    mseq:append({}, 1001.0)    -- 3, position 11.0
    mseq:append({}, 1001.2)
    mseq:append({}, 1001.4)    -- 5, position 11.4
    mseq:append({}, 1002.1)    -- 6, position 10.1
    mseq:append({}, 1003.8)    -- 7, position 11.8
    mseq:append({}, 1004.0)    -- 8, position 10.0 - On the edge!
    mseq:append({}, 1004.5)    -- 9, position 10.5

    -- Delete items 1-7 and check things before cutting

    for _ = 1, 7 do
        mseq:delete_from_front()
    end

    lu.assertEquals(mseq:length(), 2)
    lu.assertEquals(mseq.first_index, 8)
    lu.assertEquals(mseq.last_index, 9)

    lu.assertAlmostEquals(mseq:time(8), 1004.0, 0.001)
    lu.assertAlmostEquals(mseq:time(9), 1004.5, 0.001)

    lu.assertAlmostEquals(rec:position(8), 10.0, 0.001)
    lu.assertAlmostEquals(rec:position(9), 10.5, 0.001)

    -- Cut the buffer and check everything again

    local offset = rec:cut()

    lu.assertEquals(offset, 7)

    lu.assertEquals(mseq:length(), 2)
    lu.assertEquals(mseq.first_index, 1)
    lu.assertEquals(mseq.last_index, 2)

    lu.assertAlmostEquals(mseq:time(1), 1004.0, 0.001)
    lu.assertAlmostEquals(mseq:time(2), 1004.5, 0.001)

    lu.assertAlmostEquals(rec:position(1), 10.0, 0.001)
    lu.assertAlmostEquals(rec:position(2), 10.5, 0.001)
end

function test_position_with_looping_after_cut()
    local mseq = MidiSeq.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, mseq)

    -- Put some dummy data into the note data sequence

    mseq:append({}, 1000.0)    -- 1, position 10.0
    mseq:append({}, 1000.3)
    mseq:append({}, 1001.0)    -- 3, position 11.0
    mseq:append({}, 1001.2)
    mseq:append({}, 1001.4)    -- 5, position 11.4
    mseq:append({}, 1002.1)    -- 6, position 10.1
    mseq:append({}, 1003.8)    -- 7, position 11.8
    mseq:append({}, 1004.0)    -- 8, position 10.0 - On the edge!
    mseq:append({}, 1004.5)    -- 9, position 10.5

    -- Check all the positions when nothing's happened

    lu.assertAlmostEquals(rec:position(1), 10.0, 0.001)
    lu.assertAlmostEquals(rec:position(2), 10.3, 0.001)
    lu.assertAlmostEquals(rec:position(3), 11.0, 0.001)
    lu.assertAlmostEquals(rec:position(4), 11.2, 0.001)
    lu.assertAlmostEquals(rec:position(5), 11.4, 0.001)
    lu.assertAlmostEquals(rec:position(6), 10.1, 0.001)
    lu.assertAlmostEquals(rec:position(7), 11.8, 0.001)
    lu.assertAlmostEquals(rec:position(8), 10.0, 0.001)
    lu.assertAlmostEquals(rec:position(9), 10.5, 0.001)

    -- Delete one, check. The indices won't change

    mseq:delete_from_front()

    lu.assertAlmostEquals(rec:position(2), 10.3, 0.001)
    lu.assertAlmostEquals(rec:position(3), 11.0, 0.001)
    lu.assertAlmostEquals(rec:position(4), 11.2, 0.001)
    lu.assertAlmostEquals(rec:position(5), 11.4, 0.001)
    lu.assertAlmostEquals(rec:position(6), 10.1, 0.001)
    lu.assertAlmostEquals(rec:position(7), 11.8, 0.001)
    lu.assertAlmostEquals(rec:position(8), 10.0, 0.001)
    lu.assertAlmostEquals(rec:position(9), 10.5, 0.001)

    -- Cut, check. The indices will change

    rec:cut()

    lu.assertAlmostEquals(rec:position(1), 10.3, 0.001)
    lu.assertAlmostEquals(rec:position(2), 11.0, 0.001)
    lu.assertAlmostEquals(rec:position(3), 11.2, 0.001)
    lu.assertAlmostEquals(rec:position(4), 11.4, 0.001)
    lu.assertAlmostEquals(rec:position(5), 10.1, 0.001)
    lu.assertAlmostEquals(rec:position(6), 11.8, 0.001)
    lu.assertAlmostEquals(rec:position(7), 10.0, 0.001)
    lu.assertAlmostEquals(rec:position(8), 10.5, 0.001)
end

function test_cut_to_end()
    local mseq = MidiSeq.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, mseq)

    -- Put some dummy data into the note data sequence

    mseq:append({}, 1000.0)    -- 1, position 10.0
    mseq:append({}, 1000.3)
    mseq:append({}, 1001.0)    -- 3, position 11.0
    mseq:append({}, 1001.2)

    -- Delete all but one of the note data items and cut

    mseq:delete_from_front()
    mseq:delete_from_front()
    mseq:delete_from_front()

    local offset = rec:cut()

    lu.assertEquals(offset, 3)

    lu.assertEquals(mseq:length(), 1)
    lu.assertEquals(mseq.first_index, 1)
    lu.assertEquals(mseq.last_index, 1)

    lu.assertAlmostEquals(mseq:time(1), 1001.2, 0.001)

    lu.assertAlmostEquals(rec:position(1), 11.2, 0.001)
end

function test_cut_after_everything_deleted()
    local mseq = MidiSeq.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, mseq)

    -- Put some dummy data into the note data sequence

    mseq:append({}, 1000.0)    -- 1, position 10.0
    mseq:append({}, 1000.3)
    mseq:append({}, 1001.0)    -- 3, position 11.0
    mseq:append({}, 1001.2)

    -- Delete all the note data items and cut

    mseq:delete_from_front()
    mseq:delete_from_front()
    mseq:delete_from_front()
    mseq:delete_from_front()

    local offset = rec:cut()

    lu.assertNil(offset)

    lu.assertEquals(mseq:length(), 0)
    lu.assertNil(mseq.first_index)
    lu.assertNil(mseq.last_index)
end

function test_duration()
    local mseq = MidiSeq.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, mseq)

    lu.assertEquals(rec:duration(10.0), 0)
    lu.assertEquals(rec:duration(10.5), 0)

    -- Put some dummy data into the note data sequence

    mseq:append({}, 1000.0)    -- 1, position 10.0
    mseq:append({}, 1000.3)
    mseq:append({}, 1001.0)    -- 3, position 11.0
    mseq:append({}, 1001.2)
    mseq:append({}, 1002.1)    -- 5, position 10.1
    mseq:append({}, 1003.8)    -- 6, position 11.8

    -- Duration from index 1, start position of the record head is 10.0

    lu.assertAlmostEquals(rec:duration(10.0), 0.0, 0.001)
    lu.assertAlmostEquals(rec:duration(10.5), 0.5, 0.001)
    lu.assertAlmostEquals(rec:duration(11.2), 1.2, 0.001)

    -- If we delete the first MIDI event, the start is position 10.3

    mseq:delete_from_front()

    lu.assertAlmostEquals(rec:duration(10.3), 0.0, 0.001)
    lu.assertAlmostEquals(rec:duration(11.3), 1.0, 0.001)
    lu.assertAlmostEquals(rec:duration(11.5), 1.2, 0.001)

    -- If we delete the next MIDI event, the start is position 11.0,
    -- and we should consider if the record head has looped.

    mseq:delete_from_front()

    lu.assertAlmostEquals(rec:duration(11.0), 0.0, 0.001)
    lu.assertAlmostEquals(rec:duration(11.5), 0.5, 0.001)
    lu.assertAlmostEquals(rec:duration(10.0), 1.0, 0.001)    -- Looped
    lu.assertAlmostEquals(rec:duration(10.5), 1.5, 0.001)    -- Looped

    -- Delete all but the last two events, the start position is 10.1.
    -- (We'll test against 10.100001 to avoid precision issues.

    mseq:delete_from_front()
    mseq:delete_from_front()

    lu.assertAlmostEquals(rec:duration(10.100001), 0.0, 0.001)
    lu.assertAlmostEquals(rec:duration(11.3), 1.2, 0.001)
    lu.assertAlmostEquals(rec:duration(10.0), 1.9, 0.001)    -- Looped

    -- Leave only one event, with start position 11.8

    mseq:delete_from_front()

    lu.assertAlmostEquals(rec:duration(11.800001), 0.0, 0.001)
    lu.assertAlmostEquals(rec:duration(11.9), 0.1, 0.001)
    lu.assertAlmostEquals(rec:duration(10.0), 0.2, 0.001)    -- Looped
    lu.assertAlmostEquals(rec:duration(10.1), 0.3, 0.001)    -- Looped

    -- Delete the last event and we should get zero duration

    mseq:delete_from_front()

    lu.assertEquals(rec:duration(10.0), 0)
    lu.assertEquals(rec:duration(10.1), 0)
    lu.assertEquals(rec:duration(99.0), 0)    -- Silly, but should stil return 0
end

function test_position_at_or_beyond_no_looping()
    local mseq = MidiSeq.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, mseq)

    -- Put some dummy data into the note data sequence

    mseq:append({}, 1000.0)    -- 1, position 10.0
    mseq:append({}, 1000.3)    -- 2, position 10.3
    mseq:append({}, 1000.7)    -- 3, position 10.7
    mseq:append({}, 1001.0)    -- 4, position 11.0

    -- Test various positions against the indices

    lu.assertEquals(rec:position_at_or_beyond(10.0, 1), true)
    lu.assertEquals(rec:position_at_or_beyond(10.0, 2), false)
    lu.assertEquals(rec:position_at_or_beyond(10.0, 3), false)

    lu.assertEquals(rec:position_at_or_beyond(10.1, 1), true)
    lu.assertEquals(rec:position_at_or_beyond(10.1, 2), false)
    lu.assertEquals(rec:position_at_or_beyond(10.1, 3), false)

    lu.assertEquals(rec:position_at_or_beyond(10.3, 1), true)
    lu.assertEquals(rec:position_at_or_beyond(10.3, 2), true)
    lu.assertEquals(rec:position_at_or_beyond(10.3, 3), false)

    lu.assertEquals(rec:position_at_or_beyond(10.4, 1), true)
    lu.assertEquals(rec:position_at_or_beyond(10.4, 2), true)
    lu.assertEquals(rec:position_at_or_beyond(10.4, 3), false)

    -- Delete the first note data and test again

    mseq:delete_from_front()

    lu.assertEquals(rec:position_at_or_beyond(10.3, 2), true)
    lu.assertEquals(rec:position_at_or_beyond(10.3, 3), false)
    lu.assertEquals(rec:position_at_or_beyond(10.3, 4), false)

    lu.assertEquals(rec:position_at_or_beyond(10.4, 2), true)
    lu.assertEquals(rec:position_at_or_beyond(10.4, 3), false)
    lu.assertEquals(rec:position_at_or_beyond(10.4, 4), false)

    lu.assertEquals(rec:position_at_or_beyond(10.8, 2), true)
    lu.assertEquals(rec:position_at_or_beyond(10.8, 3), true)
    lu.assertEquals(rec:position_at_or_beyond(10.8, 4), false)

    lu.assertEquals(rec:position_at_or_beyond(10.8, 2), true)
    lu.assertEquals(rec:position_at_or_beyond(10.8, 3), true)
    lu.assertEquals(rec:position_at_or_beyond(10.8, 4), false)
end

function test_position_at_or_beyond_with_looping()
    local mseq = MidiSeq.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, mseq)

    -- Put some dummy data into the note data sequence

    mseq:append({}, 1000.0)
    mseq:append({}, 1000.3)
    mseq:append({}, 1000.7)
    mseq:append({}, 1001.0)    -- 1, position 11.0 (after delete and cut)
    mseq:append({}, 1001.3)    -- 2, position 11.3
    mseq:append({}, 1002.1)    -- 3, position 10.1
    mseq:append({}, 1002.3)    -- 4, position 10.3

    mseq:delete_from_front()
    mseq:delete_from_front()
    mseq:delete_from_front()
    rec:cut()

    -- Now the recording runs from position 11.0 round to 10.3

    -- Due to precision errors we may find that the MIDI event at
    -- (say) clock time 1002.1 is not exactly at position 10.1.
    -- This causes our tests to fail unexpectedly.
    -- To avoid that we'll set up some variables which represent
    -- the actual position of various clock times which are at
    -- particular MIDI events.

    local p_11_0 = rec:position(1)    -- Represents position 11.0
    local p_10_1 = rec:position(3)    -- Represents position 10.1
    local p_10_3 = rec:position(4)

    -- Test various positions against the indices

    lu.assertEquals(rec:position_at_or_beyond(p_11_0, 1), true)
    lu.assertEquals(rec:position_at_or_beyond(p_11_0, 2), false)
    lu.assertEquals(rec:position_at_or_beyond(p_11_0, 3), false)
    lu.assertEquals(rec:position_at_or_beyond(p_11_0, 4), false)

    lu.assertEquals(rec:position_at_or_beyond(11.2, 1), true)
    lu.assertEquals(rec:position_at_or_beyond(11.2, 2), false)
    lu.assertEquals(rec:position_at_or_beyond(11.2, 3), false)
    lu.assertEquals(rec:position_at_or_beyond(11.2, 4), false)

    lu.assertEquals(rec:position_at_or_beyond(11.4, 1), true)
    lu.assertEquals(rec:position_at_or_beyond(11.4, 2), true)
    lu.assertEquals(rec:position_at_or_beyond(11.4, 3), false)
    lu.assertEquals(rec:position_at_or_beyond(11.4, 4), false)

    lu.assertEquals(rec:position_at_or_beyond(10.0, 1), true)
    lu.assertEquals(rec:position_at_or_beyond(10.0, 2), true)
    lu.assertEquals(rec:position_at_or_beyond(10.0, 3), false)
    lu.assertEquals(rec:position_at_or_beyond(10.0, 4), false)

    lu.assertEquals(rec:position_at_or_beyond(p_10_1, 1), true)
    lu.assertEquals(rec:position_at_or_beyond(p_10_1, 2), true)
    lu.assertEquals(rec:position_at_or_beyond(p_10_1, 3), true)
    lu.assertEquals(rec:position_at_or_beyond(p_10_1, 4), false)

    lu.assertEquals(rec:position_at_or_beyond(10.2, 1), true)
    lu.assertEquals(rec:position_at_or_beyond(10.2, 2), true)
    lu.assertEquals(rec:position_at_or_beyond(10.2, 3), true)
    lu.assertEquals(rec:position_at_or_beyond(10.2, 4), false)
end

function test_beyond_end_no_loop()
    local mseq = MidiSeq.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, mseq)

    -- Put some dummy data into the note data sequence

    mseq:append({}, 1000.0)    -- 1, position 10.0
    mseq:append({}, 1000.3)    -- 2, position 10.3
    mseq:append({}, 1000.7)    -- 3, position 10.7
    mseq:append({}, 1001.1)    -- 4, position 11.1

    -- Due to precision errors we'll set up some variables which represent
    -- the actual position of various clock times which are at
    -- particular MIDI events.

    local p_10_0 = rec:position(1)    -- Represents position 10.0
    local p_10_3 = rec:position(2)    -- Represents position 10.3
    local p_11_1 = rec:position(4)    -- Represents position 11.0

    -- Test certain positions

    lu.assertEquals(rec:beyond_end(9.5), true)
    lu.assertEquals(rec:beyond_end(p_10_0), false)
    lu.assertEquals(rec:beyond_end(p_10_3), false)
    lu.assertEquals(rec:beyond_end(10.5), false)
    lu.assertEquals(rec:beyond_end(p_11_1), false)
    lu.assertEquals(rec:beyond_end(11.5), true)
    lu.assertEquals(rec:beyond_end(12.0), true)
    lu.assertEquals(rec:beyond_end(12.5), true)

    -- Delete the first MIDI event and test again

    mseq:delete_from_front()

    lu.assertEquals(rec:beyond_end(9.5), true)
    lu.assertEquals(rec:beyond_end(p_10_0), true)
    lu.assertEquals(rec:beyond_end(p_10_3), false)
    lu.assertEquals(rec:beyond_end(10.5), false)
    lu.assertEquals(rec:beyond_end(p_11_1), false)
    lu.assertEquals(rec:beyond_end(11.5), true)
    lu.assertEquals(rec:beyond_end(12.0), true)
    lu.assertEquals(rec:beyond_end(12.5), true)
end

function test_beyond_end_with_loop()
    local mseq = MidiSeq.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, mseq)

    -- Put some dummy data into the note data sequence

    mseq:append({}, 1000.0)
    mseq:append({}, 1000.3)
    mseq:append({}, 1000.7)    -- 1, position 10.7 after cutting
    mseq:append({}, 1001.1)    -- 2, position 11.1
    mseq:append({}, 1001.8)    -- 3, position 11.8
    mseq:append({}, 1002.2)    -- 4, position 10.2

    mseq:delete_from_front()
    mseq:delete_from_front()
    rec:cut()

    -- Recording now runs from positions 10.7 to 10.2

    -- Due to precision errors we'll set up some variables which represent
    -- the actual position of various clock times which are at
    -- particular MIDI events.

    local p_10_7 = rec:position(1)    -- Represents position 10.7
    local p_10_2 = rec:position(4)    -- Represents position 10.2

    -- Test certain positions

    lu.assertEquals(rec:beyond_end(9.5), false)
    lu.assertEquals(rec:beyond_end(10.1), false)
    lu.assertEquals(rec:beyond_end(p_10_2), false)
    lu.assertEquals(rec:beyond_end(10.5), true)
    lu.assertEquals(rec:beyond_end(p_10_7), false)
    lu.assertEquals(rec:beyond_end(11.5), false)
    lu.assertEquals(rec:beyond_end(12.5), false)
end

function test_relative_time()
    local mseq = MidiSeq.new(dummy_time)

    -- Our recording loop runs from positions 10 to 12 in the buffer
    local rec = recording.new(10, 2, mseq)

    -- Put some dummy data into the note data sequence

    mseq:append({}, 1000.0)
    mseq:append({}, 1000.3)
    mseq:append({}, 1000.7)    -- 1, position 10.7 after cutting
    mseq:append({}, 1001.1)    -- 2, position 11.1
    mseq:append({}, 1001.8)    -- 3, position 11.8
    mseq:append({}, 1002.2)    -- 4, position 10.2

    mseq:delete_from_front()
    mseq:delete_from_front()
    rec:cut()

    -- Recording now runs from positions 10.7 to 10.2

    -- Test the relative time of certain positions which don't loop

    lu.assertAlmostEquals(rec:relative_time(1, 10.7), 0.00, 0.001)
    lu.assertAlmostEquals(rec:relative_time(1, 10.8), 0.25, 0.001)
    lu.assertAlmostEquals(rec:relative_time(1, 11.1), 1.00, 0.001)

    lu.assertAlmostEquals(rec:relative_time(2, 11.1), 0.0, 0.001)
    lu.assertAlmostEquals(rec:relative_time(2, 11.2), 1/7, 0.001)
    lu.assertAlmostEquals(rec:relative_time(2, 11.5), 4/7, 0.001)
    lu.assertAlmostEquals(rec:relative_time(2, 11.8), 1.0, 0.001)

    -- This now involves a loop

    lu.assertAlmostEquals(rec:relative_time(3, 11.8), 0.00, 0.001)
    lu.assertAlmostEquals(rec:relative_time(3, 11.9), 0.25, 0.001)
    lu.assertAlmostEquals(rec:relative_time(3, 12.0), 0.50, 0.001)
    lu.assertAlmostEquals(rec:relative_time(3, 10.0), 0.50, 0.001)
    lu.assertAlmostEquals(rec:relative_time(3, 10.1), 0.75, 0.001)
    lu.assertAlmostEquals(rec:relative_time(3, 10.2), 1.00, 0.001)
end
