//
//  Context.swift
//
//  linksquared
//

import Foundation

struct Context {
    // Computed property to get and set the linksquared ID from the Keychain
    static var linksquaredID: String? {
        get {
            // Retrieves the value from the Keychain
            return KeychainHelper.getValue(forKey: .linksquaredID)
        }
        set {
            // Sets or removes the value in the Keychain based on the new value
            if let newValue = newValue {
                KeychainHelper.setValue(newValue, forKey: .linksquaredID)
            } else {
                KeychainHelper.removeValue(forKey: .linksquaredID)
            }
        }
    }
}
