import Foundation
import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import Kairo

@MainActor
final class ProfileOverviewStoreTests: XCTestCase {
    func testProfessionalBioIsOptionalMultilineAndUsesExistingLimits() throws {
        var draft = ProfileEditDraft(user: ProfileSnapshot.fixture.user)
        draft.bio = " \nFirst line\nSecond line\n "
        XCTAssertEqual(draft.request.bio, "First line\nSecond line")
        XCTAssertNil(draft.validationErrors["bio"])
        draft.bio = ""
        XCTAssertNil(draft.validationErrors["bio"])
        draft.bio = String(repeating: "a", count: 501)
        XCTAssertNotNil(draft.validationErrors["bio"])
        draft.headline = String(repeating: "a", count: 256)
        XCTAssertNotNil(draft.validationErrors["headline"])
    }
    func testPhotoPreparationAcceptsJPEGPNGAndHEICWithoutResizingOrChangingQualityPolicy() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 96), format: format).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 128, height: 96))
        }
        for type in [UTType.jpeg, .png, .heic] {
            let encoded = NSMutableData()
            let destination = try XCTUnwrap(CGImageDestinationCreateWithData(encoded, type.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, try XCTUnwrap(image.cgImage), nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
            let decoded = try ProfilePhotoPreparation.decode(encoded as Data)
            let upload = try ProfilePhotoPreparation.jpegData(decoded)
            XCTAssertEqual(upload, decoded.jpegData(compressionQuality: 0.82))
            let prepared = try XCTUnwrap(UIImage(data: upload))
            XCTAssertEqual(prepared.size, CGSize(width: 128, height: 96))
        }
        XCTAssertThrowsError(try ProfilePhotoPreparation.decode(Data("not an image".utf8))) {
            XCTAssertEqual($0 as? ProfileServiceError, .photoUnreadable)
        }
    }
    func testPhotoFailuresPreserveSafeSizeConnectionAndServerCategories() {
        XCTAssertTrue(ProfilePhotoFailure.message(for: ProfileServiceError.photoTooLarge).contains("5 MB"))
        XCTAssertTrue(ProfilePhotoFailure.message(for: URLError(.notConnectedToInternet)).contains("connection"))
        XCTAssertTrue(ProfilePhotoFailure.message(for: NetworkError.transport("PRIVATE_DETAILS")).contains("connection"))
        XCTAssertFalse(ProfilePhotoFailure.message(for: NetworkError.transport("PRIVATE_DETAILS")).contains("PRIVATE_DETAILS"))
        XCTAssertTrue(ProfilePhotoFailure.message(for: SecureDocumentTransferError.storageUploadFailed).contains("storage service"))
    }
    func test_fixtureProfileUpdateReflectsEveryMutableField() async throws {
        let service = ProfileFixtureService()
        var draft = ProfileEditDraft(user: ProfileSnapshot.fixture.user)
        draft.fullName = "Synthetic Updated Candidate"
        draft.phone = "+911234567890"
        draft.headline = "Updated headline"
        draft.currentRole = "Updated role"
        draft.industry = "Financial Services"
        draft.yearsOfExperience = "7"
        draft.location = "Pune, India"
        draft.locationCity = "Pune"
        draft.locationRegion = "Maharashtra"
        draft.locationCountry = "in"
        draft.bio = "Updated profile fixture."
        draft.dateOfBirth = "25-09-2000"

        let user = try await service.update(draft).user

        XCTAssertEqual(user.fullName, "Synthetic Updated Candidate")
        XCTAssertEqual(user.phone, "+911234567890")
        XCTAssertEqual(user.headline, "Updated headline")
        XCTAssertEqual(user.currentRole, "Updated role")
        XCTAssertEqual(user.industry, "Financial Services")
        XCTAssertEqual(user.yearsOfExperience, 7)
        XCTAssertEqual(user.location, "Pune, India")
        XCTAssertEqual(user.locationCity, "Pune")
        XCTAssertEqual(user.locationRegion, "Maharashtra")
        XCTAssertEqual(user.locationCountry, "IN")
        XCTAssertEqual(user.bio, "Updated profile fixture.")
        XCTAssertNotNil(user.dateOfBirth)
    }

    func test_fixtureServiceSupportsSuccessfulStructuredSkillAndLanguageLifecycle() async throws {
        let service = ProfileFixtureService()
        var snapshot = try await service.addSkill(name: "AWS")
        XCTAssertTrue(snapshot.skills.contains { $0.name == "Amazon Web Services" })

        snapshot = try await service.addLanguage(name: "Marathi", proficiency: .basic)
        let language = try XCTUnwrap(snapshot.user.languages.first { $0.language == "Marathi" })
        XCTAssertEqual(language.proficiency, "basic")

        snapshot = try await service.updateLanguage(id: language.id, name: "Marathi", proficiency: .native)
        XCTAssertEqual(snapshot.user.languages.first { $0.id == language.id }?.proficiency, "native")

        snapshot = try await service.removeLanguage(id: language.id)
        XCTAssertFalse(snapshot.user.languages.contains { $0.id == language.id })
    }

    func test_skillSaveFailureKeepsSnapshotAndMapsSafeMessage() async {
        let initial = ProfileSnapshot.fixture
        let store = ProfileOverviewStore(service: FailingProfileService(), initialUser: initial.user)
        await store.load()

        do {
            try await store.addSkills(["SwiftUI"])
            XCTFail("Expected save failure")
        } catch {}

        XCTAssertEqual(store.snapshot, initial)
        XCTAssertEqual(store.errorMessage, "Could not add all selected skills. Any saved skills are kept. Please try again.")
        XCTAssertFalse(store.isMutating)
    }

    func test_languageSaveFailureKeepsSnapshotAndMapsSafeMessage() async {
        let initial = ProfileSnapshot.fixture
        let store = ProfileOverviewStore(service: FailingProfileService(), initialUser: initial.user)
        await store.load()

        do {
            try await store.addLanguage(name: "Marathi", proficiency: .professional)
            XCTFail("Expected save failure")
        } catch {}

        XCTAssertEqual(store.snapshot, initial)
        XCTAssertEqual(store.errorMessage, "Your change could not be saved. Please try again.")
        XCTAssertFalse(store.isMutating)
    }
}

