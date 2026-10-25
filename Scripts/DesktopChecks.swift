import Foundation

@main struct DesktopChecks {
    static func main() throws {
        let dictionary = try ScriptingDictionary(applicationURL: URL(fileURLWithPath: "/System/Applications/Music.app"))
        guard dictionary.properties["player position"] == DesktopPlayer.code("pPos"),
              let current = dictionary.properties["current track"],
              let identifier = dictionary.properties["persistent id"],
              dictionary.enumerators["playing"] != nil else { fatalError("Music scripting dictionary missing expected properties") }
        let track = try DesktopPlayer.propertySpecifier(current)
        let nested = try DesktopPlayer.propertySpecifier(identifier, container: track)
        guard track.descriptorType == DesktopPlayer.code("obj "), nested.descriptorType == DesktopPlayer.code("obj "),
              let record = nested.coerce(toDescriptorType: DesktopPlayer.code("reco")),
              record.forKeyword( DesktopPlayer.code("seld"))?.typeCodeValue == identifier,
              record.forKeyword( DesktopPlayer.code("from"))?.descriptorType == DesktopPlayer.code("obj ") else {
            fatalError("Invalid nested Apple Event property descriptor")
        }
        print("Desktop adapter: installed Music dictionary and nested Apple Event descriptors validated. No events sent; live playback still requires manual testing.")
    }
}
