import SwiftUI
import UIKit

struct ProfileEditView: View {
    let user: AppUser
    let isSaving: Bool
    let onSave: (ProfileEditDraft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ProfileEditDraft
    @State private var showDiscardConfirmation = false
    @State private var submitted = false
    @State private var serverError: String?

    init(
        user: AppUser,
        isSaving: Bool,
        onSave: @escaping (ProfileEditDraft) async throws -> Void
    ) {
        self.user = user
        self.isSaving = isSaving
        self.onSave = onSave
        _draft = State(initialValue: ProfileEditDraft(user: user))
    }

    private var initial: ProfileEditDraft { ProfileEditDraft(user: user) }
    private var isDirty: Bool { draft != initial }
    private var errors: [String: String] { submitted ? draft.validationErrors : [:] }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Identity matching is performed only by KairoID services. Changing your name or date of birth can require identity review.")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                } header: { Text("Identity") }

                Section("Personal information") {
                    field("Full name", text: $draft.fullName, key: "full_name", contentType: .name)
                    LabeledContent("Email", value: user.email)
                    field("Mobile", text: $draft.phone, key: "phone", contentType: .telephoneNumber, keyboard: .phonePad)
                    field("Date of birth", text: $draft.dateOfBirth,
                        key: "date_of_birth", keyboard: .numbersAndPunctuation, prompt: "DD-MM-YYYY")
                        .onChange(of: draft.dateOfBirth) { _, value in
                            let formatted = ProfileBirthDate.formatInput(value)
                            if formatted != value { draft.dateOfBirth = formatted }
                        }
                    CandidateDateField(title: "Date of birth", selection: Binding(
                        get: { ProfileBirthDate.parse(draft.dateOfBirth) },
                        set: { draft.dateOfBirth = $0.map(ProfileBirthDate.display) ?? "" }),
                        displayValue: draft.dateOfBirth.isEmpty ? "DD-MM-YYYY" : draft.dateOfBirth,
                        identifier: "candidate.profile.edit.dobPicker")
                }

                Section("Professional information") {
                    field("Professional headline", text: $draft.headline, key: "headline")
                    field("Current role", text: $draft.currentRole, key: "current_role")
                    field("Industry", text: $draft.industry, key: "industry")
                    field("Years of experience", text: $draft.yearsOfExperience, key: "years_of_experience", keyboard: .numberPad)
                    VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                        Text("About").font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                        TextEditor(text: $draft.bio)
                            .frame(minHeight: 120)
                            .accessibilityLabel("About")
                        Text("\(draft.bio.count)/500")
                            .font(KairoTypography.caption)
                            .foregroundStyle(draft.bio.count > 500 ? KairoColors.danger : KairoColors.textSecondary)
                        error("bio")
                    }
                }

                Section("Location") {
                    CandidateLocationFields(country: $draft.locationCountry, region: $draft.locationRegion,
                        city: $draft.locationCity, identifier: "candidate.profile.edit.location")
                    error("location_city"); error("location_region"); error("location_country")
                }

                if let serverError {
                    Section {
                        Label(serverError, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(KairoColors.danger)
                            .accessibilityIdentifier("candidate.profile.edit.error")
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isDirty { showDiscardConfirmation = true } else { dismiss() }
                    }
                    .disabled(isSaving)
                    .accessibilityIdentifier("candidate.profile.edit.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { save() }
                        .disabled(isSaving || (submitted && !draft.validationErrors.isEmpty))
                        .accessibilityIdentifier("candidate.profile.edit.save")
                }
            }
            .confirmationDialog("Discard changes?", isPresented: $showDiscardConfirmation) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            } message: {
                Text("Your unsaved profile changes will be lost.")
            }
        }
        .interactiveDismissDisabled(isDirty || isSaving)
        .accessibilityIdentifier("candidate.profile.edit.screen")
    }

    @ViewBuilder
    private func field(
        _ title: String,
        text: Binding<String>,
        key: String,
        contentType: UITextContentType? = nil,
        keyboard: UIKeyboardType = .default,
        prompt: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            TextField(title, text: text, prompt: prompt.map(Text.init))
                .textContentType(contentType)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress || keyboard == .URL ? .never : .words)
                .accessibilityIdentifier("candidate.profile.edit.\(key)")
            error(key)
        }
    }

    @ViewBuilder
    private func error(_ key: String) -> some View {
        if let value = errors[key] {
            Text(value).font(KairoTypography.caption).foregroundStyle(KairoColors.danger)
        }
    }

    private func save() {
        submitted = true
        serverError = nil
        guard draft.validationErrors.isEmpty, !isSaving else { return }
        let value = draft
        Task {
            do {
                try await onSave(value)
                dismiss()
            } catch {
                serverError = "Your profile could not be saved. Review the information and try again."
            }
        }
    }
}

