import SwiftUI

struct HelpCenterScreenView: View {
    let supportEmailAddress: String
    let supportAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var query = ""
    @State private var expandedFAQID: String?
    @State private var selectedDetail: HelpCenterDetail?
    @State private var focusAfterDetail: HelpCenterFocus?
    @AccessibilityFocusState private var accessibilityFocus: HelpCenterFocus?

    private var isSearching: Bool {
        !HelpCenterSearch.normalizedWords(query).isEmpty
    }

    private var results: [HelpSearchResult] {
        HelpCenterSearch.search(query)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                welcomeCard
                searchField

                if isSearching {
                    searchContent
                } else {
                    supportCard
                    guidesSection
                    faqSection
                }

                contactSupportFooter
            }
            .padding(.horizontal, KairoSpacing.medium)
            .padding(.vertical, KairoSpacing.large)
        }
        .background(KairoColors.background.ignoresSafeArea())
        .navigationTitle("Help Center")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier(KairoAccessibilityID.helpCenterScreen)
        .sheet(item: $selectedDetail, onDismiss: restoreDetailFocus) { detail in
            HelpCenterDetailView(detail: detail)
        }
    }

    private var welcomeCard: some View {
        KairoCard {
            VStack(alignment: .center, spacing: KairoSpacing.xSmall) {
                Image(systemName: "questionmark.bubble.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(KairoColors.brandPrimary)
                    .accessibilityHidden(true)

                Text("How can we help?")
                    .font(KairoTypography.screenTitle)
                    .foregroundStyle(KairoColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier(KairoAccessibilityID.helpCenterTitle)

                Text("Search guides or browse common topics.")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var searchField: some View {
        HStack(spacing: KairoSpacing.small) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(KairoColors.textSecondary)
                .accessibilityHidden(true)

            TextField("Search for help…", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .accessibilityLabel("Search help")
                .accessibilityIdentifier(KairoAccessibilityID.helpCenterSearch)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(KairoColors.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear help search")
                .accessibilityIdentifier(KairoAccessibilityID.helpCenterClearSearch)
            }
        }
        .padding(.leading, KairoSpacing.medium)
        .padding(.trailing, query.isEmpty ? KairoSpacing.medium : KairoSpacing.xxSmall)
        .frame(minHeight: 52)
        .background(KairoColors.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                .stroke(KairoColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous))
    }

    private var supportCard: some View {
        KairoCard {
            HStack(alignment: .top, spacing: KairoSpacing.small) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(KairoColors.brandPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        KairoColors.surfaceMuted,
                        in: RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                    Text("Need direct help?")
                        .font(KairoTypography.headline)
                        .foregroundStyle(KairoColors.textPrimary)
                    Text("Browse the guides below, then contact KairoID support if you still need help.")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: KairoSpacing.xSmall)

                Button("Support", action: supportAction)
                    .font(KairoTypography.action)
                    .foregroundStyle(KairoColors.brandPrimary)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityHint("Opens an email to KairoID support")
                    .accessibilityIdentifier(KairoAccessibilityID.helpCenterSupport)
            }
        }
    }

    private var guidesSection: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            KairoSectionHeading(title: "Guides", count: HelpCenterContent.guides.count)
                .accessibilityIdentifier(KairoAccessibilityID.helpCenterGuidesSection)

            KairoCard {
                ForEach(Array(HelpCenterContent.guides.enumerated()), id: \.element.id) { index, guide in
                    if index > 0 { Divider() }
                    guideButton(guide)
                }
            }
        }
    }

    private func guideButton(_ guide: HelpGuide) -> some View {
        Button {
            focusAfterDetail = .guide(guide.id)
            selectedDetail = .guide(guide)
        } label: {
            HStack(alignment: .center, spacing: KairoSpacing.small) {
                Image(systemName: guide.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(KairoColors.brandPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        KairoColors.surfaceMuted,
                        in: RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                    Text(guide.title)
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textPrimary)
                    Text(guide.subtitle)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KairoColors.textSecondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(guide.title). \(guide.subtitle)")
        .accessibilityHint("Opens guide")
        .accessibilityIdentifier(KairoAccessibilityID.helpCenterGuide(guide.id))
        .accessibilityFocused($accessibilityFocus, equals: .guide(guide.id))
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            KairoSectionHeading(title: "Frequently asked questions", count: HelpCenterContent.faqs.count)
                .accessibilityIdentifier(KairoAccessibilityID.helpCenterFAQSection)

            KairoCard {
                ForEach(Array(HelpCenterContent.faqs.enumerated()), id: \.element.id) { index, faq in
                    if index > 0 { Divider() }
                    faqDisclosure(faq)
                }
            }
        }
    }

    private func faqDisclosure(_ faq: HelpFAQ) -> some View {
        let expanded = expandedFAQID == faq.id

        return VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Button {
                let change = { expandedFAQID = expanded ? nil : faq.id }
                if reduceMotion {
                    change()
                } else {
                    withAnimation(.easeInOut(duration: 0.2), change)
                }
            } label: {
                HStack(alignment: .center, spacing: KairoSpacing.small) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(KairoColors.textSecondary)
                        .frame(width: 24)
                        .accessibilityHidden(true)

                    Text(faq.question)
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KairoColors.textSecondary)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(faq.question)
            .accessibilityValue(expanded ? "Expanded" : "Collapsed")
            .accessibilityHint(expanded ? "Collapses answer" : "Expands answer")
            .accessibilityIdentifier(KairoAccessibilityID.helpCenterFAQ(faq.id))

            if expanded {
                Text(faq.answer)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 36)
                    .padding(.bottom, KairoSpacing.xSmall)
                    .transition(.opacity)
                    .accessibilityIdentifier(KairoAccessibilityID.helpCenterFAQAnswer(faq.id))
            }
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if results.isEmpty {
            KairoCard {
                VStack(spacing: KairoSpacing.small) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(KairoColors.textSecondary)
                        .accessibilityHidden(true)
                    Text("No results found")
                        .font(KairoTypography.headline)
                        .foregroundStyle(KairoColors.textPrimary)
                    Text("Try a different search term.")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(KairoAccessibilityID.helpCenterEmptySearch)
            }
        } else {
            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                KairoSectionHeading(title: "Search results", count: results.count)
                    .accessibilityIdentifier(KairoAccessibilityID.helpCenterSearchResults)

                KairoCard {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        if index > 0 { Divider() }
                        searchResultButton(result)
                    }
                }
            }
        }
    }

    private func searchResultButton(_ result: HelpSearchResult) -> some View {
        Button {
            focusAfterDetail = .result(result.id)
            selectedDetail = HelpCenterDetail(result.destination)
        } label: {
            HStack(alignment: .top, spacing: KairoSpacing.small) {
                VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                    Text(result.kind.rawValue)
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.brandPrimary)
                        .padding(.horizontal, KairoSpacing.xSmall)
                        .padding(.vertical, KairoSpacing.xxSmall)
                        .background(KairoColors.surfaceMuted, in: Capsule())

                    Text(result.title)
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(result.snippet)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KairoColors.textSecondary)
                    .padding(.top, KairoSpacing.xSmall)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.kind.rawValue). \(result.title). \(result.snippet)")
        .accessibilityHint("Opens help content")
        .accessibilityIdentifier(KairoAccessibilityID.helpCenterSearchResult(result.id))
        .accessibilityFocused($accessibilityFocus, equals: .result(result.id))
    }

    private var contactSupportFooter: some View {
        VStack(spacing: KairoSpacing.xxSmall) {
            Text("Still need help?")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
            Button("Email support · \(supportEmailAddress)", action: supportAction)
                .font(KairoTypography.action)
                .foregroundStyle(KairoColors.brandPrimary)
                .frame(minHeight: 44)
                .accessibilityHint("Opens an email to KairoID support")
        }
        .frame(maxWidth: .infinity)
    }

    private func restoreDetailFocus() {
        guard let focusAfterDetail else { return }
        accessibilityFocus = focusAfterDetail
        self.focusAfterDetail = nil
    }
}

