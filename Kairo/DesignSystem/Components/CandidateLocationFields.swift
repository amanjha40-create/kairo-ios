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
    @State private var geography = CandidateGeography.empty
    @State private var loadedCountryKey: String?
    private var countryKey: String { fixedIndia ? "IN" : country }
    private var regionOptions: [String] { loadedCountryKey == countryKey ? geography.regions.map(\.name) : [] }
    private var cityOptions: [String] { loadedCountryKey == countryKey ? geography.cities(in: region) : [] }

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
            if !regionOptions.isEmpty || !region.isEmpty {
                CandidatePlacePicker(title: "State / Province", value: region, options: regionOptions,
                    allowClear: !fixedIndia, required: fixedIndia) { selected in
                        guard selected != region else { return }; region = selected; city = ""
                    }.accessibilityIdentifier("\(identifier).region")
                    .disabled(countryKey.isEmpty || loadedCountryKey != countryKey)
            }
            CandidatePlacePicker(title: "City", value: city, options: cityOptions,
                allowClear: !required && !fixedIndia, maxLength: cityMaxLength,
                context: region.isEmpty ? nil : "City or town in \(region)", required: required || fixedIndia) { city = $0 }
                .accessibilityIdentifier("\(identifier).city")
                .disabled(countryKey.isEmpty || loadedCountryKey != countryKey || (!regionOptions.isEmpty && region.isEmpty))
            if loadedCountryKey == countryKey, !countryKey.isEmpty, cityOptions.isEmpty, regionOptions.isEmpty || !region.isEmpty {
                Text("No city choices are available for this selection in the offline catalogue. Existing saved values are preserved.")
                    .font(KairoTypography.caption).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(identifier).coverageGap")
            }
            Text("Location data: Countries States Cities Database · ODbL 1.0")
                .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
        }
        .task(id: countryKey) {
            // Local country-sized resource only; no location permission or network.
            geography = CandidateGeography.country(countryKey)
            loadedCountryKey = countryKey
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
    var placeholder: String? = nil
    var titleColor: Color = KairoColors.textSecondary
    var titleFont: Font = KairoTypography.caption
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
            Text(title + (required ? " *" : " — Optional"))
                .font(titleFont).foregroundStyle(titleColor)
                .accessibilityHidden(true)
            Button { query = ""; presented = true } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(value.isEmpty ? (placeholder ?? "Choose \(title.lowercased())") : display(value)).fixedSize(horizontal: false, vertical: true)
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
