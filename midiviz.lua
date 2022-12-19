-- midiviz
--
-- Visualisation of MIDI key presses.
--
-- k2 = play/stop
-- k2 long press = record
-- e2 = scroll through time

musicutil = require('musicutil')
idx_ndata = include('lib/idx_ndata')
Recording = include('lib/recording')

-- note_vel - Map from note value to velocity of all notes currently held
-- nd_seq - Note data sequence of MIDI notes
-- idx - Current index where there's note data, or nil.

function init_note_data()
    note_vel = {}
    nd_seq = idx_ndata.new(util.time)
    idx = nd_seq.first_index    -- This will be nil
end
init_note_data()

-- The recording voice (head) and buffer for softcut.
-- The start and end of the buffer.

SC_VOICE = 1
SC_BUFFER = 1
SC_BUFFER_START = 1
SC_BUFFER_DURATION = 5    -- Seconds
SC_BUFFER_END = SC_BUFFER_START + SC_BUFFER_DURATION

-- Voice position, when playing and recording

audio_position = nil

-- The audio recording, linked to the note data sequence.
-- Once we reinitialise the note data sequence then we need to call this
-- again, because otherwise `record` will be referencing the old
-- note data sequence.

function init_recording()
    record = Recording.new(SC_BUFFER_START, SC_BUFFER_DURATION, nd_seq)
end
init_recording()

-- Index we've started playing from

play_start_idx = nil

-- Update frequency to track the voice position in softcut
-- and update the screen and more.

SC_UPDATE_FREQ = 1/20

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

-- Our MIDI device

midi_device = midi.connect()

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

    -- Update when the voice position changes

    softcut.phase_quant(SC_VOICE, SC_UPDATE_FREQ)
    last_position = null
    softcut.event_phase(event_phase)
    softcut.poll_start_phase()

end

-- Respond when we get period information about the position of the
-- play/record head. This is a callback for `softcut.event_phase`.
-- @param voice    Voice of the head.
-- @param pos    The position of the play/record head.
--
function event_phase(voice, pos)

    if state.mode == STOP then
        return
    end

    if state.mode == RECORD then
        -- We're recording, so we may need to move the rolling recording window,
        -- as well as update the audio position.

        maintain_recording_window(pos)

    elseif state.mode == PLAY then
        -- We're playing, so we may need to move our note number, or stop

        repeat
            if idx == nd_seq.last_index or record:beyond_end(pos) then
                -- We need to stop playing

                idx = nd_seq.last_index
                to_stop_mode()
                redraw()
                return
            end

            -- We may need to move our note number

            check_play_status = false
            if record:position_at_or_beyond(pos, idx + 1) then
                idx = idx + 1
                check_play_status = true
                print("event_phase(): Inc idx to " .. idx)
            end

        until not check_play_status
    end

    audio_position = pos
    redraw()
end

-- If necessary, move the recording window, for when we've recorded
-- more than the rolling window allows.
-- When this is called it assumes we are in record mode.
-- It also assumes the current recorded period is less than the entire
-- softcut buffer.
-- @param pos    Our current position in the buffer.
--
function maintain_recording_window(pos)
    while record:duration(pos) > state.window_duration do
        nd_seq:delete_from_front()

        if nd_seq:length() == 0 then
            -- We've just deleted the only MIDI event, so re-arm the recording
            init_note_data()
            stop_recording_audio()
            state.last_event = NO_EVENT
            return
        end
    end
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

        if idx < nd_seq.last_index then
            local full_time = nd_seq:time(idx+1) - nd_seq:time(idx)
            local idx_pos = record:position(idx)
            local current_time = audio_position - idx_pos
            local full_length = timeline_x(idx+1) - start_x
            current_length = math.max(1, full_length * current_time / full_time)
        end

        screen.level(2)
        screen.move(timeline_x(play_start_idx), AUDIO_PLAY_Y)
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

    -- Show the popup if we have one

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
            nd_seq:append(note_vel)
            idx = nd_seq.last_index
        end
        state.last_event = NOTE_EVENT

        -- Maybe this is the trigger to start recording audio
        -- if #idx_ndata == 1 then
        if nd_seq.last_index == 1 then
            start_recording_audio()
        end

    end
    redraw()
end

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
    if state.mode == RECORD and nd_seq.first_index then
        start_idx = nd_seq.first_index
    end

    -- Get the time difference from first to last note
    local time_first = nd_seq:time(start_idx)
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
    -- record final empty note data, stop audio recording, and cut it.

    if state.mode == RECORD and idx then
        note_vel = {}
        nd_seq:append(note_vel)

        --  Cut the recording to the start
        record:cut()
        idx = nd_seq.last_index
        for i = 1, idx do
            print(i .. ", pos = " .. record:position(i))
        end
    end

    stop_recording_audio()
    stop_playing_audio()

    state.mode = STOP
end

-- Encoders:
-- e2 = scroll back and forth through our notes
-- If we're playing then we need to restart that.
--
function enc(n, d)
    if n == 2 then
        if nd_seq:length() > 0 then
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

    init_recording()
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
    play_start_idx = nil
end

-- Start playing audio from the point of where we are in the note data.
-- We'll also track our audio play position and update the note index
-- on the timeline.
--
function start_playing_audio()
    audio_position = SC_BUFFER_START
    if idx then
        audio_position = record:position(idx)
    end

    play_start_idx = idx

    softcut.position(SC_VOICE, audio_position)
    softcut.play(SC_VOICE, 1)    -- Start playing (1 = on)
    print("start_playing_audio(): idx = " .. idx .. ", audio_position = " .. audio_position)
end
