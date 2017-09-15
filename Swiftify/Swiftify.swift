//
//  Swiftify.swift
//  Swiftify
//
//  Created by Marco Albera on 30/01/17.
//
//

import Cocoa

import Alamofire
import SwiftyJSON

// MARK: Token saving options

enum TokenSavingMethod {
    case file
    case preference
}

// MARK: Spotify queries addresses

/**
 Parameter names for Spotify HTTP requests
 */
fileprivate struct SpotifyParameter {
    // Search
    static let name = "q"
    static let type = "type"
    
    // Authorization
    static let clientId     = "client_id"
    static let responseType = "response_type"
    static let redirectUri  = "redirect_uri"
    static let scope        = "scope"
    
    // Token
    static let clientSecret = "client_secret"
    static let grantType    = "grant_type"
    static let code         = "code"
    static let refreshToken = "refresh_token"
    
    // User's library
    static let ids          = "ids"
}

/**
 Header names for Spotify HTTP requests
 */
fileprivate struct SpotifyHeader {
    // Authorization
    static let authorization = "Authorization"
}

// MARK: Queries data types

/**
 URLs for Spotify HTTP queries
 */
fileprivate enum SpotifyQuery: String {
    // TODO: Make this more understandable
    
    // Search
    case search    = "https://api.spotify.com/v1/search"
    case album     = "https://api.spotify.com/v1/albums"
    case user      = "https://api.spotify.com/v1/users"
    
    // Authentication
    case authorize = "https://accounts.spotify.com/authorize"
    case token     = "https://accounts.spotify.com/api/token"
    
    // User's library
    case tracks    = "https://api.spotify.com/v1/me/tracks"
    case albums    = "https://api.spotify.com/v1/me/albums"
    case playlists = "https://api.spotify.com/v1/me/playlists"
    case contains  = "https://api.spotify.com/v1/me/tracks/contains"
    
    static func urlForTracksIn(_ type: SpotifyItemType,
                               _ id: String,
                               _ userId: String? = nil) -> URLConvertible {
        switch type {
        case .album:
            return (SpotifyQuery.album.rawValue + "/\(id)/tracks") as URLConvertible
        case .playlist:
            guard let userId = userId else { return "" }
            
            return (SpotifyQuery.user.rawValue + "/\(userId)/playlists/\(id)/tracks") as URLConvertible
        default:
            return ""
        }
    }
    
    public var url: URLConvertible {
        return self.rawValue as URLConvertible
    }
}

/**
 Scopes (aka permissions) required by our app
 during authorization phase
 // TODO: test this more
 */
fileprivate enum SpotifyScope: String {
    case readPrivate   = "user-read-private"
    case readEmail     = "user-read-email"
    case libraryModify = "user-library-modify"
    case libraryRead   = "user-library-read"
    
    /**
     Creates a string to pass as parameter value
     with desired scope keys
     */
    static func string(with scopes: [SpotifyScope]) -> String {
        var string = ""
        
        for scope in scopes {
            // Add the selected scopes
            string += "\(scope.rawValue) "
        }
        
        // Delete last space character
        return String(string[..<string.index(before: string.endIndex)])
    }
}

fileprivate enum SpotifyAuthorizationResponseType: String {
    case code = "code"
}

fileprivate enum SpotifyAuthorizationType: String {
    case basic  = "Basic "
    case bearer = "Bearer "
}

/**
 Spotify authentication grant types for obtaining token
 */
fileprivate enum SpotifyTokenGrantType: String {
    case authorizationCode = "authorization_code"
    case refreshToken      = "refresh_token"
}

/**
 Item type for Spotify search query
 */
public enum SpotifyItemType: String {
    case track    = "track"
    case album    = "album"
    case artist   = "artist"
    case playlist = "playlist"
}

// MARK: Items data types

public struct SpotifyTrack: Decodable {
    public var id:     String
    public var uri:    String
    public var name:   String
    public var album:  SpotifyAlbum
    
    var artists = [SpotifyArtist]()
    
    public var artist: SpotifyArtist {
        set {
            artists = [newValue]
        }
        
        get {
            return artists.first!
        }
    }
    
    init(from item: JSON) {
        self.id     = item["id"].stringValue
        self.uri    = item["uri"].stringValue
        self.name   = item["name"].stringValue
        self.album  = SpotifyAlbum(from: item["album"])
        self.artist = SpotifyArtist(from: item["artists"][0])
    }
}

