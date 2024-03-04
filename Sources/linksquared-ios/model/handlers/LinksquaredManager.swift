//
//  LinksquaredManager.swift
//
//  linksquared
//

import Foundation
import UIKit

/// A closure used for completion handlers returning boolean values.
typealias LinksquaredBoolCompletion = (_ value: Bool) -> Void

/// A manager class responsible for integrating the Linksquared SDK into the application.
class LinksquaredManager {

    // MARK: - Constants

    private struct Constants {
        static let deviceIDKey = "linkdsquare_device_id"
    }

    // MARK: - Properties

    /// The API service instance responsible for communication with the Linksquared backend.
    private var apiService: APIService

    /// The API key used for authenticating requests to the Linksquared backend.
    private let apiKey: String

    /// The bundle ID of the application.
    private let bundleID: String

    /// A flag indicating whether the Linksquared SDK is enabled.
    private var enabled = true

    /// A flag indicating whether the user is authenticated with the Linksquared backend.
    private var authenticated = false

    /// The URL to handle, used when the user is not authenticated yet.
    private var urlToHandle: String?

    /// The handler for various events related to Linksquared events.
    private let eventsHandler: EventsHandler

    /// The delegate for the LinksquaredManager, allowing customization and handling of Linksquared events.
    var delegate: LinksquaredDelegate?

    // MARK: - Initialization

    /// Initializes the LinksquaredManager with the provided API key and delegate.
    ///
    /// - Parameters:
    ///   - apiKey: The API key for authentication with the Linksquared backend.
    ///   - delegate: The delegate for the LinksquaredManager.
    init(apiKey: String, delegate: LinksquaredDelegate?) {
        self.apiKey = apiKey
        self.bundleID = AppDetailsHelper.getBundleID()
        self.delegate = delegate
        self.apiService = APIService(apiKey: apiKey, bundleID: self.bundleID)
        self.eventsHandler = EventsHandler(apiService: self.apiService)

        addObservers()
    }

    // MARK: - Public Methods

    /// Starts the LinksquaredManager.
    func start() {
        // Implementation for starting the LinksquaredManager, if needed.
    }

    /// Enables or disables the Linksquared SDK.
    ///
    /// - Parameter enabled: A flag indicating whether the SDK should be enabled.
    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        DebugLogger.shared.log(.info, "SDK setEnabled to: \(enabled)")
    }

    /// Generates a link with the provided parameters.
    ///
    /// - Parameters:
    ///   - title: The title of the link.
    ///   - subtitle: The subtitle of the link.
    ///   - imageURL: The URL of the image associated with the link.
    ///   - data: Additional data to include in the link.
    ///   - completion: A closure to be called upon completion of link generation.
    func generateLink(title: String?,
                      subtitle: String?,
                      imageURL: String?,
                      data: [String: Any],
                      completion: @escaping LinksquaredURLClosure) {
        guard enabled else {
            DebugLogger.shared.log(.error, "The SDK is not enabled. Links cannot be generated.")
            completion(nil)
            return
        }

        guard authenticated else {
            DebugLogger.shared.log(.info, "SDK is not ready for usage yet.")
            completion(nil)
            return
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                apiService.generateLink(title: title, subtitle: subtitle, imageURL: imageURL, data: jsonString, completion: completion)
                return
            }
        } catch {
            DebugLogger.shared.log(.error, "Failed to convert data to JSON: \(error.localizedDescription)")
        }

        completion(nil)
    }

    /// Authenticates the user with the Linksquared backend.
    ///
    /// - Parameter completion: A closure called upon completion of authentication, providing a boolean value indicating success.
    func authenticate(completion: @escaping LinksquaredBoolCompletion) {
        guard hasURISchemesConfigured() else {
            DebugLogger.shared.log(.error, "URI schemes or Associated domains are not configured. Deeplinking won't work!")
            completion(false)
            return
        }

        apiService.authenticate(appDetails: AppDetailsHelper.getAppDetails()) { identifier in
            if let identifier = identifier {
                Context.linksquaredID = identifier
                self.authenticated = true

                self.handleURLIfNeeded()
                self.getDataForDevice()

                completion(true)
            } else {
                self.authenticated = false
                completion(false)
            }
        }
    }

    // MARK: - App Lifecycle

    /// Called when the application becomes active.
    @objc func applicationDidBecomeActive() {
        getDataForDevice()
    }

    @objc func applicationWillResignActive() {
        // Implementation for handling application resigning active state, if needed.
    }

    // MARK: - Private Methods

    private func handleURLIfNeeded() {
        if let urlToHandle = urlToHandle {
            handleURL(url: urlToHandle)
        }
    }

    private func addObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillResignActive),
                                               name: UIApplication.willResignActiveNotification,
                                               object: nil)
    }

    private func getDataForDevice() {
        guard enabled, authenticated else {
            return
        }
        apiService.payloadFor(appDetails: AppDetailsHelper.getAppDetails()) { payload in
            self.handleReceivedAction(payload: payload)
        }
    }

    private func handleURL(url: String) {
        guard enabled else {
            return
        }

        if !authenticated {
            urlToHandle = url
            return
        }

        eventsHandler.setLink(link: url)
        apiService.payloadFor(appDetails: AppDetailsHelper.getAppDetails(), url: url) { payload in
            self.handleReceivedAction(payload: payload)
        }
    }

    private func handleReceivedAction(payload: [String: Any]?) {
        if let payload = payload {
            delegate?.linksquaredReceivedPayloadFromDeeplink(payload: payload)
        }
    }
}

// MARK: - Scene Delegate Handler

extension LinksquaredManager {

    @available(iOS 13.0, *)
    func handleSceneDelegate(openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            handleURL(url: url.absoluteString)
        }
    }

    func handleSceneDelegate(continue userActivity: NSUserActivity) {
        if let url = userActivity.webpageURL {
            handleURL(url: url.absoluteString)
        }
    }

    @available(iOS 13.0, *)
    func handleSceneDelegate(options connectionOptions: UIScene.ConnectionOptions) {
        if let url = connectionOptions.urlContexts.first?.url {
            handleURL(url: url.absoluteString)
        }
        if let url = connectionOptions.userActivities.first?.webpageURL {
            handleURL(url: url.absoluteString)
        }
    }
}

// MARK: - App Delegate Handler

extension LinksquaredManager {

    func handleAppDelegate(continue userActivity: NSUserActivity,
                           restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            handleURL(url: url.absoluteString)
            return true
        }

        return false
    }

    func handleAppDelegate(open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        handleURL(url: url.absoluteString)
        return true
    }
}

// MARK: - URI Schemes Configuration

extension LinksquaredManager {

    /// Checks if URI schemes are configured in the Info.plist.
    ///
    /// - Returns: A Boolean value indicating whether URI schemes are configured.
    func hasURISchemesConfigured() -> Bool {
        guard let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
            return false
        }
        return !urlTypes.isEmpty
    }
}
