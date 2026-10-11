import QtQuick
import QtCore

// QtCore's Settings (an ini file, set with `location`), with two repairs.
// Its own saving waits half a second after a change and copies every
// property at once, which goes wrong in two ways:
//
// - A property added to a block: the first load copies everything the
//   moment it meets the new key, before the properties declared after it
//   are loaded, so their defaults land in the file while memory has the
//   right values — the next start loads the defaults. Once that write is
//   done, every value is written back from memory.
// - A hot reload within that half second: the new instance reads the
//   file before the old one has written the change. Each change is
//   written at once instead.
Settings {
    id: root

    Component.onCompleted: {
        const own = ["objectName", "category", "location"];
        const keys = Object.keys(root).filter(k => !own.includes(k) && typeof root[k] !== "function");

        for (const key of keys)
            root[key + "Changed"].connect(() => {
                root.setValue(key, root[key]);
                root.sync();
            });

        // Not a property: those are saved to the file too.
        const timer = Qt.createQmlObject("import QtQuick; Timer { interval: 1500 }", root);
        timer.triggered.connect(() => {
            for (const key of keys)
                root.setValue(key, root[key]);
            root.sync();
            timer.destroy();
        });
        timer.start();
    }
}
