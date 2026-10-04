var hiddenWindows = {};
var isHiding = false;
var isRestoring = false;

function getAppKey(win) {
    if (!win) return null;
    return win.desktopFileName || win.resourceClass || null;
}

function isSameApp(w1, w2) {
    if (!w1 || !w2) return false;
    if (w1.desktopFileName && w2.desktopFileName && w1.desktopFileName === w2.desktopFileName) {
        return true;
    }
    if (w1.resourceClass && w2.resourceClass && w1.resourceClass === w2.resourceClass) {
        return true;
    }
    return false;
}

function restoreAppWindows(triggerWin) {
    if (isHiding || isRestoring || !triggerWin) return;

    var triggerId = String(triggerWin.internalId);
    var appKey = hiddenWindows[triggerId];
    if (!appKey) return;

    isRestoring = true;

    var targetWin = triggerWin;
    var windows = workspace.windowList();

    // Unminimize all other sibling windows first (in the background)
    for (var i = 0; i < windows.length; ++i) {
        var w = windows[i];
        var wid = String(w.internalId);
        if (hiddenWindows[wid] === appKey) {
            delete hiddenWindows[wid];
            if (w !== targetWin && w.minimized) {
                w.minimized = false;
            }
        }
    }

    // Clean up tracking state for the target window
    delete hiddenWindows[String(targetWin.internalId)];

    // Unminimize, raise, and focus the target window
    if (targetWin.minimized) {
        targetWin.minimized = false;
    }
    workspace.raiseWindow(targetWin);
    workspace.activeWindow = targetWin;

    isRestoring = false;
}

function bindWindow(win) {
    if (!win) return;
    win.minimizedChanged.connect(function() {
        if (!win.minimized) {
            restoreAppWindows(win);
        }
    });
}

workspace.windowList().forEach(bindWindow);
workspace.windowAdded.connect(bindWindow);

workspace.windowActivated.connect(function(client) {
    if (client && !client.minimized) {
        restoreAppWindows(client);
    }
});

workspace.windowRemoved.connect(function(win) {
    if (win) {
        delete hiddenWindows[String(win.internalId)];
    }
});

registerShortcut("HideCurrentApp", "Hide Application (All Windows)", "Meta+H", function() {
    var active = workspace.activeWindow;
    if (!active || !active.normalWindow) {
        return;
    }

    var appKey = getAppKey(active);
    if (!appKey) {
        return;
    }

    isHiding = true;
    var windows = workspace.windowList();

    // Minimize background windows first so focus isn't shifted across siblings
    for (var i = 0; i < windows.length; ++i) {
        var win = windows[i];
        if (win !== active && win.normalWindow && !win.minimized && isSameApp(win, active)) {
            hiddenWindows[String(win.internalId)] = appKey;
            win.minimized = true;
        }
    }

    // Minimize the active window last
    hiddenWindows[String(active.internalId)] = appKey;
    active.minimized = true;

    isHiding = false;
});
