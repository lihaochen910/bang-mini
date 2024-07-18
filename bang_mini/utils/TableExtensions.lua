function table.len( t )
    local v = 0
    for _ in pairs( t ) do
        v = v + 1
    end
    return v
end

function table.simplecopy( t )
    local nt = {}
    for k, v in pairs( t ) do
        nt[ k ] = v
    end
    return nt
end
