import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    toolTipMainText: ""
    toolTipSubText: ""

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
    compactRepresentation: compactView
    fullRepresentation: fullView

    readonly property string webUiUrl: plasmoid.configuration.webUiUrl || "http://100.76.111.34:8080"
    readonly property string username: plasmoid.configuration.username || "nobara"
    readonly property string password: plasmoid.configuration.password !== undefined ? plasmoid.configuration.password : "zippy-escapade-Cornea-aLLenable908332"
    readonly property int updateInterval: plasmoid.configuration.updateInterval || 4

    property string selectedTimeframe: plasmoid.configuration.selectedTimeframe || "1h"

    readonly property int dlMaxMbps: plasmoid.configuration.dlMaxMbps || 50
    readonly property int upMaxKbps: plasmoid.configuration.upMaxKbps || 2000
    readonly property bool showDataUsage: plasmoid.configuration.showDataUsage !== undefined ? plasmoid.configuration.showDataUsage : true

    readonly property int configuredUpKbps: (root.upMaxKbps && root.upMaxKbps > 0) ? root.upMaxKbps : 2000
    readonly property int configuredDlMbps: (root.dlMaxMbps && root.dlMaxMbps > 0) ? root.dlMaxMbps : 50

    readonly property color bgColor: plasmoid.configuration.bgColor || "#000000"
    readonly property real bgOpacity: plasmoid.configuration.bgOpacity !== undefined ? plasmoid.configuration.bgOpacity : 0.05
    readonly property int cornerRadius: plasmoid.configuration.cornerRadius !== undefined ? plasmoid.configuration.cornerRadius : 8

    readonly property color dlColor: plasmoid.configuration.dlColor || "#2ecc71"
    readonly property color upColor: plasmoid.configuration.upColor || "#ff3b30"
    readonly property color textColor: plasmoid.configuration.textColor || "#fbfbfb"
    readonly property string iconName: plasmoid.configuration.iconName || "qbittorrent"
    readonly property color iconColor: plasmoid.configuration.iconColor || "#ffffff"
    readonly property bool useIconColor: plasmoid.configuration.useIconColor !== undefined ? plasmoid.configuration.useIconColor : false

    property var historyStore: []

    property real currentDlSpeed: 0
    property real currentUpSpeed: 0

    property real sessionDlBytes: 0
    property real sessionUpBytes: 0
    property real lifetimeDlBytes: Math.max(1384285139370, (plasmoid.configuration.alltimeDl !== undefined ? plasmoid.configuration.alltimeDl : 0))
    property real lifetimeUpBytes: Math.max(667524454654, (plasmoid.configuration.alltimeUp !== undefined ? plasmoid.configuration.alltimeUp : 0))
    property real prevSessionDl: -1
    property real prevSessionUp: -1
    property real lastFetchTime: 0

    property real timeframeDlBytes: 0
    property real timeframeUpBytes: 0

    property string statusText: ""
    property string sidCookie: ""
    property bool isLoggingIn: false

    function updateTimeframeStats() {
        var now = Date.now();
        var rangeMs = 3600000;
        if (root.selectedTimeframe === "12h") rangeMs = 12 * 3600000;
        else if (root.selectedTimeframe === "24h") rangeMs = 24 * 3600000;
        else if (root.selectedTimeframe === "7d") rangeMs = 7 * 24 * 3600000;

        var startTime = now - rangeMs;
        var rawSamples = (root.historyStore || []).filter(function(item) {
            return item.t >= startTime;
        });

        if (rawSamples.length === 0) {
            timeframeDlBytes = 0;
            timeframeUpBytes = 0;
            return;
        }

        var totalDl = 0;
        var totalUp = 0;
        for (var i = 0; i < rawSamples.length; i++) {
            var dt = 0;
            if (i === 0) {
                dt = (rawSamples.length > 1) ? Math.max(0.5, (rawSamples[1].t - rawSamples[0].t) / 1000) : root.updateInterval;
            } else {
                dt = Math.max(0.5, (rawSamples[i].t - rawSamples[i - 1].t) / 1000);
            }
            // Allow downsampled historical buckets to reflect their full time span
            dt = Math.min(3600, dt);
            totalDl += rawSamples[i].dl * dt;
            totalUp += rawSamples[i].up * dt;
        }

        timeframeDlBytes = totalDl;
        timeframeUpBytes = totalUp;
    }

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec >= 1048576 * 1024) return (bytesPerSec / (1048576 * 1024)).toFixed(1) + " GB/s";
        if (bytesPerSec >= 1048576) return (bytesPerSec / 1048576).toFixed(1) + " MB/s";
        if (bytesPerSec >= 1024) return (bytesPerSec / 1024).toFixed(1) + " KB/s";
        return bytesPerSec.toFixed(0) + " B/s";
    }

    function formatBytes(bytes) {
        if (bytes >= 1099511627776) return (bytes / 1099511627776).toFixed(1) + " TB";
        if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(1) + " GB";
        if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + " MB";
        if (bytes >= 1024) return (bytes / 1024).toFixed(1) + " KB";
        return bytes.toFixed(0) + " B";
    }

    function formatMaxSpeed(kbps) {
        if (kbps >= 1024) return (kbps / 1024).toFixed(1) + "M";
        return kbps + "K";
    }

    function saveLifetimeStats() {
        var store = (historyStore || []).slice();
        var serialized = JSON.stringify(store);
        plasmoid.configuration.historyCache = serialized;
        plasmoid.configuration.alltimeDl = lifetimeDlBytes;
        plasmoid.configuration.alltimeUp = lifetimeUpBytes;
        if (typeof plasmoid.configuration.writeConfig === "function") {
            plasmoid.configuration.writeConfig();
        }
    }

    Component.onCompleted: {
        try {
            var rawCache = plasmoid.configuration.historyCache;
            if (rawCache && rawCache.length > 5) {
                var loaded = JSON.parse(rawCache);
                if (Array.isArray(loaded) && loaded.length > 0) {
                    var now = Date.now();
                    var cutoff7d = now - (7 * 24 * 60 * 60 * 1000);
                    var valid = loaded.filter(function(item) {
                        return item && item.t >= cutoff7d;
                    });
                    if (valid.length > 0) {
                        historyStore = valid;
                        updateTimeframeStats();
                    }
                }
            }
        } catch (e) {
            // cache read fallback
        }
    }

    function doLogin(callback) {
        if (isLoggingIn) return;
        isLoggingIn = true;

        var req = new XMLHttpRequest();
        req.withCredentials = true;
        req.open("POST", webUiUrl + "/api/v2/auth/login");
        req.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                isLoggingIn = false;
                var text = req.responseText ? req.responseText.trim() : "";
                var setCookie = req.getResponseHeader("Set-Cookie") || req.getResponseHeader("set-cookie");
                if (!setCookie) {
                    var allHeaders = req.getAllResponseHeaders();
                    var m = allHeaders.match(/Set-Cookie:\s*([^\r\n]+)/i);
                    if (m) setCookie = m[1];
                }

                if (req.status === 200 && (text === "Ok." || sidCookie !== "")) {
                    if (callback) callback(true);
                } else if (req.status === 200 || req.status === 204) {
                    if (callback) callback(true);
                } else {
                    statusText = "Auth Error (" + req.status + ")";
                    if (callback) callback(false);
                }
            }
        };
        var body = "username=" + encodeURIComponent(username) + "&password=" + encodeURIComponent(password);
        req.send(body);
    }

    function fetchStats() {
        var req = new XMLHttpRequest();
        req.withCredentials = true;
        req.open("GET", webUiUrl + "/api/v2/transfer/info");
        if (sidCookie !== "") {
            req.setRequestHeader("Cookie", sidCookie);
        }
        req.onreadystatechange = function() {
            if (req.readyState === XMLHttpRequest.DONE) {
                if (req.status === 200) {
                    try {
                        var parsedData = JSON.parse(req.responseText);
                        var rawDl = (parsedData && parsedData.dl_info_speed !== undefined) ? parsedData.dl_info_speed : 0;
                        var rawUp = (parsedData && parsedData.up_info_speed !== undefined) ? parsedData.up_info_speed : 0;

                        var newSessDl = (parsedData && parsedData.dl_info_data !== undefined) ? parsedData.dl_info_data : 0;
                        var newSessUp = (parsedData && parsedData.up_info_data !== undefined) ? parsedData.up_info_data : 0;

                        sessionDlBytes = newSessDl;
                        sessionUpBytes = newSessUp;

                        var now = Date.now();
                        var calcDl = 0, calcUp = 0;

                        if (prevSessionDl >= 0 && lastFetchTime > 0) {
                            var deltaDl = newSessDl >= prevSessionDl ? (newSessDl - prevSessionDl) : newSessDl;
                            var deltaUp = newSessUp >= prevSessionUp ? (newSessUp - prevSessionUp) : newSessUp;
                            var dt = Math.max(0.5, (now - lastFetchTime) / 1000);

                            calcDl = deltaDl / dt;
                            calcUp = deltaUp / dt;

                            if (deltaDl > 0 || deltaUp > 0) {
                                lifetimeDlBytes += deltaDl;
                                lifetimeUpBytes += deltaUp;
                            }
                        } else {
                            if (lifetimeDlBytes === 0) lifetimeDlBytes = newSessDl;
                            if (lifetimeUpBytes === 0) lifetimeUpBytes = newSessUp;
                        }

                        prevSessionDl = newSessDl;
                        prevSessionUp = newSessUp;
                        lastFetchTime = now;

                        currentDlSpeed = (rawDl > 0) ? rawDl : calcDl;
                        currentUpSpeed = (rawUp > 0) ? rawUp : calcUp;

                        statusText = "";

                        var store = (historyStore || []).slice();
                        store.push({ t: now, dl: currentDlSpeed, up: currentUpSpeed });

                        var cutoff7d = now - (7 * 24 * 60 * 60 * 1000);
                        while (store.length > 0 && store[0].t < cutoff7d) {
                            store.shift();
                        }

                        if (store.length > 1000) {
                            var compacted = [];
                            var oneHourAgo = now - 3600000;
                            var idx = 0;
                            while (idx < store.length && store[idx].t < oneHourAgo) {
                                if (idx + 1 < store.length && store[idx + 1].t < oneHourAgo) {
                                    compacted.push({
                                        t: Math.round((store[idx].t + store[idx + 1].t) / 2),
                                        dl: (store[idx].dl + store[idx + 1].dl) / 2,
                                        up: (store[idx].up + store[idx + 1].up) / 2
                                    });
                                    idx += 2;
                                } else {
                                    compacted.push(store[idx]);
                                    idx++;
                                }
                            }
                            while (idx < store.length) {
                                compacted.push(store[idx]);
                                idx++;
                            }
                            store = compacted;
                        }

                        historyStore = store;
                    } catch (e) {
                        statusText = "Parse Error";
                    }
                } else if (req.status === 403 || req.status === 401) {
                    doLogin(function(success) {
                        if (success) fetchStats();
                    });
                } else {
                    statusText = "HTTP " + req.status;
                }
            }
        };
        req.send();
    }

    function renderSmoothGraph(ctx, samples, valueGetter, maxVal, color, isFill, fillOpacity, canvasWidth, canvasHeight) {
        if (!samples || samples.length === 0) return;

        var pts = [];
        for (var i = 0; i < samples.length; i++) {
            var val = Math.max(0, valueGetter(samples[i]));
            var norm = Math.min(1.0, val / maxVal);
            var x = (samples.length === 1) ? 0 : (i / (samples.length - 1)) * canvasWidth;
            var y = canvasHeight - (norm * (canvasHeight - 6)) - 3;
            pts.push({ x: x, y: y });
        }

        ctx.beginPath();
        if (isFill) {
            ctx.moveTo(0, canvasHeight);
            ctx.lineTo(pts[0].x, pts[0].y);
        } else {
            ctx.moveTo(pts[0].x, pts[0].y);
        }

        if (pts.length === 1) {
            ctx.lineTo(canvasWidth, pts[0].y);
        } else {
            var tension = 0.15;
            for (var j = 0; j < pts.length - 1; j++) {
                var p0 = pts[j === 0 ? 0 : j - 1];
                var p1 = pts[j];
                var p2 = pts[j + 1];
                var p3 = pts[j + 2 >= pts.length ? j + 1 : j + 2];

                var cp1x = p1.x + (p2.x - p0.x) * tension;
                var cp1y = Math.max(4, Math.min(canvasHeight, p1.y + (p2.y - p0.y) * tension));
                var cp2x = p2.x - (p3.x - p1.x) * tension;
                var cp2y = Math.max(4, Math.min(canvasHeight, p2.y - (p3.y - p1.y) * tension));

                ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
            }
        }

        if (isFill) {
            ctx.lineTo(canvasWidth, canvasHeight);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(color.r, color.g, color.b, fillOpacity);
            ctx.fill();
        } else {
            ctx.strokeStyle = color;
            ctx.lineWidth = 1.5;
            ctx.stroke();
        }
    }

    onExpandedChanged: {
        if (root.expanded) {
            updateTimeframeStats();
            fetchStats();
        }
    }
    onHistoryStoreChanged: updateTimeframeStats()
    onSelectedTimeframeChanged: updateTimeframeStats()

    Timer {
        interval: (root.expanded ? Math.max(1, root.updateInterval) : 12) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchStats()
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: saveLifetimeStats()
    }

    Component.onDestruction: {
        saveLifetimeStats();
    }

    // --- COMPACT REPRESENTATION (Static Selectable Icon) ---
    Component {
        id: compactView
        Item {
            id: compactRoot
            Layout.minimumWidth: Kirigami.Units.iconSizes.small
            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
            Layout.fillHeight: true

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                source: root.iconName
                isMask: root.useIconColor
                color: root.iconColor
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.expanded = !root.expanded;
                }
            }
        }
    }

    // --- FULL REPRESENTATION (Desktop View & Panel Click Popup Graph) ---
    Component {
        id: fullView
        Item {
            id: fullRep
            Layout.minimumWidth: 420
            Layout.preferredWidth: 480
            Layout.minimumHeight: root.showDataUsage ? 220 : 190
            Layout.preferredHeight: root.showDataUsage ? 245 : 215

            Rectangle {
                id: customBg
                anchors.fill: parent
                color: root.bgColor
                opacity: root.bgOpacity
                radius: root.cornerRadius
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                // Header Container with Centered Buttons, Timeframe Stats & Pinned Left/Right Labels
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 42

                    // Download Speed Label (Pinned Left)
                    PlasmaComponents3.Label {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↓ " + formatSpeed(currentDlSpeed)
                        color: root.dlColor
                        font.bold: true
                        font.pixelSize: 13
                    }

                    // Centered Column: Timeframe Selector Buttons & Transferred Data Underneath
                    Column {
                        anchors.centerIn: parent
                        spacing: 5

                        // Timeframe Selector Buttons (1h, 12h, 24h, 7d)
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4

                            Repeater {
                                model: ["1h", "12h", "24h", "7d"]
                                delegate: Rectangle {
                                    width: 36
                                    height: 20
                                    radius: 3
                                    color: root.selectedTimeframe === modelData ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                                    border.color: root.selectedTimeframe === modelData ? root.textColor : Qt.rgba(1, 1, 1, 0.15)
                                    border.width: 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: root.selectedTimeframe === modelData ? root.textColor : Qt.rgba(1, 1, 1, 0.6)
                                        font.pixelSize: 11
                                        font.bold: root.selectedTimeframe === modelData
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedTimeframe = modelData;
                                            plasmoid.configuration.selectedTimeframe = modelData;
                                        }
                                    }
                                }
                            }
                        }

                        // Timeframe Transferred Data (Centered Directly Under Buttons)
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8

                            PlasmaComponents3.Label {
                                text: "↓ " + root.formatBytes(root.timeframeDlBytes)
                                color: root.dlColor
                                font.pixelSize: 11
                                font.bold: true
                            }

                            PlasmaComponents3.Label {
                                text: "↑ " + root.formatBytes(root.timeframeUpBytes)
                                color: root.upColor
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }

                    // Upload Speed Label (Pinned Right)
                    PlasmaComponents3.Label {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "↑ " + formatSpeed(currentUpSpeed)
                        color: root.upColor
                        font.bold: true
                        font.pixelSize: 13
                    }
                }

                // Main Smooth Curve Graph Canvas
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Canvas {
                        id: fullCanvas
                        anchors.fill: parent

                        Connections {
                            target: root
                            function onHistoryStoreChanged() {
                                if (root.expanded || plasmoid.location === PlasmaCore.Types.Floating) {
                                    fullCanvas.requestPaint();
                                }
                            }
                            function onSelectedTimeframeChanged() {
                                if (root.expanded || plasmoid.location === PlasmaCore.Types.Floating) {
                                    fullCanvas.requestPaint();
                                }
                            }
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            var now = Date.now();
                            var rangeMs = 3600000;
                            var numDividers = 4;
                            if (root.selectedTimeframe === "12h") {
                                rangeMs = 12 * 3600000;
                                numDividers = 6;
                            } else if (root.selectedTimeframe === "24h") {
                                rangeMs = 24 * 3600000;
                                numDividers = 8;
                            } else if (root.selectedTimeframe === "7d") {
                                rangeMs = 7 * 24 * 3600000;
                                numDividers = 7;
                            }

                            var startTime = now - rangeMs;

                            ctx.strokeStyle = root.textColor;
                            ctx.globalAlpha = 0.08;
                            ctx.lineWidth = 1;
                            for (var d = 1; d < numDividers; d++) {
                                var dx = (d / numDividers) * width;
                                ctx.beginPath();
                                ctx.moveTo(dx, 0);
                                ctx.lineTo(dx, height);
                                ctx.stroke();
                            }
                            ctx.globalAlpha = 1.0;

                            var rawSamples = (root.historyStore || []).filter(function(item) {
                                return item.t >= startTime;
                            });

                            if (rawSamples.length === 0) return;

                            var maxDlScale = (root.configuredDlMbps * 1048576);
                            var maxUpScale = (root.configuredUpKbps * 1024);

                            var numBuckets = Math.min(100, Math.max(30, Math.floor(width / 4)));
                            var bucketWidthMs = rangeMs / numBuckets;
                            var samples = [];

                            for (var b = 0; b < numBuckets; b++) {
                                var bStart = startTime + (b * bucketWidthMs);
                                var bEnd = bStart + bucketWidthMs;
                                var inBucket = rawSamples.filter(function(s) {
                                    return s.t >= bStart && s.t < bEnd;
                                });

                                if (inBucket.length > 0) {
                                    var sumDl = 0, sumUp = 0;
                                    for (var k = 0; k < inBucket.length; k++) {
                                        sumDl += inBucket[k].dl;
                                        sumUp += inBucket[k].up;
                                    }
                                    samples.push({
                                        avgDl: sumDl / inBucket.length,
                                        avgUp: sumUp / inBucket.length
                                    });
                                } else {
                                    samples.push({ avgDl: 0, avgUp: 0 });
                                }
                            }

                            root.renderSmoothGraph(ctx, samples, function(s){ return s.avgDl; }, maxDlScale, root.dlColor, true, 0.15, width, height);
                            root.renderSmoothGraph(ctx, samples, function(s){ return s.avgDl; }, maxDlScale, root.dlColor, false, 0.0, width, height);

                            root.renderSmoothGraph(ctx, samples, function(s){ return s.avgUp; }, maxUpScale, root.upColor, true, 0.15, width, height);
                            root.renderSmoothGraph(ctx, samples, function(s){ return s.avgUp; }, maxUpScale, root.upColor, false, 0.0, width, height);
                        }
                    }
                }

                // Data Usage Footer Panel
                RowLayout {
                    visible: root.showDataUsage
                    Layout.fillWidth: true
                    implicitHeight: 20

                    Row {
                        spacing: 5
                        PlasmaComponents3.Label {
                            text: "Session:"
                            color: root.textColor
                            opacity: 0.6
                            font.pixelSize: 12
                        }
                        PlasmaComponents3.Label {
                            text: "↓ " + root.formatBytes(root.sessionDlBytes)
                            color: root.dlColor
                            font.pixelSize: 12
                            font.bold: true
                        }
                        PlasmaComponents3.Label {
                            text: "↑ " + root.formatBytes(root.sessionUpBytes)
                            color: root.upColor
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Row {
                        spacing: 5
                        PlasmaComponents3.Label {
                            text: "Lifetime:"
                            color: root.textColor
                            opacity: 0.6
                            font.pixelSize: 12
                        }
                        PlasmaComponents3.Label {
                            text: "↓ " + root.formatBytes(root.lifetimeDlBytes)
                            color: root.dlColor
                            font.pixelSize: 12
                            font.bold: true
                        }
                        PlasmaComponents3.Label {
                            text: "↑ " + root.formatBytes(root.lifetimeUpBytes)
                            color: root.upColor
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}
