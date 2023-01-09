lu = require('luaunit')
State = require('transport_mode')

function test_initial_state()
    local state = State.new()

    -- Initial state should be the stop state
    lu.assertEquals(state.is('stop'), true)
end


function test_valid_events_from_stop()
    local state

    -- Stop -> k1
    state = State.new()
    state.k1()
    lu.assertEquals(state.is('play'), true)
end
