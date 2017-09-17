//: Playground - noun: a place where people can play

import Cocoa
import Swiftify

let artist = try JSONDecoder().decode(SpotifyArtist.self, from: sampleResponses[.artist]!)

let album = try JSONDecoder().decode(SpotifyAlbum.self, from: sampleResponses[.album]!)

let track = try JSONDecoder().decode(SpotifyTrack.self, from: sampleResponses[.track]!)

func parseFindResponse<T: SpotifyItem>(data: Data) -> [T]? {
    let parsed = try? JSONDecoder().decode(SpotifyFindResponse<T>.self, from: data)
    
    return parsed?.results.items
}

let artists: [SpotifyArtist]? = parseFindResponse(data: sampleResponses[.findArtist]!)

let tracks: [SpotifyTrack]? = parseFindResponse(data: sampleResponses[.findTrack]!)

let playlist = try JSONDecoder().decode(SpotifyPlaylist.self, from: sampleResponses[.playlist]!)

