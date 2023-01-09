-- A finite state machine specifically for the state of our transport.
--

local FSM = require('fsm')

local C = {}

function C.new()
    return FSM.create({
        initial = "stop",
        events = {
            { name = "k2", from = "stop", to = "play" },
            { name = "k2_long_press", from = "stop", to = "record" },
        },
    })
end

return C
