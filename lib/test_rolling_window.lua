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

function test_delta()
    local window = rw.new({ 11, 22, 33 }, 1)

    lu.assertEquals(window:size(), 11)

    -- As we add one to the index we should go through the sizes,
    -- but not go beyond the end of the array.

    window:delta(1)
    lu.assertEquals(window:size(), 22)
    window:delta(1)
    lu.assertEquals(window:size(), 33)
    window:delta(1)
    lu.assertEquals(window:size(), 33)

    -- And as we add -1 to the index we should go back through the sizes,
    -- but not go beyond the start of the array.

    window:delta(-1)
    lu.assertEquals(window:size(), 22)
    window:delta(-1)
    lu.assertEquals(window:size(), 11)
    window:delta(-1)
    lu.assertEquals(window:size(), 11)
end
