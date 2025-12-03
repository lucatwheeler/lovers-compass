import SwiftUI
import CoreLocation

/// A romantic compass that points toward your partner with a heart needle.
struct CompassView: View {
    /// Your current location
    let myLocation: CLLocationCoordinate2D?

    /// Partner's location
    let partnerLocation: CLLocationCoordinate2D?

    /// Current device heading (which way phone is pointing)
    let deviceHeading: Double

    /// Whether partner data is available
    let partnerConnected: Bool

    /// How stale the partner data is
    let staleness: Int?

    // MARK: - Computed Properties

    /// The rotation angle for the heart needle
    private var heartRotation: Double {
        guard let my = myLocation, let partner = partnerLocation else {
            return 0
        }

        let bearing = CompassCalculator.bearing(from: my, to: partner)
        // Subtract device heading so heart always points toward partner
        // regardless of which way you're holding the phone
        return bearing - deviceHeading
    }

    /// Distance to partner formatted for display
    private var distanceText: String {
        guard let my = myLocation, let partner = partnerLocation else {
            return ""
        }
        let meters = CompassCalculator.distance(from: my, to: partner)
        return CompassCalculator.formatDistance(meters)
    }

    /// Color for the heart based on connection status
    private var heartColor: Color {
        if !partnerConnected {
            return .gray.opacity(0.4)
        }
        if let stale = staleness, stale > 300 { // More than 5 minutes old
            return .pink.opacity(0.5)
        }
        return .pink
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Outer decorative ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.pink.opacity(0.3), .purple.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 8
                )
                .frame(width: 300, height: 300)

            // Compass rose background (rotates opposite to device heading)
            CompassRoseView()
                .rotationEffect(.degrees(-deviceHeading))

            // Heart needle (points to partner)
            if partnerConnected && myLocation != nil && partnerLocation != nil {
                HeartNeedleView(color: heartColor)
                    .rotationEffect(.degrees(heartRotation))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: heartRotation)
            } else {
                // Pulsing heart when waiting for connection
                WaitingHeartView()
            }

            // Center decorative element
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, .pink.opacity(0.1)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 25
                    )
                )
                .frame(width: 50, height: 50)
                .shadow(color: .pink.opacity(0.3), radius: 10)

            // Small heart in center
            Image(systemName: "heart.fill")
                .font(.system(size: 20))
                .foregroundColor(.pink)
        }
        .frame(width: 320, height: 320)
    }
}

// MARK: - Compass Rose

/// The traditional N/S/E/W compass background
struct CompassRoseView: View {
    private let directions = ["N", "E", "S", "W"]
    private let tickCount = 72 // Tick marks every 5 degrees

    var body: some View {
        ZStack {
            // Inner circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.96),
                            Color(red: 0.98, green: 0.94, blue: 0.94)
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

            // Degree tick marks
            ForEach(0..<tickCount, id: \.self) { index in
                let angle = Double(index) * (360.0 / Double(tickCount))
                let isMajor = index % 18 == 0 // Every 90 degrees
                let isMinor = index % 6 == 0 // Every 30 degrees

                Rectangle()
                    .fill(isMajor ? Color.gray.opacity(0.8) : Color.gray.opacity(0.3))
                    .frame(width: isMajor ? 2 : 1, height: isMajor ? 15 : (isMinor ? 10 : 5))
                    .offset(y: -125)
                    .rotationEffect(.degrees(angle))
            }

            // Cardinal directions
            ForEach(0..<4, id: \.self) { index in
                let angle = Double(index) * 90.0

                Text(directions[index])
                    .font(.system(size: index == 0 ? 24 : 18, weight: .semibold, design: .rounded))
                    .foregroundColor(index == 0 ? .pink : .gray.opacity(0.7))
                    .offset(y: -95)
                    .rotationEffect(.degrees(angle))
            }

            // Intercardinal directions (NE, SE, SW, NW)
            ForEach(0..<4, id: \.self) { index in
                let labels = ["NE", "SE", "SW", "NW"]
                let angle = Double(index) * 90.0 + 45.0

                Text(labels[index])
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(.gray.opacity(0.4))
                    .offset(y: -95)
                    .rotationEffect(.degrees(angle))
            }
        }
    }
}

// MARK: - Heart Needle

/// The heart-shaped needle that points toward your partner
struct HeartNeedleView: View {
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            // Heart at the tip
            Image(systemName: "heart.fill")
                .font(.system(size: 32))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.5), radius: 8)

            // Needle shaft
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4, height: 60)
                .cornerRadius(2)

            Spacer()
                .frame(height: 70)
        }
        .frame(height: 180)
    }
}

// MARK: - Waiting Heart

/// Pulsing heart shown when waiting for partner connection
struct WaitingHeartView: View {
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.3))
                .scaleEffect(isPulsing ? 1.1 : 1.0)
                .animation(
                    .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isPulsing
                )

            Text("waiting for partner")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Distance Badge

/// Shows how far away your partner is
struct DistanceBadgeView: View {
    let distance: String
    let staleness: Int?

    private var stalenessText: String {
        guard let s = staleness else { return "" }
        if s < 60 { return "\(s)s ago" }
        return "\(s / 60)m ago"
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(distance)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.pink)

            if let s = staleness {
                Text(stalenessText)
                    .font(.caption)
                    .foregroundColor(s > 300 ? .orange : .gray)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 5)
        )
    }
}

// MARK: - Preview

#Preview("Compass - Connected") {
    VStack {
        CompassView(
            myLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            partnerLocation: CLLocationCoordinate2D(latitude: 37.8044, longitude: -122.2712),
            deviceHeading: 45,
            partnerConnected: true,
            staleness: 15
        )

        DistanceBadgeView(distance: "2.3 km", staleness: 15)
    }
    .padding()
}

#Preview("Compass - Waiting") {
    CompassView(
        myLocation: nil,
        partnerLocation: nil,
        deviceHeading: 0,
        partnerConnected: false,
        staleness: nil
    )
    .padding()
}
