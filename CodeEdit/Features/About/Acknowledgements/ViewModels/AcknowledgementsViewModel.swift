//
//  AcknowledgementsModel.swift
//  CodeEditModules/Acknowledgements
//
//  Created by Lukas Pistrol on 01.05.22.
//

import SwiftUI

final class AcknowledgementsViewModel: ObservableObject {

    @Published private(set) var acknowledgements: [AcknowledgementDependency]

    private struct LicenseMetadata {
        let name: String
        let link: String
    }

    private static let licenseMetadata: [String: LicenseMetadata] = [
        "swift-markdown-engine": LicenseMetadata(
            name: "Apache-2.0",
            link: "https://github.com/nodes-app/swift-markdown-engine/blob/main/LICENSE"
        ),
        "highlighterswift": LicenseMetadata(
            name: "MIT + BSD-3-Clause",
            link: "https://github.com/smittytone/HighlighterSwift/blob/main/LICENCE.md"
        ),
        "swiftmath": LicenseMetadata(
            name: "MIT",
            link: "https://github.com/mgriebling/SwiftMath/blob/main/LICENSE"
        )
    ]

    var indexedAcknowledgements: [(index: Int, acknowledgement: AcknowledgementDependency)] {
      return Array(zip(acknowledgements.indices, acknowledgements))
    }

    init(_ dependencies: [AcknowledgementDependency] = []) {
        self.acknowledgements = dependencies

        if acknowledgements.isEmpty {
            fetchDependencies()
        }
    }

    func fetchDependencies() {
        self.acknowledgements.removeAll()
        do {
            if let bundlePath = Bundle.main.path(forResource: "Package", ofType: "resolved") {
                let jsonData = try String(contentsOfFile: bundlePath).data(using: .utf8)
                let parsedJSON = try JSONDecoder().decode(AcknowledgementObject.self, from: jsonData!)
                for dependency in parsedJSON.pins.sorted(by: { $0.identity < $1.identity })
                where dependency.identity.range(
                    of: "[Cc]ode[Ee]dit",
                    options: .regularExpression,
                    range: nil,
                    locale: nil
                ) == nil {
                    let license = Self.licenseMetadata[dependency.identity]
                    self.acknowledgements.append(
                        AcknowledgementDependency(
                            name: dependency.name,
                            repositoryLink: dependency.location,
                            version: dependency.state.version ?? "-",
                            licenseName: license?.name,
                            licenseLink: license?.link
                        )
                    )
                }
            }
        } catch {
            print(error)
        }
    }
}
