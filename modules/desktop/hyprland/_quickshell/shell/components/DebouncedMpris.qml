import Quickshell.Services.Mpris
import QtQuick

// debounces metadata clearing so track changes don't flash empty
QtObject {
    id: root

    required property MprisPlayer player // qmllint disable unresolved-type

    readonly property bool isPlaying: player?.playbackState === MprisPlaybackState.Playing // qmllint disable unresolved-type
    readonly property bool hasMedia: player !== null && title !== ""

    readonly property string _rawTitle: player?.trackTitle ?? ""
    readonly property string _rawArtist: player?.trackArtist ?? ""
    readonly property string _rawAlbum: player?.trackAlbum ?? ""
    readonly property string _rawArtUrl: player?.trackArtUrl ?? ""

    // one-shot seed, the handlers below clobber these bindings on purpose
    property string title: _rawTitle
    property string artist: _rawArtist
    property string album: _rawAlbum
    property string artUrl: _rawArtUrl

    function _debounce(raw: string, prop: string) {
        if (raw !== "")
            root[prop] = raw;
        else
            _clearDelay.restart();
    }

    on_RawTitleChanged: _debounce(_rawTitle, "title")
    on_RawArtistChanged: _debounce(_rawArtist, "artist")
    on_RawAlbumChanged: _debounce(_rawAlbum, "album")
    on_RawArtUrlChanged: _debounce(_rawArtUrl, "artUrl")

    property Timer _clearDelay: Timer {
        // players briefly blank metadata between tracks
        interval: 800
        onTriggered: {
            root.title = root._rawTitle;
            root.artist = root._rawArtist;
            root.album = root._rawAlbum;
            root.artUrl = root._rawArtUrl;
        }
    }
}