struct ProfileSkillsView: View {
    @ObservedObject var store: ProfileOverviewStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingPicker = false

    var body: some View {
        NavigationStack {
            List {
                if store.snapshot.skills.isEmpty {
                    ContentUnavailableView("No Skills", systemImage: "sparkles", description: Text("Add Skills from KairoID's structured catalogue."))
                }
                ForEach(store.snapshot.skills) { skill in
                    HStack {
                        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                            Text(skill.name)
                            if ProfileCatalogues.resolve(skill.name, in: ProfileCatalogues.skills) == nil {
                                Text("Legacy value")
                                    .font(KairoTypography.caption)
                                    .foregroundStyle(KairoColors.textSecondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Task { try? await store.removeSkill(id: skill.id) }
                        } label: {
                            Image(systemName: "trash").frame(width: 44, height: 44)
                        }
                        .disabled(store.isMutating)
                        .accessibilityLabel("Remove \(skill.name)")
                    }
                }
                if let message = store.errorMessage {
                    Text(message).foregroundStyle(KairoColors.danger).accessibilityIdentifier("candidate.profile.skills.error")
                }
            }
            .navigationTitle("Skills")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button { showingPicker = true } label: {
                    Label("Add skill", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isMutating)
                .accessibilityIdentifier("candidate.profile.skills.add")
                .padding()
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showingPicker) {
                ProfileSkillPicker(existingNames: store.snapshot.skills.map(\.name), isSaving: store.isMutating) { names in
                    try await store.addSkills(names)
                }
            }
        }
        .accessibilityIdentifier("candidate.profile.skills.screen")
    }
}

private struct ProfileSkillPicker: View {
    let existingNames: [String]
    let isSaving: Bool
    let onSave: ([String]) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selected = Set<String>()
    @State private var errorMessage: String?

    private var results: [ProfileCatalogueEntry] { ProfileCatalogues.search(query, in: ProfileCatalogues.skills) }

