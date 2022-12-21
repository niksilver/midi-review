lu = require('luaunit')
MidiSeq = require('midi_sequence')

function dummy_time()
    lu.fail("dummy_time() should not have been called")
end

function test_count_normally()
    local mseq = MidiSeq.new(os.clock)

    -- Length of a new map should be zero
    lu.assertEquals(mseq:length(), 0)

    -- Appending data should increment the length
    mseq:append({[1] = 1})
    lu.assertEquals(mseq:length(), 1)
    mseq:append({[2] = 2})
    lu.assertEquals(mseq:length(), 2)
end

function test_retrieve_data_and_time()
    local ticktock = 11
    local timefn = function()
        ticktock = ticktock + 0.5
        return ticktock
    end
    local mseq = MidiSeq.new(timefn)

    mseq:append({[11] = 111, [22] = 112})
    lu.assertEquals(mseq:get(1).note_vel, {[11] = 111, [22] = 112})
    lu.assertEquals(mseq:note_vel(1),     {[11] = 111, [22] = 112})
    lu.assertEquals(mseq:get(1).time, 11.5)
    lu.assertEquals(mseq:time(1),     11.5)

    mseq:append({[33] = 113, [44] = 114})
    lu.assertEquals(mseq:get(2).note_vel, {[33] = 113, [44] = 114})
    lu.assertEquals(mseq:note_vel(2),     {[33] = 113, [44] = 114})
    lu.assertEquals(mseq:get(2).time, 12.0)
    lu.assertEquals(mseq:time(2),     12.0)

    -- Now try appending using an explicit time

    mseq:append({[55] = 115, [66] = 116}, 99.9)
    lu.assertEquals(mseq:get(3).note_vel, {[55] = 115, [66] = 116})
    lu.assertEquals(mseq:note_vel(3),     {[55] = 115, [66] = 116})
    lu.assertEquals(mseq:get(3).time, 99.9)
    lu.assertEquals(mseq:time(3),     99.9)
end

function test_append_copies_data()
    local mseq = MidiSeq.new(os.clock)
    nv = {[11] = 111, [22] = 112}

    mseq:append(nv)
    nv[33] = 113
    lu.assertEquals(mseq:get(1).note_vel, {[11] = 111, [22] = 112})
    lu.assertEquals(mseq:note_vel(1),     {[11] = 111, [22] = 112})
end

function test_can_delete_from_front()
    local mseq = MidiSeq.new(os.clock)

    lu.assertEquals(mseq:length(), 0)

    -- Start appending items

    mseq:append({[11] = 101})
    lu.assertEquals(mseq:length(), 1)

    mseq:append({[12] = 102})
    lu.assertEquals(mseq:length(), 2)

    mseq:append({[13] = 103})
    lu.assertEquals(mseq:length(), 3)

    mseq:append({[14] = 104})
    lu.assertEquals(mseq:length(), 4)

    -- Start deleting items

    mseq:delete_from_front()
    lu.assertEquals(mseq:length(), 3)
    lu.assertNil(mseq:get(1))

    mseq:delete_from_front()
    lu.assertEquals(mseq:length(), 2)
    lu.assertNil(mseq:get(2))

    mseq:delete_from_front()
    lu.assertEquals(mseq:length(), 1)
    lu.assertNil(mseq:get(3))

    -- Can continue to append

    mseq:append({[15] = 105})
    lu.assertEquals(mseq:length(), 2)

    mseq:append({[16] = 106})
    lu.assertEquals(mseq:length(), 3)

    -- We can retrieve what we expect

    lu.assertEquals(mseq:get(4).note_vel, {[14] = 104})
    lu.assertEquals(mseq:get(5).note_vel, {[15] = 105})
    lu.assertEquals(mseq:get(6).note_vel, {[16] = 106})

    -- Deleting all remaining items gives zero length

    mseq:delete_from_front()
    mseq:delete_from_front()
    mseq:delete_from_front()
    lu.assertEquals(mseq:length(), 0)
end

