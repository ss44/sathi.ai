import QtQuick
import qs.Common
import qs.DCommon.Widgets

DDropdown {
    id: root

    property var model: null
    property string textRole: "display_name"
    property string valueRole: "id"
    property string currentValueId: ""

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

    currentValue: {
        if (!model)
            return "";
        for (var i = 0; i < model.count; i++) {
            if (model.get(i)[valueRole] === currentValueId)
                return model.get(i)[textRole];
        }
        return "";
    }

    onValueChanged: (value) => {
        if (!model)
            return;
        for (var i = 0; i < model.count; i++) {
            if (model.get(i)[textRole] === value) {
                currentValueId = model.get(i)[valueRole];
                break;
            }
        }
    }
}
