import SwiftUI

struct PassportShareReview: View {
    let draft: PassportShareDraft

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            field("Mode", PassportShareHierarchy.modeTitle(draft.sharingMode), id: "mode")
            field("Purpose", PassportShareHierarchy.purpose(draft), id: "purpose")
            field("Expiry", PassportShareHierarchy.expiry(draft), id: "expiry")
            field("Selected sections", selectedSections, id: "sections")
            field("Profile details", draft.permissions.includeProfile ? "Shared · Candidate-provided" : "Not shared", id: "profile")
            field("Profile photo", draft.permissions.showPhoto ? "Shared" : "Not shared", id: "photo")
            field("Trust Score", draft.permissions.showTrustScore ? "Shared · account-wide derived aggregate" : "Not shared", id: "trustScore")
            Text("Private email and phone are excluded. Existing links can only be narrowed; broader disclosure requires a new link.")
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedSections: String {
        let values = PassportShareHierarchy.selectedSections(draft.permissions)
        return values.isEmpty ? "No optional sections shared" : values.joined(separator: ", ")
    }

    private func field(_ title: String, _ value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text(title).font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
            Text(value).font(KairoTypography.bodyStrong).foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("passport.share.review.\(id)")
    }
}
