--- Context accessor kind for a system.
--- This will specify the kind of operation that each system will perform, so the world
--- can parallelize efficiently each system execution.
ContextAccessorKind = _ENUM {

    --- This will specify that the system implementation will only perform read operations.
	{ 'read', 0 },

    --- This will specify that the system implementation will only perform write operations.
	{ 'write', 1 },

    { 'readwrite', 2 }
}

ContextAccessorKind.read = 0
ContextAccessorKind.write = 1
ContextAccessorKind.readwrite = 2
