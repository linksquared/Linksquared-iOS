//
//  LinksquaredService.swift
//
//  linksquared
//

import Foundation

/// A typealias for a closure returning a URL.
public typealias LinksquaredURLClosure = (_ url: URL?) -> Void

/// A typealias for a closure returning a dictionary.
typealias LinksquaredDictionaryClosure = (_ dictionary: [String: Any]?) -> Void

/// A typealias for a closure returning a string.
typealias LinksquaredStringClosure = (_ string: String?) -> Void

/// A class responsible for handling API service calls.
class APIService: BaseService {

    // MARK: - Constants

    private struct Constants {
        struct URLs {
            static let endpoint = "https://sdk.sqd.link/api/v1/sdk"
            static let authenticate = "/authenticate"
            static let dataForDevice = "/data_for_device"
            static let dataForDeviceAndURL = "/data_for_device_and_url"
            static let generateLink = "/create_link"
            static let event = "/event"
        }
        struct Headers {
            static let apiKey = "PROJECT-KEY"
            static let identifier = "IDENTIFIER"
            static let platform = "PLATFORM"
            static let linksquaredID = "LINKSQUARED"
        }
    }

    // MARK: - Properties

    private let apiKey: String
    private let bundleID: String

    // MARK: - Lifecycle

    /// Initializes an `APIService` object with the provided API key and bundle ID.
    ///
    /// - Parameters:
    ///   - apiKey: The API key for authentication.
    ///   - bundleID: The bundle ID of the app.
    init(apiKey: String, bundleID: String) {
        self.apiKey = apiKey
        self.bundleID = bundleID
    }

    // MARK: - Public Methods

    /// Retrieves payload for app details and a URL.
    ///
    /// - Parameters:
    ///   - appDetails: Details of the app.
    ///   - url: The URL to retrieve payload for.
    ///   - completion: A closure returning the payload as a dictionary.
    func payloadFor(appDetails: AppDetails, url: String, completion: @escaping LinksquaredDictionaryClosure) {
        var request = urlRequestWithAuthHeaders(path: Constants.URLs.dataForDeviceAndURL)
        request.httpMethod = "POST"

        var body = appDetails.toBackend()
        body["url"] = url

        request.httpBody = body.dictToData()

        DebugLogger.shared.log(.info, "Fetching payload for device and URL")
        makeRequest(URLRequest: request) { success, json in
            guard let json = json, success, let data = json["data"] as? [String: Any] else {
                DebugLogger.shared.log(.info, "Fetching payload for device and URL - No payload")
                completion(nil)
                return
            }

            DebugLogger.shared.log(.info, "Fetching payload for device and URL - Received payload")
            completion(data)
        }
    }

    /// Retrieves payload for app details.
    ///
    /// - Parameters:
    ///   - appDetails: Details of the app.
    ///   - completion: A closure returning the payload as a dictionary.
    func payloadFor(appDetails: AppDetails, completion: @escaping LinksquaredDictionaryClosure) {
        var request = urlRequestWithAuthHeaders(path: Constants.URLs.dataForDevice)
        request.httpMethod = "POST"
        request.httpBody = appDetails.toBackend().dictToData()

        DebugLogger.shared.log(.info, "Fetching payload for device")
        makeRequest(URLRequest: request) { success, json in
            guard let json = json, success, let data = json["data"] as? [String: Any] else {
                DebugLogger.shared.log(.info, "Fetching payload for device - No payload")
                completion(nil)
                return
            }

            DebugLogger.shared.log(.info, "Fetching payload for device - Received payload")
            completion(data)
        }
    }

    /// Generates a link.
    ///
    /// - Parameters:
    ///   - title: The title for the link.
    ///   - subtitle: The subtitle for the link.
    ///   - imageURL: The image URL for the link.
    ///   - data: Additional data for the link.
    ///   - completion: A closure returning the generated link as a URL.
    func generateLink(title: String?,
                      subtitle: String?,
                      imageURL: String?,
                      data: String?,
                      completion: @escaping LinksquaredURLClosure) {

        var request = urlRequestWithAuthHeaders(path: Constants.URLs.generateLink)
        request.httpMethod = "POST"
        let body = ["title": title, "subtitle": subtitle, "image_url": imageURL, "data": data]
        request.httpBody = body.dictToData()

        DebugLogger.shared.log(.info, "Generating link")
        makeRequest(URLRequest: request) { success, json in
            guard let json = json, success, let link = json["link"] as? String, let url = URL(string: link) else {
                DebugLogger.shared.log(.error, "Generating link FAILED")
                completion(nil)
                return
            }

            DebugLogger.shared.log(.info, "Generating link \(url.absoluteString)")
            completion(url)
        }
    }

    /// Authenticates the app.
    ///
    /// - Parameters:
    ///   - appDetails: Details of the app.
    ///   - completion: A closure returning the Linksquared ID as a string.
    func authenticate(appDetails: AppDetails, completion: @escaping LinksquaredStringClosure) {
        var request = urlRequestWithAuthHeaders(path: Constants.URLs.authenticate)
        request.httpMethod = "POST"
        request.httpBody = appDetails.toBackend().dictToData()

        DebugLogger.shared.log(.info, "Authenticate")
        makeRequest(URLRequest: request) { success, json in
            guard let json = json, success, let data = json["linksquared_id"] as? String else {
                DebugLogger.shared.log(.info, "Authenticate - No payload")
                completion(nil)
                return
            }

            DebugLogger.shared.log(.info, "Authenticate - Received payload")
            completion(data)
        }
    }

    /// Adds an event.
    ///
    /// - Parameters:
    ///   - event: The event to add.
    ///   - completion: A closure indicating the success or failure of the operation.
    func addEvent(event: Event, completion: @escaping LinksquaredBoolCompletion) {
        var request = urlRequestWithAuthHeaders(path: Constants.URLs.event)
        request.httpMethod = "POST"
        request.httpBody = event.toBackend().dictToData()

        DebugLogger.shared.log(.info, "Add event")
        makeRequest(URLRequest: request) { success, json in
            guard json != nil, success else {
                DebugLogger.shared.log(.info, "Add event - Failed")
                completion(false)
                return
            }

            DebugLogger.shared.log(.info, "Add event - Successful")
            completion(true)
        }
    }

    // MARK: - Private Methods

    /// Constructs a URLRequest with authentication headers.
    ///
    /// - Parameter path: The path to append to the base URL.
    /// - Returns: A URLRequest object with authentication headers set.
    private func urlRequestWithAuthHeaders(path: String) -> URLRequest {
        let endpoint = Constants.URLs.endpoint + path
        let url = URL(string: endpoint)!

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: Constants.Headers.apiKey)
        request.setValue(bundleID, forHTTPHeaderField: Constants.Headers.identifier)
        request.setValue("ios", forHTTPHeaderField: Constants.Headers.platform)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let id = Context.linksquaredID {
            request.setValue(id, forHTTPHeaderField: Constants.Headers.linksquaredID)
        }

        return request
    }

}
