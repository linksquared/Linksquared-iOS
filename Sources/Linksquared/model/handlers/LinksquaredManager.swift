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

    /// Stores the payloads received since the startup
    private var receivedPayloads = [[String: Any]]()

    /// Stores weather the app or scene delegates were called
    private var handledAppOrSceneDelegates = false

    /// Closures to be called for the last payload
    private var lastPayloadClosureArray = [LinksquaredPayloadClosure]()

    /// Closures to be called for the payloads
    private var payloadsClosureArray = [LinksquaredPayloadsClosure]()

    /// Stores if attributes needs to be updated after auth
    private var shouldUpdateAttributes = false

    /// The delegate for the LinksquaredManager, allowing customization and handling of Linksquared events.
    var delegate: LinksquaredDelegate?

    /// Indicates if the test environment should be used
    var useTestEnvironment = false {
        didSet {
            apiService.useTestEnvironment = useTestEnvironment
        }
    }

    /// The identifier for the current user, normally a userID. This will be visible in the linksquared dashboard.
    var identifier: String? {
        set {
            Context.identifier = newValue
            updateAttributesIfNeeded()
        }
        get {
            Context.identifier
        }
    }

    /// The attributes for the current user. This will be visible in the linksquared dashboard.
    var attributes: [String: Any]? {
        set {
            Context.attributes = newValue
            updateAttributesIfNeeded()
        }
        get {
            Context.attributes
        }
    }

    /// A property representing the push notification token.
    ///
    /// This token is used for identifying the device to receive push notifications.
    var pushToken: String? {
        set {
            Context.pushToken = newValue
            updateAttributesIfNeeded()
        }
        
        get {
            Context.pushToken
        }
    }

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

    /// Enables or disables the Linksquared SDK.
    ///
    /// - Parameter enabled: A flag indicating whether the SDK should be enabled.
    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        DebugLogger.shared.log(.info, "SDK setEnabled to: \(enabled)")
    }

    /// Starts the LinksquaredManager.
    func start() {
        // Implementation for starting the LinksquaredManager, if needed.
    }

    /// Generates a link with the provided parameters.
    ///
    /// - Parameters:
    ///   - title: The title of the link.
    ///   - subtitle: The subtitle of the link.
    ///   - imageURL: The URL of the image associated with the link.
    ///   - data: Additional data to include in the link.
    ///   - tags: Tags for the link.
    ///   - completion: A closure to be called upon completion of link generation.
    func generateLink(title: String?,
                      subtitle: String?,
                      imageURL: String?,
                      data: [String: Any]?,
                      tags: [String]?,
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
            var jsonString: String?
            if let data = data {
                let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                jsonString = String(data: jsonData, encoding: .utf8)
            }

            var tagsString: String?
            if let tags = tags {
                let jsonData = try JSONSerialization.data(withJSONObject: tags, options: .prettyPrinted)
                tagsString = String(data: jsonData, encoding: .utf8)
            }

            apiService.generateLink(title: title, subtitle: subtitle, imageURL: imageURL, data: jsonString, tags: tagsString, completion: completion)
            return
        } catch {
            DebugLogger.shared.log(.error, "Failed to convert data to JSON: \(error.localizedDescription)")
        }

        completion(nil)
    }

    /// Adds a closure to receive the last payload data.
    ///
    /// This method appends the provided closure to an array of closures that will be invoked when the last payload data is received. It then checks if payloads have been received and invokes the appropriate handler to process them.
    ///
    /// - Parameter completion: A closure that takes a dictionary representing the payload data as its parameter.
    func getLastPayload(completion: @escaping LinksquaredPayloadClosure) {
        lastPayloadClosureArray.append(completion)

        handlePayloadsReceivedIfNeeded()
    }

    /// Adds a closure to receive all payloads received since startup.
    ///
    /// This method appends the provided closure to an array of closures that will be invoked when all payloads received since startup are available. It then checks if payloads have been received and invokes the appropriate handler to process them.
    ///
    /// - Parameter completion: A closure that takes an array of dictionaries, each representing a payload data, as its parameter.
    func getAllPayloadsSinceStartup(completion: @escaping LinksquaredPayloadsClosure) {
        payloadsClosureArray.append(completion)

        handlePayloadsReceivedIfNeeded()
    }

    /// Authenticates the user with the Linksquared backend.
    ///
    /// - Parameter completion: A closure called upon completion of authentication, providing a boolean value indicating success.
    func authenticate(completion: @escaping LinksquaredBoolCompletion) {
        guard hasURISchemesConfigured() else {
            DebugLogger.shared.log(.error, "URI schemes are not configured. Deeplinking won't work!")
            completion(false)
            return
        }

        // Fetch the user agent
        handleUserAgent {
            // Handle app details
            self.apiService.authenticate(appDetails: AppDetailsHelper.getAppDetails()) { success, linksquaredID, uriScheme, identifier, attributes in
                guard let linksquaredID = linksquaredID, let uriScheme = uriScheme, success else {
                    self.authenticated = false
                    completion(false)

                    return
                }

                Context.linksquaredID = linksquaredID

                // Update context attributes if needed
                if !self.shouldUpdateAttributes {
                    Context.identifier = identifier
                    Context.attributes = attributes
                }

                self.authenticated = true

                self.checkIfURISchemeProperlySet(uriScheme: uriScheme)
                self.handleURLIfNeeded()
                self.getDataForDevice()
                self.updateAttributesIfNeeded()

                completion(true)
            }
        }
    }
    /// Retrieves notifications for a specified page.
    ///
    /// - Parameters:
    ///   - page: The page number of notifications to retrieve. This allows for pagination of notifications.
    ///   - completion: A closure that will be called with an array of notifications when the request completes.
    func getNotifications(page: Int, completion: @escaping LinksquaredNotificationsClosure) {
        apiService.notifications(page: page, completion: completion) // Delegates the call to the API service.
    }

    /// Retrieves the number of unread notifications.
    ///
    /// - Parameter completion: A closure that will be called with the count of unread notifications, or `nil` if the request fails.
    func getNumberOfUnreadNotifications(completion: @escaping LinksquaredIntClosure) {
        apiService.numberOfUnreadNotifications(completion: completion) // Delegates the call to the API service.
    }

    /// Marks a specific notification as read.
    ///
    /// - Parameters:
    ///   - notificationID: The unique identifier of the notification to mark as read.
    ///   - completion: A closure that will be called with a boolean indicating the success or failure of the operation.
    func markNotificationAsRead(notificationID: Int, completion: @escaping LinksquaredBoolCompletion) {
        apiService.markNotificationAsRead(notificationID: notificationID, completion: completion) // Delegates the call to the API service.
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

    private func updateAttributesIfNeeded() {
        if !authenticated {
            shouldUpdateAttributes = true
        }

        apiService.updateAttributes { value in
            if value {
                self.shouldUpdateAttributes = false
            }
        }
    }

    private func handleUserAgent(completion: @escaping LinksquaredEmptyClosure) {
        UserAgentHelper.getSafariUserAgent { userAgent in
            Context.userAgent = userAgent
            completion()
        }
    }

    private func handlePayloadsReceivedIfNeeded() {
        guard authenticated, handledAppOrSceneDelegates else {
            return
        }

        payloadsClosureArray.forEach { closure in
            closure(receivedPayloads)
        }
        payloadsClosureArray.removeAll()

        lastPayloadClosureArray.forEach { closure in
            closure(receivedPayloads.last)
        }
        lastPayloadClosureArray.removeAll()
    }

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

        self.apiService.payloadFor(appDetails: AppDetailsHelper.getAppDetails()) { payload, link in
            self.eventsHandler.setLinkToNewFutureActions(link: link)

            self.handleReceivedAction(payload: payload)
            self.displayAutomaticNotificationsIfNeeded()
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

        eventsHandler.setLinkToNewFutureActions(link: url)
        self.apiService.payloadFor(appDetails: AppDetailsHelper.getAppDetails(), url: url) { payload, link in
            self.eventsHandler.setLinkToNewFutureActions(link: link)
            self.handleReceivedAction(payload: payload)
        }
    }

    private func handleReceivedAction(payload: [String: Any]?) {
        if let payload = payload {
            receivedPayloads.append(payload)

            delegate?.linksquaredReceivedPayloadFromDeeplink(payload: payload)
        }

        handlePayloadsReceivedIfNeeded()
    }

    private func displayAutomaticNotificationsIfNeeded() {
        apiService.notificationsToDisplayAutomatically { notifications in
            guard let notifications = notifications else {
                return
            }

            self.automaticallyDisplayNotifications(notifications: notifications)
        }
    }

    private func automaticallyDisplayNotifications(notifications: [Notification]) {
        let dispatchGroup = DispatchGroup()

        // Process each notification one by one
        DispatchQueue.global(qos: .background).async {
            for notification in notifications {
                dispatchGroup.enter()

                // Display each notification sequentially
                self.displayNotification(notification: notification) {
                    dispatchGroup.leave() // Leave the group once the notification is displayed
                }

                dispatchGroup.wait()
            }
        }
    }

    private func displayNotification(notification: Notification, completion: @escaping LinksquaredEmptyClosure) {
        // Ensure that the presentation happens on the main thread
        DispatchQueue.main.async {
            if let vc = MessageDetailsViewController.loadVCFromNib() {
                vc.notification = notification
                vc.manager = self

                // Present the notification view controller on top
                Presenter.presentOnTop(vc, animated: false) {
                    // Call the completion handler after the presentation is done
                    completion()
                }
            }
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

        handledAppOrSceneDelegates = true
    }

    func handleSceneDelegate(continue userActivity: NSUserActivity) {
        if let url = userActivity.webpageURL {
            handleURL(url: url.absoluteString)
        }

        handledAppOrSceneDelegates = true
    }

    @available(iOS 13.0, *)
    func handleSceneDelegate(connectionOptions: UIScene.ConnectionOptions) {
        if let url = connectionOptions.urlContexts.first?.url {
            handleURL(url: url.absoluteString)
        }

        if let url = connectionOptions.userActivities.first?.webpageURL {
            handleURL(url: url.absoluteString)
        }

        handledAppOrSceneDelegates = true
    }
}

// MARK: - App Delegate Handler

extension LinksquaredManager {

    func handleAppDelegate(continue userActivity: NSUserActivity,
                           restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        defer {
            handledAppOrSceneDelegates = true
        }

        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            handleURL(url: url.absoluteString)
            return true
        }

        return false
    }

    func handleAppDelegate(open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        handleURL(url: url.absoluteString)

        handledAppOrSceneDelegates = true

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

    /// Checks if a specific URI scheme is properly configured in the app's Info.plist.
    ///
    /// - Parameter uriScheme: The URI scheme to check.
    func checkIfURISchemeProperlySet(uriScheme: String) {
        // Retrieve the URL types from the Info.plist.
        guard let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
            return
        }

        let parsedSchema = uriScheme.replacingOccurrences(of: "://", with: "")

        // Iterate through the URL types to find the specified URI scheme.
        for urlType in urlTypes {
            if let role = urlType["CFBundleTypeRole"] as? String, let schemes = urlType["CFBundleURLSchemes"] as? [String], role == "Editor" {
                if schemes.contains(parsedSchema) {
                    // If the URI scheme is found, log success and return.
                    DebugLogger.shared.log(.info, "URL Scheme properly configured.")
                    return
                }
            }
        }

        // Log an error if the URI scheme is not properly configured.
        DebugLogger.shared.log(.error, "There's a mismatch between the URL Scheme in the project and the one from the dashboard, deeplinking won't function properly!")
    }
}