public struct SpotifyAlbum: Decodable {
    struct Image: Decodable {
        var url: String
    }
    
    public var id:     String
    public var uri:    String
    public var name:   String
    
    var images  = [Image]()
    var artists = [SpotifyArtist]()
    
    public var artist: SpotifyArtist {
        set {
            artists = [newValue]
        }
        
        get {
            return artists.first!
        }
    }
    
    public var artUri: String {
        set {
            images = [Image(url: newValue)]
        }
        
        get {
            return images.first!.url
        }
    }
    
    init(from item: JSON) {
        self.id     = item["id"].stringValue
        self.uri    = item["uri"].stringValue
        self.name   = item["name"].stringValue
        self.artUri = item["images"][0]["url"].stringValue
        self.artist = SpotifyArtist(from: item["artists"][0])
    }
}

public struct SpotifyPlaylist: Decodable {
    public var id:   String
    public var uri:  String
    public var name: String
    
    init(from item: JSON) {
        self.id   = item["id"].stringValue
        self.uri  = item["uri"].stringValue
        self.name = item["name"].stringValue
    }
}

public struct SpotifyArtist: Decodable {
    public var id:     String
    public var uri:    String
    public var name:   String
    
    init(from item: JSON) {
        self.id     = item["id"].stringValue
        self.uri    = item["uri"].stringValue
        self.name   = item["name"].stringValue
    }
}

public class SwiftifyHelper {
    
    public struct SpotifyDeveloperApplication {
        var clientId:     String
        var clientSecret: String
        var redirectUri:  String
        
        public init(clientId:     String,
                    clientSecret: String,
                    redirectUri:  String) {
            self.clientId     = clientId
            self.clientSecret = clientSecret
            self.redirectUri  = redirectUri
        }
        
        public init(from item: JSON) {
            self.clientId     = item["client_id"].stringValue
            self.clientSecret = item["client_secret"].stringValue
            self.redirectUri  = item["redirect_uri"].stringValue
        }
    }
    
    private struct SpotifyToken {
        var accessToken:  String
        var expiresIn:    Int
        var refreshToken: String
        var tokenType:    String
        var saveTime:     TimeInterval
        
        static let preferenceKey = "spotifyToken"
        
        init(accessToken:  String,
             expiresIn:    Int,
             refreshToken: String,
             tokenType:    String) {
            self.accessToken  = accessToken
            self.expiresIn    = expiresIn
            self.refreshToken = refreshToken
            self.tokenType    = tokenType
            self.saveTime     = Date.timeIntervalSinceReferenceDate
        }
        
        init(from json: JSON) {
            self.init(accessToken:  json["access_token"].stringValue,
                      expiresIn:    json["expires_in"].intValue,
                      refreshToken: json["refresh_token"].stringValue,
                      tokenType:    json["token_type"].stringValue)
        }
        
        init(from dictionary: [String: Any]) {
            self.init(accessToken:  dictionary["access_token"] as? String ?? "",
                      expiresIn:    dictionary["expires_in"] as? Int ?? 0,
                      refreshToken: dictionary["refresh_token"] as? String ?? "",
                      tokenType:    dictionary["token_type"] as? String ?? "")
        }
        
        /**
         Returns a dictionary representation suited for usage in preferences.
         */
        var dictionaryRepresentation: [String: Any] {
            return ["access_token":  self.accessToken,
                    "expires_in":    self.expiresIn,
                    "refresh_token": self.refreshToken,
                    "token_type":    self.tokenType]
        }
        
        /**
         Writes the contents of the token back to the JSON file.
         This allows to save new data when a new token is received.
         http://stackoverflow.com/questions/28768015/how-to-save-an-array-as-a-json-file-in-swift
         */
        func writeJSON(to path: URL?) {
            guard let path = path else { return }
            
            do {
                // Open the JSON file
                var item = try JSON(Data(contentsOf: path))
                
                // Update it
                item["access_token"].stringValue  = self.accessToken
                item["expires_in"].intValue       = self.expiresIn
                item["refresh_token"].stringValue = self.refreshToken
                item["token_type"].stringValue    = self.tokenType
                
                // Open the file stream for writing
                let file = try FileHandle(forUpdating: path)
                
                // Actually write back to the file
                if let data = item.description.data(using: .utf8) { file.write(data) }
            } catch {
                // Item has not been updated
            }
        }
        
