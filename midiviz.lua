-- midiviz
--
-- Visualisation of MIDI key presses.
--
-- k2 = play/stop
-- k2 long press = record
-- e2 = scroll through time

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

-- (Re)draw the screen
--
function redraw()
    screen.clear()
    screen.line_width(1)

    -- Draw the timeline at the top, plus the note notches and
    -- where we are now.

    screen.level(2)
    screen.move(0, 2)
    screen.line(127, 2)
    screen.stroke()
    if idx > 0 then
        -- Draw the notches on the timeline
        for i, _ in pairs(idx_ndata) do
            draw_notch(i, 2)
        end

        -- Draw the current notch. We must do this last to ensure it
        -- shows up over the other notches
        draw_notch(idx, 15)
    end

    -- From our current idx, draw all the notes as vertical lines.
    
    screen.level(15)
    if idx > 0 then
        for note, vel in pairs(idx_ndata[idx].note_vel) do
            screen.move(note, 63)
            screen.line(note, 63 - vel * 0.4)
            screen.stroke()
        end
    end

    if idx == 0 then
        screen.move(48, 40)
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

-- Draw a notch on the timeline
-- @param i    Which notch idx
-- @param level    Screen brightness
--
function draw_notch(i, level)
    -- Get the time difference from first to last note
    local time_first = idx_ndata[1].time
    local time_last = idx_ndata[#idx_ndata].time
    local time_diff = time_last - time_first

    -- Calculate the x position of the notch
    local ndata = idx_ndata[i]
    local x = (ndata.time - time_first) / time_diff * 127 + 1
    if time_diff == 0 then x = 1 end

    -- Draw
    screen.level(level)
    screen.move(x, 0)
    screen.line_rel(0, 3)
    screen.stroke()
end

-- Encoders:
-- e2 = scroll back and forth through our notes
--
function enc(n, d)
    if n == 2 and #idx_ndata > 0 then
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
