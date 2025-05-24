import Foundation

struct Message: Codable {
    let role: String
    let content: [Content]
}

struct Content: Codable {
    let type: String
    let text: String?
    let image_url: ImageURL?
}

struct ImageURL: Codable {
    let url: String
}

struct GemmaRequest: Codable {
    let model: String?
    let messages: [Message]
    let max_tokens: Int
    let temperature: Double
}

struct GemmaCloudflareResponse: Codable {
    let result: GemmaResult
}

struct GemmaOpenRouterResponse: Codable {
    let choices: [Choice]
    let usage: Usage
}

struct GemmaResult: Codable {
    let response: String
    let usage: Usage
}

struct Choice: Codable {
    let message: ResponseMessage
}

struct ResponseMessage: Codable {
    let content: String
}

struct Usage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

let USE_OPENROUTER = false
let CloudflareBaseUrl = "https://api.cloudflare.com/client/v4/accounts/5a01107832a452396e45ec30ab919dea/ai/run/@cf/google/gemma-3-12b-it"
let OpenRouterBaseUrl = "https://openrouter.ai/api/v1/chat/completions"

class GemmaService {
    static let shared = GemmaService()
    private let apiKey: String
    private let baseURL = USE_OPENROUTER ? OpenRouterBaseUrl : CloudflareBaseUrl
    private var currentTask: URLSessionDataTask?
    
    private init() {
        // Get API key from environment or configuration
        self.apiKey = USE_OPENROUTER ? (ProcessInfo.processInfo.environment["OPENROUTER_API_KEY"] ?? "") : (ProcessInfo.processInfo.environment["CLOUDFLARE_API_KEY"] ?? "")
    }
    
    private func getUserLanguagePreference() -> String {
        let locale = Locale.current
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        // let regionCode = locale.region?.identifier
        
        // Map language codes to more descriptive names for the AI
        // Handle region-specific variants where relevant
        switch languageCode {
        case "zh":
            // // Distinguish between Simplified and Traditional Chinese
            // if let region = regionCode {
            //     switch region {
            //     case "CN", "SG": return "Chinese (Simplified)"
            //     case "TW", "HK", "MO": return "Chinese (Traditional)"
            //     default: return "Chinese"
            //     }
            // }
            return "Chinese"
        case "en":
            return "English"
        case "ja":
            return "Japanese"
        case "ko":
            return "Korean"
        case "es":
            return "Spanish"
        case "fr":
            return "French"
        case "de":
            return "German"
        case "it":
            return "Italian"
        case "pt":
            return "Portuguese"
        case "ru":
            return "Russian"
        case "ar":
            return "Arabic"
        case "hi":
            return "Hindi"
        case "th":
            return "Thai"
        case "vi":
            return "Vietnamese"
        case "id":
            return "Indonesian"
        case "ms":
            return "Malay"
        case "tr":
            return "Turkish"
        case "pl":
            return "Polish"
        case "nl":
            return "Dutch"
        case "sv":
            return "Swedish"
        case "da":
            return "Danish"
        case "no":
            return "Norwegian"
        case "fi":
            return "Finnish"
        case "he":
            return "Hebrew"
        default:
            return "English" // Default fallback
        }
    }
    
    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }
    
    func processImage(_ imageBase64: String) async throws -> String {
        let userLanguage = getUserLanguagePreference()
        print("Detected user language preference: \(userLanguage)")
        
        let systemMessage = Message(
            role: "system",
            content: [
                Content(
                    type: "text",
                    text: """
                    You are a helpful assistant. The user that you assist is a blind person.
                    
                    Your primary task is to help the user navigate on foot, based on realtime images from the user's camera. Since the user is blind, you'll be their eyes.
                    
                    Address the user directly. No need to be polite, be practical, keep your language concise and effective, cut to the chase, packed with information.
                    
                    Highlight key elements that's crucial to navigation. Some examples:
                    - pay attention to signs and text related to navigation, describe them in detail
                    - obstacles, stairs, ramps, etc. give user a heads-up
                    - available paths that are not obvious
                    
                    Ignore elements that are not relevant to navigation.
                    
                    User's language preference: \(userLanguage).
                    """,
                    image_url: nil
                )
            ]
        )
        
        let userMessage = Message(
            role: "user",
            content: [
                Content(
                    type: "image_url",
                    text: nil,
                    image_url: ImageURL(url: "data:image/jpeg;base64,\(imageBase64)")
                )
            ]
        )
        
        let request = GemmaRequest(
            model: USE_OPENROUTER ? "google/gemma-3-12b-it" : nil,
            messages: [systemMessage, userMessage],
            max_tokens: 1000,
            temperature: 0
        )
        
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        print("request headers: \(String(describing: urlRequest.allHTTPHeaderFields))")

        let timeStart = Date()
        
        // Use a custom URLSession task that can be cancelled
        let (data, response): (Data, URLResponse) = try await withCheckedThrowingContinuation { continuation in
            let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
                }
            }
            
            // Store the task so it can be cancelled
            self.currentTask = task
            task.resume()
        }
        
        let timeEnd = Date()
        let timeElapsed = timeEnd.timeIntervalSince(timeStart)
        print("time elapsed: \(timeElapsed) seconds")
        
        // Clear the current task
        currentTask = nil
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
                // print what's wrong
                print("response: \(String(describing: response))")
                // print the response body as string
                print("response body: \(String(describing: String(data: data, encoding: .utf8)))")
            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "API request failed"])
        }

        print("response body: \(String(describing: String(data: data, encoding: .utf8)))")
        if USE_OPENROUTER {
            let resp = try JSONDecoder().decode(GemmaOpenRouterResponse.self, from: data)
            let usage = resp.usage
            print("tokens input: \(usage.prompt_tokens), tokens output: \(usage.completion_tokens)")
            return resp.choices.first?.message.content ?? "No description available"
        } else {
            let resp = try JSONDecoder().decode(GemmaCloudflareResponse.self, from: data)
            let usage = resp.result.usage
            print("tokens input: \(usage.prompt_tokens), tokens output: \(usage.completion_tokens)")
            return resp.result.response
        }
    }
} 