private struct FailingProfileService: ProfileServiceProtocol {
    private let snapshot = ProfileSnapshot.fixture
    private struct Failure: Error {}

    func load() async throws -> ProfileSnapshot { snapshot }
    func update(_ draft: ProfileEditDraft) async throws -> ProfileSnapshot { _ = draft; throw Failure() }
    func uploadAvatar(jpegData: Data) async throws -> ProfileSnapshot { _ = jpegData; throw Failure() }
    func removeAvatar() async throws -> ProfileSnapshot { throw Failure() }
    func addSkill(name: String) async throws -> ProfileSnapshot { _ = name; throw Failure() }
    func removeSkill(id: String) async throws -> ProfileSnapshot { _ = id; throw Failure() }
    func addLanguage(name: String, proficiency: ProfileLanguageProficiency) async throws -> ProfileSnapshot {
        _ = (name, proficiency); throw Failure()
    }
    func updateLanguage(id: String, name: String, proficiency: ProfileLanguageProficiency) async throws -> ProfileSnapshot {
        _ = (id, name, proficiency); throw Failure()
    }
    func removeLanguage(id: String) async throws -> ProfileSnapshot { _ = id; throw Failure() }
    func addLink(type: ProfileLinkType, label: String?, url: URL) async throws -> ProfileSnapshot {
        _ = (type, label, url); throw Failure()
    }
    func updateLink(id: String, type: ProfileLinkType, label: String?, url: URL) async throws -> ProfileSnapshot {
        _ = (id, type, label, url); throw Failure()
    }
    func removeLink(id: String) async throws -> ProfileSnapshot { _ = id; throw Failure() }
}
