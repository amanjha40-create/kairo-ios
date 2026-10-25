import PhotosUI
import SwiftUI
import UIKit

enum ProfilePhotoPreparation {
    static func decode(_ data: Data) throws -> UIImage {
        guard let image = UIImage(data: data) else { throw ProfileServiceError.photoUnreadable }
        return image
    }

    static func jpegData(_ image: UIImage) throws -> Data {
        // Preserve the existing product compression policy; do not shrink dimensions.
        guard let data = image.jpegData(compressionQuality: 0.82) else {
            throw ProfileServiceError.photoEncodingFailed
        }
        return data
    }
}

struct ProfileOverviewSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @EnvironmentObject private var digiLockerStore: DigiLockerStore
    @StateObject private var store: ProfileOverviewStore

    @State private var editor: ProfileEditor?
    private let initialEditorTarget: ProfileEditTarget?
    @State private var editorTarget: ProfileEditTarget?
    @State private var didOpenRequestedEditor = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var pendingPhoto: UIImage?
    @State private var photoErrorMessage: String?
    @State private var showRemovePhotoConfirmation = false

    init(initialUser: AppUser, service: any ProfileServiceProtocol, initialEditorTarget: ProfileEditTarget? = nil) {
        _store = StateObject(wrappedValue: ProfileOverviewStore(service: service, initialUser: initialUser))
        self.initialEditorTarget = initialEditorTarget
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    if store.isLoading && store.snapshot.skills.isEmpty {
                        KairoLoadingStateView(
                            title: "Loading Profile",
                            message: "Preparing your professional information."
                        )
                    }
                    hero
                    identity
                    professionalInformation
                    skills
                    KairoSection(compact: true) {
                        KairoDisclosure(title: "Languages", summary: "\(store.snapshot.user.languages.count) added") { languages }
                        KairoDisclosure(title: "Professional links", summary: "\(store.snapshot.user.professionalLinks.count) added") { links }
                    }
                    if let errorMessage = store.errorMessage {
                        KairoErrorStateView(
                            title: "Profile update unavailable",
                            message: errorMessage,
                            retryAction: { Task { await store.load() } }
                        )
                    }
                }
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.vertical, KairoSpacing.large)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") { editorTarget = nil; editor = .profile }
                        .accessibilityIdentifier("candidate.profile.edit")
                }
            }
            .refreshable { await store.load(showLoading: false) }
            .task {
                async let profile: Void = store.load()
                async let identity: Void = digiLockerStore.loadSummaryIfNeeded()
                _ = await (profile, identity)
                if let initialEditorTarget, !didOpenRequestedEditor, store.errorMessage == nil {
                    didOpenRequestedEditor = true
                    editorTarget = initialEditorTarget
                    editor = .profile
                }
            }
            .onChange(of: store.snapshot.user) { _, user in
                if sessionStore.currentUser?.id == user.id {
                    sessionStore.replaceCurrentUser(user)
                }
                refreshStore.candidateDataChanged()
                if initialEditorTarget == .dateOfBirth, user.dateOfBirth != nil {
                    dismiss()
                }
            }
            .onChange(of: refreshStore.revision) { _, _ in
                Task { await store.load(showLoading: false) }
            }
            .onChange(of: photoSelection) { _, selection in
                guard let selection else { return }
                Task { await prepare(selection) }
            }
            .sheet(item: $editor) { editor in
                editorView(editor)
            }
            .sheet(isPresented: Binding(
                get: { pendingPhoto != nil },
                set: { if !$0 { pendingPhoto = nil } }
            )) {
                if let pendingPhoto {
                    ProfilePhotoPreviewView(
                        image: pendingPhoto,
                        isSaving: store.isMutating,
                        errorMessage: photoErrorMessage,
                        onCancel: { self.pendingPhoto = nil },
                        onSave: { Task { await savePhoto(pendingPhoto) } }
                    )
                }
            }
            .confirmationDialog(
                "Remove profile photo?",
                isPresented: $showRemovePhotoConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove photo", role: .destructive) {
                    Task {
                        do {
                            try await store.removeAvatar()
                            photoErrorMessage = nil
                        } catch {
                            photoErrorMessage = "The profile photo could not be removed. Please try again."
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your initials will be shown instead.")
            }
            .overlay(alignment: .bottom) {
                if let message = store.actionMessage {
                    Text(message)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, KairoSpacing.medium)
                        .padding(.vertical, KairoSpacing.small)
                        .background(KairoColors.navy, in: Capsule())
                        .padding(.bottom, KairoSpacing.medium)
                        .accessibilityLabel(message)
                        .task {
                            try? await Task.sleep(for: .seconds(2))
                            store.clearActionMessage()
                        }
                }
            }
        }
        .interactiveDismissDisabled(store.isMutating)
        .accessibilityIdentifier("candidate.profile.screen")
    }

    private var hero: some View {
        let photoTitle = store.snapshot.user.avatarURL == nil ? "Add photo" : "Replace photo"
        return KairoSection(compact: true) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    ProfileAvatarView(user: store.snapshot.user)
                    heroSummary
                }
            } else {
                HStack(alignment: .center, spacing: KairoSpacing.medium) {
                    ProfileAvatarView(user: store.snapshot.user)
                    heroSummary
                }
            }
            ProgressView(value: Double(store.snapshot.user.profileCompletionPercentage), total: 100)
                .tint(KairoColors.brandPrimary)
                .accessibilityLabel("Profile completion")
                .accessibilityValue("\(store.snapshot.user.profileCompletionPercentage) percent")
            ViewThatFits(in: .horizontal) {
                HStack(spacing: KairoSpacing.small) { photoActions(photoTitle) }
                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) { photoActions(photoTitle) }
            }
            if let photoErrorMessage {
                Label(photoErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("candidate.profile.avatar.error")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("candidate.profile.hero")
    }

    @ViewBuilder
    private func photoActions(_ photoTitle: String) -> some View {
        let font = KairoTypography.footnote
        let padding = KairoSpacing.small
        let background = KairoColors.surfaceMuted
        PhotosPicker(selection: $photoSelection, matching: .images) {
            Label(photoTitle, systemImage: "photo")
                .font(font)
                .padding(.horizontal, padding)
                .frame(minHeight: 44)
                .background(background, in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(KairoColors.accent)
        .disabled(store.isMutating)
        .accessibilityIdentifier("candidate.profile.avatar.choose")
        if store.snapshot.user.avatarURL != nil {
            Button("Remove", role: .destructive) { showRemovePhotoConfirmation = true }
                .font(KairoTypography.caption)
                .buttonStyle(.plain)
                .foregroundStyle(KairoColors.danger)
                .frame(minWidth: 44, minHeight: 44)
                .disabled(store.isMutating)
                .accessibilityIdentifier("candidate.profile.avatar.remove")
        }
    }

    private var heroSummary: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text(displayName)
                .font(KairoTypography.title)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(store.snapshot.user.headline ?? "Professional headline not added")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("candidate.profile.headline")
            if !location.isEmpty {
                Label(location, systemImage: "location")
                    .font(KairoTypography.metadata)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var identity: some View {
        KairoSection(compact: true) {
            if let attention = digiLockerStore.attentionDigiLockerSources.first {
                identityHeadingLayout {
                    KairoSectionHeading(title: "Identity")
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: KairoSpacing.small) }
                    KairoStatusChip(title: "Needs review", tone: .attention)
                        .accessibilityValue("Needs review")
                }
                Text(DigiLockerPresentation.safeReason(attention.reason))
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                identityHeadingLayout {
                    KairoSectionHeading(title: "Identity")
                    if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: KairoSpacing.small) }
                    KairoStatusChip(
                        title: digiLockerStore.identityIsVerified ? "Verified" : "Not currently verified",
                        tone: digiLockerStore.identityIsVerified ? .verified : .draft
                    )
                }
            }
            if digiLockerStore.identityVerifiedViaDigiLocker {
                Text("Source: DigiLocker")
                    .font(KairoTypography.metadata)
                    .foregroundStyle(KairoColors.textSecondary)
            }
            HStack(alignment: .top, spacing: KairoSpacing.small) {
                Image(systemName: "info.circle")
                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                    Text("About identity").font(KairoTypography.caption.weight(.semibold))
                    Text("Your sensitive identity details stay private. KairoID only shows your verification status.")
                        .font(KairoTypography.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(KairoColors.textSecondary)
            .padding(KairoSpacing.small)
            .background(KairoColors.surfaceMuted, in: RoundedRectangle(cornerRadius: KairoCornerRadius.medium))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("candidate.profile.identity.info")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("candidate.identity.provenance")
    }

    private var identityHeadingLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: KairoSpacing.small))
            : AnyLayout(HStackLayout(alignment: .center, spacing: KairoSpacing.small))
    }

    private var professionalInformation: some View {
        ProfileSection(title: "Profile") {
            Button { editorTarget = nil; editor = .profile } label: {
                HStack(spacing: KairoSpacing.small) {
                    Image(systemName: "pencil.circle.fill").foregroundStyle(KairoColors.accent)
                    VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                        Text("Personal & professional information").font(KairoTypography.bodyStrong)
                        Text("Edit your headline, bio and personal details").font(KairoTypography.caption)
                            .foregroundStyle(KairoColors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(KairoColors.accent)
                }
                .frame(minHeight: 44)
                .padding(KairoSpacing.small)
                .background(KairoColors.surfaceMuted, in: RoundedRectangle(cornerRadius: KairoCornerRadius.medium))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("candidate.profile.information.edit")
            ProfileFactRow(title: "Professional headline", value: store.snapshot.user.headline ?? "Not added")
            ProfileFactRow(title: "Email", value: store.snapshot.user.email, status: verified(store.snapshot.user.emailVerifiedAt))
            ProfileFactRow(title: "Mobile", value: store.snapshot.user.phone ?? "Not added", status: verified(store.snapshot.user.phoneVerifiedAt))
            ProfileFactRow(title: "Date of birth", value: store.snapshot.user.dateOfBirth.map(ProfileBirthDate.display) ?? "Not added")
            ProfileFactRow(title: "Current role", value: store.snapshot.user.currentRole ?? "Not added")
            ProfileFactRow(title: "Industry", value: store.snapshot.user.industry ?? "Not added")
            ProfileFactRow(
                title: "Experience",
                value: store.snapshot.user.yearsOfExperience.map { "\($0) years" } ?? "Not added"
            )
            ProfileFactRow(title: "Location", value: location.isEmpty ? "Not added" : location)
            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                Text("Professional Bio (optional)")
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.textSecondary)
                Text(store.snapshot.user.bio ?? "Not added yet")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var skills: some View {
        ProfileSection(title: "Skills", count: store.snapshot.skills.count) {
            if store.snapshot.skills.isEmpty {
                ProfileEmptyRow(message: "No Skills added yet.")
            } else {
                FlowLayout(spacing: KairoSpacing.xSmall) {
                    ForEach(store.snapshot.skills) { skill in
                        Text(skill.name)
                            .font(KairoTypography.footnote)
                            .padding(.horizontal, KairoSpacing.small)
                            .padding(.vertical, KairoSpacing.xSmall)
                            .background(KairoColors.surfaceMuted, in: Capsule())
                    }
                }
            }
            Button("Manage Skills") { editor = .skills }
                .buttonStyle(KairoActionStyle())
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("candidate.profile.skills.manage")
        }
    }

    private var languages: some View {
        ProfileSection(title: "Languages", count: store.snapshot.user.languages.count) {
            if store.snapshot.user.languages.isEmpty {
                ProfileEmptyRow(message: "No Languages added yet.")
            } else {
                ForEach(store.snapshot.user.languages, id: \.id) { language in
                    ProfileFactRow(
                        title: language.language,
                        value: ProfileLanguageProficiency(rawValue: language.proficiency ?? "")?.title ?? "No proficiency"
                    )
                }
            }
            Button("Manage Languages") { editor = .languages }
                .buttonStyle(KairoActionStyle())
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("candidate.profile.languages.manage")
        }
    }

    private var links: some View {
        ProfileSection(title: "Professional links", count: store.snapshot.user.professionalLinks.count) {
            if store.snapshot.user.professionalLinks.isEmpty {
                ProfileEmptyRow(message: "No professional links added yet.")
            } else {
                ForEach(store.snapshot.user.professionalLinks, id: \.id) { link in
                    Button {
                        if let url = ProfileURLValidator.normalized(link.url) { openURL(url) }
                    } label: {
                        HStack {
                            Image(systemName: "link")
                            Text(link.label ?? ProfileLinkType(rawValue: link.linkType)?.title ?? "Professional link")
                                .font(KairoTypography.bodyStrong)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("Manage professional links") { editor = .links }
                .buttonStyle(KairoActionStyle())
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("candidate.profile.links.manage")
        }
    }

    @ViewBuilder
    private func editorView(_ editor: ProfileEditor) -> some View {
        switch editor {
        case .profile:
            ProfileEditView(user: store.snapshot.user, isSaving: store.isMutating, initialTarget: editorTarget) { draft in
                try await store.update(draft)
            }
        case .skills:
            ProfileSkillsView(store: store)
        case .languages:
            ProfileLanguagesView(store: store)
        case .links:
            ProfileLinksView(store: store)
        }
    }

    private var displayName: String { profileOptional(store.snapshot.user.fullName ?? "") ?? store.snapshot.user.email }

    private var location: String {
        let structured = [store.snapshot.user.locationCity, store.snapshot.user.locationRegion, store.snapshot.user.locationCountry]
            .compactMap { profileOptional($0 ?? "") }
            .joined(separator: ", ")
        return structured.isEmpty ? (store.snapshot.user.location ?? "") : structured
    }

    private func verified(_ date: Date?) -> String { date == nil ? "Unverified" : "Verified" }

    private func prepare(_ item: PhotosPickerItem) async {
        photoSelection = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                photoErrorMessage = "The selected photo could not be read. Choose an available photo from your library."
                return
            }
            let image = try ProfilePhotoPreparation.decode(data)
            photoErrorMessage = nil
            pendingPhoto = image
        } catch {
            if let failure = error as? ProfileServiceError {
                photoErrorMessage = failure.localizedDescription
            } else {
                photoErrorMessage = "The selected photo could not be read. Check access to the photo and try again."
            }
        }
    }

    private func savePhoto(_ image: UIImage) async {
        do {
            let data = try ProfilePhotoPreparation.jpegData(image)
            try await store.uploadAvatar(data)
            photoErrorMessage = nil
            pendingPhoto = nil
        } catch {
            photoErrorMessage = ProfilePhotoFailure.message(for: error)
        }
    }
}

private enum ProfileEditor: String, Identifiable {
    case profile, skills, languages, links
    var id: String { rawValue }
}

private struct ProfileAvatarView: View {
    let user: AppUser
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let raw = user.avatarURL,
               let url = URL(string: raw),
               url.scheme?.lowercased() == "https" {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFit()
                    } else {
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: 72, height: 72)
        .background(KairoColors.surfaceMuted)
        .clipShape(Circle())
        .overlay(Circle().stroke(KairoColors.border, lineWidth: 1))
        .contentTransition(.opacity)
        .animation(.easeOut(duration: reduceMotion ? 0.14 : 0.16), value: user.avatarURL)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Profile photo for \(user.fullName ?? "candidate")")
    }

    private var initials: some View {
        Text((user.fullName ?? user.email).split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased())
            .font(.system(size: 24, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KairoColors.navy)
    }
}

struct ProfileSection<Content: View>: View {
    let title: String
    var count: Int? = nil
    @ViewBuilder let content: Content

    init(title: String, count: Int? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.count = count
        self.content = content()
    }

    var body: some View {
        KairoCard {
            KairoSectionHeading(title: title, count: count)
            content
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ProfileFactRow: View {
    let title: String
    let value: String
    var status: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: KairoSpacing.small) {
            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                Text(title).font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                Text(value).font(KairoTypography.bodyStrong).foregroundStyle(KairoColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: KairoSpacing.small)
            if let status {
                KairoStatusChip(title: status, tone: status == "Verified" ? .verified : .draft)
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileEmptyRow: View {
    let message: String
    var body: some View {
        Text(message)
            .font(KairoTypography.footnote)
            .foregroundStyle(KairoColors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}

private struct ProfilePhotoPreviewView: View {
    let image: UIImage
    let isSaving: Bool
    let errorMessage: String?
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: KairoSpacing.large) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .background(KairoColors.surfaceMuted)
                    .clipShape(Circle())
                    .accessibilityLabel("Selected profile photo preview")
                Text("Preview of your profile frame. Your photo is fitted without zooming; the original image is uploaded only after you confirm.")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                if let errorMessage {
                    Text(errorMessage)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("candidate.profile.avatar.preview.error")
                }
                KairoPrimaryButton(title: "Use this photo", isLoading: isSaving, action: onSave)
                    .disabled(isSaving)
                KairoSecondaryButton(title: "Cancel", action: onCancel)
                    .disabled(isSaving)
            }
            .padding(KairoSpacing.large)
            .navigationTitle("Profile photo")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled(isSaving)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var points: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}
