-- Midiviz
--
-- Visualisation of MIDI keys

function init()
    print("In the init function")
end

-- Display something on the screen.
--
function redraw()
    screen.clear()
    screen.move(0, 40)
    screen.level(15)
    screen.text("Welcome to midiviz")
    screen.update()
end
