-- Midiviz
--
-- Visualisation of MIDI keys

-- Our MIDI device

m = midi.connect()

-- Last MIDI note number

note_num = nil

function init()
    print("In the init function 2")
end

-- Display something on the screen.
--
function redraw()
    screen.clear()
    screen.move(0, 40)
    screen.level(15)
    screen.text("Note: " .. (note_num or "-"))
    screen.update()
end

-- Capture current MIDI data
--
m.event = function(data)
    local msg = midi.to_msg(data)
    if msg.type == "note_on" then
        note_num = msg.note
    end
    redraw()
end
