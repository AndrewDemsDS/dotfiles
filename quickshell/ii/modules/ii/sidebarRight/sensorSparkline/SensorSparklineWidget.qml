import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/*
 * Sidebar card: live mini-graphs of Home Assistant sensors (SensorSparkline service).
 * Each configured sensor renders as a Canvas polyline scaled to its own min/max, with the
 * name + current value + unit beside it. Hidden until enabled.
 */
Rectangle {
    id: root
    Layout.fillWidth: true
    visible: Config.options.sensorSparkline.enable && SensorSparkline.model.length > 0
    implicitHeight: visible ? contentCol.implicitHeight + 20 : 0
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    clip: true

    ColumnLayout {
        id: contentCol
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 12
            rightMargin: 12
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            MaterialSymbol {
                text: "monitoring"
                iconSize: 24
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Sensors")
                color: Appearance.colors.colOnLayer1
                font.pixelSize: Appearance.font.pixelSize.normal
            }
        }

        Repeater {
            model: SensorSparkline.model
            delegate: RowLayout {
                id: sensorRow
                required property var modelData
                Layout.fillWidth: true
                spacing: 10

                Canvas {
                    id: spark
                    Layout.preferredWidth: 84
                    Layout.preferredHeight: 28
                    readonly property var series: sensorRow.modelData.series
                    readonly property real lo: sensorRow.modelData.min
                    readonly property real hi: sensorRow.modelData.max
                    readonly property color strokeColor: Appearance.colors.colPrimary
                    onSeriesChanged: requestPaint()
                    onStrokeColorChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const n = series ? series.length : 0;
                        if (n < 2)
                            return;
                        const pad = 2;
                        const w = width - pad * 2;
                        const h = height - pad * 2;
                        const span = (hi - lo) > 0 ? (hi - lo) : 1;
                        ctx.lineWidth = 1.5;
                        ctx.strokeStyle = strokeColor;
                        ctx.lineJoin = "round";
                        ctx.beginPath();
                        for (let i = 0; i < n; i++) {
                            const x = pad + (n === 1 ? 0 : (i / (n - 1)) * w);
                            const y = pad + (1 - (series[i] - lo) / span) * h;
                            if (i === 0)
                                ctx.moveTo(x, y);
                            else
                                ctx.lineTo(x, y);
                        }
                        ctx.stroke();
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: sensorRow.modelData.name
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        readonly property real cur: sensorRow.modelData.current
                        text: isNaN(cur) ? Translation.tr("no data") : `${root.fmt(cur)}${sensorRow.modelData.unit.length > 0 ? " " + sensorRow.modelData.unit : ""}`
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    function fmt(v) {
        if (isNaN(v))
            return "–";
        const a = Math.abs(v);
        if (a >= 100)
            return String(Math.round(v));
        if (a >= 10)
            return v.toFixed(1);
        return v.toFixed(2);
    }
}
