import CoreGraphics
import Testing
@testable import Lens

struct ScannerStabilizerTests {
    private func read(_ raw: String, side: CGFloat = 100) -> CodeRead {
        CodeRead(raw: raw, symbology: .qr, quad: Quad(rect: CGRect(x: 0, y: 0, width: side, height: side)))
    }

    @Test func oneFrameIsNotEnough() {
        var stabilizer = DetectionStabilizer()
        #expect(stabilizer.ingest([read("A")], at: 0).isEmpty)
    }

    @Test func twoConsecutiveFramesLock() {
        var stabilizer = DetectionStabilizer()
        _ = stabilizer.ingest([read("A")], at: 0)
        #expect(stabilizer.ingest([read("A")], at: 0.033).map(\.raw) == ["A"])
    }

    @Test func aGapBetweenReadsStartsOver() {
        var stabilizer = DetectionStabilizer()
        _ = stabilizer.ingest([read("A")], at: 0)
        #expect(stabilizer.ingest([read("A")], at: 0.5).isEmpty)
        #expect(stabilizer.ingest([read("A")], at: 0.53).map(\.raw) == ["A"])
    }

    @Test func anEmptyFrameBreaksTheStreak() {
        var stabilizer = DetectionStabilizer()
        _ = stabilizer.ingest([read("A")], at: 0)
        _ = stabilizer.ingest([], at: 0.033)
        #expect(stabilizer.ingest([read("A")], at: 0.066).isEmpty)
    }

    @Test func aDifferentPayloadDoesNotCountTowardAnother() {
        var stabilizer = DetectionStabilizer()
        _ = stabilizer.ingest([read("A")], at: 0)
        #expect(stabilizer.ingest([read("B")], at: 0.033).isEmpty)
        #expect(stabilizer.ingest([read("A")], at: 0.066).isEmpty)
    }

    @Test func handledPayloadStaysQuietWhileInView() {
        var stabilizer = DetectionStabilizer()
        _ = stabilizer.ingest([read("A")], at: 0)
        _ = stabilizer.ingest([read("A")], at: 0.033)
        // Still pointing at it 5 s later: never fires again.
        var time = 0.066
        while time < 5 {
            #expect(stabilizer.ingest([read("A")], at: time).isEmpty)
            time += 0.033
        }
    }

    @Test func handledPayloadFiresAgainAfterTwoSecondsAway() {
        var stabilizer = DetectionStabilizer()
        _ = stabilizer.ingest([read("A")], at: 0)
        _ = stabilizer.ingest([read("A")], at: 0.033)
        #expect(stabilizer.ingest([read("A")], at: 1.9).isEmpty)
        #expect(stabilizer.ingest([read("A")], at: 1.93).isEmpty)
        // Gone for more than the cooldown.
        #expect(stabilizer.ingest([read("A")], at: 4.0).isEmpty)
        #expect(stabilizer.ingest([read("A")], at: 4.033).map(\.raw) == ["A"])
    }

    @Test func restartingCooldownsBlocksTheCodeThatCausedAPause() {
        var stabilizer = DetectionStabilizer()
        _ = stabilizer.ingest([read("A")], at: 0)
        _ = stabilizer.ingest([read("A")], at: 0.033)
        // A result was open for 10 s; detection resumes pointing at the same code.
        stabilizer.restartCooldowns(at: 10)
        #expect(stabilizer.ingest([read("A")], at: 10.1).isEmpty)
        #expect(stabilizer.ingest([read("A")], at: 10.13).isEmpty)
    }

    @Test func suppressedPayloadIsIgnored() {
        var stabilizer = DetectionStabilizer()
        stabilizer.suppress("A", at: 0)
        _ = stabilizer.ingest([read("A")], at: 0.1)
        #expect(stabilizer.ingest([read("A")], at: 0.133).isEmpty)
    }

    @Test func severalCodesLockTogetherLargestFirst() {
        var stabilizer = DetectionStabilizer()
        _ = stabilizer.ingest([read("small", side: 40), read("big", side: 200)], at: 0)
        let locked = stabilizer.ingest([read("small", side: 40), read("big", side: 200)], at: 0.033)
        #expect(locked.map(\.raw) == ["big", "small"])
    }

    @Test func duplicateReadsInOneFrameCountOnce() {
        var stabilizer = DetectionStabilizer()
        #expect(stabilizer.ingest([read("A"), read("A")], at: 0).isEmpty)
    }

    @Test func resetForgetsEverything() {
        var stabilizer = DetectionStabilizer()
        _ = stabilizer.ingest([read("A")], at: 0)
        _ = stabilizer.ingest([read("A")], at: 0.033)
        stabilizer.reset()
        _ = stabilizer.ingest([read("A")], at: 0.066)
        #expect(stabilizer.ingest([read("A")], at: 0.1).map(\.raw) == ["A"])
    }
}
