import QtQuick
import qs.Common 
import qs.Widgets

DankDropdown {
    id: root

    property var model: null
    property string textRole: "display_name"
    property string valueRole: "id"
    property string currentValueId: ""
    property real maxPopupHeight: 300

    width: parent.width
    dropdownWidth: width
    popupWidth: width
    
    // We map the model to an array of display names. 
    // To include the providerName as a group, we could format it, but sticking to display_name is simpler.
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
        if (!model) return "Select an AI Model...";
        for (var i = 0; i < model.count; i++) {
            if (model.get(i)[valueRole] === currentValueId) {
                return model.get(i)[textRole];
            }
        }
        return "Select an AI Model...";
    }

    onValueChanged: (value) => {
        if (!model) return;
        for (var i = 0; i < model.count; i++) {
            if (model.get(i)[textRole] === value) {
                currentValueId = model.get(i)[valueRole];
                break;
            }
        }
    }
}
