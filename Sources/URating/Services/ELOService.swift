import Foundation

enum ELOService {
    static func ratingChange(winnerRating: Double, loserRating: Double, kFactor: Double = 32.0) -> Double {
        let expected = 1.0 / (1.0 + pow(10.0, (loserRating - winnerRating) / 400.0))
        return kFactor * (1.0 - expected)
    }
}