    var body: some View {
        NavigationStack {
            List(results) { entry in
                let unavailable = ProfileCatalogues.contains(entry, values: existingNames, in: ProfileCatalogues.skills)
                Button {
                    guard !unavailable else { return }
                    if selected.contains(entry.id) { selected.remove(entry.id) } else { selected.insert(entry.id) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                            Text(entry.name).foregroundStyle(KairoColors.textPrimary)
                            if let category = entry.category {
                                Text(category).font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                            }
                        }
                        Spacer()
                        if unavailable {
                            Text("Already added").font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                        } else {
                            Image(systemName: selected.contains(entry.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(KairoColors.brandPrimary)
                        }
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(unavailable || isSaving)
                .accessibilityLabel(entry.name)
                .accessibilityValue(unavailable ? "Already added" : selected.contains(entry.id) ? "Selected" : "Not selected")
            }
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Search Skills")
            .navigationTitle("Add Skills")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: KairoSpacing.xSmall) {
                    if let errorMessage {
                        Text(errorMessage).font(KairoTypography.footnote).foregroundStyle(KairoColors.danger)
                    }
                    Button(isSaving ? "Saving…" : "Add selected (\(selected.count))") { save() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(selected.isEmpty || isSaving)
                        .accessibilityIdentifier("candidate.profile.skills.save")
                }
                .padding()
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        let names = ProfileCatalogues.skills.filter { selected.contains($0.id) }.map(\.name)
        Task {
            do { try await onSave(names); dismiss() }
            catch { errorMessage = "Could not add all selected Skills. Any saved Skills are kept." }
        }
    }
}

struct ProfileLanguagesView: View {
    @ObservedObject var store: ProfileOverviewStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: AppUser.Language?
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                if store.snapshot.user.languages.isEmpty {
                    ContentUnavailableView("No Languages", systemImage: "character.book.closed", description: Text("Add a Language and select your Proficiency."))
                }
                ForEach(store.snapshot.user.languages, id: \.id) { language in
                    HStack {
                        Button { editing = language } label: {
                            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                                Text(language.language).foregroundStyle(KairoColors.textPrimary)
                                Text(ProfileLanguageProficiency(rawValue: language.proficiency ?? "")?.title ?? "No proficiency")
                                    .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                                if ProfileCatalogues.resolve(language.language, in: ProfileCatalogues.languages) == nil {
                                    Text("Legacy value · choose a listed language to replace")
                                        .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit \(language.language)")
                        Button(role: .destructive) {
                            Task { try? await store.removeLanguage(id: language.id) }
                        } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                        .disabled(store.isMutating)
                        .accessibilityLabel("Remove \(language.language)")
                    }
                }
                if let message = store.errorMessage {
                    Text(message).foregroundStyle(KairoColors.danger).accessibilityIdentifier("candidate.profile.languages.error")
                }
            }
            .navigationTitle("Languages")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button { adding = true } label: {
                    Label("Add language", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isMutating)
                .accessibilityIdentifier("candidate.profile.languages.add")
                .padding()
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $adding) { languageEditor(nil) }
            .sheet(item: $editing) { languageEditor($0) }
        }
        .accessibilityIdentifier("candidate.profile.languages.screen")
    }

    private func languageEditor(_ item: AppUser.Language?) -> some View {
        ProfileLanguageEditor(
            item: item,
            allLanguages: store.snapshot.user.languages,
            isSaving: store.isMutating
        ) { name, proficiency in
            if let item {
                try await store.updateLanguage(id: item.id, name: name, proficiency: proficiency)
            } else {
                try await store.addLanguage(name: name, proficiency: proficiency)
            }
        }
    }
}

private struct ProfileLanguageEditor: View {
    let item: AppUser.Language?
    let allLanguages: [AppUser.Language]
    let isSaving: Bool
    let onSave: (String, ProfileLanguageProficiency) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var selectedID: String
    @State private var proficiency: ProfileLanguageProficiency?
    @State private var errorMessage: String?

    init(
        item: AppUser.Language?,
        allLanguages: [AppUser.Language],
        isSaving: Bool,
        onSave: @escaping (String, ProfileLanguageProficiency) async throws -> Void
    ) {
        self.item = item
        self.allLanguages = allLanguages
        self.isSaving = isSaving
        self.onSave = onSave
        _selectedID = State(initialValue: item.flatMap { ProfileCatalogues.resolve($0.language, in: ProfileCatalogues.languages)?.id } ?? "")
        _proficiency = State(initialValue: item.flatMap { ProfileLanguageProficiency(rawValue: $0.proficiency ?? "") })
    }

    private var results: [ProfileCatalogueEntry] { ProfileCatalogues.search(query, in: ProfileCatalogues.languages) }
    private var selected: ProfileCatalogueEntry? { ProfileCatalogues.languages.first { $0.id == selectedID } }

    var body: some View {
        NavigationStack {
            List {
                if let item, ProfileCatalogues.resolve(item.language, in: ProfileCatalogues.languages) == nil {
                    Section {
                        Text("\(item.language) is a legacy value. Choose a listed Language to replace it. Nothing changes until you save.")
                            .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                    }
                }
                Section("Proficiency") {
                    Picker("Proficiency", selection: $proficiency) {
                        Text("Select Proficiency").tag(ProfileLanguageProficiency?.none)
                        ForEach(ProfileLanguageProficiency.allCases, id: \.self) { level in
                            Text(level.title).tag(Optional(level))
                        }
                    }
                    .accessibilityIdentifier("candidate.profile.languages.proficiency")
                }
                Section("Language") {
                    ForEach(results) { entry in
                        let unavailable = allLanguages.contains { value in
                            value.id != item?.id && ProfileCatalogues.resolve(value.language, in: ProfileCatalogues.languages)?.id == entry.id
                        }
                        Button {
                            selectedID = entry.id
                        } label: {
                            HStack {
                                Text(entry.name).foregroundStyle(KairoColors.textPrimary)
                                Spacer()
                                if unavailable { Text("Already added").font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary) }
                                else { Image(systemName: selectedID == entry.id ? "checkmark.circle.fill" : "circle") }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(unavailable || isSaving)
                        .accessibilityLabel(entry.name)
                        .accessibilityValue(
                            unavailable ? "Already added" : selectedID == entry.id ? "Selected" : "Not selected"
                        )
                    }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(KairoColors.danger) }
            }
            .searchable(text: $query, prompt: "Search Languages")
            .navigationTitle(item == nil ? "Add Language" : "Edit Language")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button(isSaving ? "Saving…" : "Save Language") { save() }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .disabled(selected == nil || proficiency == nil || isSaving)
                    .accessibilityIdentifier("candidate.profile.languages.save")
                    .padding()
                    .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        guard let selected, let proficiency else { return }
        Task {
            do { try await onSave(selected.name, proficiency); dismiss() }
            catch { errorMessage = "The Language could not be saved. Please try again." }
        }
    }
}

struct ProfileLinksView: View {
    @ObservedObject var store: ProfileOverviewStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var editing: AppUser.ProfessionalLink?
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                if store.snapshot.user.professionalLinks.isEmpty {
                    ContentUnavailableView("No professional links", systemImage: "link", description: Text("Add an approved professional link."))
                }
                ForEach(store.snapshot.user.professionalLinks, id: \.id) { link in
                    HStack {
                        Button {
                            if let url = ProfileURLValidator.normalized(link.url) { openURL(url) }
                        } label: {
                            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                                Text(link.label ?? ProfileLinkType(rawValue: link.linkType)?.title ?? "Professional link")
                                    .foregroundStyle(KairoColors.textPrimary)
                                Text(URL(string: link.url)?.host ?? "Saved link")
                                    .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        Button { editing = link } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                            .accessibilityLabel("Edit \(link.label ?? link.linkType) link")
                        Button(role: .destructive) {
                            Task { try? await store.removeLink(id: link.id) }
                        } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                        .accessibilityLabel("Remove \(link.label ?? link.linkType) link")
                    }
                }
                if let message = store.errorMessage { Text(message).foregroundStyle(KairoColors.danger) }
            }
            .navigationTitle("Professional links")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button { adding = true } label: {
                    Label("Add link", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isMutating)
                .accessibilityIdentifier("candidate.profile.links.add")
                .padding()
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $adding) { linkEditor(nil) }
            .sheet(item: $editing) { linkEditor($0) }
        }
        .accessibilityIdentifier("candidate.profile.links.screen")
    }

    private func linkEditor(_ item: AppUser.ProfessionalLink?) -> some View {
        ProfileLinkEditor(item: item, existing: store.snapshot.user.professionalLinks, isSaving: store.isMutating) { type, label, url in
            if let item { try await store.updateLink(id: item.id, type: type, label: label, url: url) }
            else { try await store.addLink(type: type, label: label, url: url) }
        }
    }
}

private struct ProfileLinkEditor: View {
    let item: AppUser.ProfessionalLink?
    let existing: [AppUser.ProfessionalLink]
    let isSaving: Bool
    let onSave: (ProfileLinkType, String?, URL) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var type: ProfileLinkType
    @State private var label: String
    @State private var url: String
    @State private var submitted = false
    @State private var errorMessage: String?

    init(
        item: AppUser.ProfessionalLink?,
        existing: [AppUser.ProfessionalLink],
        isSaving: Bool,
        onSave: @escaping (ProfileLinkType, String?, URL) async throws -> Void
    ) {
        self.item = item
        self.existing = existing
        self.isSaving = isSaving
        self.onSave = onSave
        _type = State(initialValue: ProfileLinkType(rawValue: item?.linkType ?? "") ?? .linkedin)
        _label = State(initialValue: item?.label ?? "")
        _url = State(initialValue: item?.url ?? "")
    }

    private var validatedURL: URL? { ProfileURLValidator.normalized(url) }
    private var isDuplicate: Bool {
        guard let validatedURL else { return false }
        return existing.contains { $0.id != item?.id && ProfileURLValidator.normalized($0.url) == validatedURL }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Link type", selection: $type) {
                    ForEach(ProfileLinkType.allCases, id: \.self) { type in Text(type.title).tag(type) }
                }
                TextField("Label (optional)", text: $label)
                TextField("https://…", text: $url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("candidate.profile.links.url")
                if submitted && validatedURL == nil {
                    Text("Enter a valid HTTP or HTTPS professional link.").foregroundStyle(KairoColors.danger)
                }
                if submitted && isDuplicate {
                    Text("This professional link is already on your profile.").foregroundStyle(KairoColors.danger)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(KairoColors.danger) }
            }
            .navigationTitle(item == nil ? "Add link" : "Edit link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { save() }.disabled(isSaving)
                        .accessibilityIdentifier("candidate.profile.links.save")
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        submitted = true
        guard let validatedURL, !isDuplicate else { return }
        Task {
            do { try await onSave(type, profileOptional(label), validatedURL); dismiss() }
            catch { errorMessage = "The professional link could not be saved. Please try again." }
        }
    }
}
