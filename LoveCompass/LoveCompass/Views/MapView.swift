import SwiftUI
import MapKit
import CoreLocation
import PhotosUI

struct MapView: View {
    let deviceId: String
    let coupleId: String
    var onUnpair: (() -> Void)? = nil

    private let api = APIService.shared
    @StateObject private var locationManager = LocationManager()
    @StateObject private var photoStorage = PhotoStorage.shared

    @State private var partnerLocation: CLLocationCoordinate2D?
    @State private var partnerConnected: Bool = false
    @State private var staleness: Int?
    @State private var syncTimer: Timer?
    @State private var showSettings: Bool = false
    @State private var showMap: Bool = false
    @State private var isSharing: Bool = true

    @State private var pokeManager: PokeManager?
    @State private var waitingPulse: Bool = false

    // Arrow fire animation states
    @State private var bowPulledBack: Bool = false
    @State private var arrowFlyOffset: CGFloat = 0
    @State private var arrowFlyOpacity: Double = 1.0
    @State private var arrowFiring: Bool = false
    @State private var showPokeSentBurst: Bool = false
    @State private var pokeSentMessage: String = ""
    @State private var showPhotoPicker: Bool = false
    @State private var selectedPhoto: PhotosPickerItem? = nil

    // Poke composer state
    @State private var showPokeComposer: Bool = false
    @State private var selectedPokePreset: String? = nil
    @State private var customPokeText: String = ""

    // Consecutive 401/404 sync failures — the couple was deleted remotely
    @State private var staleCredentialFailures: Int = 0

    private let syncInterval: TimeInterval = 10

    // Theme
    private let rosePink = Color(red: 1.0, green: 0.42, blue: 0.54)
    private let deepRose = Color(red: 1.0, green: 0.27, blue: 0.44)
    private let crimson = Color(red: 0.85, green: 0.1, blue: 0.28)
    private let blush = Color(red: 1.0, green: 0.92, blue: 0.94)
    private let warmWhite = Color(red: 1.0, green: 0.97, blue: 0.98)
    private let gold = Color(red: 0.85, green: 0.7, blue: 0.45)
    private let warmBrown = Color(red: 0.55, green: 0.35, blue: 0.22)

    // MARK: - Computed

    private var distanceText: String {
        guard let my = locationManager.currentLocation, let partner = partnerLocation else { return "" }
        return CompassCalculator.formatDistance(CompassCalculator.distance(from: my, to: partner))
    }

    private var bearingToPartner: Double {
        guard let my = locationManager.currentLocation, let partner = partnerLocation else { return 0 }
        return CompassCalculator.bearing(from: my, to: partner)
    }

    /// Screen-relative angle for the arrow to fly toward
    private var screenAngle: Double {
        bearingToPartner - locationManager.heading
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Textured background with subtle hearts
            backgroundLayer

            VStack(spacing: 0) {
                headerBar.padding(.top, 8).padding(.bottom, 4)
                Spacer(minLength: 4)

                // Compass
                compassBody.padding(.horizontal, 20)

                Spacer(minLength: 4)

                infoArea.padding(.bottom, 8)

                fireArrowButton
                    .padding(.horizontal, 36)
                    .padding(.bottom, 10)

                Button { showMap = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "map").font(.system(size: 12))
                        Text("View Map").font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(rosePink.opacity(0.6))
                }
                .padding(.bottom, 28)
            }

            // Poke sent burst
            if showPokeSentBurst {
                pokeSentBurstOverlay
                    .allowsHitTesting(false)
                    .zIndex(25)
            }

            // Poke received
            if let pm = pokeManager, pm.showPokeBanner {
                pokeReceivedOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(30)
            }

