--- When a system is watching for a component, this is the kind of notification currently fired.
--- The order of the enumerator dictates the order that these will be called on the watcher systems.
WatcherNotificationKind = _ENUM{

    --- Component has been added. It is not called if the entity is dead.
	{ 'added', 0 },

    --- Component was removed.
	{ 'removed', 1 },

    --- Component was modified. It is not called if the entity is dead.
	{ 'modified', 2 },

    --- Entity has been enabled, hence all its components. Called if an entity was
    --- previously disabled.
	{ 'enabled', 3 },

    --- Entity has been disabled, hence all its components.
	{ 'disabled', 4 }

}

WatcherNotificationKind.added = 0
WatcherNotificationKind.removed = 1
WatcherNotificationKind.modified = 2
WatcherNotificationKind.enabled = 3
WatcherNotificationKind.disabled = 4