        /**
         Writes the contents of the token to a preference.
         */
        func writePreference() {
            UserDefaults.standard.set(self.dictionaryRepresentation,
                                      forKey: SpotifyToken.preferenceKey)
        }
        
        /**
         Loads the token object from a preference.
         */
        static func loadPreference() -> SpotifyToken? {
            if let dictionaryRepresentation = UserDefaults.standard.value(forKey: preferenceKey) as? [String: Any] {
                return self.init(from: dictionaryRepresentation)
            }
            
            return nil
        }
        
        /**
         Updates a token from a JSON, for instance after calling 'refreshToken',
         when only a new 'accessToken' is provided
         */
        mutating func refresh(from item: JSON) {
            accessToken = item["access_token"].stringValue
            saveTime    = Date.timeIntervalSinceReferenceDate
        }
        
        /**
         Returns whether a token is expired basing on saving time,
         current time and provided duration limit
         */
        var isExpired: Bool {
            return Date.timeIntervalSinceReferenceDate - saveTime > Double(expiresIn)
        }
        
        /**
         Returns true if the token is valid (aka not blank)
         */
        var isValid: Bool {
            return  self.accessToken  != "" &&
                self.expiresIn    != 0  &&
                self.refreshToken != "" &&
                self.tokenType    != ""
        }
        
        var description: NSString {
            let description =   "Access token:  \(accessToken)\r\n" +
                "Expires in:    \(expiresIn)\r\n" +
                "Refresh token: \(refreshToken)\r\n" +
            "Token type:    \(tokenType)"
            
            return description as NSString
        }
    }
    
    private var application: SpotifyDeveloperApplication?
    
    private var tokenSavingMethod: TokenSavingMethod = .preference
    
    private var applicationJsonURL: URL?
    
    private var token: SpotifyToken?
    
    private var tokenJsonURL: URL?
    
    // MARK: Constructors
    
    public static let shared = SwiftifyHelper()
    
    private init() { }
    
    public init(with application: SpotifyDeveloperApplication) {
        self.application = application
        
        if let token = SpotifyToken.loadPreference() {
            self.token = token
        }
    }
    
    public init(with applicationJsonURL: URL? = nil,
                _ tokenJsonURL: URL?          = nil,
                fallbackURL: URL?             = nil) {
        if let applicationURL = applicationJsonURL {
            do {
                try self.application = SpotifyDeveloperApplication(from: JSON(Data(contentsOf: applicationURL)))
            } catch {
                if let applicationURL = fallbackURL {
                    do {
                        try self.application = SpotifyDeveloperApplication(from: JSON(Data(contentsOf: applicationURL)))
                    } catch { }
                }
            }
            self.applicationJsonURL = applicationURL
        }
        
        if let tokenURL = tokenJsonURL {
            do {
                try self.token = SpotifyToken(from: JSON(Data(contentsOf: tokenURL)))
            } catch { }
            self.tokenJsonURL = tokenURL
            
            // Set the proper toking saving method
            // if a JSON file URL is available
            self.tokenSavingMethod = .file
        } else if let token = SpotifyToken.loadPreference() {
            self.token = token
        }
    }
    
    // MARK: Query functions
    
    private func tokenQuery(operation: @escaping (SpotifyToken) -> ()) {
        guard let token = self.token else { return }
        
        guard !token.isExpired else {
            // If the token is expired, refresh it first
            // Then try repeating the operation
            refreshToken { refreshed in
                if refreshed {
                    operation(token)
                }
            }
            
            return
        }
        
        // Run the requested query operation
        operation(token)
    }
    
    /**
     Finds tracks on Spotify that match a provided keyword
     - parameter track: the track name
     - parameter completionHandler: the block to run when results
     are found and passed as parameter to it
     */
    public func find(_ type: SpotifyItemType,
                     _ keyword: String,
                     completionHandler: @escaping ([Any]) -> Void) {
        tokenQuery { token in
            Alamofire.request(SpotifyQuery.search.url,
                              method: .get,
                              parameters: self.searchParameters(for: type, keyword),
                              headers: self.authorizationHeader(with: token))
                .responseJSON { response in
                    guard let response = response.result.value else { return }
                    
                    var results: [Any] = []
                    
                    let json = JSON(response)
                    
                    for (_, item) : (String, JSON) in json[type.rawValue + "s"]["items"] {
                        switch type {
                        case .track:
                            results.append(SpotifyTrack(from: item))
                        case .album:
                            results.append(SpotifyAlbum(from: item))
                        case .artist:
                            results.append(SpotifyArtist(from: item))
                        case .playlist:
                            results.append(SpotifyPlaylist(from: item))
                        }
                    }
                    
                    completionHandler(results)
            }
        }
    }
    
