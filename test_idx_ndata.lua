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

os.exit(lu.LuaUnit.run())
