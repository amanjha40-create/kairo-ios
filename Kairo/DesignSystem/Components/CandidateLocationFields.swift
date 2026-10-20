import SwiftUI

/// Exact canonical State/UT names from the frozen Android reference. No city/provider lookup.
nonisolated enum CandidateLocationCatalogue {
    static let indiaStates = [
        "Andaman and Nicobar Islands", "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar",
        "Chandigarh", "Chhattisgarh", "Dadra and Nagar Haveli and Daman and Diu", "Delhi", "Goa",
        "Gujarat", "Haryana", "Himachal Pradesh", "Jammu and Kashmir", "Jharkhand", "Karnataka",
        "Kerala", "Ladakh", "Lakshadweep", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya",
        "Mizoram", "Nagaland", "Odisha", "Puducherry", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu",
        "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal"
    ]
    static func isIndia(_ country: String) -> Bool { ["IN", "INDIA"].contains(country.uppercased()) }
    static func countryName(_ code: String) -> String {
        Locale.current.localizedString(forRegionCode: code.uppercased()) ?? code
    }
}

/// Parent changes are deliberate selections only. Opening/cancelling never normalizes old values.
struct CandidateLocationFields: View {
    @Binding var country: String
    @Binding var region: String
    @Binding var city: String
    var fixedIndia = false
    var required = false
    var cityMaxLength = 128
    var identifier = "candidate.location"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if fixedIndia { LabeledContent("Country", value: "India") }
            else {
                CandidatePlacePicker(title: "Country", value: country,
                    options: Locale.Region.isoRegions.map(\.identifier),
                    allowClear: !required, required: required, display: CandidateLocationCatalogue.countryName) { selected in
                        guard selected != country else { return }
                        country = selected; region = ""; city = ""
                    }.accessibilityIdentifier("\(identifier).country")
            }
            if fixedIndia || CandidateLocationCatalogue.isIndia(country) {
                CandidatePlacePicker(title: "State", value: region, options: CandidateLocationCatalogue.indiaStates,
                    allowClear: !fixedIndia, required: fixedIndia) { selected in
                        guard selected != region else { return }; region = selected; city = ""
                    }.accessibilityIdentifier("\(identifier).region")
            } else {
                VStack(alignment: .leading) {
                    Text("State / Region — Optional").font(KairoTypography.caption)
                    TextField("State / Region", text: Binding(get: { region }, set: { next in
                        guard next != region else { return }; region = String(next.prefix(128)); city = ""
                    })).textContentType(.addressState).accessibilityIdentifier("\(identifier).region")
                }
            }
            CandidatePlacePicker(title: "City", value: city, options: city.isEmpty ? [] : [city],
                allowClear: !required && !fixedIndia, allowCustom: true, maxLength: cityMaxLength,
                context: region.isEmpty ? nil : "City or town in \(region)", required: required || fixedIndia) { city = $0 }
                .accessibilityIdentifier("\(identifier).city")
        }
    }
}

struct CandidatePlacePicker: View {
    let title: String
    let value: String
    let options: [String]
    var allowClear = false
    var allowCustom = false
    var maxLength = 128
    var context: String? = nil
    var required = false
    var display: (String) -> String = { $0 }
    let select: (String) -> Void
    @State private var presented = false
    @State private var query = ""
    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var choices: [String] {
        let values = options + (value.isEmpty || options.contains(value) ? [] : [value])
        return values.filter { trimmed.isEmpty || display($0).localizedCaseInsensitiveContains(trimmed) || $0.localizedCaseInsensitiveContains(trimmed) }
            .sorted { display($0).localizedStandardCompare(display($1)) == .orderedAscending }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button { query = ""; presented = true } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title + (required ? " *" : " — Optional")).font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                    HStack {
                        Text(value.isEmpty ? "Choose \(title.lowercased())" : display(value)).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8); Image(systemName: "chevron.up.chevron.down").accessibilityHidden(true)
                    }
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(KairoActionStyle(role: .secondary))
            .accessibilityLabel("\(title), \(required ? "required" : "optional")").accessibilityValue(value.isEmpty ? "Not selected" : display(value))
            .accessibilityHint("Opens searchable choices. Cancel preserves the current value.")
            if allowCustom { Text("Search or enter your \(title.lowercased()). Unlisted values are supported.").font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary) }
        }
        .sheet(isPresented: $presented) {
            NavigationStack {
                List {
                    if let context { Text(context).font(KairoTypography.footnote) }
                    if allowClear && !value.isEmpty && trimmed.isEmpty {
                        Button("Clear \(title.lowercased())") { choose("") }
                    }
                    ForEach(choices, id: \.self) { option in
                        Button { choose(option) } label: {
                            HStack {
                                Text(display(option)).foregroundStyle(KairoColors.textPrimary)
                                Spacer(); if option == value { Image(systemName: "checkmark").accessibilityHidden(true) }
                            }.frame(minHeight: 44)
                        }.accessibilityAddTraits(option == value ? [.isSelected] : [])
                    }
                    if allowCustom && !trimmed.isEmpty && !options.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                        Button("Use \(trimmed)") { choose(trimmed) }.accessibilityIdentifier("candidate.location.customCity")
                    }
                    if choices.isEmpty && (!allowCustom || trimmed.isEmpty) {
                        Text(allowCustom ? "Type your \(title.lowercased()) to use it." : "No matching choices.")
                    }
                }
                .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search \(title.lowercased())")
                .onChange(of: query) { _, next in if next.count > maxLength { query = String(next.prefix(maxLength)) } }
                .navigationTitle("Choose \(title.lowercased())").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { presented = false }.accessibilityIdentifier("candidate.picker.cancel") } }
            }
        }
    }
    private func choose(_ next: String) { select(next); presented = false; query = "" }
}
