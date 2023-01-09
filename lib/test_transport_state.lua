lu = require('luaunit')
State = require('transport_state')

function test_initial_state()
    local state = State.new()

    -- Initial state should be the stop state
    lu.assertEquals(state.is('stop'), true)
end

