import SwiftUI

/// Versioned common choices, not a backend enum. Unknown saved strings are preserved.
nonisolated enum CandidateDegreeCatalogue {
    static let version = 1
    static let other = "Other"
    static let values = [
        "High School", "Diploma", "Associate Degree",
        "Bachelor of Arts (BA)", "Bachelor of Science (BSc)", "Bachelor of Commerce (BCom)",
        "Bachelor of Engineering (BE)", "Bachelor of Technology (BTech)",
        "Bachelor of Business Administration (BBA)", "Bachelor of Computer Applications (BCA)",
        "Bachelor of Laws (LLB)", "Bachelor of Medicine, Bachelor of Surgery (MBBS)",
        "Master of Arts (MA)", "Master of Science (MSc)", "Master of Commerce (MCom)",
        "Master of Engineering (ME)", "Master of Technology (MTech)",
        "Master of Business Administration (MBA)", "Master of Computer Applications (MCA)",
        "Master of Laws (LLM)", "Doctor of Philosophy (PhD)", "Postgraduate Diploma"
    ]
    static func isCustom(_ value: String) -> Bool { !value.isEmpty && !values.contains(value) }
}

struct CandidateDegreeField: View {
    @Binding var degree: String
    var required = false
    let identifier: String
    @State private var choseOther = false
    private var custom: Bool { choseOther || CandidateDegreeCatalogue.isCustom(degree) }

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            CandidatePlacePicker(title: "Degree",
                value: custom ? CandidateDegreeCatalogue.other : degree,
                options: CandidateDegreeCatalogue.values + [CandidateDegreeCatalogue.other],
                maxLength: 255, required: required) { selected in
                    if selected == CandidateDegreeCatalogue.other {
                        if !custom { degree = "" }
                        choseOther = true
                    } else {
                        choseOther = false
                        degree = selected
                    }
                }
                .accessibilityIdentifier(identifier)
            if custom {
                KairoTextField(title: "Other degree" + (required ? " *" : ""), prompt: "Enter your degree",
                    text: Binding(get: { degree }, set: { degree = String($0.prefix(255)) }),
                    accessibilityIdentifier: identifier + ".other")
            }
        }
    }
}
