import SwiftUI

/// One remote catalogue picker for Career, resume review, and manual onboarding.
struct InstitutionPicker: View {
    @Environment(\.appConfiguration) private var configuration
    let value: String
    let identifier: String
    let select: (InstitutionSelection) -> Void
    @State private var presented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Institution").font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
            Button { presented = true } label: {
                HStack {
                    Text(value.isEmpty ? "Choose institution…" : value)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: "magnifyingglass").accessibilityHidden(true)
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(KairoActionStyle(role: .field))
            .accessibilityLabel("Institution, required").accessibilityValue(value.isEmpty ? "Not selected" : value)
            .accessibilityIdentifier(identifier)
            Text("Search the directory or enter an unlisted institution.")
                .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
        }
        .sheet(isPresented: $presented) {
            InstitutionSearchView(current: value, service: InstitutionCatalogueClient.make(configuration: configuration)) {
                select($0); presented = false
            }
        }
    }
}

private struct InstitutionSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var state: InstitutionSearchState
    let current: String
    let select: (InstitutionSelection) -> Void
    @State private var query = ""
    @State private var page = 1
    @State private var retry = 0
    @State private var manual = false
    @State private var manualName = ""

    init(current: String, service: any InstitutionCatalogueServing, select: @escaping (InstitutionSelection) -> Void) {
        self.current = current; self.select = select
        _state = StateObject(wrappedValue: InstitutionSearchState(service: service))
    }

    var body: some View {
        NavigationStack {
            List {
                if !current.isEmpty && query.isEmpty {
                    Section("Current institution — unchanged until you choose") {
                        Text(current).accessibilityIdentifier("institution.current")
                    }
                }
                Section {
                    Button("Institution not listed / Enter manually") {
                        manualName = current; manual = true
                    }.accessibilityIdentifier("institution.manual")
                }
                Section {
                    if state.isLoading {
                        ProgressView("Searching institutions…").accessibilityIdentifier("institution.loading")
                    } else if state.failed {
                        Text("Institution search could not load. Try again or enter your institution manually.")
                            .accessibilityIdentifier("institution.failure")
                        Button("Retry search") { retry += 1 }
                    } else if let result = state.result {
                        if !result.available || result.version.isEmpty {
                            Text("Institution directory is unavailable. You can enter your institution manually.")
                                .accessibilityIdentifier("institution.unavailable")
                        } else if result.items.isEmpty {
                            Text("No matching institutions. Try another search or enter manually.")
                                .accessibilityIdentifier("institution.empty")
                        } else {
                            ForEach(result.items) { item in
                                Button {
                                    select(.init(name: item.name, catalogueID: item.id, catalogueVersion: result.version))
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name).foregroundStyle(KairoColors.textPrimary)
                                        if !item.location.isEmpty {
                                            Text(item.location).font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                                        }
                                    }.frame(minHeight: 44).fixedSize(horizontal: false, vertical: true)
                                }.accessibilityIdentifier("institution.result.\(item.id)")
                            }
                        }
                        if result.available {
                            if page > 1 { Button("Previous results") { page -= 1 } }
                            if result.offset + result.items.count < result.total && !result.items.isEmpty {
                                Button("More results") { page += 1 }
                            }
                        }
                    }
                }
                if let result = state.result {
                    NavigationLink("Institution data sources") { InstitutionProvenanceContent(result: result) }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search institutions")
            .onChange(of: query) { _, _ in page = 1 }
            .task(id: "\(query)|\(page)|\(retry)") { await state.load(query, page: page) }
            .navigationTitle("Choose institution").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.accessibilityIdentifier("candidate.picker.cancel")
            } }
            .sheet(isPresented: $manual) {
                NavigationStack {
                    Form {
                        TextField("Institution name", text: $manualName, axis: .vertical)
                            .textInputAutocapitalization(.words).accessibilityIdentifier("institution.manual.name")
                        Text("This name will be saved as a manual entry, without a directory link.")
                            .font(KairoTypography.footnote)
                    }
                    .navigationTitle("Enter institution").navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { manual = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Use institution") { select(.init(name: manualName.trimmingCharacters(in: .whitespacesAndNewlines))) }
                                .disabled(manualName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || manualName.count > 512)
                                .accessibilityIdentifier("institution.manual.confirm")
                        }
                    }
                }
            }
        }
    }
}

struct InstitutionDataSourcesView: View {
    @Environment(\.appConfiguration) private var configuration
    @State private var result: InstitutionCataloguePage?
    @State private var failed = false
    @State private var retry = 0
    var body: some View {
        Group {
            if let result { InstitutionProvenanceContent(result: result) }
            else {
                List {
                    if failed {
                        Text("Institution data sources could not load.")
                        Button("Retry") { retry += 1 }
                    } else { ProgressView("Loading data sources…") }
                }
            }
        }
        .navigationTitle("Institution data sources").navigationBarTitleDisplayMode(.inline)
        .task(id: retry) {
            failed = false
            do { result = try await InstitutionCatalogueClient.make(configuration: configuration).search("", state: nil, district: nil, page: 1, limit: 1) }
            catch { failed = true }
        }
    }
}

private struct InstitutionProvenanceContent: View {
    let result: InstitutionCataloguePage
    var body: some View {
        List {
            Section("Source") {
                Text(result.provenance.sourceName)
                Text(result.scope)
                Text("Version: \(result.version)")
                if let url = publicURL(result.provenance.sourceUrl) { Link("Source database", destination: url) }
            }
            Section("Licence & attribution") {
                Text(result.provenance.licenceName)
                Text(result.provenance.attribution)
                Text(result.provenance.nonEndorsement)
                if let url = publicURL(result.provenance.licenceUrl) { Link("Read licence", destination: url) }
            }
        }.navigationTitle("Institution data sources").navigationBarTitleDisplayMode(.inline)
    }
    private func publicURL(_ raw: String) -> URL? {
        guard let url = URL(string: raw), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
}
