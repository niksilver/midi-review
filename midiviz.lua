-- midiviz
--
-- Visualisation of MIDI keys

-- Our MIDI device

midi_device = midi.connect()

-- Map from MIDI note to velocity (if it's on)

note_nums = {}

-- Display something on the screen.
--
function redraw()
    screen.clear()
    screen.level(15)
    screen.line_width(1)

    -- Draw all the notes as vertical lines
    
    local drawn = false
    for note, vel in pairs(note_nums) do
        screen.move(note, 63)
        screen.line(note, 63 - vel/2)
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
midi_device.event = function(data)
    local msg = midi.to_msg(data)
    if msg.type == "note_on" then
        note_nums[msg.note] = msg.vel
    elseif msg.type == "note_off" then
        note_nums[msg.note] = nil
    end
    redraw()
end
