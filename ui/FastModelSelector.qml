import QtQuick
import qs.Common
import qs.DCommon.Widgets
import "../providers/providers.js" as Providers

Column {
    id: root
    width: parent.width
    spacing: Theme.spacingS

    // Duck-typed crawl for the PluginSettings root, same approach as ProviderList.qml
    function findSettings(item) {
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined)
                return item;
            item = item.parent;
        }
        return null;
    }

    property var _settings: null
    property string savedValue: ""
    property string _lastSnapshot: ""

    ListModel {
        id: fastModels
    }

    StyledText {
        width: parent.width
        text: "Fast Model"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Model used to summarize context buckets in the background. Defaults to the main model when unset. A small, fast model works best."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    AiSelector {
        id: selector
        width: parent.width
        model: fastModels
        emptyText: "No models loaded yet..."

        onCurrentValueChanged: (value) => {
            if (!root._settings) {
                return;
            }
            root.savedValue = selector.currentValueId;
            root._settings.saveValue("smartContextModel", selector.currentValueId);
            console.info("[FastModelSelector] Saved fast model: '" + selector.currentValueId + "'");
        }
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        onTriggered: root.refreshModels()
    }

    Component.onCompleted: {
        root._settings = findSettings(root.parent);
        if (root._settings) {
            root.savedValue = root._settings.loadValue("smartContextModel", "");
        }
        refreshModels();
    }

    function refreshModels() {
        Providers.listModels(function(models) {
            var snapshot = "";
            var entries = [{ display_name: "Main model (default)", id: "" }];
            if (models) {
                for (var i = 0; i < models.length; i++) {
                    entries.push({ display_name: models[i].display_name, id: models[i].id });
                }
            }
            for (var e = 0; e < entries.length; e++) {
                snapshot += entries[e].id + "|";
            }

            if (snapshot === root._lastSnapshot) {
                return;
            }
            root._lastSnapshot = snapshot;

            fastModels.clear();
            for (var j = 0; j < entries.length; j++) {
                fastModels.append(entries[j]);
            }
            // Re-assert selection after repopulation (no binding, avoids loops)
            selector.currentValueId = root.savedValue;
        });
    }
}