function test_indices_update_correctly_as_we_append_and_delete()
    local mseq = MidiSeq.new(os.clock)

    lu.assertEquals(mseq:length(), 0)
    lu.assertNil(mseq.first_index)
    lu.assertNil(mseq.last_index)

    -- Start appending items

    mseq:append({[21] = 101})
    lu.assertEquals(mseq:get(mseq.first_index).note_vel, {[21] = 101})
    lu.assertEquals(mseq:get(mseq.last_index).note_vel,  {[21] = 101})

    mseq:append({[22] = 102})
    lu.assertEquals(mseq:get(mseq.first_index).note_vel, {[21] = 101})
    lu.assertEquals(mseq:get(mseq.last_index).note_vel,  {[22] = 102})

    mseq:append({[23] = 103})
    lu.assertEquals(mseq:get(mseq.first_index).note_vel, {[21] = 101})
    lu.assertEquals(mseq:get(mseq.last_index).note_vel,  {[23] = 103})

    mseq:append({[24] = 104})
    lu.assertEquals(mseq:get(mseq.first_index).note_vel, {[21] = 101})
    lu.assertEquals(mseq:get(mseq.last_index).note_vel,  {[24] = 104})

    -- Start deleting items

    mseq:delete_from_front()
    lu.assertEquals(mseq:get(mseq.first_index).note_vel, {[22] = 102})
    lu.assertEquals(mseq:get(mseq.last_index).note_vel,  {[24] = 104})

    mseq:delete_from_front()
    lu.assertEquals(mseq:get(mseq.first_index).note_vel, {[23] = 103})
    lu.assertEquals(mseq:get(mseq.last_index).note_vel,  {[24] = 104})

    mseq:delete_from_front()
    lu.assertEquals(mseq:get(mseq.first_index).note_vel, {[24] = 104})
    lu.assertEquals(mseq:get(mseq.last_index).note_vel,  {[24] = 104})

    mseq:delete_from_front()
    lu.assertNil(mseq.first_index)
    lu.assertNil(mseq.last_index)
end

function test_time1_as_we_append_and_delete()
    local mseq = MidiSeq.new(os.clock)

    lu.assertNil(mseq.time1)

    -- Start appending items starting at clock time 1000.1

    mseq:append({}, 1000.1)
    lu.assertAlmostEquals(mseq.time1, 1000.1, 0.001)

    mseq:append({}, 1000.2)
    lu.assertAlmostEquals(mseq.time1, 1000.1, 0.001)

    mseq:append({}, 1000.5)
    lu.assertAlmostEquals(mseq.time1, 1000.1, 0.001)

    mseq:append({}, 1000.6)
    lu.assertAlmostEquals(mseq.time1, 1000.1, 0.001)

    -- Start deleting items

    mseq:delete_from_front()
    lu.assertAlmostEquals(mseq.time1, 1000.1, 0.001)

    mseq:delete_from_front()
    lu.assertAlmostEquals(mseq.time1, 1000.1, 0.001)

    mseq:delete_from_front()
    lu.assertAlmostEquals(mseq.time1, 1000.1, 0.001)

    mseq:delete_from_front()
    lu.assertNil(mseq.time1)
end

function test_reindex()
    local mseq = MidiSeq.new(os.clock)

    -- Append and delete items

    mseq:append({[31] = 71})
    mseq:append({[32] = 72})
    mseq:append({[33] = 73})
    mseq:append({[34] = 74})
    mseq:append({[35] = 75})
    mseq:append({[36] = 76})
    mseq:delete_from_front()
    mseq:delete_from_front()
    lu.assertEquals(mseq:length(), 4)

    local offset = mseq:reindex()

    lu.assertEquals(offset, 2)

    lu.assertEquals(mseq:length(), 4)
    lu.assertEquals(mseq.first_index, 1)
    lu.assertEquals(mseq.last_index, 4)
    lu.assertEquals(mseq:get(1).note_vel, {[33] = 73})
    lu.assertEquals(mseq:get(2).note_vel, {[34] = 74})
    lu.assertEquals(mseq:get(3).note_vel, {[35] = 75})
    lu.assertEquals(mseq:get(4).note_vel, {[36] = 76})
end

function test_reindex_empty_sequence()
    local mseq = MidiSeq.new(os.clock)

    local offset = mseq:reindex()

    lu.assertEquals(offset, 0)

    lu.assertEquals(mseq:length(), 0)
    lu.assertNil(mseq.first_index)
    lu.assertNil(mseq.last_index)
end

function test_time1_after_reindex()
    local mseq = MidiSeq.new(dummy_time)

    lu.assertNil(mseq.time1)

    -- Append items starting at clock time 1000.1

    mseq:append({}, 1000.1)
    mseq:append({}, 1000.2)
    mseq:append({}, 1000.5)
    mseq:append({}, 1000.6)
    lu.assertAlmostEquals(mseq.time1, 1000.1, 0.001)

    -- Delete a couple

    mseq:delete_from_front()
    lu.assertAlmostEquals(mseq.time1, 1000.1, 0.001)

    mseq:delete_from_front()
    lu.assertAlmostEquals(mseq.time1, 1000.1, 0.001)

    -- Reindex and check time1 has updated

    mseq:reindex()
    lu.assertAlmostEquals(mseq.time1, 1000.5, 0.001)
end
