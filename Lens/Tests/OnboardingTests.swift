import AVFoundation
import Testing
@testable import Lens

struct OnboardingStepTests {
    @Test func cameraPrimingOnlyBeforeTheSystemPrompt() {
        #expect(OnboardingStep.steps(cameraStatus: .notDetermined) == OnboardingStep.allCases)
        for answered in [AVAuthorizationStatus.authorized, .denied, .restricted] {
            #expect(!OnboardingStep.steps(cameraStatus: answered).contains(.camera))
        }
    }

    @Test func firstScanIsTheOnlyDarkStep() {
        #expect(OnboardingStep.allCases.filter(\.prefersDarkAppearance) == [.firstScan])
    }
}

struct OnboardingQRMatrixTests {
    @Test func trimsQuietZoneToTheSymbol() throws {
        let matrix = try #require(QRMatrix("https://lens.app/welcome"))
        // 24 bytes at error correction L is a version 2 symbol: 25 × 25 modules.
        #expect(matrix.size == 25)
    }

    @Test func findersAreInTheCorners() throws {
        let matrix = try #require(QRMatrix("LENS"))
        let last = matrix.size - 1
        // Each finder pattern: dark outer ring, light ring, dark core.
        for (row, column) in [(0, 0), (0, last - 6), (last - 6, 0)] {
            #expect(matrix.isDark(row: row, column: column))
            #expect(!matrix.isDark(row: row + 1, column: column + 1))
            #expect(matrix.isDark(row: row + 3, column: column + 3))
        }
    }
}
