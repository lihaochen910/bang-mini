MiniDelegate = function()
    local methods = {}
    local meta = {
        __add = function( delegates, func )
            --print( '[MiniDelegate] add func!' )
            --print( debug.traceback() )
            methods[ #methods + 1 ] = func
            --table.insert( methods, func )
            return delegates
        end,
        __sub = function( delegates, func )
            for i, f in ipairs( methods ) do
                if f == func then
                    table.remove( methods, i )
                    break
                end
            end
            return delegates
        end,
        __call = function( delegates, ... )
            --print( '[MiniDelegate] fired!' )
            --print( debug.traceback() )
            for _, f in ipairs( methods ) do
                f( ... )
            end
        end
    }
    return setmetatable( {
        count = function( delegates )
            return #methods
        end,
        isEmpty = function( delegates )
            return #methods == 0
        end,
        clear = function( delegates )
            for i = 1, #methods do
                methods[ i ] = nil
            end
        end
    }, meta )
end
