--------------------------------------------------------------------
---@class IComponent
CLASS: IComponent()
    :META {
        interface = true
    }

function IComponent.equals( componentA, componentB )
    -- ref compare
    if componentA == componentB then
        return true
    end

    -- NOTE: comment on Released
    assert( isClassInstance( componentA ) )
    assert( isClassInstance( componentB ) )

    -- class type compare
    local componentAClass = getClass( componentA )
    local componentBClass = getClass( componentB )
    if componentAClass ~= componentBClass then
        return false
    end

    -- class same and fields compare
    local model = Model.fromClass( componentAClass )
    local fieldList = model:getFullFieldList()
    for i = 1, #fieldList do
        local f = fieldList[ i ]
        if f:getValue( componentA ) ~= f:getValue( componentB ) then
            return false
        end
    end

    return true
end
