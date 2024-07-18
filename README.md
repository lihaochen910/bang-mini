<p align="center">
<img src="https://github.com/isadorasophia/bang/blob/1f7f6a86a42bb5ba66b7fce6a64fec1539432e69/media/logo-3x-2-export.png" alt="Murder logo">
</p>

<h1 align="center">A real ECS framework!</h1>

<p align="center">
<a href="LICENSE"><img src="https://img.shields.io/github/license/isadorasophia/bang.svg" alt="License"></a>
</p>

Check out original author repository [bang](https://github.com/isadorasophia/bang) for more details.

### How to use it?
```lua
CLASS: MyLuaComponent( IComponent )
    :MODEL {
		Field 'boolField' :boolean();
		Field 'intField' :int();
		Field 'floatField' :float();
		Field 'numberField' :number();
		Field 'stringField' :string();
		Field 'assetField' :asset();
		Field 'enumField' :enum( "SomethingEnum" );
		Field 'arrayField' :array( "number" );
		Field 'tableField' :table( "string", "number" );
	}

function MyLuaComponent:__init()
	self.intField = 0
end

Bang.registerComponent( MyLuaComponent )

CLASS: MyUpdateSystem( IStartupSystem, IUpdateSystem, IReactiveSystem )
	:META {
		watcher = WatchAttr( "MyLuaComponent" ),
		filters = {
			FilterAttr( {
				filter = ContextAccessorFilter.allOf,
				kind = ContextAccessorKind.readwrite,
				types = {
					MyLuaComponent
				}
			} )
		}
	}

function MyUpdateSystem:update( context )
	for entityId, e in pairs( context:getEntities() ) do
		print( '[MyUpdateSystem] update entity:', entityId )
		local var = e:getMyLua().intField
		local updated = e:getMyLua()
		updated.intField = var + 1
		e:setMyLua( updated )
	end
end

function MyUpdateSystem:onAdded( world, entities )
	print( 'detect MyLuaComponent added.' )
end

function MyUpdateSystem:onModified( world, entities )
	print( 'detect MyLuaComponent modified.' )
end

function MyUpdateSystem:onRemoved( world, entities )
	print( 'detect MyLuaComponent removed.' )
end

local world = World( {
	{ MyUpdateSystem, true },
} )

local e = world:addEntity( {
	MyLuaComponent()
} )

world:update()
print( 'intField = ', e:getMyLua().intField )

world:update()
print( 'intField = ', e:getMyLua().intField )

print( 'getMyLua ->', e:getMyLua() )

e:removeMyLua()
world:update()

```