-- midiviz
--
-- Visualisation of MIDI key presses.
--
-- k2 = play/stop
-- k2 long press (1 sec) = record
-- e2 = scroll through time

musicutil = require('musicutil')

-- Current status, including
-- when k2 was pressed down (for long press);
-- what the last MIDI event was.

STOP = 0
PLAY = 1
RECORD = 2

NO_EVENT = 10
NOTE_EVENT = 11
TRANSPORT_EVENT = 12

status = {
    mode = STOP,
    k2_down = nil,
    last_event = NO_EVENT,
}

LONG_PRESS_SECS = 1.0  -- Length of a long press, in seconds

-- The metronome for playing back notes; nil means stopped.

player = nil

-- Our MIDI device

midi_device = midi.connect()

-- Tracking notes.
-- note_vel - Map from note value to velocity of all notes currently held
-- idx_ndata - Map from note count (starting at 1) to a table of note data:
--     - time - time in milliseconds.
--     - note_vel - a note-velocity table as above.
-- idx - Current index where there's note data, or 0.

function init_note_data()
    note_vel = {}
    idx_ndata = {}
    idx = 0
end
init_note_data()

TIMELINE_WIDTH = 118

-- (Re)draw the screen
--
function redraw()
    screen.clear()
    screen.line_width(1)

    -- Draw the timeline at the top, plus the note notches and
    -- where we are now.

    screen.level(2)
    screen.move(0, 2)
    screen.line(TIMELINE_WIDTH, 2)
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

    -- Show the current mode

    screen.level(15)
    screen.move(122, 5)
    if status.mode == PLAY then
        screen.text(">")
    elseif status.mode == RECORD then
        screen.text("R")
    else
        screen.text("-")
    end

    -- From our current idx, draw all the notes as vertical lines.
    -- We'll also save the notes to display the names.
    
    screen.level(15)
    if status.last_event ~= NO_EVENT then
        -- We've just had some event, so work out what data we need to display

        local data =
            status.last_event == NOTE_EVENT and note_vel or idx_ndata[idx].note_vel
        local notes = {}

        for note, vel in pairs(data) do
            screen.move(note, 56)
            screen.line_rel(0, -vel * 0.4)
            screen.stroke()

            table.insert(notes, note)
        end

        display_note_names(notes)
    else
        -- We haven't had any events yet

        screen.move(48, 40)
        screen.text("Waiting")
    end

    screen.update()
end

-- Display the notes at the bottom of the screen.
-- @param notes    List of MIDI notes (each is 0-127).
--
function display_note_names(notes)
    -- We need to know the width of each note name and the width
    -- of the gaps between them. The gaps will get resized in
    -- proportion to each other.

    local name = {}        -- name[n] is the name of note number n
    local name_size = {}   -- note_size[n] is the width of note number n
    local gap_size = {}    -- gap_size[n] is the gap just before note number n

    gap_size[1] = 1

    table.sort(notes)
    for i, n in ipairs(notes) do
        local nam = musicutil.note_num_to_name(n)
        name[i] = nam
        name_size[i] = #name * 5
        if i < #notes then
            gap_size[i+1] = notes[i+1] - n
        end
    end

    table.insert(gap_size, 1)

    -- We need to get to:
    -- (all the name sizes) + factor * (all the gap sizes) = 128

    local name_size_sum = 0
    for i, s in pairs(name_size) do
        name_size_sum = name_size_sum + s
    end

    local gap_size_sum = 0
    for i, s in pairs(gap_size) do
        gap_size_sum = gap_size_sum + s
    end

    local factor = (128 - name_size_sum) / gap_size_sum

    local x = 0
    for i, n in ipairs(notes) do
        x = x + gap_size[i] * factor
        screen.move(x, 63)
        screen.text( name[i] )
        x = x + name_size[i]
    end
end

-- Capture current MIDI data
--
midi_device.event = function(data)
    local msg = midi.to_msg(data)

    if msg.type == "note_on" then
        -- If it's note on, add to the current 'on' notes
        note_vel[msg.note] = msg.vel
        if status.mode == RECORD then
            append_ndata(note_vel)
        end
        status.last_event = NOTE_EVENT

    elseif msg.type == "note_off" then
        -- If it's note off, remove from the current 'on' notes
        note_vel[msg.note] = nil
        if status.mode == RECORD then
            append_ndata(note_vel)
        end
        status.last_event = NOTE_EVENT
    end
    redraw()
end

-- Add note data to the end of our current history.
--
function append_ndata()
    local millis = util.time()

    idx = #idx_ndata + 1
    idx_ndata[idx] = {
        time = millis,
        note_vel = shallow_copy(note_vel)
    }
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
    local x = (ndata.time - time_first) / time_diff * TIMELINE_WIDTH + 1
    if time_diff == 0 then x = 1 end

    -- Draw
    screen.level(level)
    screen.move(x, 0)
    screen.line_rel(0, 3)
    screen.stroke()
end

-- Handle key presses
--
function key(n, z)
    local time = util.time()
    if n == 2 then
        if z == 1 then
            -- k2 has gone down; note when
            status.k2_down = time
        else
            -- k2 has gone up...

            if status.k2_down and (time - status.k2_down) >= LONG_PRESS_SECS then
                reset_player()
                init_note_data()
                status.last_event = NO_EVENT
                status.mode = RECORD
            elseif status.mode == STOP then
                status.mode = PLAY
                play_next()
            else
                reset_player()
                status.mode = STOP
            end

            status.k2_down = nil
            redraw()
        end
    end
end

-- Play the next MIDI note (and continue)
--
function play_next()
    -- We should be displaying the current MIDI note, so we need to
    -- stop if at the end, or queue up the next note.

    reset_player()

    if idx == #idx_ndata then
        status.mode = STOP
        redraw()
    else
        local duration = idx_ndata[idx+1].time - idx_ndata[idx].time
        player = metro.init(
            function()
                idx = idx + 1
                redraw()
                play_next()
            end, duration, 1
        )
        player:start()
    end
end

-- Reset/cancel the note player
--
function reset_player()
    if player then
        player:stop()
        metro.free(player.id)
        player = nil
    end
end

-- Encoders:
-- e2 = scroll back and forth through our notes
--
function enc(n, d)
    if n == 2 and #idx_ndata > 0 then
        idx = util.clamp(idx + d, 1, #idx_ndata)
        status.last_event = TRANSPORT_EVENT
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