    /**
     Finds the first track on Spotify matching search results for
     - parameter title: the title of the track
     - parameter artist: the artist of the track
     - parameter completionHandler: the handler that is executed with the track as parameter
     */
    func getTrack(title: String,
                  artist: String,
                  completionHandler: @escaping (SpotifyTrack) -> Void) {
        find(.track, "\(title) \(artist)") { results in
            if let track = results.first as? SpotifyTrack {
                completionHandler(track)
            }
        }
    }
    
    // MARK: Authorization
    
    /**
     Retrieves the authorization code with user interaction
     Note: this only opens the browser window with the proper request,
     you then have to manually copy the 'code' from the opened url
     and insert it to get the actual token
     */
    public func authorize() {
        guard let application = application else { return }
        
        Alamofire.request(SpotifyQuery.authorize.url,
                          method: .get,
                          parameters: authorizationParameters(for: application))
            .response { response in
                if let request = response.request, let url = request.url {
                    NSWorkspace.shared.open(url)
                }
        }
    }
    
    /**
     Retrieves the token from the authorization code and saves it locally
     - parameter authorizationCode: the code received from Spotify redirected uri
     */
    public func saveToken(from authorizationCode: String) {
        guard let application = application else { return }
        
        Alamofire.request(SpotifyQuery.token.url,
                          method: .post,
                          parameters: tokenParameters(for: application,
                                                      from: authorizationCode))
            .validate().responseJSON { response in
                if response.result.isSuccess {
                    self.token = self.generateToken(from: response)
                    
                    // Prints the token for debug
                    if let token = self.token {
                        debugPrint(token.description)
                        
                        switch self.tokenSavingMethod {
                        case .file:
                            // Save token to JSON file
                            token.writeJSON(to: self.tokenJsonURL)
                        case .preference:
                            token.writePreference()
                        }
                    }
                }
        }
    }
    
    /**
     Generates a token from values provided by the user
     - parameters: the token data
     */
    public func saveToken(accessToken:  String,
                          expiresIn:    Int,
                          refreshToken: String,
                          tokenType:    String) {
        self.token = SpotifyToken(accessToken: accessToken,
                                  expiresIn: expiresIn,
                                  refreshToken: refreshToken,
                                  tokenType: tokenType)
        
        // Prints the token for debug
        if let token = self.token { debugPrint(token.description) }
    }
    
    /**
     Returns if the helper is currently holding a token
     */
    public var hasToken: Bool {
        guard let token = token else { return false }
        
        // Only return true if the token is actually valid
        return token.isValid
    }
    
    /**
     Refreshes the token when expired
     */
    public func refreshToken(completionHandler: @escaping (Bool) -> Void) {
        guard let application = application, let token = self.token else { return }
        
        Alamofire.request(SpotifyQuery.token.url,
                          method: .post,
                          parameters: refreshTokenParameters(from: token),
                          headers: refreshTokenHeaders(for: application))
            .validate().responseJSON { response in
                completionHandler(response.result.isSuccess)
                
                if response.result.isSuccess {
                    guard let response = response.result.value else { return }
                    
                    // Refresh current token
                    // Only 'accessToken' needs to be changed
                    // guard is not really needed here because we checked before
                    self.token?.refresh(from: JSON(response))
                    
                    // Prints the token for debug
                    if let token = self.token { debugPrint(token.description) }
                }
        }
    }
    
    // MARK: User library interaction
    
