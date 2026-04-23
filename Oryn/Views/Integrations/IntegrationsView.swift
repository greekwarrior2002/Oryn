import SwiftUI

/// User-facing connection controls for Outlook and Google Calendar, plus
/// the toggles that gate suggestion behavior. Reached from Settings.
struct IntegrationsView: View {
    @EnvironmentObject var store: TaskStore
    @StateObject private var outlook = OutlookService.shared
    @StateObject private var gcal = GoogleCalendarService.shared

    @AppStorage("importCalendarEvents") private var importCalendarEvents: Bool = true
    @AppStorage("importEmailActions")   private var importEmailActions:   Bool = true
    @AppStorage("smartParsingEnabled")  private var smartParsingEnabled:  Bool = true
    @AppStorage("autoSuggestMeetingPrep") private var autoSuggestMeetingPrep: Bool = true

    @State private var connectError: String? = nil

    var body: some View {
        List {
            calendarSection
            behaviorSection
            helpSection
        }
        .navigationTitle("Integrations")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Connection issue", isPresented: errorBinding) {
            Button("OK", role: .cancel) { connectError = nil }
        } message: {
            Text(connectError ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { connectError != nil }, set: { if !$0 { connectError = nil } })
    }

    // MARK: - Sections

    private var calendarSection: some View {
        Section {
            ProviderRow(
                name: outlook.displayName,
                icon: outlook.icon,
                isConnected: outlook.isConnected,
                state: outlook.connectionState,
                onConnect: { Task { await connect(outlook) } },
                onDisconnect: { Task { await outlook.disconnect() } }
            )
            ProviderRow(
                name: gcal.displayName,
                icon: gcal.icon,
                isConnected: gcal.isConnected,
                state: gcal.connectionState,
                onConnect: { Task { await connect(gcal) } },
                onDisconnect: { Task { await gcal.disconnect() } }
            )
        } header: {
            Text("Connected accounts")
        } footer: {
            Text("Oryn reads events and unread mail only. It never writes back without your explicit Add.")
        }
    }

    private var behaviorSection: some View {
        Section {
            Toggle("Smart keyword parsing", isOn: $smartParsingEnabled)
                .tint(.orynAccent)
            Toggle("Import calendar events as suggestions", isOn: $importCalendarEvents)
                .tint(.orynAccent)
            Toggle("Detect action items in email", isOn: $importEmailActions)
                .tint(.orynAccent)
            Toggle("Suggest prep tasks for upcoming meetings", isOn: $autoSuggestMeetingPrep)
                .tint(.orynAccent)
        } header: {
            Text("Behavior")
        } footer: {
            Text("Suggestions always land in a review queue — nothing is added automatically.")
        }
    }

    private var helpSection: some View {
        Section {
            NavigationLink {
                IntegrationsSetupGuide()
            } label: {
                Label("Setup guide", systemImage: "book")
            }
        } header: {
            Text("Help")
        }
    }

    private func connect(_ provider: IntegrationProvider) async {
        do {
            try await provider.connect()
        } catch let error as IntegrationError {
            connectError = error.errorDescription
        } catch {
            connectError = error.localizedDescription
        }
    }
}

// MARK: - Provider row

private struct ProviderRow: View {
    let name: String
    let icon: String
    let isConnected: Bool
    let state: OutlookService.ConnectionState
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        HStack {
            Label(name, systemImage: icon)
                .orynFont(.orynSubheadline)
            Spacer()
            switch state {
            case .connecting:
                ProgressView()
            case .connected:
                Button("Disconnect") { onDisconnect() }
                    .foregroundColor(.red)
            case .failed:
                Button("Retry") { onConnect() }
                    .foregroundColor(.orynAccent)
            case .disconnected:
                if isConnected {
                    Button("Disconnect") { onDisconnect() }
                        .foregroundColor(.red)
                } else {
                    Button("Connect") { onConnect() }
                        .foregroundColor(.orynAccent)
                }
            }
        }
    }
}

// MARK: - Setup guide

struct IntegrationsSetupGuide: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Outlook")
                    .orynFont(.orynTitle2)
                Text("""
1. Register an app at portal.azure.com → App registrations (native client).
2. Add a redirect URI of the form msauth.com.oryn://auth.
3. Paste the resulting Client ID into Secrets.xcconfig as OUTLOOK_CLIENT_ID.
4. Add the microsoft-authentication-library-for-objc SPM package.
5. The rest of the integration (token storage, calendar + mail fetch, \
suggestion surfacing) is already wired.
""")
                .orynFont(.orynSubheadline, color: .orynTextSecondary)

                Divider().padding(.vertical, Spacing.sm)

                Text("Google Calendar")
                    .orynFont(.orynTitle2)
                Text("""
1. Create an iOS OAuth client at console.cloud.google.com → Credentials.
2. Paste the Client ID into Secrets.xcconfig as GCAL_CLIENT_ID.
3. Add the GoogleSignIn-iOS SPM package.
4. Update Info.plist with the reversed client ID URL scheme.
5. The calendar fetch pipeline will light up after sign-in.
""")
                .orynFont(.orynSubheadline, color: .orynTextSecondary)
            }
            .padding(Spacing.md)
        }
        .navigationTitle("Setup guide")
        .navigationBarTitleDisplayMode(.inline)
    }
}
