var primaryScreen = 0;

function updatePrimaryScreen() {
    var dockScreens = [];
    for (const window of workspace.windowList()) {
        if (window.dock) {
            dockScreens.push(window.output);
        }
    }

    if (dockScreens.length === 1) {
        primaryScreen = dockScreens[0];
        return;
    }

    primaryScreen = 0;
    return;
}

function bind(window) {
    var update = function (window) {
        var window = window || this;

        if (
            window.desktopWindow ||
            window.dock ||
            (!window.normalWindow && window.skipTaskbar)
        ) {
            return;
        }

        var currentScreen = window.output;
        var previousScreen = window.previousScreen;
        window.previousScreen = currentScreen;

        if (currentScreen != primaryScreen) {
            window.desktops = [];
            print("Window " + window.internalId + " has been pinned");
        } else if (previousScreen != primaryScreen) {
            window.desktops = workspace.currentDesktop;
            print("Window " + window.internalId + " has been unpinned");
        }
    };

    window.previousScreen = window.output;

    update(window);

    window.outputChanged.connect(window, update);
    window.desktopsChanged.connect(window, update);
    print("Window " + window.internalId + " has been bound");
}

function main() {
    updatePrimaryScreen();
    
    workspace.windowList().forEach(bind);
    workspace.windowAdded.connect(bind);

    workspace.screensChanged.connect(updatePrimaryScreen)
}

main();