    /**
     Gets the first saved tracks/albums/playlists in user's library
     - parameter type: .track, .album or .playlist
     - parameter completionHandler: the callback to run, passes the tracks array
     as argument
     // TODO: read more than 20/10 items
     */
    public func library(_ type: SpotifyItemType,
                        completionHandler: @escaping ([Any]) -> Void) {
        tokenQuery { token in
            var url: URLConvertible
            
            // Pick the correct URL for track or album
            switch type {
            case .track:
                url = SpotifyQuery.tracks.url
            case .album:
                url = SpotifyQuery.albums.url
            case .playlist:
                url = SpotifyQuery.playlists.url
            default:
                // Artists are not supported
                return
            }
            
            Alamofire.request(url,
                              method: .get,
                              headers: self.authorizationHeader(with: token))
                .responseJSON { response in
                    guard let response = response.result.value else { return }
                    
                    var results: [Any] = []
                    
                    let json = JSON(response)
                    
                    for (_, item) : (String, JSON) in json["items"] {
                        switch type {
                        case .track:
                            results.append(SpotifyTrack(from: item[type.rawValue]))
                        case .album:
                            results.append(SpotifyAlbum(from: item[type.rawValue]))
                        case .playlist:
                            results.append(SpotifyPlaylist(from: item))
                        default:
                            break
                        }
                    }
                    
                    completionHandler(results)
            }
        }
    }
    
    /**
     Fetches the first tracks contained in a user playlist or album
     - parameter type: the source type of the tracks, .album or .playlist
     - parameter id: the id of the source
     - parameter userId: the name of the source owner, required for playlist only
     */
    public func tracks(in type: SpotifyItemType,
                       _ id: String,
                       userId: String? = nil,
                       completionHandler: @escaping ([SpotifyTrack]) -> Void) {
        switch type {
        case .album:
            Alamofire.request(SpotifyQuery.urlForTracksIn(.album, id),
                              method: .get)
                .responseJSON { response in
                    guard let response = response.result.value else { return }
                    
                    completionHandler(self.tracks(from: JSON(response), source: .album))
            }
        case .playlist:
            guard let token = self.token, let userId = userId else { return }
            
            // Browsing a user playlist requires authorization
            // TODO: Test this
            Alamofire.request(SpotifyQuery.urlForTracksIn(.playlist, id, userId),
                              method: .get,
                              headers: authorizationHeader(with: token))
                .responseJSON { response in
                    guard let response = response.result.value else { return }
                    
                    completionHandler(self.tracks(from: JSON(response), source: .playlist))
            }
        default:
            return
        }
    }
    
    /**
     Saves a track to user's "Your Music" library
     - parameter trackId: the id of the track to save
     - parameter completionHandler: the callback to execute after response,
     brings the saving success as parameter
     */
    public func save(trackId: String,
                     completionHandler: @escaping (Bool) -> Void) {
        tokenQuery { token in
            Alamofire.request(SpotifyQuery.tracks.url,
                              method: .put,
                              parameters: self.trackIdsParameters(for: trackId),
                              encoding: URLEncoding(destination: .queryString),
                              headers: self.authorizationHeader(with: token))
                .validate().responseData { response in
                    completionHandler(response.result.isSuccess)
            }
        }
    }
    
    /**
     Saves a track to user's "Your Music" library
     - parameter track: the 'SpotifyTrack' object to save
     - parameter completionHandler: the callback to execute after response,
     brings the saving success as parameter
     */
    public func save(track: SpotifyTrack,
                     completionHandler: @escaping (Bool) -> Void) {
        save(trackId: track.id, completionHandler: completionHandler)
    }
    
    /**
     Deletes a track from user's "Your Music" library
     - parameter trackId: the id of the track to save
     - parameter completionHandler: the callback to execute after response,
     brings the deletion success as parameter
     */
    public func delete(trackId: String,
                       completionHandler: @escaping (Bool) -> Void) {
        tokenQuery { token in
            Alamofire.request(SpotifyQuery.tracks.url,
                              method: .delete,
                              parameters: self.trackIdsParameters(for: trackId),
                              encoding: URLEncoding(destination: .queryString),
                              headers: self.authorizationHeader(with: token))
                .validate().responseData { response in
                    completionHandler(response.result.isSuccess)
            }
        }
    }
    
    /**
     Deletes a track from user's "Your Music" library
     - parameter track: the 'SpotifyTrack' object to save
     - parameter completionHandler: the callback to execute after response,
     brings the deletion success as parameter
     */
    public func delete(track: SpotifyTrack,
                       completionHandler: @escaping (Bool) -> Void) {
        delete(trackId: track.id, completionHandler: completionHandler)
    }
    
