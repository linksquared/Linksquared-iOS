# Linksquared iOS SDK

[Linksquared](https://linksquared.io) is a powerful SDK that enables deep linking and universal linking within your iOS applications. This document serves as a guide to integrate and utilize Linksquared seamlessly within your project.

<br />
<br />

## Installation

### SPM

Linksquared is available as a Swift Package Manager (SPM) package. You can add it to your project by following these steps:

1. In Xcode, go to File -> Swift Packages -> Add Package Dependency.
2. Enter the repository URL: `https://github.com/your-repository/linksquared.git`.
3. Select the version range that fits your project requirements.
4. Click Next, then Finish.
   <br />
   <br />

### COCOAPODS

To integrate the SDK using COCOCAPODS, add the pod to your Podfile

```
pod 'Linksquared'
```

<br />
<br />

## Configuration

To configure the Linksquared SDK within your application, follow these steps:

1. Import the Linksquared module in your Swift file:

```swift
import Linksquared
```

1. Initialize the SDK with your API key (usually in AppDelegate):

```swift
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {

        Linksquared.configure(APIKey: "your-api-key", delegate: yourDelegate)

        # Optionally, you can adjust the debug level for logging:

        Linksquared.setDebug(level: .info)

        ... Your other code ...
    }
```

### Scene Delegate Integration

If your application uses a scene delegate, you need to forward relevant calls to Linksquared.

```swift
// Handle open URL contexts
@available(iOS 13.0, *)
func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    Linksquared.handleSceneDelegate(openURLContexts: URLContexts)
}

// Handle continue user activity
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    Linksquared.handleSceneDelegate(continue: userActivity)
}

// Handle scene delegate options
@available(iOS 13.0, *)
func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    Linksquared.handleSceneDelegate(options: connectionOptions)
}

```

### App Delegate Integration

If your application doesn't use a scene delegate, you should forward relevant calls from the app delegate to Linksquared:

```swift

// Handle universal link continuation
func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    return Linksquared.handleAppDelegate(continue: userActivity, restorationHandler: restorationHandler)
}

// Handle URI opening
func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    return Linksquared.handleAppDelegate(open: url, options: options)
}

```

## Usage

Once configured, you can utilize the various functionalities provided by Linksquared.

### Handling deeplinks

You can receive deep link events by conforming to the LinksquaredDelegate protocol. Here's how you can implement it:

```swift

class YourViewController: UIViewController, LinksquaredDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        Linksquared.delegate = self
    }

    // Implement the delegate method
    func linksquaredReceivedPayloadFromDeeplink(payload: [String: Any]) {
        // Handle the received payload here
    }
}

```

### Generating Links

```swift

Linksquared.generateLink(title: "Link Title", subtitle: "Link Subtitle", imageURL: "imageURL", data: ["key": "value"]) { url in
    // Handle generated URL
}

```

## Further Assistance

For further assistance and detailed documentation, refer to the Linksquared documentation available at https://linksquared.io/docs.

For technical support and inquiries, contact our support team at [support@linksquared.io](mailto:support@linksquared.io).

Thank you for choosing Linksquared! We're excited to see what you build with our SDK.

<br />
<br />
Copyright linksquared.
