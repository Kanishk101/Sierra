import Foundation

/// Learns per-trip fuel usage without needing known tank capacity.
/// The model uses fuel percentage deltas + refuel receipt litres as anchors.
actor FuelOptimizationService {
    static let shared = FuelOptimizationService()

    struct TripFuelSummary: Codable, Sendable {
        let tripId: UUID
        let baselineFuelPct: Double
        let finalFuelPct: Double
        let estimatedLitresPerPercent: Double
        let totalRefuelLitres: Double
        let estimatedFuelConsumedLitres: Double
        let distanceKm: Double
        let mileageKmPerLitre: Double?
        let generatedAt: Date
        let ignoredAnomalyCount: Int
    }

    struct RefuelUpdate: Sendable {
        let accepted: Bool
        let reason: String?
        let estimatedLitresPerPercent: Double?
    }

    private struct TripFuelSession: Codable {
        let tripId: UUID
        var baselineFuelPct: Double
        var baselineOdometerKm: Double?
        var baselineRecordedAt: Date

        var lastFuelPct: Double
        var lastDistanceKm: Double

        var totalRefuelLitres: Double
        var cumulativeConsumedLitres: Double
        var pendingDropPctWithoutFactor: Double

        var estimatedLitresPerPercent: Double?
        var acceptedAnchorCount: Int
        var anchorRisePctTotal: Double
        var anchorLitresTotal: Double

        var ignoredAnomalies: [String]
        var finalSummary: TripFuelSummary?
    }

    private struct PersistedStore: Codable {
        var sessions: [String: TripFuelSession]
    }

    private let defaultsKey = "fuel_optimization_sessions_v1"
    private var sessions: [UUID: TripFuelSession] = [:]

    private init() {
        sessions = Self.loadFromDefaults(key: defaultsKey)
    }

    // MARK: - Public API

    func startTripBaseline(
        tripId: UUID,
        fuelPct: Int,
        odometerKm: Double?
    ) {
        let pct = clampPercent(Double(fuelPct))
        let session = TripFuelSession(
            tripId: tripId,
            baselineFuelPct: pct,
            baselineOdometerKm: odometerKm,
            baselineRecordedAt: Date(),
            lastFuelPct: pct,
            lastDistanceKm: 0,
            totalRefuelLitres: 0,
            cumulativeConsumedLitres: 0,
            pendingDropPctWithoutFactor: 0,
            estimatedLitresPerPercent: nil,
            acceptedAnchorCount: 0,
            anchorRisePctTotal: 0,
            anchorLitresTotal: 0,
            ignoredAnomalies: [],
            finalSummary: nil
        )
        sessions[tripId] = session
        saveToDefaults()
    }

    func recordMidTripRefuel(
        tripId: UUID,
        litresAdded: Double,
        fuelPctBefore: Int,
        fuelPctAfter: Int,
        odometerKm: Double?
    ) -> RefuelUpdate {
        guard litresAdded > 0 else {
            return RefuelUpdate(accepted: false, reason: "Receipt litres must be greater than zero.", estimatedLitresPerPercent: nil)
        }

        guard var session = sessions[tripId] else {
            return RefuelUpdate(accepted: false, reason: "Pre-trip fuel baseline missing for this trip.", estimatedLitresPerPercent: nil)
        }

        var before = clampPercent(Double(fuelPctBefore))
        var after = clampPercent(Double(fuelPctAfter))

        guard after >= before else {
            addAnomaly("Refuel ignored: fuel after (\(Int(after))%) is lower than before (\(Int(before))%).", to: &session)
            sessions[tripId] = session
            saveToDefaults()
            return RefuelUpdate(accepted: false, reason: "Fuel after-refuel must be >= fuel before-refuel.", estimatedLitresPerPercent: session.estimatedLitresPerPercent)
        }

        // OCR sanity check: sudden positive jump before refuel is suspicious.
        let beforeJump = before - session.lastFuelPct
        if beforeJump > 12 {
            addAnomaly("Sudden +\(Int(beforeJump))% jump before refuel ignored; using previous fuel reading.", to: &session)
            before = session.lastFuelPct
            if after < before {
                after = before
            }
        }

        // Consumption since previous point (drop from last post-refuel level to current pre-refuel).
        let dropPct = max(0, session.lastFuelPct - before)
        accumulateDrop(dropPct, into: &session)

        // Refuel anchor: rise in percentage should map to receipt litres.
        let risePct = max(0, after - before)
        if risePct >= 2 {
            let candidate = litresAdded / risePct
            session.anchorRisePctTotal += risePct
            session.anchorLitresTotal += litresAdded
            if isPlausibleLitresPerPercent(candidate) {
                let newCount = session.acceptedAnchorCount + 1
                if let current = session.estimatedLitresPerPercent {
                    let blended = (current * Double(session.acceptedAnchorCount) + candidate) / Double(newCount)
                    session.estimatedLitresPerPercent = blended
                } else {
                    session.estimatedLitresPerPercent = candidate
                }
                session.acceptedAnchorCount = newCount
            } else {
                addAnomaly("Anchor \(String(format: "%.3f", candidate)) L/% out of range, ignored.", to: &session)
            }
        } else {
            addAnomaly("Refuel rise \(String(format: "%.1f", risePct))% too small for a reliable anchor.", to: &session)
        }

        // Flush pending drops once we have a learned factor.
        if session.pendingDropPctWithoutFactor > 0, let factor = session.estimatedLitresPerPercent {
            session.cumulativeConsumedLitres += session.pendingDropPctWithoutFactor * factor
            session.pendingDropPctWithoutFactor = 0
        }

        session.totalRefuelLitres += litresAdded
        session.lastFuelPct = after
        session.lastDistanceKm = max(session.lastDistanceKm, distanceFromBaseline(session: session, odometerKm: odometerKm))

        sessions[tripId] = session
        saveToDefaults()

        return RefuelUpdate(
            accepted: true,
            reason: nil,
            estimatedLitresPerPercent: session.estimatedLitresPerPercent
        )
    }

    func finalizeTrip(
        tripId: UUID,
        finalFuelPct: Int,
        tripDistanceKm: Double?
    ) -> TripFuelSummary? {
        guard var session = sessions[tripId] else { return nil }

        var finalPct = clampPercent(Double(finalFuelPct))
        let finalJump = abs(finalPct - session.lastFuelPct)
        if finalJump > 45, session.totalRefuelLitres == 0 {
            addAnomaly("Final fuel OCR jump \(Int(finalJump))% ignored; using last stable reading.", to: &session)
            finalPct = session.lastFuelPct
        }

        let trailingDrop = max(0, session.lastFuelPct - finalPct)
        accumulateDrop(trailingDrop, into: &session)

        // Fallback factor from aggregate anchors if no direct accepted anchor exists.
        if session.estimatedLitresPerPercent == nil,
           session.anchorRisePctTotal > 0 {
            let fallback = session.anchorLitresTotal / session.anchorRisePctTotal
            if isPlausibleLitresPerPercent(fallback) {
                session.estimatedLitresPerPercent = fallback
            }
        }

        guard let factor = session.estimatedLitresPerPercent else {
            addAnomaly("Trip finalized without enough anchor data to estimate litres-per-percent.", to: &session)
            sessions[tripId] = session
            saveToDefaults()
            return nil
        }

        if session.pendingDropPctWithoutFactor > 0 {
            session.cumulativeConsumedLitres += session.pendingDropPctWithoutFactor * factor
            session.pendingDropPctWithoutFactor = 0
        }

        // Balance check that combines net percentage drop with actual refuel litres.
        let balanceConsumption = session.totalRefuelLitres + max(0, session.baselineFuelPct - finalPct) * factor
        var estimatedConsumed = session.cumulativeConsumedLitres
        if estimatedConsumed > 0 {
            let drift = abs(estimatedConsumed - balanceConsumption) / max(estimatedConsumed, 1)
            if drift > 0.25 {
                addAnomaly("Consumption drift \(Int(drift * 100))% corrected with balance model.", to: &session)
                estimatedConsumed = (estimatedConsumed + balanceConsumption) / 2
            }
        } else {
            estimatedConsumed = balanceConsumption
        }

        let distanceKm = max(0, tripDistanceKm ?? session.lastDistanceKm)
        let mileage = estimatedConsumed > 0 ? distanceKm / estimatedConsumed : nil

        let summary = TripFuelSummary(
            tripId: tripId,
            baselineFuelPct: session.baselineFuelPct,
            finalFuelPct: finalPct,
            estimatedLitresPerPercent: factor,
            totalRefuelLitres: session.totalRefuelLitres,
            estimatedFuelConsumedLitres: max(0, estimatedConsumed),
            distanceKm: distanceKm,
            mileageKmPerLitre: mileage,
            generatedAt: Date(),
            ignoredAnomalyCount: session.ignoredAnomalies.count
        )

        session.finalSummary = summary
        session.lastFuelPct = finalPct
        sessions[tripId] = session
        saveToDefaults()
        return summary
    }

    func latestSummary(for tripId: UUID) -> TripFuelSummary? {
        sessions[tripId]?.finalSummary
    }

    func latestSummaries(for tripIds: [UUID]) -> [UUID: TripFuelSummary] {
        var result: [UUID: TripFuelSummary] = [:]
        for tripId in tripIds {
            if let summary = sessions[tripId]?.finalSummary {
                result[tripId] = summary
            }
        }
        return result
    }

    // MARK: - Helpers

    private func clampPercent(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    private func isPlausibleLitresPerPercent(_ value: Double) -> Bool {
        (0.05...8.0).contains(value)
    }

    private func distanceFromBaseline(session: TripFuelSession, odometerKm: Double?) -> Double {
        guard let odo = odometerKm else { return session.lastDistanceKm }
        guard let base = session.baselineOdometerKm else { return session.lastDistanceKm }
        return max(0, odo - base)
    }

    private func accumulateDrop(_ dropPct: Double, into session: inout TripFuelSession) {
        guard dropPct > 0 else { return }
        if let factor = session.estimatedLitresPerPercent {
            session.cumulativeConsumedLitres += dropPct * factor
        } else {
            session.pendingDropPctWithoutFactor += dropPct
        }
    }

    private func addAnomaly(_ message: String, to session: inout TripFuelSession) {
        var messages = session.ignoredAnomalies
        messages.append(message)
        if messages.count > 12 {
            messages.removeFirst(messages.count - 12)
        }
        session.ignoredAnomalies = messages
    }

    private static func loadFromDefaults(key: String) -> [UUID: TripFuelSession] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let store = try? JSONDecoder().decode(PersistedStore.self, from: data) else { return [:] }
        return store.sessions.reduce(into: [:]) { partial, pair in
            if let id = UUID(uuidString: pair.key) {
                partial[id] = pair.value
            }
        }
    }

    private func saveToDefaults() {
        let mapped = sessions.reduce(into: [String: TripFuelSession]()) { partial, pair in
            partial[pair.key.uuidString.lowercased()] = pair.value
        }
        let store = PersistedStore(sessions: mapped)
        guard let data = try? JSONEncoder().encode(store) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
