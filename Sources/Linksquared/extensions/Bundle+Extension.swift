//
//  Bundle+Extension.swift
//
//  linksquared
//

import Foundation

extension Bundle {

    static var framework: Bundle {
        get {
            let bundle = Bundle(for: Linksquared.self)

            return bundle
        }
    }
}
