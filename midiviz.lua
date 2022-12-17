-- midiviz
--
-- Visualisation of MIDI key presses.
--
-- k2 = play/stop
-- k2 long press = record
-- e2 = scroll through time

-- To do:
--   - Do we still need record.start_index?

musicutil = require('musicutil')
idx_ndata = include('lib/idx_ndata')

-- The recording voice (head) and buffer for softcut.
-- The start and end of the buffer, because if we're not on
-- a rolling record window then we need to stop recording at the end.
-- Our play/record data.
-- The play.start_idx relates to the MIDI data, not the audio,
-- but we keep it with the audio because it's only used when
-- we draw the audio play line.

SC_VOICE = 1
SC_BUFFER = 1
SC_BUFFER_START = 1
SC_BUFFER_DURATION = 5    -- Seconds
SC_BUFFER_END = SC_BUFFER_START + SC_BUFFER_DURATION

audio_position = nil    -- Voice position, when playing and recording

record = {
    start_position = nil,    -- Position of the start of our recording
    start_idx = nil,    -- Index of where our MIDI recording data starts
                        -- (it may move forward as our rolling window moves).
}

play = {
    start_position = nil,
    start_idx = nil,
}

SC_UPDATE_FREQ = 1/20    -- Screen update frequency from audio playing (seconds)

-- Current key/screen state, including
-- when k2 was pressed down (for long press);
-- rolling window length;
-- what the popup message is;
-- when the popup appeared;
-- the popup coroutine handle for its timeout;
-- what the last MIDI event was.

STOP = 0
PLAY = 1
RECORD = 2

POPUP_DURATION = 1.0

NO_EVENT = 10
NOTE_EVENT = 11
TRANSPORT_EVENT = 12

state = {
    mode = STOP,
    k2_down = nil,
    window_duration = SC_BUFFER_DURATION - 1,
    popup_message = nil,
    popup_appeared = 0,
    popup_handle = nil,
    last_event = NO_EVENT,
}

LONG_PRESS_SECS = 0.5  -- Length of a long press, in seconds

-- The metronome for playing back note data; nil means stopped.

-- ndata_player = nil

-- Our MIDI device

midi_device = midi.connect()

-- Tracking notes in a note data sequence.
-- note_vel - Map from note value to velocity of all notes currently held
-- idx - Current index where there's note data, or nil.

function init_note_data()
    note_vel = {}
    nd_seq = idx_ndata.new(util.time)
    idx = nd_seq.first_index    -- This will be nil
end
init_note_data()

-- Some visual positioning

