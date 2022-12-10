-- midiviz
--
-- Visualisation of MIDI keys.
--
-- e1 = scroll through time

-- Our MIDI device

midi_device = midi.connect()

-- Tracking notes.
-- note_vel - Map from note value to velocity of all notes currently held
-- idx_ndata - Map from note count (starting at 1) to a table of note data:
--     - time - time in milliseconds.
--     - note_vel - a note-velocity table as above.
-- idx - Current index where there's note data, or 0.

note_vel = {}
idx_ndata = {}
idx = 0

-- Display something on the screen.
--
function redraw()
    screen.clear()
    screen.level(15)
    screen.line_width(1)

    -- Draw all the notes as vertical lines.
    -- Draw the notes from our current idx.
    
    local drawn = false
    if idx > 0 then
        for note, vel in pairs(idx_ndata[idx].note_vel) do
            screen.move(note, 63)
            screen.line(note, 63 - vel/2)
            screen.stroke()
            drawn = true
        end
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
    local millis = os.clock()

    if msg.type == "note_on" then
        -- If it's note on, add to the current 'on' notes
        note_vel[msg.note] = msg.vel
        idx = #idx_ndata + 1
        idx_ndata[idx] = {
            time = millis,
            note_vel = shallow_copy(note_vel)
        }

    elseif msg.type == "note_off" then
        -- If it's note off, remove from the current 'on' notes
        note_vel[msg.note] = nil
        idx = #idx_ndata + 1
        idx_ndata[idx] = {
            time = millis,
            note_vel = shallow_copy(note_vel)
        }
    end
    redraw()
end

-- Encoders:
-- k1 - scroll back and forth through our notes
--
function enc(n, d)
    if n == 1 and #idx_ndata > 0 then
        idx = clamp(idx + d, 1, #idx_ndata)
        redraw()
    end
end

-- Return a shallow copy of a table
--
function shallow_copy(tab)
    local copy = {}
    for k, v in pairs(tab) do
        copy[k] = v
    end
    return copy
end

function clamp(n, lo, hi)
    if n < lo then
        return lo
    elseif hi < n then
        return hi
    end
    return n
end
