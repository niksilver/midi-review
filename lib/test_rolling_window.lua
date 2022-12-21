lu = require('luaunit')
rw = require('rolling_window')

function test_new()
    local window = rw.new({ 11, 22, 33 }, 1)

    lu.assertEquals(window.current_index, 1)

    -- And again, with a different initial index...

    window = rw.new({ 11, 22, 33 }, 2)

    lu.assertEquals(window.current_index, 2)

    -- And just for safety, with no index...

    window = rw.new({ 11, 22, 33 })

    lu.assertEquals(window.current_index, 1)
end

function test_size()
    local window = rw.new({ 11, 22, 33 }, 1)

    lu.assertEquals(window:size(), 11)

    -- And again, with a different initial index...

    window = rw.new({ 11, 22, 33 }, 2)

    lu.assertEquals(window:size(), 22)

    -- And if we start with no index it should default to the first

    window = rw.new({ 11, 22, 33 })

    lu.assertEquals(window:size(), 11)
end
