lu = require('luaunit')
Mode = require('transport_mode')

function test_initial_mode()
    local mode = Mode.new()

    -- Initial mode should be the stop mode
    lu.assertEquals(mode.is('stop'), true)
end

function test_valid_events_from_stop()
    local mode

    -- Stop -> k2 -> Play
    mode = Mode.new()
    mode.k2()
    lu.assertEquals(mode.is('play'), true)

    -- Stop -> k2 long press -> Record
    mode = Mode.new()
    mode.k2_long_press()
    lu.assertEquals(mode.is('record'), true)
end

function test_valid_events_from_play()
    local mode

    -- Play -> k2 -> Stop
    mode = Mode.new()
    mode.k2()
    lu.assertEquals(mode.is('play'), true)
    mode.k2()
    lu.assertEquals(mode.is('stop'), true)

    -- Play -> k2 long press -> Record
    mode = Mode.new()
    mode.k2()
    lu.assertEquals(mode.is('play'), true)
    mode.k2_long_press()
    lu.assertEquals(mode.is('record'), true)
end
