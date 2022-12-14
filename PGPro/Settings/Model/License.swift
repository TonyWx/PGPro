//
//  License.swift
//  PGPro
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

class License {

    /// Name of the library / framework / ...
    var title: String
    /// Description of the library / framework / ...
    var subtitle: String?
    /// Actual license of the library / framework / ...
    var licenseURL: URL

    init(for name: String, describedBy description: String? = nil, at url: URL) {
        title = name
        subtitle = description
        licenseURL = url
    }

}

class Licenses {

    private init() {}

    static let allLicenses: [License] = [
        License(for: "PGPro",
                describedBy: "OpenPGP en- & decryption app for iOS",
                at: URL(string: "https://github.com/lucanaef/PGPro/blob/master/LICENSE")!),
        License(for: "ObjectivePGP",
                describedBy: "OpenPGP library for iOS and macOS",
                at: URL(string: "https://objectivepgp.com/LICENSE.txt")!),
        License(for: "OpenSSL",
                describedBy: "Cryptography and SSL/TLS Toolkit",
                at: URL(string: "https://www.openssl.org/source/license-openssl-ssleay.txt")!),
        License(for: "SwiftTryCatch",
                describedBy: "Adds Objective-C try-catch support for Swift",
                at: URL(string: "https://github.com/seanparsons/SwiftTryCatch/blob/master/LICENSE")!),
        License(for: "Navajo-Swift",
                describedBy: "Password Validator & Strength Evaluator",
                at: URL(string: "https://github.com/jasonnam/Navajo-Swift/blob/master/LICENSE")!),
        License(for: "Swiftlogger",
                describedBy: "Tiny Logger in Swift",
                at: URL(string: "https://github.com/sauvikdolui/swiftlogger/blob/master/LICENSE")!),
        License(for: "IsoCountryCodes",
                describedBy: "Provides ISO codes, names and currencies for countries",
                at: URL(string: "https://github.com/funky-monkey/IsoCountryCodes")!),
        License(for: "CodeScanner",
                describedBy: "A SwiftUI view that is able to scan barcodes, QR codes, and more",
                at: URL(string: "https://github.com/twostraws/CodeScanner/blob/main/LICENSE")!),
        License(for: "MimeParser",
                describedBy: "MimeParser is a simple MIME parsing library written in Swift",
                at: URL(string: "https://github.com/miximka/MimeParser/blob/master/LICENSE")!),
        License(for: "EmptyDataSet-Swift",
                describedBy: "A drop-in UITableView/UICollectionView superclass category for showing empty datasets whenever the view has no content to display.",
                at: URL(string: "https://github.com/Xiaoye220/EmptyDataSet-Swift/blob/master/LICENSE")!),
        License(for: "SPAlert",
                describedBy: "Native alert from Apple Music & Feedback. Contains Done, Heart & Message and other presets. Support SwiftUI.",
                at: URL(string: "https://github.com/ivanvorobei/SPAlert/blob/main/LICENSE")!)
    ]

}
