--------------------------------------------------------------------
---@class Bang
CLASS: Bang()

Bang.componentRegistry = setmetatable( {}, { __no_traverse = true } )

function Bang.registerComponent( klass )
    if not klass:isSubclass( IComponent ) then
        _error( 'invalid component class:', name )
    end
    -- assert( not componentRegistry[ name ], 'duplicated component type:'..name )
    if not klass then
        _error( 'no component to register', name )
    end
    if not isClass( klass ) then
        _error( 'attempt to register non-class component', name )
    end

    local name = klass:getClassName()
    Bang.componentRegistry[ name ] = klass
    
    Bang._buildEntityExtensionMethodsForComponent( klass )
end

function Bang._buildEntityExtensionMethodsForComponent( componentKlass )
    --print( 'IComponent:__updatemeta call!', componentKlass:getClassName(), componentKlass:isInterface() )
    if componentKlass:isInterface() then
        return
    end

    local entityKlass = findClass( 'Entity' )

    --print( 'generate EntityExtensions for: ' .. componentKlass:getClassName() )

    local function getCleanComponentName( name )
        return name:gsub( "%Component", "" )
    end

    local cleanComponentName = getCleanComponentName( componentKlass:getClassName() )
    local componentGetMethodName = string.format( 'get%s', cleanComponentName )
    local componentHasMethodName = string.format( 'has%s', cleanComponentName )
    local componentSetMethodName = string.format( 'set%s', cleanComponentName )
    local componentWithMethodName = string.format( 'with%s', cleanComponentName )
    local componentRemoveMethodName = string.format( 'remove%s', cleanComponentName )

    entityKlass[ componentGetMethodName ] = function( e )
        return e:getComponent( componentKlass )
    end

    entityKlass[ componentHasMethodName ] = function( e )
        return e:hasComponent( componentKlass )
    end

    entityKlass[ componentSetMethodName ] = function( e, component )
        return e:addOrReplaceComponent( component )
    end

    entityKlass[ componentWithMethodName ] = entityKlass[ componentSetMethodName ]

    entityKlass[ componentRemoveMethodName ] = function( e )
        return e:removeComponent( componentKlass )
    end
end
