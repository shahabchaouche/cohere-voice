import os

public enum CVLog {
    private static let subsystem = "com.shahab.coherevoice"
    public static let audio = Logger(subsystem: subsystem, category: "audio")
    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let session = Logger(subsystem: subsystem, category: "session")
    public static let shortcut = Logger(subsystem: subsystem, category: "shortcut")
}
