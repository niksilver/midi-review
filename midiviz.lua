-- Midiviz
--
-- Visualisation of MIDI keys

-- Our MIDI device

m = midi.connect()

-- Map from MIDI note to true (if it's on)

note_nums = {}

function init()
    print("In the init function 2")
end

-- Display something on the screen.
--
function redraw()
    screen.clear()
    screen.level(15)
    screen.line_width(1)

    -- Draw all the notes as vertical lines
    
    local drawn = false
    for note, _ in pairs(note_nums) do
        screen.move(note, 0)
        screen.line(note, 63)
        screen.stroke()
        drawn = true
    end
    if not drawn then
        screen.move(40, 40)
        screen.text("Waiting")
    end

    screen.update()
end

-- Capture current MIDI data
--
m.event = function(data)
    local msg = midi.to_msg(data)
    if msg.type == "note_on" then
        note_nums[msg.note] = true
    elseif msg.type == "note_off" then
        note_nums[msg.note] = nil
    end
    redraw()
end
