import Foundation

public enum AudioEvent: Sendable, Equatable {
    case level(Float)
    case speechStarted
    case speechEnded
    case routeChanged
    case interrupted
}

public enum EngineEvent: Sendable {
    case chunk(PCMChunk)
    case routeChanged
    case interrupted(String)
}
