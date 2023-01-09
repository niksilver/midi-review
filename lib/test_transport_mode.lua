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
    lu.assertEquals(mode.current, 'play')

    -- Stop -> k2 long press -> Record
    mode = Mode.new()
    mode.k2_long_press()
    lu.assertEquals(mode.current, 'record')
end

function test_valid_events_from_play()
    local mode

    -- Play -> k2 -> Stop
    mode = Mode.new()
    mode.k2()
    lu.assertEquals(mode.current, 'play')
    mode.k2()
    lu.assertEquals(mode.current, 'stop')

    -- Play -> k2 long press -> Record
    mode = Mode.new()
    mode.k2()
    lu.assertEquals(mode.current, 'play')
    mode.k2_long_press()
    lu.assertEquals(mode.current, 'record')
end

function test_valid_events_from_record()
    local mode

    -- Record -> k2 -> Stop
    mode = Mode.new()
    mode.k2_long_press()
    lu.assertEquals(mode.current, 'record')
    mode.k2()
    lu.assertEquals(mode.current, 'stop')

    -- Record -> k2 long press -> Record
    mode = Mode.new()
    mode.k2_long_press()
    lu.assertEquals(mode.current, 'record')
    mode.k2_long_press()
    lu.assertEquals(mode.current, 'record')
end

function test_record_to_record_triggers_actions()
    local mode = Mode.new()

    -- Set up a counter
    local count = 0
    mode.on_record = function()
        count = count + 1
    end

    -- First get us into record mode
    mode.k2_long_press()
    lu.assertEquals(mode.current, 'record')
    lu.assertEquals(count, 1)

    -- Now go into record mode again
    mode.k2_long_press()
    lu.assertEquals(mode.current, 'record')
    lu.assertEquals(count, 2)
end
