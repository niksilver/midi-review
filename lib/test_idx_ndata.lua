lu = require('luaunit')
idx_ndata = require('idx_ndata')

function dummy_time()
    lu.fail("dummy_time() should not have been called")
end

function test_count_normally()
    local nd = idx_ndata.new(os.clock)

    -- Length of a new map should be zero
    lu.assertEquals(nd:length(), 0)

    -- Appending data should increment the length
    nd:append({[1] = 1})
    lu.assertEquals(nd:length(), 1)
    nd:append({[2] = 2})
    lu.assertEquals(nd:length(), 2)
end

function test_retrieve_data_and_time()
    local ticktock = 11
    local timefn = function()
        ticktock = ticktock + 0.5
        return ticktock
    end
    local nd = idx_ndata.new(timefn)

    nd:append({[11] = 111, [22] = 112})
    lu.assertEquals(nd:get(1).note_vel, {[11] = 111, [22] = 112})
    lu.assertEquals(nd:note_vel(1),     {[11] = 111, [22] = 112})
    lu.assertEquals(nd:get(1).time, 11.5)
    lu.assertEquals(nd:time(1),     11.5)

    nd:append({[33] = 113, [44] = 114})
    lu.assertEquals(nd:get(2).note_vel, {[33] = 113, [44] = 114})
    lu.assertEquals(nd:note_vel(2),     {[33] = 113, [44] = 114})
    lu.assertEquals(nd:get(2).time, 12.0)
    lu.assertEquals(nd:time(2),     12.0)

    -- Now try appending using an explicit time

    nd:append({[55] = 115, [66] = 116}, 99.9)
    lu.assertEquals(nd:get(3).note_vel, {[55] = 115, [66] = 116})
    lu.assertEquals(nd:note_vel(3),     {[55] = 115, [66] = 116})
    lu.assertEquals(nd:get(3).time, 99.9)
    lu.assertEquals(nd:time(3),     99.9)
end

function test_append_copies_data()
    local nd = idx_ndata.new(os.clock)
    nv = {[11] = 111, [22] = 112}

    nd:append(nv)
    nv[33] = 113
    lu.assertEquals(nd:get(1).note_vel, {[11] = 111, [22] = 112})
    lu.assertEquals(nd:note_vel(1),     {[11] = 111, [22] = 112})
end

function test_can_delete_from_front()
    local nd = idx_ndata.new(os.clock)

    lu.assertEquals(nd:length(), 0)

    -- Start appending items

    nd:append({[11] = 101})
    lu.assertEquals(nd:length(), 1)

    nd:append({[12] = 102})
    lu.assertEquals(nd:length(), 2)

    nd:append({[13] = 103})
    lu.assertEquals(nd:length(), 3)

    nd:append({[14] = 104})
    lu.assertEquals(nd:length(), 4)

    -- Start deleting items

    nd:delete_from_front()
    lu.assertEquals(nd:length(), 3)
    lu.assertNil(nd:get(1))

    nd:delete_from_front()
    lu.assertEquals(nd:length(), 2)
    lu.assertNil(nd:get(2))

    nd:delete_from_front()
    lu.assertEquals(nd:length(), 1)
    lu.assertNil(nd:get(3))

    -- Can continue to append

    nd:append({[15] = 105})
    lu.assertEquals(nd:length(), 2)

    nd:append({[16] = 106})
    lu.assertEquals(nd:length(), 3)

    -- We can retrieve what we expect

    lu.assertEquals(nd:get(4).note_vel, {[14] = 104})
    lu.assertEquals(nd:get(5).note_vel, {[15] = 105})
    lu.assertEquals(nd:get(6).note_vel, {[16] = 106})

    -- Deleting all remaining items gives zero length

    nd:delete_from_front()
    nd:delete_from_front()
    nd:delete_from_front()
    lu.assertEquals(nd:length(), 0)
end

