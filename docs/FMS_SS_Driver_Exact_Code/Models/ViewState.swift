import Foundation

enum ScreenLoadState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(String)
}

enum TripFilterMode: Equatable {
    case all
    case priority(TripPriority)
    case completed
}
