import Testing
@testable import CohereVoiceCore

struct MetricsTests {
    @Test func marksProduceDurations() async {
        let metrics = MetricsCollector()
        await metrics.mark(.shortcutDown)
        await metrics.mark(.engineStarted)
        await metrics.mark(.recordingStopped)
        await metrics.mark(.encodingCompleted)
        await metrics.mark(.requestSent)
        await metrics.mark(.transcriptionReturned)
        await metrics.mark(.rewriteReturned)
        await metrics.mark(.textInserted)
        let snapshot = await metrics.snapshot()
        #expect(snapshot.recordingStartupMs != nil)
        #expect(snapshot.totalPostRecordingMs != nil)
    }
}
