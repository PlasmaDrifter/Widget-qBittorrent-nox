import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.iconthemes as KIconThemes
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_webUiUrl: webUiUrlField.text
    property alias cfg_username: usernameField.text
    property alias cfg_password: passwordField.text
    property alias cfg_updateInterval: updateIntervalSpin.value

    property alias cfg_dlMaxMbps: dlMaxField.value
    property alias cfg_upMaxKbps: upMaxField.value
    property alias cfg_showDataUsage: showDataUsageCheckBox.checked

    property alias cfg_bgOpacity: bgOpacitySlider.value
    property alias cfg_cornerRadius: cornerRadiusSpin.value

    property string cfg_iconName: "qbittorrent"
    property string cfg_iconColor: "#ffffff"
    property alias cfg_useIconColor: colorizeCheck.checked

    property alias cfg_bgColor: bgColorSwatch.color
    property alias cfg_textColor: textColorSwatch.color
    property alias cfg_dlColor: dlColorSwatch.color
    property alias cfg_upColor: upColorSwatch.color

    component ColorRow: RowLayout {
        id: colorRow
        property alias color: swatch.color
        property alias dialog: colorDialog

        Rectangle {
            id: swatch
            width: Kirigami.Units.gridUnit * 1.6
            height: Kirigami.Units.gridUnit * 1.6
            radius: 4
            border.width: 1
            border.color: Kirigami.Theme.disabledTextColor

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: colorDialog.open()
            }
        }

        QQC2.Button {
            text: i18n("Choose…")
            onClicked: colorDialog.open()
        }

        ColorDialog {
            id: colorDialog
            options: ColorDialog.ShowAlphaChannel
            selectedColor: swatch.color
            onAccepted: swatch.color = selectedColor
        }
    }

    // --- Network & Connection ---
    Kirigami.Separator { Kirigami.FormData.label: "Connection"; Kirigami.FormData.isSection: true }

    QQC2.TextField {
        id: webUiUrlField
        Kirigami.FormData.label: "Web UI URL:"
        placeholderText: "http://100.76.111.34:8080"
    }

    QQC2.TextField {
        id: usernameField
        Kirigami.FormData.label: "Username:"
        placeholderText: "nobara"
    }

    QQC2.TextField {
        id: passwordField
        Kirigami.FormData.label: "Password:"
        echoMode: QQC2.TextField.Password
    }

    QQC2.SpinBox {
        id: updateIntervalSpin
        Kirigami.FormData.label: "Update Interval (Seconds):"
        from: 1
        to: 60
        stepSize: 1
    }

    // --- Scaling & Data Usage ---
    Kirigami.Separator { Kirigami.FormData.label: "Scaling & Data Display"; Kirigami.FormData.isSection: true }

    QQC2.SpinBox {
        id: dlMaxField
        Kirigami.FormData.label: "Download Max Scale (MB/s):"
        from: 1
        to: 10000
        stepSize: 5
    }

    QQC2.SpinBox {
        id: upMaxField
        Kirigami.FormData.label: "Upload Max Scale (KB/s):"
        from: 50
        to: 1000000
        stepSize: 100
    }

    QQC2.CheckBox {
        id: showDataUsageCheckBox
        Kirigami.FormData.label: "Display Session & Lifetime Data Usage:"
        checked: true
    }

    // --- Appearance & Styling ---
    Kirigami.Separator { Kirigami.FormData.label: "Appearance & Colors"; Kirigami.FormData.isSection: true }

    RowLayout {
        Kirigami.FormData.label: i18n("Panel icon:")
        spacing: Kirigami.Units.smallSpacing

        QQC2.Button {
            icon.name: page.cfg_iconName && page.cfg_iconName.length > 0 ? page.cfg_iconName : "qbittorrent"
            text: i18n("Choose Icon…")
            onClicked: iconDialog.open()
        }

        QQC2.Button {
            text: i18n("Browse File…")
            icon.name: "document-open"
            onClicked: iconFileDialog.open()
        }

        QQC2.ToolButton {
            icon.name: "edit-clear"
            text: i18n("Reset to default")
            display: QQC2.AbstractButton.IconOnly
            onClicked: page.cfg_iconName = "qbittorrent"
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered
        }
    }

    KIconThemes.IconDialog {
        id: iconDialog

        onIconNameChanged: (iconName) => {
            if (iconName && iconName.length > 0)
                page.cfg_iconName = iconName;
        }
    }

    FileDialog {
        id: iconFileDialog
        title: "Select Custom Icon / Image File"
        currentFolder: "file:///usr/share/icons"
        nameFilters: ["Icon & Image Files (*.png *.svg *.svgz *.ico *.jpg *.jpeg)", "All Files (*)"]
        onAccepted: {
            if (selectedFile) {
                page.cfg_iconName = selectedFile.toString();
            }
        }
    }

    QQC2.CheckBox {
        id: colorizeCheck
        Kirigami.FormData.label: i18n("Colourize icon:")
        text: i18n("Tint icon with a custom colour")
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Icon colour:")
        spacing: Kirigami.Units.smallSpacing
        enabled: colorizeCheck.checked
        opacity: colorizeCheck.checked ? 1 : 0.4

        Rectangle {
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            radius: 4
            color: page.cfg_iconColor
            border.color: Kirigami.Theme.disabledTextColor
            border.width: 1

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: iconColorDialog.open()
            }
        }

        QQC2.Button {
            text: i18n("Choose Color…")
            onClicked: iconColorDialog.open()
        }

        QQC2.ToolButton {
            icon.name: "edit-clear"
            text: i18n("Reset to default")
            display: QQC2.AbstractButton.IconOnly
            onClicked: page.cfg_iconColor = "#ffffff"
            QQC2.ToolTip.text: text
            QQC2.ToolTip.visible: hovered
        }
    }

    ColorDialog {
        id: iconColorDialog
        title: "Choose Icon Color"
        selectedColor: page.cfg_iconColor
        onAccepted: page.cfg_iconColor = selectedColor.toString()
    }

    ColorRow {
        id: bgColorSwatch
        Kirigami.FormData.label: i18n("Background color:")
    }

    RowLayout {
        Kirigami.FormData.label: i18n("Background Transparency:")
        QQC2.Slider {
            id: bgOpacitySlider
            from: 0.0
            to: 1.0
            stepSize: 0.05
        }
        QQC2.Label {
            text: Math.round(bgOpacitySlider.value * 100) + "%"
        }
    }

    QQC2.SpinBox {
        id: cornerRadiusSpin
        Kirigami.FormData.label: i18n("Corner Roundness (Radius):" )
        from: 0
        to: 30
        stepSize: 1
    }

    ColorRow {
        id: textColorSwatch
        Kirigami.FormData.label: i18n("Text / Numbers color:")
    }

    ColorRow {
        id: dlColorSwatch
        Kirigami.FormData.label: i18n("Download graph color:")
    }

    ColorRow {
        id: upColorSwatch
        Kirigami.FormData.label: i18n("Upload graph color:")
    }
}