    /**
     Checks if a track is saved into user's "Your Music" library
     - parameter track: the id of the track to check
     - parameter completionHandler: the callback to execute after response,
     brings 'isSaved' as parameter
     */
    public func isSaved(trackId: String,
                        completionHandler: @escaping (Bool) -> Void) {
        tokenQuery { token in
            Alamofire.request(SpotifyQuery.contains.url,
                              method: .get,
                              parameters: self.trackIdsParameters(for: trackId),
                              headers: self.authorizationHeader(with: token))
                .responseJSON { response in
                    guard let value = response.result.value else { return }
                    
                    // Sends the 'isSaved' value back to the completion handler
                    completionHandler(JSON(value)[0].boolValue)
            }
        }
    }
    
    /**
     Checks if a track is saved into user's "Your Music" library
     - parameter track: the 'SpotifyTrack' object to check
     - parameter completionHandler: the callback to execute after response,
     brings 'isSaved' as parameter
     */
    public func isSaved(track: SpotifyTrack,
                        completionHandler: @escaping (Bool) -> Void) {
        isSaved(trackId: track.id, completionHandler: completionHandler)
    }
    
    // MARK: Helper functions
    
    /**
     Builds search query parameters for an element on Spotify
     - return: searchquery parameters
     */
    private func searchParameters(for type: SpotifyItemType,
                                  _ keyword: String) -> Parameters {
        return [SpotifyParameter.name: keyword,
                SpotifyParameter.type: type.rawValue]
    }
    
    /**
     Builds authorization parameters
     */
    private func authorizationParameters(for application: SpotifyDeveloperApplication) -> Parameters {
        return [SpotifyParameter.clientId: application.clientId,
                SpotifyParameter.responseType: SpotifyAuthorizationResponseType.code.rawValue,
                SpotifyParameter.redirectUri: application.redirectUri,
                SpotifyParameter.scope: SpotifyScope.string(with: [.readPrivate, .readEmail, .libraryModify, .libraryRead])]
    }
    
    /**
     Builds token parameters
     - return: parameters for token retrieval
     */
    private func tokenParameters(for application: SpotifyDeveloperApplication,
                                 from authorizationCode: String) -> Parameters {
        return [SpotifyParameter.clientId: application.clientId,
                SpotifyParameter.clientSecret: application.clientSecret,
                SpotifyParameter.grantType: SpotifyTokenGrantType.authorizationCode.rawValue,
                SpotifyParameter.code: authorizationCode,
                SpotifyParameter.redirectUri: application.redirectUri]
    }
    
    /**
     Builds token refresh parameters
     - return: parameters for token refresh
     */
    private func refreshTokenParameters(from oldToken: SpotifyToken) -> Parameters {
        return [SpotifyParameter.grantType: SpotifyTokenGrantType.refreshToken.rawValue,
                SpotifyParameter.refreshToken: oldToken.refreshToken]
    }
    
    /**
     Builds the authorization header for token refresh
     - return: authorization header
     */
    private func refreshTokenHeaders(for application: SpotifyDeveloperApplication) -> HTTPHeaders {
        guard let auth = Request.authorizationHeader(user: application.clientId, password: application.clientSecret) else { return [:] }
        
        return [auth.key: auth.value]
    }
    
    /**
     Builds the authorization header for user library interactions
     - return: authorization header
     */
    private func authorizationHeader(with token: SpotifyToken) -> HTTPHeaders {
        return [SpotifyHeader.authorization: SpotifyAuthorizationType.bearer.rawValue +
            token.accessToken]
    }
    
    /**
     Builds parameters for saving a track into user's library
     - return: parameters for track saving
     */
    private func trackIdsParameters(for trackId: String) -> Parameters {
        return [SpotifyParameter.ids: trackId]
    }
    
    /**
     Generates a 'SpotifyToken' from a JSON response
     - return: the 'SpotifyToken' object
     */
    private func generateToken(from response: DataResponse<Any>) -> SpotifyToken? {
        guard let response = response.result.value else { return nil }
        
        let json = JSON(response)
        
        return SpotifyToken(from: json)
    }
    
    /**
     Generates an array of 'SpotifyTrack's from JSON data
     - parameter json: the JSON containing the tracks
     - return: the array of tracks
     */
    private func tracks(from json: JSON, source: SpotifyItemType) -> [SpotifyTrack] {
        var tracks: [SpotifyTrack] = []
        
        for (_, item) : (String, JSON) in json["items"] {
            switch source {
            case .album:
                tracks.append(SpotifyTrack(from: item))
            case .playlist:
                tracks.append(SpotifyTrack(from: item["track"]))
            default:
                break
            }
        }
        
        return tracks
    }
    
}
