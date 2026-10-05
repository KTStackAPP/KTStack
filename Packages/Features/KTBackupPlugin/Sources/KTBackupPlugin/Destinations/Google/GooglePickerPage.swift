import Foundation

enum GooglePickerPage {
    static func html(configuration: GooglePickerConfiguration, accessToken: String, nonce: String) -> String {
        let settings = script(["token": accessToken, "key": configuration.apiKey, "appId": configuration.appID, "nonce": nonce])
        return """
        <!doctype html><html><head><meta charset="utf-8"><title>Choose a Google Drive folder · KTStack</title>
        <style>body{font:15px -apple-system,BlinkMacSystemFont,sans-serif;margin:64px auto;max-width:480px;color:#1d1d1f}
        @media(prefers-color-scheme:dark){body{background:#1e1e1e;color:#f5f5f7}}</style></head>
        <body><p id="status">Opening Google Drive…</p>
        <script>
        const settings = \(settings);
        function finish(path) {
          const joiner = path.indexOf("?") < 0 ? "?" : "&";
          location.replace(path + joiner + "n=" + encodeURIComponent(settings.nonce));
        }
        function showPicker() {
          const view = new google.picker.DocsView(google.picker.ViewId.FOLDERS)
            .setIncludeFolders(true).setSelectFolderEnabled(true)
            .setMimeTypes("application/vnd.google-apps.folder");
          new google.picker.PickerBuilder()
            .addView(view)
            .setOAuthToken(settings.token)
            .setDeveloperKey(settings.key)
            .setAppId(settings.appId)
            .setOrigin(location.origin)
            .setTitle("Choose a backup folder")
            .setCallback(function (data) {
              if (data.action === google.picker.Action.PICKED && data.docs && data.docs.length) {
                const doc = data.docs[0];
                finish("/picked?id=" + encodeURIComponent(doc.id) + "&name=" + encodeURIComponent(doc.name));
              } else if (data.action === google.picker.Action.CANCEL) {
                finish("/cancelled");
              }
            })
            .build().setVisible(true);
        }
        function failed() {
          document.getElementById("status").textContent = "Couldn't load Google Picker. Check your network and try again.";
        }
        </script>
        <script src="https://apis.google.com/js/api.js" onload="gapi.load('picker', showPicker)" onerror="failed()"></script>
        </body></html>
        """
    }

    static func script(_ values: [String: String]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: ">", with: "\\u003e")
            .replacingOccurrences(of: "&", with: "\\u0026")
    }
}