            if locationManager.isDenied {
                VStack { Spacer(); locationDeniedBanner.padding(.horizontal, 20).padding(.bottom, 200) }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: partnerConnected)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: pokeManager?.showPokeBanner)
        .navigationBarHidden(true)
        .onAppear {
            let pm = PokeManager(coupleId: coupleId, deviceId: deviceId)
            pokeManager = pm
            startServices()
            pm.startPolling()
            waitingPulse = true
        }
        .onDisappear { stopServices(); pokeManager?.stopPolling() }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhoto, matching: .images)
        .onChange(of: selectedPhoto) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    photoStorage.saveImage(image)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(coupleId: coupleId, deviceId: deviceId, onUnpair: { onUnpair?() })
        }
        .sheet(isPresented: $showMap) { mapSheet }
        .sheet(isPresented: $showPokeComposer) {
            pokeComposerSheet
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Textured Background

    private var backgroundLayer: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [warmWhite, blush, rosePink.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                // Repeating heart grid pattern — evenly spaced, gentle tilt alternating
                let cols = 6
                let rows = 12
                let spacingX = w / CGFloat(cols)
                let spacingY = h / CGFloat(rows)

                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        let isOffset = row % 2 == 1
                        let x = CGFloat(col) * spacingX + spacingX / 2 + (isOffset ? spacingX / 2 : 0)
                        let y = CGFloat(row) * spacingY + spacingY / 2
                        let tilt = isOffset ? 12.0 : -12.0

                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(rosePink.opacity(0.07))
                            .rotationEffect(.degrees(tilt))
                            .position(x: x, y: y)
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(deepRose.opacity(0.45))
                    .padding(10)
                    .background(Circle().fill(.white.opacity(0.7)))
            }
            Spacer()
            VStack(spacing: 2) {
                Text("Lover's Compass")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(deepRose)
                HStack(spacing: 5) {
                    Circle().fill(partnerConnected ? Color.green : Color.orange).frame(width: 6, height: 6)
                    Text(partnerConnected ? "Connected" : "Searching...")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Compass Body

    private var compassBody: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                // Everything inside rotates with heading
                ZStack {
                    compassFace(size: size)

                    // Inner dial — counter-rotates against the outer face.
                    // Outer face rotates at -heading, so this rotates at +heading * 0.5
                    // giving it 1.5x apparent counter-rotation.
                    innerDial(size: size)
                        .rotationEffect(.degrees(locationManager.heading * 0.5))
                        .animation(.linear(duration: 0.12), value: locationManager.heading)

                    if partnerConnected {
                        // The bow (stays in place, fades during fire)
                        bowPart(size: size, pulled: bowPulledBack)
                            .rotationEffect(.degrees(bearingToPartner))
                            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: bearingToPartner)
                            .opacity(arrowFiring ? 0.35 : 1.0)

                        // The arrow (slides forward along its own axis when fired)
                        arrowPart(size: size, pulled: bowPulledBack)
                            .offset(y: -arrowFlyOffset) // applied BEFORE rotation = moves along arrow axis
                            .rotationEffect(.degrees(bearingToPartner))
                            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: bearingToPartner)
                            .opacity(arrowFlyOpacity)
                    } else if !partnerConnected {
                        Image(systemName: "heart.fill")
                            .font(.system(size: size * 0.1))
                            .foregroundColor(rosePink.opacity(0.25))
                            .scaleEffect(waitingPulse ? 1.15 : 0.9)
                            .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: waitingPulse)
                    }
                }
                .rotationEffect(.degrees(-locationManager.heading))
                .animation(.linear(duration: 0.1), value: locationManager.heading)

                // Center pin (fixed)
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(colors: [gold, warmBrown.opacity(0.6)], center: .center, startRadius: 0, endRadius: size * 0.03)
                        )
                        .frame(width: size * 0.055, height: size * 0.055)
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    Circle()
                        .fill(RadialGradient(colors: [.white.opacity(0.7), .clear], center: UnitPoint(x: 0.35, y: 0.35), startRadius: 0, endRadius: size * 0.025))
                        .frame(width: size * 0.045, height: size * 0.045)
                }
            }
            .frame(width: size, height: size)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Compass Face

    private func compassFace(size: Double) -> some View {
        ZStack {
            // Outer shadow
            Circle()
                .fill(.white)
                .frame(width: size * 0.96, height: size * 0.96)
                .shadow(color: rosePink.opacity(0.2), radius: 25, y: 10)

            // Bezel ring
            Circle()
                .fill(
                    AngularGradient(
                        colors: [gold.opacity(0.6), warmBrown.opacity(0.3), gold.opacity(0.5), warmBrown.opacity(0.4), gold.opacity(0.6)],
                        center: .center
                    )
                )
                .frame(width: size * 0.95, height: size * 0.95)

            // Inner face -- photo locket or plain
            if let photo = photoStorage.partnerImage {
                // Partner photo as compass face
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size * 0.86, height: size * 0.86)
                    .clipShape(Circle())
                    .overlay(
                        // Soft vignette so compass elements stay readable
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.clear, .clear, .white.opacity(0.3), .white.opacity(0.7)],
                                    center: .center,
                                    startRadius: size * 0.2,
                                    endRadius: size * 0.44
                                )
                            )
                    )
                    .frame(width: size * 0.86, height: size * 0.86)

                // Tap to change photo hint
                Circle()
                    .fill(.clear)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .onTapGesture { showPhotoPicker = true }
            } else {
                // Plain white face with hearts texture
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, Color(red: 1.0, green: 0.98, blue: 0.97)],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.45
                        )
                    )
                    .frame(width: size * 0.88, height: size * 0.88)

                ForEach(0..<12, id: \.self) { i in
                    let angle = Double(i) * 30.0
                    let radius = size * 0.28
                    Image(systemName: "heart.fill")
                        .font(.system(size: size * 0.022))
                        .foregroundColor(rosePink.opacity(0.06))
                        .offset(x: cos(angle * .pi / 180) * radius, y: sin(angle * .pi / 180) * radius)
                }

                // Tap to add photo
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: size * 0.03))
                    Text("add photo")
                        .font(.system(size: size * 0.022, weight: .medium, design: .rounded))
                }
                .foregroundColor(rosePink.opacity(0.2))
                .offset(y: size * 0.15)
                .onTapGesture { showPhotoPicker = true }
            }

            // Inner ring
            Circle()
                .strokeBorder(rosePink.opacity(0.12), lineWidth: 1)
                .frame(width: size * 0.65, height: size * 0.65)

            // Degree ticks
            ForEach(0..<72, id: \.self) { i in
                let isCardinal = i % 18 == 0
                let isMajor = i % 9 == 0
                let isMid = i % 3 == 0
                Rectangle()
                    .fill(isCardinal ? deepRose : (isMajor ? rosePink.opacity(0.5) : rosePink.opacity(isMid ? 0.2 : 0.08)))
                    .frame(
                        width: isCardinal ? 2.5 : (isMajor ? 1.5 : 0.8),
                        height: isCardinal ? size * 0.05 : (isMajor ? size * 0.032 : (isMid ? size * 0.018 : size * 0.01))
                    )
                    .offset(y: -size * 0.42)
                    .rotationEffect(.degrees(Double(i) * 5))
            }

            // Cardinals
            Text("N")
                .font(.system(size: size * 0.06, weight: .heavy, design: .serif))
                .foregroundColor(deepRose)
                .offset(y: -size * 0.345)
            Text("S")
                .font(.system(size: size * 0.042, weight: .bold, design: .serif))
                .foregroundColor(rosePink.opacity(0.4))
                .offset(y: size * 0.345)
            Text("E")
                .font(.system(size: size * 0.042, weight: .bold, design: .serif))
                .foregroundColor(rosePink.opacity(0.4))
                .offset(x: size * 0.345)
            Text("W")
                .font(.system(size: size * 0.042, weight: .bold, design: .serif))
                .foregroundColor(rosePink.opacity(0.4))
                .offset(x: -size * 0.345)
        }
    }

    // MARK: - Inner Dial (counter-rotating for parallax)

    private func innerDial(size: Double) -> some View {
        let outer = size * 0.62
        let inner = size * 0.52

        return ZStack {
            // Filled band between two circles
            Circle()
                .fill(rosePink.opacity(0.04))
                .frame(width: outer, height: outer)

            Circle()
                .fill(.white.opacity(0.6))
                .frame(width: inner, height: inner)

            // Outer edge of the band
            Circle()
                .strokeBorder(deepRose.opacity(0.10), lineWidth: 1)
                .frame(width: outer, height: outer)

            // Inner edge of the band
            Circle()
                .strokeBorder(rosePink.opacity(0.08), lineWidth: 0.5)
                .frame(width: inner, height: inner)

            // Tick marks around the band
            ForEach(0..<36, id: \.self) { i in
                let isMajor = i % 9 == 0
                let isMid = i % 3 == 0
                Rectangle()
                    .fill(isMajor ? deepRose.opacity(0.2) : rosePink.opacity(isMid ? 0.12 : 0.06))
                    .frame(
                        width: isMajor ? 1.5 : 0.8,
                        height: isMajor ? (outer - inner) / 2 * 0.7 : (outer - inner) / 2 * 0.4
                    )
                    .offset(y: -(outer + inner) / 4)
                    .rotationEffect(.degrees(Double(i) * 10))
            }

            // Heart markers at the four quadrants
            ForEach(0..<4, id: \.self) { i in
                Image(systemName: "heart.fill")
                    .font(.system(size: size * 0.022))
                    .foregroundColor(deepRose.opacity(0.18))
                    .offset(y: -(outer + inner) / 4)
                    .rotationEffect(.degrees(Double(i) * 90 + 45))
            }
        }
    }

    // MARK: - Bow and Arrow Needle

    // MARK: - Bow Part (stays in place during fire)

    private func bowPart(size: Double, pulled: Bool) -> some View {
        let bowSpan = size * 0.38
        let bowCurve = size * 0.16
        let shaftLen = size * 0.40
        let nockY = shaftLen / 2 + size * 0.005
        let pullExtra = pulled ? size * 0.06 : 0.0
        let canvasS = size * 0.85

        return Canvas { context, cs in
            let cx = cs.width / 2
            let cy = cs.height / 2

            let leftTip = CGPoint(x: cx - bowSpan, y: cy)
            let rightTip = CGPoint(x: cx + bowSpan, y: cy)
            let archControl = CGPoint(x: cx, y: cy - bowCurve)

            // Bow arch
            var arch = Path()
            arch.move(to: leftTip)
            arch.addQuadCurve(to: rightTip, control: archControl)
            context.stroke(arch, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 1.0, green: 0.27, blue: 0.44).opacity(0.85),
                    Color(red: 0.85, green: 0.1, blue: 0.28).opacity(0.75),
                    Color(red: 1.0, green: 0.27, blue: 0.44).opacity(0.85)
                ]),
                startPoint: leftTip, endPoint: rightTip
            ), style: StrokeStyle(lineWidth: size * 0.028, lineCap: .round))

            // String V
            let nockPoint = CGPoint(x: cx, y: cy + nockY + pullExtra)
            var string = Path()
            string.move(to: leftTip)
            string.addLine(to: nockPoint)
            string.addLine(to: rightTip)
            context.stroke(string, with: .color(
                Color(red: 1.0, green: 0.42, blue: 0.54).opacity(0.45)
            ), style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round))

            // Bow tips
            let tipR: CGFloat = size * 0.014
            context.fill(Path(ellipseIn: CGRect(x: leftTip.x - tipR, y: leftTip.y - tipR, width: tipR * 2, height: tipR * 2)),
                         with: .color(Color(red: 1.0, green: 0.27, blue: 0.44).opacity(0.7)))
            context.fill(Path(ellipseIn: CGRect(x: rightTip.x - tipR, y: rightTip.y - tipR, width: tipR * 2, height: tipR * 2)),
                         with: .color(Color(red: 1.0, green: 0.27, blue: 0.44).opacity(0.7)))
        }
        .frame(width: canvasS, height: canvasS)
        .allowsHitTesting(false)
    }

    // MARK: - Arrow Part (flies away on fire)

    private func arrowPart(size: Double, pulled: Bool) -> some View {
        let shaftLen = size * 0.40
        let heartSize = size * 0.11
        let pullExtra = pulled ? size * 0.06 : 0.0
        let ribbonSize = size * 0.07

        return ZStack {
            // Shaft
            Capsule()
                .fill(LinearGradient(colors: [warmBrown.opacity(0.9), warmBrown.opacity(0.6)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: size * 0.016, height: shaftLen)
                .offset(y: -size * 0.02 + pullExtra / 2)

            // Heart arrowhead (flipped, point leads) — tight against shaft
            Image(systemName: "heart.fill")
                .font(.system(size: heartSize, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [deepRose, crimson], startPoint: .bottom, endPoint: .top)
                )
                .shadow(color: deepRose.opacity(0.5), radius: 5, y: -2)
                .rotationEffect(.degrees(180))
                .offset(y: -shaftLen / 2 - size * 0.01 + pullExtra / 2)

            // Classic feather fletching — two swept-back vanes like a real cupid arrow
            Canvas { context, cs in
                let cx = cs.width / 2
                let cy = cs.height / 2
                let featherLen = size * 0.10
                let featherW = size * 0.035

                // Left feather vane — teardrop shape swept back-left
                var left = Path()
                left.move(to: CGPoint(x: cx, y: cy - featherLen * 0.15))
                left.addQuadCurve(
                    to: CGPoint(x: cx, y: cy + featherLen),
                    control: CGPoint(x: cx - featherW * 2.2, y: cy + featherLen * 0.3)
                )
                left.addQuadCurve(
                    to: CGPoint(x: cx, y: cy - featherLen * 0.15),
                    control: CGPoint(x: cx - featherW * 0.6, y: cy + featherLen * 0.35)
                )
                context.fill(left, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.27, blue: 0.44),
                        Color(red: 0.85, green: 0.1, blue: 0.28)
                    ]),
                    startPoint: CGPoint(x: cx, y: cy),
                    endPoint: CGPoint(x: cx - featherW * 2, y: cy + featherLen)
                ))
                // Feather spine
                var leftSpine = Path()
                leftSpine.move(to: CGPoint(x: cx, y: cy))
                leftSpine.addQuadCurve(
                    to: CGPoint(x: cx - featherW * 0.8, y: cy + featherLen * 0.85),
                    control: CGPoint(x: cx - featherW * 0.3, y: cy + featherLen * 0.4)
                )
                context.stroke(leftSpine, with: .color(Color(red: 0.85, green: 0.1, blue: 0.28).opacity(0.5)),
                               style: StrokeStyle(lineWidth: 1.0))

                // Right feather vane — mirrored
                var right = Path()
                right.move(to: CGPoint(x: cx, y: cy - featherLen * 0.15))
                right.addQuadCurve(
                    to: CGPoint(x: cx, y: cy + featherLen),
                    control: CGPoint(x: cx + featherW * 2.2, y: cy + featherLen * 0.3)
                )
                right.addQuadCurve(
                    to: CGPoint(x: cx, y: cy - featherLen * 0.15),
                    control: CGPoint(x: cx + featherW * 0.6, y: cy + featherLen * 0.35)
                )
                context.fill(right, with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 1.0, green: 0.27, blue: 0.44),
                        Color(red: 0.85, green: 0.1, blue: 0.28)
                    ]),
                    startPoint: CGPoint(x: cx, y: cy),
                    endPoint: CGPoint(x: cx + featherW * 2, y: cy + featherLen)
                ))
                var rightSpine = Path()
                rightSpine.move(to: CGPoint(x: cx, y: cy))
                rightSpine.addQuadCurve(
                    to: CGPoint(x: cx + featherW * 0.8, y: cy + featherLen * 0.85),
                    control: CGPoint(x: cx + featherW * 0.3, y: cy + featherLen * 0.4)
                )
                context.stroke(rightSpine, with: .color(Color(red: 0.85, green: 0.1, blue: 0.28).opacity(0.5)),
                               style: StrokeStyle(lineWidth: 1.0))

                // Nock notch at the very end
                let nockR = size * 0.006
                context.fill(
                    Path(ellipseIn: CGRect(x: cx - nockR, y: cy + featherLen - nockR, width: nockR * 2, height: nockR * 2)),
                    with: .color(Color(red: 0.55, green: 0.35, blue: 0.22).opacity(0.5))
                )
            }
            .frame(width: size * 0.2, height: size * 0.25)
            .allowsHitTesting(false)
            .offset(y: shaftLen / 2 - size * 0.025 + pullExtra / 2)
        }
    }

    // MARK: - Fire Arrow Button

    private var fireArrowButton: some View {
        Button {
            selectedPokePreset = nil
            customPokeText = ""
            showPokeComposer = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill").font(.system(size: 16))
                Text("Send a Poke").font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Capsule()
                    .fill(LinearGradient(colors: [rosePink, deepRose], startPoint: .leading, endPoint: .trailing))
                    .shadow(color: deepRose.opacity(0.3), radius: 10, y: 4)
            )
        }
        .disabled(pokeManager?.isSendingPoke == true || arrowFiring)
        .opacity((pokeManager?.isSendingPoke == true || bowPulledBack) ? 0.6 : 1.0)
    }

    // MARK: - Poke Composer

    private let pokeMessages = [
        "ily 💕", "thinking of you ✨", "miss you 🥺",
        "you're my favorite 💗", "poke! 😘", "hey cutie 💘",
        "love you always 💝", "wish you were here 🫶",
        "you make me smile 😊", "sending love your way 💌"
    ]

    private var pokeComposerSheet: some View {
        VStack(spacing: 18) {
            Text("Send some love 💌")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(deepRose)
                .padding(.top, 22)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                ForEach(pokeMessages, id: \.self) { preset in
                    let isSelected = selectedPokePreset == preset
                    Button {
                        selectedPokePreset = isSelected ? nil : preset
                        customPokeText = ""
                    } label: {
                        Text(preset)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .foregroundColor(isSelected ? .white : deepRose)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule().fill(
                                    isSelected
                                        ? AnyShapeStyle(LinearGradient(colors: [rosePink, deepRose], startPoint: .leading, endPoint: .trailing))
                                        : AnyShapeStyle(blush)
                                )
                            )
                    }
                }
            }
            .padding(.horizontal, 20)

            TextField("...or write your own", text: $customPokeText)
                .textFieldStyle(.plain)
                .font(.system(size: 16, design: .rounded))
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(warmWhite)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(rosePink.opacity(0.3), lineWidth: 1.5)
                        )
                )
                .padding(.horizontal, 20)
                .onChange(of: customPokeText) { _, newValue in
                    if !newValue.isEmpty { selectedPokePreset = nil }
                    if newValue.count > 240 { customPokeText = String(newValue.prefix(240)) }
                }

            Button {
                let custom = customPokeText.trimmingCharacters(in: .whitespacesAndNewlines)
                let message = custom.isEmpty ? selectedPokePreset : custom
                showPokeComposer = false
                fireArrowSequence(message: message)
                Task { await pokeManager?.sendPoke(message: message) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "heart.fill").font(.system(size: 15))
                    Text("Send 💘").font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [rosePink, deepRose], startPoint: .leading, endPoint: .trailing))
                        .shadow(color: deepRose.opacity(0.3), radius: 8, y: 3)
                )
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 8)
        }
        .background(Color(red: 1.0, green: 0.97, blue: 0.98).ignoresSafeArea())
    }

    // MARK: - Fire Arrow Sequence

    private func fireArrowSequence(message: String?) {
        // 1. Pull back
        withAnimation(.easeOut(duration: 0.3)) {
            bowPulledBack = true
        }

        // 2. Release — arrow flies forward
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            bowPulledBack = false
            arrowFiring = true

            withAnimation(.easeIn(duration: 0.5)) {
                arrowFlyOffset = 500
                arrowFlyOpacity = 0
            }

            // Show heart burst + the actual message being sent
            pokeSentMessage = message ?? "poke! 💕"
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showPokeSentBurst = true
            }
        }

        // 3. Hide burst
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showPokeSentBurst = false
            }
        }

        // 4. Reset arrow
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            arrowFiring = false
            arrowFlyOffset = 0
            arrowFlyOpacity = 1.0
        }
    }

    // MARK: - Poke Sent Burst

    private var pokeSentBurstOverlay: some View {
        ZStack {
            // Exploding hearts
            ForEach(0..<12, id: \.self) { i in
                let angle = Double(i) * 30.0
                let rad = angle * .pi / 180.0
                let dist: CGFloat = showPokeSentBurst ? CGFloat(60 + (i % 3) * 25) : 0

                Image(systemName: "heart.fill")
                    .font(.system(size: CGFloat([14, 10, 18, 12, 16, 11, 15, 9, 13, 17, 10, 14][i])))
                    .foregroundColor(
                        [deepRose, rosePink, crimson, rosePink, deepRose, crimson,
                         rosePink, deepRose, crimson, rosePink, deepRose, rosePink][i]
                            .opacity(showPokeSentBurst ? 0 : 0.9)
                    )
                    .offset(
                        x: cos(rad) * dist,
                        y: sin(rad) * dist
                    )
                    .scaleEffect(showPokeSentBurst ? 0.3 : 1.0)
                    .animation(
                        .easeOut(duration: 0.8).delay(Double(i) * 0.03),
                        value: showPokeSentBurst
                    )
            }

            // Message pill
            Text(pokeSentMessage)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(colors: [rosePink, deepRose],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .shadow(color: deepRose.opacity(0.3), radius: 8, y: 3)
                )
                .scaleEffect(showPokeSentBurst ? 1 : 0.5)
                .opacity(showPokeSentBurst ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showPokeSentBurst)
        }
    }

    // MARK: - Info Area

    private var infoArea: some View {
        VStack(spacing: 6) {
            if partnerConnected && !distanceText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill").font(.system(size: 11)).foregroundColor(deepRose)
                    Text(distanceText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(deepRose)
                    Text("apart")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(rosePink.opacity(0.6))
                }
                if let s = staleness {
                    Text("updated \(formatStaleness(s))")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(s > 300 ? .orange : .secondary)
                }
            } else if !partnerConnected {
                Text("Waiting for your lover...")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(rosePink.opacity(0.5))
            }
        }
    }

    // MARK: - Poke Received

    private var pokeReceivedOverlay: some View {
        ZStack {
            Color.black.opacity(0.15).ignoresSafeArea()
                .onTapGesture { pokeManager?.showPokeBanner = false }
            VStack(spacing: 16) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(LinearGradient(colors: [rosePink, deepRose], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: deepRose.opacity(0.4), radius: 12)

                if let message = pokeManager?.lastReceivedMessage {
                    // The sender's actual words
                    Text(message)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(deepRose)
                        .multilineTextAlignment(.center)
                    Text("— your lover 💌")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(rosePink.opacity(0.7))
                } else {
                    Text("Your lover is\nthinking of you!")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(deepRose)
                        .multilineTextAlignment(.center)
                }

                if let extra = pokeManager?.additionalUnseenCount, extra > 0 {
                    Text("+\(extra) more poke\(extra == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(36)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 28).fill(.white.opacity(0.95))
                    .shadow(color: rosePink.opacity(0.25), radius: 20, y: 8)
            )
        }
    }

    // MARK: - Location Denied

    private var locationDeniedBanner: some View {
        Button { locationManager.openSettings() } label: {
            HStack(spacing: 10) {
                Image(systemName: "location.slash.fill").font(.system(size: 16))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Location Access Needed").font(.system(size: 14, weight: .semibold))
                    Text("Tap to open Settings").font(.system(size: 12)).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(.orange.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.orange.opacity(0.3), lineWidth: 1))
            )
            .foregroundColor(.orange)
        }
    }

    // MARK: - Map Sheet

    private var mapSheet: some View {
        NavigationStack {
            Map {
                if let myLoc = locationManager.currentLocation {
                    Annotation("You", coordinate: myLoc) {
                        ZStack {
                            Circle().fill(rosePink.opacity(0.2)).frame(width: 44, height: 44)
                            Circle().fill(.white).frame(width: 24, height: 24).shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            Circle().fill(rosePink).frame(width: 16, height: 16)
                        }
                    }
                }
                if let partnerLoc = partnerLocation, partnerConnected {
                    Annotation("Partner", coordinate: partnerLoc) {
                        ZStack {
                            Circle().fill(deepRose.opacity(0.2)).frame(width: 48, height: 48)
                            Circle().fill(.white).frame(width: 28, height: 28).shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                            Image(systemName: "heart.fill").font(.system(size: 16)).foregroundColor(deepRose)
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showMap = false }.foregroundColor(rosePink).fontWeight(.semibold)
                }
            }
        }
    }

    private func formatStaleness(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s ago" }
        else if seconds < 3600 { return "\(seconds / 60)m ago" }
        else { return "\(seconds / 3600)h ago" }
    }
}


// MARK: - Services

extension MapView {
    private func startServices() {
        if locationManager.isNotDetermined {
            locationManager.requestPermission()
        } else if locationManager.isAuthorized {
            locationManager.startUpdating()
        }
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { _ in
            Task { await syncOnce() }
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await syncOnce()
        }
    }

    private func stopServices() {
        locationManager.stopUpdating()
        syncTimer?.invalidate()
        syncTimer = nil
    }

    private func syncOnce() async {
        await sendMyLocation()
        await fetchPartnerLocation()
    }

    private func sendMyLocation() async {
        guard let location = locationManager.currentLocation else { return }
        let request = LocationUpdateRequest(
            couple_id: coupleId, device_id: deviceId, is_sharing: isSharing,
            latitude: location.latitude, longitude: location.longitude
        )
        do {
            _ = try await api.updateLocation(request)
            await MainActor.run { staleCredentialFailures = 0 }
        } catch {
            print("Send location error: \(error)")
            await registerPossibleStaleCredentials(error)
        }
    }

    private func fetchPartnerLocation() async {
        do {
            let response = try await api.getPartnerLocation(coupleId: coupleId, deviceId: deviceId)
            await MainActor.run {
                staleCredentialFailures = 0
                if !response.partner_found { partnerConnected = false; partnerLocation = nil; staleness = nil; return }
                if response.is_sharing != true { partnerConnected = false; partnerLocation = nil; staleness = response.staleness_seconds; return }
                if let lat = response.latitude, let lon = response.longitude {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        partnerConnected = true
                        partnerLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        staleness = response.staleness_seconds
                    }
                }
            }
        } catch {
            print("Fetch partner error: \(error)")
            await registerPossibleStaleCredentials(error)
        }
    }

    /// If the server repeatedly says our couple/device no longer exists
    /// (partner unpaired, or credentials invalidated), reset to the pairing
    /// screen instead of hammering a dead couple forever.
    private func registerPossibleStaleCredentials(_ error: Error) async {
        guard let apiError = error as? APIService.APIError,
              let status = apiError.statusCode,
              status == 404 || status == 401 else { return }

        await MainActor.run {
            staleCredentialFailures += 1
            if staleCredentialFailures >= 3 {
                staleCredentialFailures = 0
                onUnpair?()
            }
        }
    }
}

