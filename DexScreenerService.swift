import Foundation

enum MarketDataError: LocalizedError {
    case invalidURL
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Could not build the market-data URL."
        case .badResponse(let code): return "Market-data request failed (HTTP \(code))."
        }
    }
}

struct DexScreenerService {
    func fetchPairs(for addresses: [String]) async throws -> [DexPair] {
        guard !addresses.isEmpty else { return [] }

        var allPairs: [DexPair] = []
        for batchStart in stride(from: 0, to: addresses.count, by: 30) {
            let end = min(batchStart + 30, addresses.count)
            let batch = addresses[batchStart..<end].joined(separator: ",")
            guard let encoded = batch.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://api.dexscreener.com/tokens/v1/solana/\(encoded)") else {
                throw MarketDataError.invalidURL
            }

            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw MarketDataError.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
            }

            let pairs = try JSONDecoder().decode([DexPair].self, from: data)
            allPairs.append(contentsOf: pairs)
        }
        return allPairs
    }
}