function test_indices_update_correctly_as_we_append_and_delete()
    local nd = idx_ndata.new(os.clock)

    lu.assertEquals(nd:length(), 0)
    lu.assertNil(nd.first_index)
    lu.assertNil(nd.last_index)

    -- Start appending items

    nd:append({[21] = 101})
    lu.assertEquals(nd:get(nd.first_index).note_vel, {[21] = 101})
    lu.assertEquals(nd:get(nd.last_index).note_vel,  {[21] = 101})

    nd:append({[22] = 102})
    lu.assertEquals(nd:get(nd.first_index).note_vel, {[21] = 101})
    lu.assertEquals(nd:get(nd.last_index).note_vel,  {[22] = 102})

    nd:append({[23] = 103})
    lu.assertEquals(nd:get(nd.first_index).note_vel, {[21] = 101})
    lu.assertEquals(nd:get(nd.last_index).note_vel,  {[23] = 103})

    nd:append({[24] = 104})
    lu.assertEquals(nd:get(nd.first_index).note_vel, {[21] = 101})
    lu.assertEquals(nd:get(nd.last_index).note_vel,  {[24] = 104})

    -- Start deleting items

    nd:delete_from_front()
    lu.assertEquals(nd:get(nd.first_index).note_vel, {[22] = 102})
    lu.assertEquals(nd:get(nd.last_index).note_vel,  {[24] = 104})

    nd:delete_from_front()
    lu.assertEquals(nd:get(nd.first_index).note_vel, {[23] = 103})
    lu.assertEquals(nd:get(nd.last_index).note_vel,  {[24] = 104})

    nd:delete_from_front()
    lu.assertEquals(nd:get(nd.first_index).note_vel, {[24] = 104})
    lu.assertEquals(nd:get(nd.last_index).note_vel,  {[24] = 104})

    nd:delete_from_front()
    lu.assertNil(nd.first_index)
    lu.assertNil(nd.last_index)
end

function test_time1_as_we_append_and_delete()
    local nd = idx_ndata.new(os.clock)

    lu.assertNil(nd.time1)

    -- Start appending items starting at clock time 1000.1

    nd:append({}, 1000.1)
    lu.assertAlmostEquals(nd.time1, 1000.1, 0.001)

    nd:append({}, 1000.2)
    lu.assertAlmostEquals(nd.time1, 1000.1, 0.001)

    nd:append({}, 1000.5)
    lu.assertAlmostEquals(nd.time1, 1000.1, 0.001)

    nd:append({}, 1000.6)
    lu.assertAlmostEquals(nd.time1, 1000.1, 0.001)

    -- Start deleting items

    nd:delete_from_front()
    lu.assertAlmostEquals(nd.time1, 1000.1, 0.001)

    nd:delete_from_front()
    lu.assertAlmostEquals(nd.time1, 1000.1, 0.001)

    nd:delete_from_front()
    lu.assertAlmostEquals(nd.time1, 1000.1, 0.001)

    nd:delete_from_front()
    lu.assertNil(nd.time1)
end

function test_reindex()
    local nd = idx_ndata.new(os.clock)

    -- Append and delete items

    nd:append({[31] = 71})
    nd:append({[32] = 72})
    nd:append({[33] = 73})
    nd:append({[34] = 74})
    nd:append({[35] = 75})
    nd:append({[36] = 76})
    nd:delete_from_front()
    nd:delete_from_front()
    lu.assertEquals(nd:length(), 4)

    local offset = nd:reindex()

    lu.assertEquals(offset, 2)

    lu.assertEquals(nd:length(), 4)
    lu.assertEquals(nd.first_index, 1)
    lu.assertEquals(nd.last_index, 4)
    lu.assertEquals(nd:get(1).note_vel, {[33] = 73})
    lu.assertEquals(nd:get(2).note_vel, {[34] = 74})
    lu.assertEquals(nd:get(3).note_vel, {[35] = 75})
    lu.assertEquals(nd:get(4).note_vel, {[36] = 76})
end

function test_reindex_empty_sequence()
    local nd = idx_ndata.new(os.clock)

    local offset = nd:reindex()

    lu.assertEquals(offset, 0)

    lu.assertEquals(nd:length(), 0)
    lu.assertNil(nd.first_index)
    lu.assertNil(nd.last_index)
end

function test_time1_after_reindex()
    local nd = idx_ndata.new(dummy_time)

    lu.assertNil(nd.time1)

    -- Append items starting at clock time 1000.1

    nd:append({}, 1000.1)
    nd:append({}, 1000.2)
    nd:append({}, 1000.5)
    nd:append({}, 1000.6)
    lu.assertAlmostEquals(nd.time1, 1000.1, 0.001)

    -- Delete a couple

    nd:delete_from_front()
    lu.assertAlmostEquals(nd.time1, 1000.1, 0.001)

    nd:delete_from_front()
    lu.assertAlmostEquals(nd.time1, 1000.1, 0.001)

    -- Reindex and check time1 has updated

    nd:reindex()
    lu.assertAlmostEquals(nd.time1, 1000.5, 0.001)
end
