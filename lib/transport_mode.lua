-- A finite state machine specifically for the state of our transport.
--

local FSM = require('fsm')

local C = {}

function C.new()
    return FSM.create({
        initial = "stop",
        events = {
            { from = "stop", name = "k2",            to = "play" },
            { from = "stop", name = "k2_long_press", to = "record" },
            { from = "stop", name = "move_head" },

            { from = "play", name = "k2",            to = "stop" },
            { from = "play", name = "k2_long_press", to = "record" },
            { from = "play", name = "move_head",     to = "play" },

            { from = "record", name = "k2",            to = "stop" },
            { from = "record", name = "k2_long_press", to = "record" },
            { from = "record", name = "move_head",     to = "stop" },
        },
    })
end

return C
