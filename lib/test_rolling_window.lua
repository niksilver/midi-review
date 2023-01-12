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

function test_text()
    local window = rw.new({
        10,
        20,
        60,
        62,
        120,
        130,
        5 * 60,
        5 * 60 + 22,
        5 * 60 + 28,
    })

    lu.assertEquals(window:text(), "10 sec")
    window:delta(1)
    lu.assertEquals(window:text(), "20 sec")
    window:delta(1)
    lu.assertEquals(window:text(), "1 min")
    window:delta(1)
    lu.assertEquals(window:text(), "1 min 2 sec")
    window:delta(1)
    lu.assertEquals(window:text(), "2 min")
    window:delta(1)
    lu.assertEquals(window:text(), "about 2 min 10 sec")
    window:delta(1)
    lu.assertEquals(window:text(), "about 5 min")
    window:delta(1)
    lu.assertEquals(window:text(), "about 5 min 20 sec")
    window:delta(1)
    lu.assertEquals(window:text(), "about 5 min 30 sec")
end

function test_text_list()
    local window = rw.new({
        20,
        60,
        130,
    })

    lu.assertEquals(window:text_list(), {"20 sec", "1 min", "about 2 min 10 sec"})
end

function test_max_text_length()
    local window = rw.new({
        10,
        20,
        60,
        130,
        62,
        120,
    })

    local charsfn = function(t) return #t end
    local constfn = function(t) return 99 end

    lu.assertEquals(window:max_text_length(charsfn), #"about 2 min 10 sec")
    lu.assertEquals(window:max_text_length(constfn), 99)
end
