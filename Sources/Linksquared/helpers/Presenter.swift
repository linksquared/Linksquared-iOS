//
//  Presenter.swift
//
//  linksquared
//

import UIKit

class DismissalDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    static let shared = DismissalDelegate() // Singleton instance

    var completion: LinksquaredEmptyClosure? // Store the completion closure

    // This method will be called when the presented view controller is dismissed
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        completion?() // Call the completion closure if it exists
    }

    func viewControllerDidDismiss() {
        completion?()
    }
}

class Presenter {

    /// Presents the given view controller on top of everything else in the app.
    /// - Parameters:
    ///   - viewController: The view controller to present.
    ///   - animated: A flag indicating whether to animate the presentation.
    ///   - completion: A block to execute after the presentation finishes.
    static func presentOnTop(_ viewController: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        // Get the top most view controller
        if let topViewController = getTopViewController() {
            topViewController.present(viewController, animated: animated, completion: completion)
        }
    }

    /// Recursively find the top most view controller.
    /// - Returns: The top most view controller in the app.
    private static func getTopViewController() -> UIViewController? {
        // Get the key window based on the scene or legacy approach
        let keyWindow = getKeyWindow()

        // If we have the key window, find the root view controller
        var topController = keyWindow?.rootViewController

        // Loop through any presented view controllers to find the top one
        while let presentedViewController = topController?.presentedViewController {
            topController = presentedViewController
        }

        return topController
    }

    /// Retrieves the app's key window. Supports both older and newer iOS versions, even if scenes are not used on iOS 13+.
    /// - Returns: The key window in the application.
    private static func getKeyWindow() -> UIWindow? {
        if #available(iOS 13, *) {
            // Check if the app uses scenes or not
            if let windowScene = UIApplication.shared.connectedScenes
                .filter({ $0.activationState == .foregroundActive })
                .compactMap({ $0 as? UIWindowScene })
                .first {
                return windowScene.windows.first { $0.isKeyWindow }
            }
        }

        // For iOS versions before 13, or if the app does not use scenes on iOS 13+
        return UIApplication.shared.keyWindow
    }
}
