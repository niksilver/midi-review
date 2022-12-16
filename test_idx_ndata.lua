lu = require('luaunit')

idx_ndata = require('idx_ndata')

function test_count_normally()
    local nd = idx_ndata.new()

    -- Length of a new map should be zero
    lu.assertEquals(nd:length(), 0)
end

os.exit(lu.LuaUnit.run())
