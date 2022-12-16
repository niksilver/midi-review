lu = require('luaunit')

recording = require('recording')
idx_ndata = require('idx_ndata')

function test_new()
    local idx_nd = idx_ndata.new(os.clock)
    local rec = recording.new(1, 4, idx_nd)
end
