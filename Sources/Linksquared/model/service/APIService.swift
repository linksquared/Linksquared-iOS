//
//  LinksquaredService.swift
//
//  linksquared
//

import Foundation

/// A typealias for a closure returning a URL.
public typealias LinksquaredURLClosure = (_ url: URL?) -> Void

/// A typealias for a closure returning a dictionary.
public typealias LinksquaredPayloadClosure = (_ dictionary: [String: Any]?) -> Void

public typealias LinksquaredDeviceDataClosureClosure = (_ dictionary: [String: Any]?, _ link: String?) -> Void

/// A typealias for a closure returning a dictionary.
public typealias LinksquaredPayloadsClosure = (_ array: [[String: Any]]?) -> Void

/// A typealias for a closure returning a string.
typealias LinksquaredAuthenticationClosure = (_ success: Bool, _ linksquaredID: String?, _ URIScheme: String?, _ identifier: String?, _ attributes: [String: Any]?) -> Void

/// A class responsible for handling API service calls.
class APIService: BaseService {

    // MARK: - Constants

    private struct Constants {
        struct URLs {
            static let endpoint = "https://sdk.sqd.link/api/v1/sdk"
//            static let endpoint = "http://sdk.lvh.me:3000/api/v1/sdk"

            static let authenticate = "/authenticate"
            static let dataForDevice = "/data_for_device"
            static let dataForDeviceAndURL = "/data_for_device_and_url"
            static let generateLink = "/create_link"
            static let event = "/event"
            static let attributes = "/visitor_attributes"
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
    private var accessKey: String {
        get {
            if useTestEnvironment {
                return "test_" + apiKey
            }

            return apiKey
        }
    }

    /// Indicates if the test environment should be used
    var useTestEnvironment = false

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
    func payloadFor(appDetails: AppDetails, url: String, completion: @escaping LinksquaredDeviceDataClosureClosure) {
        var request = urlRequestWithAuthHeaders(
            path: Constants.URLs.dataForDeviceAndURL)
        request.httpMethod = "POST"

        var body = appDetails.toBackend()
        body["url"] = url

        request.httpBody = body.dictToData()

        DebugLogger.shared.log(.info, "Fetching payload for device and URL")
        makeRequest(URLRequest: request) { success, json in
            guard let json = json, success, let data = json["data"] as? [String: Any] else {
                DebugLogger.shared.log(.info, "Fetching payload for device and URL - No payload")
                completion(nil, nil)
                return
            }

            let link = json["link"] as? String

            DebugLogger.shared.log(.info, "Fetching payload for device and URL - Received payload")
            completion(data, link)
        }
    }

    /// Retrieves payload for app details.
    ///
    /// - Parameters:
    ///   - appDetails: Details of the app.
    ///   - completion: A closure returning the payload as a dictionary.
    func payloadFor(appDetails: AppDetails, completion: @escaping LinksquaredDeviceDataClosureClosure) {
        var request = urlRequestWithAuthHeaders(
            path: Constants.URLs.dataForDevice)
        request.httpMethod = "POST"
        request.httpBody = appDetails.toBackend().dictToData()

        DebugLogger.shared.log(.info, "Fetching payload for device")
        makeRequest(URLRequest: request) { success, json in
            guard let json = json, success, let data = json["data"] as? [String: Any] else {
                DebugLogger.shared.log(.info, "Fetching payload for device - No payload")
                completion(nil, nil)
                return
            }

            let link = json["link"] as? String

            DebugLogger.shared.log(.info, "Fetching payload for device - Received payload")
            completion(data, link)
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
                      tags: String?,
                      completion: @escaping LinksquaredURLClosure) {

        var request = urlRequestWithAuthHeaders(path: Constants.URLs.generateLink)
        request.httpMethod = "POST"
        let body = ["title": title, "subtitle": subtitle, "image_url": imageURL, "data": data, "tags": tags] as [String : Any?]
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
    func authenticate(appDetails: AppDetails, completion: @escaping LinksquaredAuthenticationClosure) {
        var request = urlRequestWithAuthHeaders(
            path: Constants.URLs.authenticate)
        request.httpMethod = "POST"
        request.httpBody = appDetails.toBackend().dictToData()

        DebugLogger.shared.log(.info, "Authenticate")
        makeRequest(URLRequest: request) { success, json in
            guard let json = json, success,
                    let id = json["linksquared"] as? String,
                    let uriScheme = json["uri_scheme"] as? String else {

                DebugLogger.shared.log(.info, "Authenticate - No payload")
                completion(false, nil, nil, nil, nil)
                return
            }

            let identifier = json["sdk_identifier"] as? String
            let attributes = json["sdk_attributes"] as? [String: Any]

            DebugLogger.shared.log(.info, "Authenticate - Received payload")
            completion(true, id, uriScheme, identifier, attributes)
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

    func updateAttributes(completion: @escaping LinksquaredBoolCompletion) {
        var request = urlRequestWithAuthHeaders(path: Constants.URLs.attributes)
        request.httpMethod = "POST"
        let body = ["sdk_identifier": Context.identifier as Any,
                    "sdk_attributes": Context.attributes as Any]
        request.httpBody = body.dictToData()

        DebugLogger.shared.log(.info, "Set attributes")
        makeRequest(URLRequest: request) { success, json in
            guard json != nil, success else {
                DebugLogger.shared.log(.info, "Set attributes - Failed")
                completion(false)
                return
            }

            DebugLogger.shared.log(.info, "Set attributes - Successful")
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
        request.setValue(accessKey, forHTTPHeaderField: Constants.Headers.apiKey)
        request.setValue(bundleID, forHTTPHeaderField: Constants.Headers.identifier)
        request.setValue("ios", forHTTPHeaderField: Constants.Headers.platform)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let userAgent = Context.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }

        if let id = Context.linksquaredID {
            request.setValue(id, forHTTPHeaderField: Constants.Headers.linksquaredID)
        }

        return request
    }

}
