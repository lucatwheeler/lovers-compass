import SwiftUI

struct MainView: View {
    let deviceId: String
    let coupleId: String
    
    private let apiClient = APIClient.shared
    
    // Stub SF coordinates
    private let stubLat = 37.7749
    private let stubLon = -122.4194
    
    @State private var lastUpdateStatus: String = "Location not sent yet."
    @State private var partnerStatus: String = "Partner location not fetched yet."
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Lover's Compass")
                    .font(.largeTitle.bold())
                
                Text("Couple ID: \(coupleId)")
                    .font(.footnote.monospaced())
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Button {
                        Task { await sendLocationOnce() }
                    } label: {
                        Text("Send My Location Once")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button {
                        Task { await fetchPartnerLocation() }
                    } label: {
                        Text("Fetch Partner Location")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Update Status:")
                        .font(.headline)
                    Text(lastUpdateStatus)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    Text("Partner Status:")
                        .font(.headline)
                    Text(partnerStatus)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
        }
    }
}


// MARK: - Actions

extension MainView {
    
    private func sendLocationOnce() async {
        lastUpdateStatus = "Sending location..."
        
        let request = LocationUpdateRequest(
            couple_id: coupleId,
            device_id: deviceId,
            is_sharing: true,
            latitude: stubLat,
            longitude: stubLon
        )
        
        do {
            let response = try await apiClient.updateLocation(request)
            lastUpdateStatus = "Location sent at \(response.updated_at)"
        } catch {
            lastUpdateStatus = "Error sending location: \(error.localizedDescription)"
        }
    }
    
    private func fetchPartnerLocation() async {
        partnerStatus = "Fetching partner location..."
        
        do {
            let response = try await apiClient.getPartnerLocation(
                coupleId: coupleId,
                deviceId: deviceId
            )
            
            if !response.partner_found {
                partnerStatus = "No partner found yet."
                return
            }

            if response.is_sharing != true {
                partnerStatus = "Partner is not sharing their location yet."
                return
            }
            
            if let lat = response.latitude, let lon = response.longitude {
                let stale = response.staleness_seconds ?? -1
                partnerStatus = "Partner at (\(lat), \(lon)). Staleness: \(stale) seconds."
            } else {
                partnerStatus = "Partner is sharing, but no coordinates returned."
            }
        } catch {
            partnerStatus = "Error fetching partner: \(error.localizedDescription)"
        }
    }
}


// MARK: - Preview

#Preview {
    MainView(deviceId: "TEST-DEVICE", coupleId: "TESTCODE")
}
