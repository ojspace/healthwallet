import Foundation
import Observation

@Observable
@MainActor
final class BiomarkerDetailViewModel {
    let biomarker: Biomarker

    init(biomarker: Biomarker) {
        self.biomarker = biomarker
    }

    var gaugeProgress: Double {
        let range = biomarker.optimalRange
        let total = range.upperBound - range.lowerBound
        guard total > 0 else { return 0 }
        let clamped = min(max(biomarker.value, range.lowerBound * 0.5), range.upperBound * 1.5)
        let fullRange = range.upperBound * 1.5 - range.lowerBound * 0.5
        return (clamped - range.lowerBound * 0.5) / fullRange
    }
}
