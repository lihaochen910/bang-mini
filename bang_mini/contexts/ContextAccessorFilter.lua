--- Context accessor filter for a system.
--- This will specify the kind of filter which will be performed on a certain list of component types.
ContextAccessorFilter = _ENUM {

    --- No filter is required. This won't be applied when filtering entities to a system.
    --- This is used when a system will, for example, add a new component to an entity but does
    --- not require such component.
	{ 'none', 1 },

    --- Only entities which has all of the listed components will be fed to the system.
	{ 'allOf', 2 },

    --- Filter entities which has any of the listed components will be fed to the system.
	{ 'anyOf', 3 },

    --- Filter out entities that have the components listed.
	{ 'noneOf', 4 }

}

ContextAccessorFilter.none = 1
ContextAccessorFilter.allOf = 2
ContextAccessorFilter.anyOf = 3
ContextAccessorFilter.noneOf = 4
