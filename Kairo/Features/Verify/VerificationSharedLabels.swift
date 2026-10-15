import Foundation

/// Presentation allowlist only; wire consent scopes and submission payloads stay unchanged.
nonisolated enum VerificationSharedLabels {
    static let fields = [
        "employment.employer_name": "Employer", "employment.role": "Role", "role": "Role",
        "employment_dates": "Employment dates", "employment.start_date": "Employment dates", "employment.end_date": "Employment dates",
        "employment.employment_type": "Employment type", "employment.work_location_country": "Work country",
        "employment.work_location_region": "Work region", "education.institution_name": "Institution",
        "education.degree": "Degree", "education.field_of_study": "Field of study", "education_dates": "Education dates",
        "education.start_date": "Education dates", "education.end_date": "Education dates"
    ]
    static let evidence = [
        "employment_evidence": "Employment evidence", "education_evidence": "Education evidence",
        "offer_letter": "Offer letter", "appointment_letter": "Appointment letter", "experience_letter": "Experience letter",
        "relieving_letter": "Relieving letter", "payslip": "Payslip", "salary_slip": "Payslip",
        "employment_contract": "Employment contract", "degree": "Degree certificate", "degree_certificate": "Degree certificate",
        "diploma": "Diploma", "transcript": "Transcript", "marksheet": "Marksheet", "certificate": "Certificate", "other": "Supporting document"
    ]
    static func labels(_ values: [String]) -> [String] {
        values.compactMap { fields[$0] }.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
    }
    static func evidenceLabel(_ value: String) -> String { evidence[value] ?? "Verification evidence" }
}
