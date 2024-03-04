//
//  Linksquared.swift
//
//  linksquared
//

import UIKit

/// A protocol for receiving payload from Linksquared SDK.
public protocol LinksquaredDelegate {
    func linksquaredReceivedPayloadFromDeeplink(payload: [String: Any])
}

/// A class representing Linksquared SDK.
public class Linksquared {

    /// The delegate to receive callbacks from the SDK.
    public static var delegate: LinksquaredDelegate? {
        set {
            manager.delegate = newValue
        }

        get {
            return manager.delegate
        }
    }

    /// The API key used for linking the SDK to your account.
    private static var APIKey: String!

    /// The manager handling Linksquared functionality.
    private static var manager: LinksquaredManager!

    // MARK: Public methods

    /// Configures the Linksquared SDK with the provided API key.
    ///
    /// - Parameters:
    ///   - APIKey: The API key obtained from the web console at https://linksquared.io.
    ///   - delegate: The delegate to receive payload from the SDK.
    public static func configure(APIKey: String, delegate: LinksquaredDelegate?) {
        self.APIKey = APIKey
        self.manager = LinksquaredManager(apiKey: APIKey, delegate: delegate)

        self.checkConfiguration()
    }

    /// Disables the Linksquared SDK.
    /// - Parameter enabled: The log level to set.
    /// Default is true.
    public static func setSDK(enabled: Bool) {
        manager.setEnabled(enabled)
    }

    /// Sets the debug level for the SDK log messages.
    /// - Parameter level: The log level to set.
    /// Default is error.
    public static func setDebug(level: LogLevel) {
        DebugLogger.shared.logLevel = level
    }

    /// Generates a link.
    ///
    /// - Parameters:
    ///   - title: The title of the link.
    ///   - subtitle: The subtitle of the link.
    ///   - imageURL: The URL of the image associated with the link.
    ///   - data: Additional data for the link.
    ///   - completion: A closure to be executed after generating the link.
    public static func generateLink(title: String?,
                                    subtitle: String?,
                                    imageURL: String?,
                                    data: [String: Any],
                                    completion: @escaping LinksquaredURLClosure) {

        manager.generateLink(title: title, subtitle: subtitle, imageURL: imageURL, data: data, completion: completion)
    }

    // MARK: Private methods

    /// Checks the configuration validity.
    private static func checkConfiguration() {
        guard let APIKey = APIKey, APIKey.count > 0 else {
            fatalError("API Key is invalid. Make sure you've used the right value from the Web interface.")
        }

        self.manager.authenticate { success in
            if !success {
                DebugLogger.shared.log(.error, "Can not initialize the SDK, the Bundle Key combo is invalid")
            } else {
                self.manager.start()
            }
        }
    }
}

// MARK: Public scene delegate forward -- This should be called if you're using a scene delegate

extension Linksquared {
    /// Handles open URL contexts for scene delegate.
    ///
    /// - Parameter URLContexts: The set of open URL contexts.
    @available(iOS 13.0, *)
    public static func handleSceneDelegate(openURLContexts URLContexts: Set<UIOpenURLContext>) {
        // Handle URI
        manager.handleSceneDelegate(openURLContexts: URLContexts)
    }

    /// Handles continue user activity for scene delegate.
    ///
    /// - Parameter userActivity: The user activity.
    public static func handleSceneDelegate(continue userActivity: NSUserActivity) {
        // Handle Universal Link
        manager.handleSceneDelegate(continue: userActivity)
    }

    /// Handles options for scene delegate.
    ///
    /// - Parameter connectionOptions: The connection options.
    @available(iOS 13.0, *)
    public static func handleSceneDelegate(options connectionOptions: UIScene.ConnectionOptions) {
        // Handle both URI and Universal links
        manager.handleSceneDelegate(options: connectionOptions)
    }
}


// MARK: Public scene delegate forward -- This should be called if you're using a the app delegate WITHOUT Scene Delegate

extension Linksquared {

    /// Handles universal link continuation for iOS 13 and later.
    ///
    /// - Parameters:
    ///   - userActivity: The user activity to continue.
    ///   - restorationHandler: A block to execute if the app is launched into the background to handle the user activity.
    /// - Returns: A Boolean value indicating whether the universal link continuation was handled successfully.
    public static func handleAppDelegate(continue userActivity: NSUserActivity,
                                         restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // Handle universal link
        return manager.handleAppDelegate(continue: userActivity, restorationHandler: restorationHandler)
    }

    /// Handles URI opening.
    ///
    /// - Parameters:
    ///   - url: The URL to open.
    ///   - options: A dictionary of URL handling options.
    /// - Returns: A Boolean value indicating whether the URI opening was handled successfully.

    public static func handleAppDelegate(open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle URI
        return manager.handleAppDelegate(open: url, options: options)
    }
}
