import SwiftUI

struct DigiLockerAadhaarView: View {
    @EnvironmentObject private var store: DigiLockerStore
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @State private var verifiedMotion = 0

    var body: some View {
        KairoSection {
            KairoSectionHeading(title: "e-Aadhaar identity")
            Text("Check whether e-Aadhaar is available through your DigiLocker connection. Availability does not mean it is verified.")
                .font(KairoTypography.metadata)
                .fixedSize(horizontal: false, vertical: true)
            Text("No Aadhaar number entry is needed. KairoID keeps the verification result, not your Aadhaar number, photo or source file. Permanent Address verification remains separate.")
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let saved = store.savedAadhaar {
                HStack(alignment: .top) {
                    if saved.isVerified {
                        KairoTrustSignature(kind: .verified, trigger: verifiedMotion,
                                            animateInitially: verifiedMotion > 0, size: 36)
                            .accessibilityHidden(true)
                    }
                    KairoStatusChip(title: saved.isVerified ? "Verified" : "Needs review",
                                    tone: saved.isVerified ? .verified : .attention)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(saved.isVerified ? "e-Aadhaar. Verified" : "e-Aadhaar. Needs review")
                .accessibilityIdentifier("candidate.aadhaar.saved")
                if !saved.isVerified {
                    Text(DigiLockerPresentation.safeReason(saved.matchReason))
                        .font(KairoTypography.metadata)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if store.summaryError {
                status("Connection status unavailable. Refresh saved results before checking e-Aadhaar.")
            } else if store.status?.connected != true {
                status(store.status?.status == .reconnectRequired
                       ? "Reconnect DigiLocker to check e-Aadhaar availability."
                       : "Connect DigiLocker to check e-Aadhaar availability.")
            } else {
                if store.aadhaarState != .idle { status(store.aadhaarState.message) }
                if store.aadhaarState.isBusy { ProgressView().accessibilityLabel(store.aadhaarState.message) }
                if store.aadhaarState == .available {
                    consent
                    Text("This does not verify your Permanent Address or add separate Trust Score points.")
                        .font(KairoTypography.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    KairoPrimaryButton(title: "Verify e-Aadhaar", accessibilityIdentifier: "candidate.aadhaar.verify") {
                        Task {
                            if await store.verifyAadhaar() {
                                if store.savedAadhaar?.isVerified == true { verifiedMotion += 1 }
                                refreshStore.candidateDataChanged()
                            }
                        }
                    }
                    .disabled(!store.aadhaarConsent || store.actionInProgress || store.aadhaarNeedsReconciliation || store.isLoadingSummary)
                } else if !store.aadhaarState.isBusy && store.aadhaarState != .verified {
                    KairoSecondaryButton(title: "Check e-Aadhaar availability") {
                        Task { await store.checkAadhaarAvailability() }
                    }
                    .disabled(store.actionInProgress || store.aadhaarNeedsReconciliation || store.isLoadingSummary)
                    .accessibilityIdentifier("candidate.aadhaar.check")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("candidate.aadhaar.section")
        .onChange(of: store.aadhaarState) { _, state in
            if state != .idle { AccessibilityNotification.Announcement(state.message).post() }
        }
    }

    private var consent: some View {
        Button {
            store.aadhaarConsent.toggle()
        } label: {
            HStack(alignment: .top, spacing: KairoSpacing.small) {
                Image(systemName: store.aadhaarConsent ? "checkmark.square.fill" : "square")
                    .accessibilityHidden(true)
                Text("I consent to KairoID retrieving e-Aadhaar from DigiLocker and matching my name and date of birth for identity verification. Required.")
                    .font(KairoTypography.metadata)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.actionInProgress)
        .accessibilityLabel("Consent to retrieve e-Aadhaar and match name and date of birth for identity verification. Required.")
        .accessibilityValue(store.aadhaarConsent ? "Checked" : "Unchecked")
        .accessibilityHint("Double tap to change consent. Required to enable Verify e-Aadhaar.")
        .accessibilityIdentifier("candidate.aadhaar.consent")
    }

    private func status(_ text: String) -> some View {
        Text(text)
            .font(KairoTypography.metadata)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("candidate.aadhaar.status")
    }
}
