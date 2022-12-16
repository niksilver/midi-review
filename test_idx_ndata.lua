lu = require('luaunit')

idx_ndata = require('idx_ndata')

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
    local nd = idx_ndata.new(os.clock)

    local time = nd.timefn()
    nd:append({[11] = 111, [22] = 112})
    lu.assertEquals(nd:get(1).note_vel, {[11] = 111, [22] = 112})
    lu.assertAlmostEquals(nd:get(1).time, time, 0.1)

    time = nd.timefn()
    nd:append({[33] = 113, [44] = 114})
    lu.assertEquals(nd:get(2).note_vel, {[33] = 113, [44] = 114})
    lu.assertAlmostEquals(nd:get(2).time, time, 0.1)
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

-- To do:
-- - Can get first data correctly

os.exit(lu.LuaUnit.run())
