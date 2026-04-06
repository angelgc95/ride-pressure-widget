import Foundation

struct HTTPClient {
    enum HTTPError: LocalizedError {
        case badStatus(Int, String)
        case emptyData

        var errorDescription: String? {
            switch self {
            case .badStatus(let status, let name):
                return "\(name) failed with status \(status)."
            case .emptyData:
                return "The upstream response was empty."
            }
        }
    }

    func fetch<T: Decodable>(
        url: URL,
        name: String,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String] = [:],
        retries: Int = 2,
        timeout: TimeInterval = 9,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...retries {
            do {
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
                request.httpMethod = method
                request.httpBody = body
                request.timeoutInterval = timeout
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")

                for (key, value) in headers {
                    request.setValue(value, forHTTPHeaderField: key)
                }

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AppError.invalidResponse("Invalid response from \(name).")
                }

                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw HTTPError.badStatus(httpResponse.statusCode, name)
                }

                guard !data.isEmpty else {
                    throw HTTPError.emptyData
                }

                return try decoder.decode(T.self, from: data)
            } catch {
                lastError = error
                if attempt == retries {
                    break
                }

                try? await Task.sleep(nanoseconds: UInt64((250_000_000) * (attempt + 1)))
            }
        }

        throw lastError ?? AppError.invalidResponse("Could not load \(name).")
    }
}
