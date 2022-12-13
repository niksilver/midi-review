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

-- The metronome for playing back note data; nil means stopped.

ndata_player = nil

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

-- The recording voice (head) and buffer for softcut

SC_VOICE = 1
SC_BUFFER = 1
SC_BUFFER_START = 1

-- Initialise softcut for recording and playback
--
function init()
    audio.level_adc_cut(1.0)    -- Softcut ADC level

    -- Setup and play parameters for softcut

    softcut.buffer_clear()    -- Clear all buffers
    softcut.enable(SC_VOICE, 1)    -- Enable (1) the voice
    softcut.buffer(SC_VOICE, SC_BUFFER)    -- Link the voice to the buffer
    softcut.level(SC_VOICE, 1.0)    -- Output level for the voice
    softcut.rate(SC_VOICE, 1.0)    -- Playback rate for the voice
    softcut.loop(SC_VOICE, 0)    -- No looping on the voice (0 = off)
    softcut.position(SC_VOICE, 1)    -- Play position at the start
    softcut.play(SC_VOICE, 0)    -- Don't play the voice yet (0 = off)

    -- Even though we're not looping we need to say where the voice runs.
    -- We'll have 5 minutes of audio.

    softcut.loop_start(SC_VOICE, SC_BUFFER_START)
    softcut.loop_end(SC_VOICE, SC_BUFFER_START + 5 * 60)

    -- Record paramaters

    softcut.level_input_cut(1, SC_VOICE, 1.0)    -- Input level of channel 1
    softcut.level_input_cut(2, SC_VOICE, 1.0)    -- Input level of channel 2
    softcut.rec_level(SC_VOICE, 1.0)    -- Record level for the voice
    softcut.pre_level(SC_VOICE, 0.0)    -- Preserve level for the voice
    softcut.rec(SC_VOICE, 0)    -- Don't record to the voice yet (0 = off)
end

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
            screen.line_rel(0, math.min(-vel * 0.4, -1))
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
    if #notes == 0 then
        return
    end

    -- We need to know the width of each note name and the width
    -- of the gaps between them. The gaps will get resized in
    -- proportion to each other.

    local name = {}        -- name[n] is the name of note number n
    local name_size = {}   -- note_size[n] is the width of note number n
    local gap_size = {}    -- gap_size[n] is the gap after note number n

    table.sort(notes)
    for i, n in ipairs(notes) do
        local nnam = musicutil.note_num_to_name(n)
        name[i] = nnam
        name_size[i] = #nnam * 5
        if i < #notes then
            gap_size[i] = notes[i+1] - n
        end
    end

    -- We need to get to:
    --
    -- (total end gap) + (all the name sizes) + factor * (all the gap sizes) = 128
    --
    -- where factor is the space between two notes that are next to each other
    -- (note distance 1).  We'll decide that the factor is 1.
    -- The total end gap will be split proportionally to how far from
    -- the end the lowest and highest notes are.

    local name_size_sum = 0
    for i, s in pairs(name_size) do
        name_size_sum = name_size_sum + s
    end

    local gap_size_sum = 0
    for i, s in pairs(gap_size) do
        gap_size_sum = gap_size_sum + s
    end

    local factor = 1
    local total_end_gap = 128 - name_size_sum - factor * gap_size_sum
    local front_end_gap = total_end_gap * notes[1] / (128 - notes[#notes] + notes[1])

    -- If we've got a negative end gap then for get the end gap and
    -- recalculate our factor:
    --
    -- (all the name sizes) + factor * (all the gap sizes) = 128

    if total_end_gap < 0 then
        factor = (128 - name_size_sum) / gap_size_sum
        front_end_gap = 0
    end

    -- Write all the note names

    local x = front_end_gap
    for i, n in ipairs(notes) do
        screen.move(x, 63)
        screen.text( name[i] )
        if i < #notes then
            x = x + name_size[i] + factor * gap_size[i]
        end
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
            append_ndata()
        end
        status.last_event = NOTE_EVENT

        -- Maybe this is the trigger to start recording audio
        if #idx_ndata == 1 then
            start_recording_audio()
        end

    elseif msg.type == "note_off" then
        -- If it's note off, remove from the current 'on' notes
        note_vel[msg.note] = nil
        if status.mode == RECORD then
            append_ndata()
        end
        status.last_event = NOTE_EVENT
    end
    redraw()
end

-- Add note data (the note_val table) to the end of our current history.
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
                -- Go into record mode.
                -- We don't start writing audio and MIDI data here;
                -- we start when we get the first MIDI note.

                reset_ndata_player()
                init_note_data()
                stop_recording_audio()
                stop_playing_audio()

                status.last_event = NO_EVENT
                status.mode = RECORD

            elseif status.mode == STOP then
                -- Short press - go into play mode

                stop_recording_audio()

                status.mode = PLAY
                play_next_ndata()
                start_playing_audio()
            else
                -- Short press - go into stop mode

                -- If we were recording, record final empty note data
                -- and stop audio recording
                if status.mode == RECORD then
                    note_vel = {}
                    append_ndata()
                    stop_recording_audio()
                end

                reset_ndata_player()
                stop_playing_audio()
                status.mode = STOP
            end

            status.k2_down = nil
            redraw()
        end
    end
end

-- Play the next MIDI note data (and continue)
--
function play_next_ndata()
    -- We should be displaying the current MIDI note, so we need to
    -- stop if at the end, or queue up the next note.

    reset_ndata_player()

    if idx == #idx_ndata then
        -- End of the note data

        stop_playing_audio()
        status.mode = STOP
        redraw()
    else
        local duration = idx_ndata[idx+1].time - idx_ndata[idx].time
        ndata_player = metro.init(
            function()
                idx = idx + 1
                redraw()
                play_next_ndata()
            end, duration, 1
        )
        ndata_player:start()
    end
end

-- Reset/cancel the note data player
--
function reset_ndata_player()
    if ndata_player then
        ndata_player:stop()
        metro.free(ndata_player.id)
        ndata_player = nil
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

-- Start recording audio
--
function start_recording_audio()
    softcut.buffer_clear()    -- Clear all the buffers
    softcut.position(SC_VOICE, 1)    -- Play position at the start
    softcut.rec(SC_VOICE, 1)    -- Start recording (1 = on)
end

-- Stop recording audio
--
function stop_recording_audio()
    softcut.rec(SC_VOICE, 0)    -- Stop recording (0 = off)
end

-- Stop playing audio
--
function stop_playing_audio()
    softcut.play(SC_VOICE, 0)    -- Stop playing (0 = off)
end

-- Start playing audio from the point of where we are in the note data
--
function start_playing_audio()
    local position = SC_BUFFER_START
    if idx > 0 then
        position = SC_BUFFER_START + (idx_ndata[idx].time - idx_ndata[1].time)
    end

    softcut.position(SC_VOICE, position)
    softcut.play(SC_VOICE, 1)    -- Start playing (1 = on)
end