private enum HelpCenterFocus: Hashable {
    case guide(String)
    case result(String)
}

private enum HelpCenterDetail: Identifiable {
    case guide(HelpGuide)
    case faq(HelpFAQ)

    init(_ destination: HelpSearchDestination) {
        switch destination {
        case .guide(let guide): self = .guide(guide)
        case .faq(let faq): self = .faq(faq)
        }
    }

    var id: String {
        switch self {
        case .guide(let guide): "guide.\(guide.id)"
        case .faq(let faq): "faq.\(faq.id)"
        }
    }

    var title: String {
        switch self {
        case .guide(let guide): guide.title
        case .faq(let faq): faq.question
        }
    }
}

private struct HelpCenterDetailView: View {
    let detail: HelpCenterDetail

    @Environment(\.dismiss) private var dismiss
    @AccessibilityFocusState private var closeFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    switch detail {
                    case .guide(let guide):
                        Text(guide.subtitle)
                            .font(KairoTypography.body)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(guide.sections) { section in
                            VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                                Text(section.title)
                                    .font(KairoTypography.headline)
                                    .foregroundStyle(KairoColors.textPrimary)
                                    .accessibilityAddTraits(.isHeader)
                                Text(section.body)
                                    .font(KairoTypography.body)
                                    .foregroundStyle(KairoColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                    case .faq(let faq):
                        Text("Frequently asked question")
                            .font(KairoTypography.caption)
                            .foregroundStyle(KairoColors.brandPrimary)
                        Text(faq.answer)
                            .font(KairoTypography.body)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button("Got it") { dismiss() }
                        .font(KairoTypography.action)
                        .foregroundStyle(KairoColors.onPrimary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            KairoColors.brandPrimary,
                            in: RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                        )
                        .accessibilityIdentifier("candidate.help.detail.done")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(KairoSpacing.medium)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle(detail.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityIdentifier(KairoAccessibilityID.helpCenterDetailClose)
                        .accessibilityFocused($closeFocused)
                }
            }
            .accessibilityIdentifier(KairoAccessibilityID.helpCenterDetail(detail.id))
            .onAppear { closeFocused = true }
        }
        .presentationDragIndicator(.visible)
    }
}
