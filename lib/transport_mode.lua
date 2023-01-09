-- A finite state machine specifically for the state of our transport.
--

local FSM = require('fsm')

local C = {}

function C.new()
    return FSM.create({
        initial = "stop",
        events = {
            { name = "k1", from = "stop", to = "play" },
        },
    })
end

return C
