//
//  Dictionary+Extension.swift
//
//  linksquared
//

import Foundation

extension Dictionary {

    /// Converts the dictionary to JSON data.
    ///
    /// - Returns: The JSON data representation of the dictionary.
    func dictToData() -> Data? {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: self, options: .prettyPrinted)

            return jsonData
        } catch {
            print(error.localizedDescription)
        }

        return nil
    }
}
