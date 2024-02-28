//
//  LinksquaredManager.swift
//
//  linksquared
//

import Foundation
import UIKit

/// A closure used for completion of boolean values.
typealias LinksquaredBoolCompletion = (_ value: Bool) -> Void

/// A manager class responsible for integrating the Linksquared SDK.
class LinksquaredManager {

    // MARK: - Properties

    /// The API service instance.
    private var apiService: APIService

    /// The API key used for authentication.
    private let apiKey: String

    /// The bundle ID of the app.
    private let bundleID: String

    /// A flag indicating whether the SDK is enabled.
    private var enabled = true

    /// The delegate for the LinksquaredManager.
    var delegate: LinksquaredDelegate?

    // MARK: - Lifecycle

    /// Initializes the LinksquaredManager with the given API key and delegate.
    ///
    /// - Parameters:
    ///   - apiKey: The API key for authentication.
    ///   - delegate: The delegate for the LinksquaredManager.
    init(apiKey: String, delegate: LinksquaredDelegate?) {
        self.apiKey = apiKey
        self.bundleID = AppDetailsHelper.getBundleID()
        self.delegate = delegate
        self.apiService = APIService(apiKey: apiKey, bundleID: self.bundleID)
    }

    // MARK: - Public Methods

    /// Starts the LinksquaredManager.
    func start() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidBecomeActive),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    /// Sets the SDK enabled state.
    ///
    /// - Parameter enabled: A flag indicating whether the SDK is enabled.
    func setEnabled(_ enabled: Bool) {
        DebugLogger.shared.log(.info, "SDK setEnabled to: \(enabled)")
        self.enabled = enabled
    }

    /// Checks the configuration keys asynchronously.
    ///
    /// - Parameter completion: A closure to be called upon completion of the check.
    func checkKeys(completion: @escaping LinksquaredBoolCompletion) {
        if !hasURISchemesConfigured() || !hasAssociatedDomainsConfigured() {
            DebugLogger.shared.log(.error, "URI schemes or Associated domains are not configured, deeplinking won't work!")
            completion(false)
        }

        apiService.checkConfiguration(completion: completion)
    }

    /// Generates a link with the provided parameters.
    ///
    /// - Parameters:
    ///   - title: The title of the link.
    ///   - subtitle: The subtitle of the link.
    ///   - imageURL: The URL of the image associated with the link.
    ///   - data: Additional data to be included in the link.
    ///   - completion: A closure to be called upon completion of link generation.
    func generateLink(title: String?,
                      subtitle: String?,
                      imageURL: String?,
                      data: [String: Any],
                      completion: @escaping LinksquaredURLClosure) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                apiService.generateLink(title: title, subtitle: subtitle, imageURL: imageURL, data: jsonString, completion: completion)
                return
            }
        } catch {
            print("Can not convert data to JSON")
        }
        completion(nil)
    }

    // MARK: - App Lifecycle

    /// Called when the application becomes active.
    @objc func applicationDidBecomeActive() {
        getDataForDevice()
    }

    // MARK: - Private Methods

    /// Retrieves data for the device from the API service.
    private func getDataForDevice() {
        if !enabled {
            return
        }
        apiService.payloadFor(appDetails: AppDetailsHelper.getAppDetails()) { payload in
            self.handleReceivedAction(payload: payload)
        }
    }

    /// Handles a URL received by the application.
    ///
    /// - Parameter url: The URL to handle.
    private func handleURL(url: String) {
        if !enabled {
            return
        }
        apiService.payloadFor(appDetails: AppDetailsHelper.getAppDetails(), url: url) { payload in
            self.handleReceivedAction(payload: payload)
        }
    }

    /// Handles a received action payload.
    ///
    /// - Parameter payload: The payload to handle.
    private func handleReceivedAction(payload: [String: Any]?) {
        if let payload = payload {
            delegate?.linksquaredReceivedPayloadFromDeeplink(payload: payload)
        }
    }
}

// MARK: - Scene Delegate Handler

extension LinksquaredManager {

    /// Handles opening URLs from the scene delegate.
    ///
    /// - Parameter URLContexts: The set of URL contexts.
    @available(iOS 13.0, *)
    func handleSceneDelegate(openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            handleURL(url: url.absoluteString)
        }
    }

    /// Handles continuing user activities from the scene delegate.
    ///
    /// - Parameter userActivity: The user activity to continue.
    func handleSceneDelegate(continue userActivity: NSUserActivity) {
        if let url = userActivity.webpageURL {
            handleURL(url: url.absoluteString)
        }
    }

    /// Handles scene delegate options.
    ///
    /// - Parameter connectionOptions: The connection options.
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

    /// Handles continuing user activities from the app delegate.
    ///
    /// - Parameters:
    ///   - userActivity: The user activity to continue.
    ///   - restorationHandler: The restoration handler closure.
    /// - Returns: A Boolean value indicating whether the activity was handled.
    func handleAppDelegate(continue userActivity: NSUserActivity,
                           restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {

        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            handleURL(url: url.absoluteString)
            return true
        }

        return false
    }

    /// Handles opening URLs from the app delegate.
    ///
    /// - Parameters:
    ///   - url: The URL to open.
    ///   - options: The URL handling options.
    /// - Returns: A Boolean value indicating whether the URL was handled.
    func handleAppDelegate(open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        handleURL(url: url.absoluteString)
        return true
    }
}

extension LinksquaredManager {

    // Check if URI schemes are configured in Info.plist
    func hasURISchemesConfigured() -> Bool {
        guard let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
            return false
        }
        return !urlTypes.isEmpty
    }

    // Check if associated domains are configured in Info.plist
    func hasAssociatedDomainsConfigured() -> Bool {
        guard let associatedDomains = Bundle.main.infoDictionary?["com.apple.developer.associated-domains"] as? [String] else {
            return false
        }
        return !associatedDomains.isEmpty
    }
}
