import SwiftUI

struct DevicesView: View {
    @Environment(TVManager.self) private var tvs
    @Environment(SubscriptionStore.self) private var store
    @Environment(AppRouter.self) private var router
    @State private var showManualAdd = false

    var body: some View {
        NavigationStack {
            List {
                if !tvs.saved.isEmpty {
                    Section("My TVs") {
                        ForEach(tvs.saved) { device in
                            DeviceRow(device: device, state: rowState(device)) { select(device) }
                                .swipeActions {
                                    Button("Forget", role: .destructive) { tvs.forget(device) }
                                }
                        }
                    }
                }
                Section {
                    ForEach(tvs.newlyDiscovered) { device in
                        DeviceRow(device: device, state: rowState(device),
                                  isLocked: tvs.requiresPremium(device, isPremium: store.isPremium)) { select(device) }
                    }
                    if tvs.isScanning {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Looking for TVs on your Wi-Fi…")
                                .foregroundStyle(.secondary)
                        }
                    } else if tvs.hasScanned && tvs.newlyDiscovered.isEmpty {
                        Text(tvs.saved.isEmpty
                             ? "No TVs found yet. Make sure your TV is on and connected to the same Wi-Fi network as this iPhone."
                             : "No other TVs found.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await tvs.scan() }
                    } label: {
                        Label("Scan Again", systemImage: "arrow.clockwise")
                    }
                    .disabled(tvs.isScanning)
                } header: {
                    Text("On this Wi-Fi")
                }
                .listRowBackground(Theme.surface)

                Section {
                    Button { showManualAdd = true } label: {
                        Label("Add TV by IP Address", systemImage: "plus.circle")
                    }
                    Button { select(.demo) } label: {
                        Label("Try the Demo TV", systemImage: "sparkles.tv")
                    }
                } footer: {
                    Text("The Demo TV shows a virtual TV screen so you can try every button without a TV.")
                }
                .listRowBackground(Theme.surface)

                Section("Can't find your TV?") {
                    TipRow(symbol: "wifi", text: "Connect your iPhone and TV to the same Wi-Fi network. Guest networks and VPNs can hide devices.")
                    TipRow(symbol: "lock.shield", text: "Allow local network access in Settings > Privacy & Security > Local Network > Zapply.")
                    TipRow(symbol: "tv", text: "Roku: set Settings > System > Advanced system settings > Control by mobile apps > Network access to Default.")
                    TipRow(symbol: "checkmark.circle", text: "Samsung and LG: accept the prompt that appears on the TV the first time you connect.")
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("TVs")
            .refreshable { await tvs.scan() }
            .task(id: router.paywall == nil) {
                // Wait until the first-run paywall is closed so the network permission alert isn't hidden behind it.
                if router.paywall == nil, !tvs.hasScanned, !tvs.isScanning { await tvs.scan() }
            }
            .sheet(isPresented: $showManualAdd) {
                ManualAddSheet { device in select(device) }
            }
        }
    }

    private func rowState(_ device: TVDevice) -> DeviceRow.State {
        guard tvs.current?.id == device.id else { return .none }
        switch tvs.status {
        case .connected: return .connected
        case .connecting: return .connecting
        default: return .none
        }
    }

    private func select(_ device: TVDevice) {
        if tvs.requiresPremium(device, isPremium: store.isPremium) {
            router.paywall = .multipleTVs
            return
        }
        router.tab = .remote
        Task { await tvs.connect(device) }
    }
}

private struct DeviceRow: View {
    enum State { case none, connecting, connected }

    let device: TVDevice
    let state: State
    var isLocked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: device.platform.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 42, height: 42)
                    .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if isLocked {
                    LockBadge()
                } else {
                    switch state {
                    case .connected: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    case .connecting: ProgressView()
                    case .none: Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .listRowBackground(Theme.surface)
    }

    private var subtitle: String {
        if device.platform == .demo { return device.model ?? "" }
        return [device.platform.brand, device.model, device.host].compactMap { $0 }.joined(separator: " · ")
    }
}

private struct TipRow: View {
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text).font(.footnote).foregroundStyle(.secondary)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Theme.accent)
        }
    }
}

private struct ManualAddSheet: View {
    let onAdd: (TVDevice) -> Void
    @Environment(TVManager.self) private var tvs
    @Environment(\.dismiss) private var dismiss
    @State private var host = ""
    @State private var brand: TVPlatform?
    @State private var isChecking = false
    @State private var error: String?

    private var address: String { host.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("192.168.1.20", text: $host)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("TV IP address")
                } footer: {
                    Text("You'll find it on your TV under Settings > Network (often in Network Status or About).")
                }
                Section("Brand") {
                    Picker("Brand", selection: $brand) {
                        Text("Detect automatically").tag(TVPlatform?.none)
                        Text("Roku").tag(TVPlatform?.some(.roku))
                        Text("Samsung").tag(TVPlatform?.some(.samsung))
                        Text("LG").tag(TVPlatform?.some(.lg))
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                if let error {
                    Section {
                        Text(error).font(.footnote).foregroundStyle(Theme.gold)
                    }
                }
            }
            .navigationTitle("Add TV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isChecking {
                        ProgressView()
                    } else {
                        Button("Connect") { Task { await add() } }
                            .disabled(!IPv4.isPrivate(address))
                    }
                }
            }
        }
    }

    private func add() async {
        isChecking = true
        defer { isChecking = false }
        if let device = await tvs.device(atHost: address, platform: brand) {
            dismiss()
            onAdd(device)
        } else {
            error = "No TV answered at \(address). Check the address, or pick the brand above and try again."
        }
    }
}
