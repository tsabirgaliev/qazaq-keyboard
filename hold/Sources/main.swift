// "Kazakh - PC+ Hold" input method: the Kazakh - PC+ layout plus an ABC-style long-press popup.
import Cocoa
import InputMethodKit

let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String ?? "dev_tair_KazakhPCPlus_Connection"
guard let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier) else {
    Log.error("could not create IMKServer \(connectionName)")
    exit(1)
}
Log.debug("started: \(Variants.table.count) letters with variants")
withExtendedLifetime(server) { NSApplication.shared.run() }
