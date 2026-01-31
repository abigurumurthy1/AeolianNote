import Foundation

enum Environment {
    static var supabaseUrl: String {
        ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://your-project.supabase.co"
    }

    static var supabaseAnonKey: String {
        ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "your-anon-key"
    }

    static var openWeatherMapApiKey: String {
        ProcessInfo.processInfo.environment["OPENWEATHERMAP_API_KEY"] ?? "your-api-key"
    }

    static var openAiApiKey: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? "your-api-key"
    }

    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
