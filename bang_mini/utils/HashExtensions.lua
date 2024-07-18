--------------------------------------------------------------------
---@class HashExtensions
CLASS: HashExtensions()

function HashExtensions.getHashCodeImpl( values )
    local result = 0
    local shift = 0

    for _, v in ipairs( values ) do
        shift = ( shift + 11 ) % 21
        --result = result ^ ( ( v + 1024 ) << shift )
        result = result ^ ( bit32.lshift( v + 1024, shift ) )
    end

    return result
end

function HashExtensions.getHashCode( a, b )
    local hash = 23
    hash = hash * 31 + a
    hash = hash * 31 + b
    return hash
end
