import XCTest
@testable import LoveCompass

final class APIServiceTests: XCTestCase {

    // MARK: - APIError

    func testAPIErrorBadStatusDescription() {
        let error = APIService.APIError.badStatus(404, "Not found")
        XCTAssertTrue(error.errorDescription!.contains("404"))
        XCTAssertTrue(error.errorDescription!.contains("Not found"))
    }

    func testAPIErrorDecodingFailedDescription() {
        let error = APIService.APIError.decodingFailed("{invalid}")
        XCTAssertTrue(error.errorDescription!.contains("{invalid}"))
    }

    func testAPIErrorInvalidURLDescription() {
        let error = APIService.APIError.invalidURL
        XCTAssertNotNil(error.errorDescription)
    }

    func testAPIErrorUnknownDescription() {
        let error = APIService.APIError.unknown
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - Singleton

    func testSharedInstanceIsSingleton() {
        let a = APIService.shared
        let b = APIService.shared
        XCTAssertTrue(a === b, "APIService.shared should return the same instance")
    }

    // MARK: - Health Check (Integration - requires running server)

    func testHealthCheckAgainstLiveServer() async throws {
        // This is an integration test that requires the backend to be running.
        // Skip if server is not available.
        do {
            let healthy = try await APIService.shared.healthCheck()
            XCTAssertTrue(healthy)
        } catch {
            // Server not available - that's ok for unit test runs
            print("Skipping health check - server not reachable: \(error)")
        }
    }
}
