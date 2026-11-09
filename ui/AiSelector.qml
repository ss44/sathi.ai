import QtQuick
import qs.Common
import qs.DCommon.Widgets

DDropdown {
    id: root

    property var model: null
    property string textRole: "display_name"
    property string valueRole: "id"
    property alias currentValueId: root.currentValue

    compactMode: true
    triggerHeight: Theme.buttonHeightXS
    triggerRadius: Theme.cornerRadius
    popupWidth: width
    emptyText: "Select an AI Model..."

    options: {
        var opts = [];
        if (model) {
            for (var i = 0; i < model.count; i++) {
                opts.push(model.get(i)[textRole]);
            }
        }
        return opts;
    }

    optionValues: {
        var vals = [];
        if (model) {
            for (var i = 0; i < model.count; i++) {
                vals.push(model.get(i)[valueRole]);
            }
        }
        return vals;
    }
}