// MARK: - Compass Calculator

enum CompassCalculator {
    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180.0
        let lon1 = from.longitude * .pi / 180.0
        let lat2 = to.latitude * .pi / 180.0
        let lon2 = to.longitude * .pi / 180.0
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180.0 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: from.latitude, longitude: from.longitude)
            .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    }

    static func formatDistance(_ meters: Double) -> String {
        let miles = meters / 1609.344
        if miles < 0.1 {
            let feet = meters * 3.28084
            return String(format: "%.0f ft", feet)
        } else if miles < 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
}

// MARK: - Poke Manager

@MainActor
final class PokeManager: ObservableObject {
    @Published var showPokeBanner: Bool = false
    @Published var showPokeSentToast: Bool = false
    @Published var isSendingPoke: Bool = false
    /// The most recent received poke's message (nil = no personal message).
    @Published var lastReceivedMessage: String? = nil
    /// How many additional pokes arrived beyond the one shown.
    @Published var additionalUnseenCount: Int = 0

    private let api = APIService.shared
    private var pollTimer: Timer?
    private let coupleId: String
    private let deviceId: String

    init(coupleId: String, deviceId: String) { self.coupleId = coupleId; self.deviceId = deviceId }

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.checkForPokes() }
        }
        Task { await checkForPokes() }
    }

    func stopPolling() { pollTimer?.invalidate(); pollTimer = nil }

    func sendPoke(message: String? = nil) async {
        guard !isSendingPoke else { return }
        isSendingPoke = true
        do {
            _ = try await api.sendPoke(coupleId: coupleId, deviceId: deviceId, message: message)
            showPokeSentToast = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showPokeSentToast = false
        } catch { print("Failed to send poke: \(error)") }
        isSendingPoke = false
    }

    private func checkForPokes() async {
        do {
            let response = try await api.getPokes(coupleId: coupleId, deviceId: deviceId)
            if response.pokes > 0 {
                // Show the newest message with actual text, if any
                let received = response.messages ?? []
                lastReceivedMessage = received.compactMap(\.message).last
                additionalUnseenCount = max(0, response.pokes - 1)
                showPokeBanner = true
                fireLocalNotification(message: lastReceivedMessage)
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                showPokeBanner = false
            }
        } catch { print("Failed to check pokes: \(error)") }
    }

    private let pokeNotifications = [
        "Your lover is thinking of you! 💕",
        "Someone loves you! 💘",
        "You just got poked! 😘",
        "Your lover misses you! 🥺",
        "A little love note just arrived! 💌",
        "Someone can't stop thinking about you! ✨",
        "You're on your lover's mind! 💗",
        "Poke! Your lover says hi! 💝"
    ]

    private func fireLocalNotification(message: String?) {
        // Foreground: the in-app overlay already shows the poke, and APNs
        // handles the app-closed case — a local notification here would be
        // a duplicate in Notification Center.
        guard UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = "Lover's Compass"
        // Show the sender's actual words when they wrote some
        content.body = message ?? pokeNotifications.randomElement() ?? "Your lover poked you! 💕"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "poke-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in if let error { print("Notification error: \(error)") } }
    }
}

#Preview {
    NavigationStack { MapView(deviceId: "TEST-DEVICE", coupleId: "LOVE1234") }
}