TIMELINE_WIDTH = 116
TIMELINE_Y = 3
AUDIO_PLAY_Y = 7

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
    softcut.position(SC_VOICE, 1)    -- Play position at the start
    softcut.play(SC_VOICE, 0)    -- Don't play the voice yet (0 = off)

    -- We allow looping, for the rolling window

    softcut.loop(SC_VOICE, 1)
    softcut.loop_start(SC_VOICE, SC_BUFFER_START)
    softcut.loop_end(SC_VOICE, SC_BUFFER_END)

    -- Record paramaters

    softcut.level_input_cut(1, SC_VOICE, 1.0)    -- Input level of channel 1
    softcut.level_input_cut(2, SC_VOICE, 1.0)    -- Input level of channel 2
    softcut.rec_level(SC_VOICE, 1.0)    -- Record level for the voice
    softcut.pre_level(SC_VOICE, 0.0)    -- Preserve level for the voice
    softcut.rec(SC_VOICE, 0)    -- Don't record to the voice yet (0 = off)

    -- Update the audio play data (but only if we're playing)

    softcut.phase_quant(SC_VOICE, SC_UPDATE_FREQ)
    last_position = null
    softcut.event_phase(function(i, pos)
        -- DEBUGGING

        if audio_position and (pos < audio_position) then
            print("softcut.event_phase(): We have looped")
        end
        if pos > SC_BUFFER_END then
            print("softcut.event_phase(): More than a second beyond the buffer! " .. position)
        end

        if state.mode == STOP then
            return
        end

        if state.mode == RECORD then
            -- We're recording, so we may need to move the rolling recording window,
            -- as well as update the audio position.

            move_recording_window(pos)

        elseif state.mode == PLAY then

            -- We're playing, so we may need to move our note number, or stop

            local end_pos = idx_audio_position(record.start_position, 1, nd_seq.last_index)
            if idx == nd_seq.last_index or pos >= end_pos then
                -- We need to stop playing

                idx = nd_seq.last_index
                to_stop_mode()
                redraw()
                return
            end

            -- We may need to move our note number
            while idx_audio_position(record.start_position, 1, idx+1) <= pos do
                idx = idx + 1
            end

        end

        audio_position = pos
        redraw()
    end)
    softcut.poll_start_phase()

end

-- Calculate the current duration of the recording.
-- @param pos    Our current position in the buffer.
--
function recording_duration(pos)
    -- We may have an easy calculation
    if record.start_position <= pos then
        return pos - record.start_position
    end

    -- We've looped round the buffer loop, so it's more complicated
    return (pos - SC_BUFFER_START) + (SC_BUFFER_END - record.start_position)
end

-- If necessary, move the recording window, for when we've recorded
-- more than the rolling window allows.
-- @param pos    Our current position in the buffer.
--
function move_recording_window(pos)
    -- We'll see if we need to reduce the window,
    -- if so then we'll reduce it by one notch,
    -- and then we'll test again

    local debug_mrw = function(pos)
        print("move_recording_window(): index [" .. record.start_idx .. ", " .. idx ..
            "] and position [" .. record.start_position .. ", " .. pos .. "]")
    end

    local repeat_count = 0

    repeat

        if recording_duration(pos) <= state.window_duration then
            -- The window isn't big enough to roll
            debug_mrw(pos)
            return
        end

        if not idx then
            -- We haven't recorded anything yet
            debug_mrw(pos)
            return
        end

        if nd_seq:length() == 1 then
            -- We've only recorded one set of MIDI events and it's outside
            -- our rolling window, so re-arm the recording.
            init_note_data()
            stop_recording_audio()
            state.last_event = NO_EVENT
            debug_mrw(pos)
            return
        end

        -- We have at least two MIDI events.
        -- Move our record start index forward as necessary

        record.start_position = idx_audio_position(record.start_position, record.start_idx, record.start_idx+1)
        -- idx_ndata[record.start_idx] = nil
        -- record.start_idx = record.start_idx + 1
        nd_seq:delete_from_front()
        record.start_idx = nd_seq.first_index

        repeat_count = repeat_count + 1

        debug_mrw(pos)
    until repeat_count >= 100
    print("Likely error! 100 repeat counts!")
end

-- (Re)draw the screen
--
function redraw()
    screen.clear()
    screen.line_width(1)

    -- Draw the timeline at the top, plus the note notches and
    -- where we are now.

    screen.level(2)
    screen.move(0, TIMELINE_Y)
    screen.line(TIMELINE_WIDTH, TIMELINE_Y)
    screen.stroke()

    if idx then
        -- Draw the notches on the timeline
        -- for i, _ in pairs(idx_ndata) do
        for i = nd_seq.first_index, nd_seq.last_index do
            draw_notch(i, 2)
        end

        -- Draw the current notch. We must do this last to ensure it
        -- shows up over the other notches
        draw_notch(idx, 15)
    end

    -- If we're playing, draw our audio progress. It is a line drawn
    -- from the current note notch (idx).

    if state.mode == PLAY and idx then
        local start_x = timeline_x(idx)
        local current_length = 1

        -- if idx < #idx_ndata then
        if idx < nd_seq.last_index then
            -- local full_time = idx_ndata[idx+1].time - idx_ndata[idx].time
            local full_time = nd_seq:time(idx+1) - nd_seq:time(idx)
            local idx_pos = idx_audio_position(play.start_position, play.start_idx, idx)
            local current_time = audio_position - idx_pos
            local full_length = timeline_x(idx+1) - start_x
            current_length = math.max(1, full_length * current_time / full_time)
        end

        screen.level(2)
        screen.move(timeline_x(play.start_idx), AUDIO_PLAY_Y)
        screen.line(start_x, AUDIO_PLAY_Y)
        screen.stroke()

        screen.level(15)
        screen.move(start_x, AUDIO_PLAY_Y)
        screen.line_rel(current_length, 0)
        screen.stroke()
    end

    -- Show the current mode

    if state.mode == PLAY then
        draw_play_button()
    elseif state.mode == RECORD then
        draw_record_button()
    else
        draw_stop_button()
    end

    -- From our current idx, draw all the notes as vertical lines.
    -- We'll also save the notes to display the note names.

    screen.level(15)
    if state.last_event ~= NO_EVENT then
        -- We've just had some event, so work out what data we need to display

        local data =
            -- state.last_event == NOTE_EVENT and note_vel or idx_ndata[idx].note_vel
            state.last_event == NOTE_EVENT and note_vel or nd_seq:note_vel(idx)
        local notes = {}

        for note, vel in pairs(data) do
            screen.move(note, 55)
            screen.line_rel(0, math.min(-vel * 0.33, -1))
            screen.stroke()

            table.insert(notes, note)
        end

        display_note_names(notes)
    end

    -- Show or clear the popup

    if util.time() >= state.popup_appeared + POPUP_DURATION then
        state.popup_appeared = 0
        state.popup_message = nil
    end

    if state.popup_message then
        local length = #state.popup_message

        screen.level(0)
        screen.rect(64 - 2.5 * length, 32 - 7, length*5, 10)
        screen.fill()

        screen.level(15)
        screen.rect(64 - 2.5 * length, 32 - 7, length*5, 10)
        screen.stroke()

        screen.move(64, 32)
        screen.text_center(state.popup_message)
    end

    screen.update()
end

-- Draw a play button
--
function draw_play_button()
    screen.level(15)

    local x = TIMELINE_WIDTH + 8
    local y = TIMELINE_Y - 3
    local height = 5

    screen.move(x, y + 1)
    screen.line_rel(0, height)
    screen.stroke()

    for i = height, 1, -2 do
        y = y + 1
        height = i
        screen.pixel(x, y)
        screen.fill()
        screen.pixel(x, y + height - 1)
        screen.fill()
        x = x + 1
    end
end

-- Draw a stop button
--
function draw_stop_button()
    screen.level(0)
    screen.circle(TIMELINE_WIDTH + 8, TIMELINE_Y + 1, 3)
    screen.level(15)
    screen.stroke()
end

-- Draw a record button
--
function draw_record_button()
    screen.level(15)

    screen.circle(TIMELINE_WIDTH + 8, TIMELINE_Y + 1, 1.5)
    screen.fill()

    screen.circle(TIMELINE_WIDTH + 8, TIMELINE_Y + 1, 3)
    screen.stroke()
end

-- Display the note names at the bottom of the screen.
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
    elseif msg.type == "note_off" then
        -- If it's note off, remove from the current 'on' notes
        note_vel[msg.note] = nil
    end

    if msg.type == "note_on" or msg.type == "note_off" then
        if state.mode == RECORD then
            -- append_ndata()
            nd_seq:append(note_vel)
            idx = nd_seq.last_index
        end
        state.last_event = NOTE_EVENT

        -- Maybe this is the trigger to start recording audio
        -- if #idx_ndata == 1 then
        if nd_seq.last_index == 1 then
            record.start_idx = 1
            start_recording_audio()
        end

    end
    redraw()
end

-- Add note data (the note_val table) to the end of our current history.
--
--[[function append_ndata()
    local seconds = util.time()

    idx = #idx_ndata + 1
    idx_ndata[idx] = {
        time = seconds,
        note_vel = shallow_copy(note_vel)
    }
end--]]

-- Draw a notch on the timeline
-- @param i    Which notch idx
-- @param level    Screen brightness
--
function draw_notch(i, level)
    screen.level(level)
    screen.move(timeline_x(i), TIMELINE_Y - 2)
    screen.line_rel(0, TIMELINE_Y + 1)
    screen.stroke()
end

-- The screen x position of a notch on the timeline.
-- @param i    The index of the note.
--
function timeline_x(i)
    -- Get the index of the first note. It may have rolled forward
    -- with the rolling recording window.

    local start_idx = 1
    if state.mode == RECORD and record.start_idx then
        start_idx = record.start_idx
    end

    -- Get the time difference from first to last note
    -- local time_first = idx_ndata[start_idx].time
    local time_first = nd_seq:time(start_idx)
    -- local time_last = idx_ndata[#idx_ndata].time
    local time_last = nd_seq:time(nd_seq.last_index)
    local time_diff = time_last - time_first

    -- Calculate the x position of the notch
    -- local ndata = idx_ndata[i]
    local ndata = nd_seq:get(i)
    local x = (ndata.time - time_first) / time_diff * TIMELINE_WIDTH + 1
    if time_diff == 0 then x = 1 end

    return x
end

-- Handle key presses
--
function key(n, z)
    local time = util.time()
    if n == 2 then
        if z == 1 then
            -- k2 has gone down; note when
            state.k2_down = time
        else
            -- k2 has gone up...

            if state.k2_down and (time - state.k2_down) >= LONG_PRESS_SECS then
                -- Go into record mode.
                -- We don't start writing audio and MIDI data here;
                -- we start when we get the first MIDI note.

                init_note_data()
                stop_recording_audio()
                stop_playing_audio()

                state.last_event = NO_EVENT
                state.mode = RECORD

            elseif state.mode == STOP then
                -- Short press - go into play mode if we can

                if nd_seq.first_index then
                    stop_recording_audio()

                    state.mode = PLAY
                    start_playing_audio()
                end
            else
                -- Short press - go into stop mode

                to_stop_mode()
            end

            state.k2_down = nil
            redraw()
        end
    end
    if n == 3 and z == 0 then
        local stamp = util.time()
        _norns.screen_export_png("/home/we/dust/midiviz_" .. stamp .. ".png")
    end
end

-- Go into stop mode
--
function to_stop_mode()
    -- If we were recording, and we got some MIDI data,
    -- record final empty note data and stop audio recording.

    if state.mode == RECORD and idx then
        note_vel = {}
        -- append_ndata()
        nd_seq:append(note_vel)
        idx = nd_seq.last_index

        -- The rolling record window might have shifted the start of
        -- the note data, so we may need to move it down.
        reindex_note_data()
    end

    stop_recording_audio()
    stop_playing_audio()

    state.mode = STOP
end

-- The start of the note data might not be 1. If so, copy it
-- all back to the 1 index.
-- This assumes we were recording and are moving into stop mode.
--
function reindex_note_data()
--[[    if record.start_idx == nil or record.start_idx == 1 then
        return
    end

    local offset = record.start_idx - 1
    local idx_ndata2 = {}

    for i, d in pairs(idx_ndata) do
        local dst = i - offset
        idx_ndata2[i - offset] = {
            time = d.time,
            note_vel = shallow_copy(d.note_vel)
        }
    end

    idx = idx - offset
    idx_ndata = idx_ndata2--]]

    local offset = nd_seq:reindex()
    idx = idx - offset
end

-- Encoders:
-- e2 = scroll back and forth through our notes
-- If we're playing then we need to restart that.
--
function enc(n, d)
    if n == 2 then
        -- if #idx_ndata > 0 then
        if nd_seq:length() > 0 then
            -- idx = util.clamp(idx + d, 1, #idx_ndata)
            idx = util.clamp(idx + d, nd_seq.first_index, nd_seq.last_index)
            state.last_event = TRANSPORT_EVENT
        end


        if state.mode == RECORD then
            -- Stop recording

            to_stop_mode()

        elseif state.mode == PLAY then
            -- Restart playback from the new point

            stop_playing_audio()

            state.mode = PLAY
            start_playing_audio()
        end

        redraw()
    elseif n == 3 then
        if state.popup_handle ~= nil then
            clock.cancel(state.popup_handle)
        end

        state.popup_message = "Hello!"
        state.popup_appeared = util.time()
        state.popup_handle = clock.run(function()
            clock.sleep(POPUP_DURATION)
            state.popup_handle = nil
            redraw()
        end)

        redraw()
    end
end

-- Start recording audio
--
function start_recording_audio()
    softcut.buffer_clear()    -- Clear all the buffers
    softcut.position(SC_VOICE, SC_BUFFER_START)    -- Play position at the start

    record.start_position = SC_BUFFER_START
    audio_position = SC_BUFFER_START

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
    audio_position = nil
    play.start_idx = nil
    play.start_position = nil
end

-- Start playing audio from the point of where we are in the note data.
-- We'll also track our audio play position and update the note index
-- on the timeline.
--
function start_playing_audio()
    audio_position = SC_BUFFER_START
    if idx then
        audio_position = idx_audio_position(SC_BUFFER_START, 1, idx)
    end

    play.start_idx = idx
    play.start_position = audio_position

    print("start_playing_audio(): Play from position " .. audio_position)
    softcut.position(SC_VOICE, audio_position)
    softcut.play(SC_VOICE, 1)    -- Start playing (1 = on)
end

-- The softcut audio position of note number i.
-- @param start_position    Softcut voice position of the audio start
-- @param start_i    The index of the start of audio
-- @param i    Index of the note number we want
--
function idx_audio_position(start_position, start_i, i)
    if i == nil then
        print("idx_audio_position(): Error! Wrong parameters!")
    end

    -- local i_time = idx_ndata[i].time
    local i_time = nd_seq:time(i)
    -- local start_i_time = idx_ndata[start_i].time
    local start_i_time = nd_seq:time(start_i)

    local duration = i_time - start_i_time
    local end_position = start_position + duration
    local duration_beyond = end_position - SC_BUFFER_END

    if duration_beyond <= 0 then
        return end_position
    end

    if SC_BUFFER_START + duration_beyond > SC_BUFFER_END then
        print("idx_audio_position(): Error! Audio position is far beyond!")
    end

    return SC_BUFFER_START + duration_beyond
end
