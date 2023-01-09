lu = require('luaunit')
State = require('transport_mode')

function test_initial_state()
    local state = State.new()

    -- Initial state should be the stop state
    lu.assertEquals(state.is('stop'), true)
end

function test_valid_events_from_stop()
    local state

    -- Stop -> k2 -> Play
    state = State.new()
    state.k2()
    lu.assertEquals(state.is('play'), true)

    -- Stop -> k2 long press -> Record
    state = State.new()
    state.k2_long_press()
    lu.assertEquals(state.is('record'), true)
end

function test_valid_events_from_play()
    local state

    -- Play -> k2 -> Stop
    state = State.new()
    state.k2()
    lu.assertEquals(state.is('play'), true)
    state.k2()
    lu.assertEquals(state.is('stop'), true)

    -- Play -> k2 long press -> Record
    state = State.new()
    state.k2()
    lu.assertEquals(state.is('play'), true)
    state.k2_long_press()
    lu.assertEquals(state.is('record'), true)
end
