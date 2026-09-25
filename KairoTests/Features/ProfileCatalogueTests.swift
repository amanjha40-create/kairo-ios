import XCTest
@testable import Kairo

@MainActor
final class ProfileCatalogueTests: XCTestCase {
    func test_skillCatalogueMatchesCertifiedAndroidCountsAndSource() {
        XCTAssertEqual(ProfileCatalogues.androidSourceSHA, "3a1ed54dae7f40b07ffbf0401c0ed8ed9c2bbc7e")
        XCTAssertEqual(ProfileCatalogues.skills.count, 278)
        XCTAssertEqual(Set(ProfileCatalogues.skills.compactMap(\.category)).count, 32)
    }

    func test_languageCatalogueMatchesCertifiedAndroidCount() {
        XCTAssertEqual(ProfileCatalogues.languages.count, 186)
        XCTAssertEqual(ProfileLanguageProficiency.allCases.map(\.rawValue), [
            "basic", "conversational", "professional", "fluent", "native"
        ])
        XCTAssertEqual(ProfileLanguageProficiency.native.title, "Native / Bilingual")
    }

    func test_cataloguesHaveUniqueCanonicalIdentity() {
        XCTAssertEqual(Set(ProfileCatalogues.skills.map(\.id)).count, 278)
        XCTAssertEqual(Set(ProfileCatalogues.languages.map(\.id)).count, 186)
        XCTAssertFalse(ProfileCatalogues.skills.contains { $0.name.localizedCaseInsensitiveContains("verified") })
    }

    func test_skillAliasesResolveOnlyToReviewedCanonicalValues() {
        XCTAssertEqual(ProfileCatalogues.resolve(" ms   EXCEL ", in: ProfileCatalogues.skills)?.name, "Microsoft Excel")
        XCTAssertEqual(ProfileCatalogues.resolve("AWS", in: ProfileCatalogues.skills)?.name, "Amazon Web Services")
        XCTAssertEqual(ProfileCatalogues.resolve("financial modelling", in: ProfileCatalogues.skills)?.name, "Financial Modeling")
        XCTAssertNil(ProfileCatalogues.resolve("PM", in: ProfileCatalogues.skills))
        XCTAssertNil(ProfileCatalogues.resolve("Totally made up skill", in: ProfileCatalogues.skills))
    }

    func test_skillSearchMatchesAliasesPrefixesAndCategory() {
        XCTAssertTrue(ProfileCatalogues.search("fin mod", in: ProfileCatalogues.skills).contains { $0.name == "Financial Modeling" })
        XCTAssertTrue(ProfileCatalogues.search("js", in: ProfileCatalogues.skills).contains { $0.name == "JavaScript" })
        XCTAssertEqual(ProfileCatalogues.search(" PM ", in: ProfileCatalogues.skills).map(\.name), ["Product Management", "Project Management"])
        XCTAssertTrue(ProfileCatalogues.search("cyber", in: ProfileCatalogues.skills).contains { $0.name == "Network Security" })
    }

    func test_skillDuplicateDetectionUsesCanonicalAndAliasesButNotPrefixes() throws {
        let excel = try XCTUnwrap(ProfileCatalogues.resolve("Microsoft Excel", in: ProfileCatalogues.skills))
        XCTAssertTrue(ProfileCatalogues.contains(excel, values: ["Excel"], in: ProfileCatalogues.skills))
        XCTAssertTrue(ProfileCatalogues.contains(excel, values: [" MS Excel "], in: ProfileCatalogues.skills))
        XCTAssertFalse(ProfileCatalogues.contains(excel, values: ["Exce"], in: ProfileCatalogues.skills))
    }

    func test_languageAliasesAndIndianLanguagesMatchAndroid() {
        XCTAssertEqual(ProfileCatalogues.resolve("Bangla", in: ProfileCatalogues.languages)?.name, "Bengali")
        XCTAssertEqual(ProfileCatalogues.resolve("Mandarin", in: ProfileCatalogues.languages)?.id, "cmn")
        XCTAssertEqual(ProfileCatalogues.resolve("Chinese", in: ProfileCatalogues.languages)?.id, "zh")
        for name in ["Hindi", "Kannada", "Tamil", "Telugu", "Malayalam", "Marathi", "Gujarati", "Punjabi", "Urdu", "Odia"] {
            XCTAssertNotNil(ProfileCatalogues.resolve(name, in: ProfileCatalogues.languages), name)
        }
    }

    func test_unknownLegacyLanguageIsNotSilentlyRemapped() {
        XCTAssertNil(ProfileCatalogues.resolve("Hinglish", in: ProfileCatalogues.languages))
        XCTAssertTrue(ProfileCatalogues.search("Hinglish", in: ProfileCatalogues.languages).isEmpty)
    }

    func test_profileURLValidationNormalizesSafeLinksAndRejectsUnsafeSchemes() {
        XCTAssertEqual(ProfileURLValidator.normalized("example.com/me")?.absoluteString, "https://example.com/me")
        XCTAssertEqual(ProfileURLValidator.normalized("http://example.com")?.scheme, "http")
        XCTAssertNil(ProfileURLValidator.normalized("javascript:alert(1)"))
        XCTAssertNil(ProfileURLValidator.normalized("https://user:secret@example.com"))
        XCTAssertNil(ProfileURLValidator.normalized("not a link"))
    }

    func test_profileDraftValidatesSupportedFieldsAndEncodesPrivateDateOnly() throws {
        var draft = ProfileEditDraft(user: ProfileSnapshot.fixture.user)
        draft.fullName = "  "
        draft.yearsOfExperience = "81"
        draft.locationCountry = "India"
        draft.dateOfBirth = "25/09/2000"
        draft.bio = String(repeating: "a", count: 501)
        XCTAssertEqual(Set(draft.validationErrors.keys), [
            "full_name", "years_of_experience", "location_country", "date_of_birth", "bio"
        ])

        draft = ProfileEditDraft(user: ProfileSnapshot.fixture.user)
        draft.dateOfBirth = "2000-09-25"
        draft.locationCountry = "in"
        XCTAssertTrue(draft.validationErrors.isEmpty)
        XCTAssertEqual(draft.request.dateOfBirth, "2000-09-25")
        XCTAssertEqual(draft.request.locationCountry, "IN")
    }

    func test_careerSkillDraftRejectsFreeTextAndCanonicalizesAlias() {
        XCTAssertNotNil(CareerSkillDraft(name: "Made Up").validationErrors(existingNames: [])["name"])
        let alias = CareerSkillDraft(name: "ms excel")
        XCTAssertTrue(alias.validationErrors(existingNames: []).isEmpty)
        XCTAssertEqual(alias.createRequest().name, "Microsoft Excel")
        XCTAssertNotNil(alias.validationErrors(existingNames: ["Excel"])["name"])
    }
}
