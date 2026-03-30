import SwiftUI
import AppKit

// MARK: - Helpers

/// Returns the folder containing the .app bundle, or the binary's own folder
/// when running outside a bundle (e.g. during development).
/// Firefox.app and profiles/ are expected to be siblings of this folder.
func resolveAppDirectory() -> URL {
    var url = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
    while url.pathComponents.count > 1 {
        if url.lastPathComponent.hasSuffix(".app") {
            return url.deletingLastPathComponent()
        }
        url = url.deletingLastPathComponent()
    }
    return URL(fileURLWithPath: CommandLine.arguments[0])
        .resolvingSymlinksInPath()
        .deletingLastPathComponent()
}

func discoverProfiles(appDirectory: URL) -> [URL] {
    let profilesDir = appDirectory.appendingPathComponent("profiles")
    guard let entries = try? FileManager.default.contentsOfDirectory(
        at: profilesDir,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }

    return entries
        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        .sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }
}

// MARK: - Focused value key (ContentView → Commands bridge)

private struct CreateProfileActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var createProfileAction: (() -> Void)? {
        get { self[CreateProfileActionKey.self] }
        set { self[CreateProfileActionKey.self] = newValue }
    }
}

// MARK: - Menu commands

private struct FireprofileCommands: Commands {
    @FocusedValue(\.createProfileAction) var createProfileAction

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Profile…") { createProfileAction?() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(createProfileAction == nil)
        }
    }
}

// MARK: - App

// @main can't be used in main.swift; .main() is called explicitly at the bottom.
struct FireprofileApp: App {
    var body: some Scene {
        // Window (macOS 14+) gives a single non-duplicatable instance — right for a launcher.
        Window("Fireprofile", id: "main") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands { FireprofileCommands() }
    }
}

// MARK: - Content View

struct ContentView: View {

    @State private var profiles: [URL] = discoverProfiles(appDirectory: resolveAppDirectory())
    @State private var launchError: String?

    // Rename — use sheet(item:) so the URL is guaranteed non-nil when the sheet body runs
    @State private var renameTarget: IdentifiableURL? = nil

    // Delete
    @State private var showDeleteAlert  = false
    @State private var deleteTarget: URL? = nil
    @State private var deleteFileCount  = 0
    @State private var deleteTotalSize  = ""

    // Create profile
    @State private var showCreateSheet  = false

    // Info panel
    @State private var infoTarget: IdentifiableURL? = nil

    private let appDirectory = resolveAppDirectory()

    // ── Layout constants ─────────────────────────────────────────────────────
    private static let windowWidth:  CGFloat = 360
    private static let logoSize:     CGFloat = 100
    private static let logoPadding:  CGFloat = 32    // total vertical padding around logo
    private static let statusHeight: CGFloat = 28    // status bar + its padding
    private static let rowHeight:    CGFloat = 40    // inset List row
    private static let listOverhead: CGFloat = 16    // List's own top+bottom insets

    private var contentHeight: CGFloat {
        let halfScreen = (NSScreen.main?.visibleFrame.height ?? 800) / 2
        let fixedChrome = Self.logoSize + Self.logoPadding + Self.statusHeight
        if profiles.isEmpty {
            return min(fixedChrome + 150, halfScreen)   // room for empty-state icon + text + button
        }
        let listH = Self.listOverhead + CGFloat(profiles.count) * Self.rowHeight
        return min(fixedChrome + listH, halfScreen)
    }

    // ── Body ─────────────────────────────────────────────────────────────────

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Firefox logo ─────────────────────────────────────────────────
            if let url = Bundle.main.url(forResource: "Fireprofile", withExtension: "png"),
               let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Self.logoSize, height: Self.logoSize)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Self.logoPadding / 2)
            }

            // ── Profile list or empty state ──────────────────────────────────
            if profiles.isEmpty {
                EmptyStateView { showCreateSheet = true }
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            } else {
                List(profiles, id: \.self) { profile in
                    Button { launch(profile: profile) } label: {
                        ProfileRow(profile: profile)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { contextMenu(for: profile) }
                    .listRowBackground(Color(NSColor.controlBackgroundColor))
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }

            // ── Status / error bar ───────────────────────────────────────────
            statusBar
        }
        .frame(width: Self.windowWidth, height: contentHeight)
        .background(WindowDragShim())
        .onAppear { profiles = discoverProfiles(appDirectory: appDirectory) }
        // Expose create action to menu bar (nil when profiles list is empty → item stays disabled)
        .focusedValue(\.createProfileAction, profiles.isEmpty ? nil : { showCreateSheet = true })
        // ── Rename sheet ─────────────────────────────────────────────────────
        .sheet(item: $renameTarget) { item in
            RenameSheet(profile: item.url, existingProfiles: profiles) { newName in
                rename(from: item.url, to: newName)
                renameTarget = nil
            } onCancel: {
                renameTarget = nil
            }
        }
        // ── Create profile sheet ─────────────────────────────────────────────
        .sheet(isPresented: $showCreateSheet) {
            CreateProfileSheet(existingProfiles: profiles) { name in
                createProfile(named: name)
                showCreateSheet = false
            } onCancel: {
                showCreateSheet = false
            }
        }
        // ── Info sheet ───────────────────────────────────────────────────────
        .sheet(item: $infoTarget) { item in
            ProfileInfoSheet(profile: item.url) { infoTarget = nil }
        }
        // ── Delete confirmation alert ─────────────────────────────────────────
        .alert(
            deleteTarget.map { "Delete \"\($0.lastPathComponent)\"?" } ?? "Delete profile?",
            isPresented: $showDeleteAlert
        ) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Move to Trash", role: .destructive) { deleteProfile() }
        } message: {
            if let target = deleteTarget {
                if deleteFileCount == 0 {
                    Text("The profile \"\(target.lastPathComponent)\" is empty and will be moved to the Trash.")
                } else {
                    Text("The profile \"\(target.lastPathComponent)\" contains \(deleteFileCount) file\(deleteFileCount == 1 ? "" : "s") (\(deleteTotalSize)) and will be moved to the Trash.")
                }
            }
        }
    }

    // MARK: Sub-views

    @ViewBuilder
    private var statusBar: some View {
        Group {
            if let error = launchError {
                Text(error).foregroundStyle(.red)
            } else if !profiles.isEmpty {
                let n = profiles.count
                Text("\(n) profile\(n == 1 ? "" : "s")").foregroundStyle(.tertiary)
            }
        }
        .font(.caption2)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func contextMenu(for profile: URL) -> some View {
        Button("Info…") { infoTarget = IdentifiableURL(profile) }
        Button("Open in Finder") {
            NSWorkspace.shared.selectFile(profile.path, inFileViewerRootedAtPath: "")
        }
        Divider()
        Button("Rename…") {
            renameTarget = IdentifiableURL(profile)
        }
        Button("Duplicate") { duplicate(profile) }
        Divider()
        Button("Delete", role: .destructive) { prepareDelete(profile) }
    }

    // MARK: Launch

    private func launch(profile: URL) {
        let firefox = appDirectory.appendingPathComponent("Firefox.app/Contents/MacOS/firefox")
        guard FileManager.default.isExecutableFile(atPath: firefox.path) else {
            launchError = "Firefox.app not found next to Fireprofile.app"
            return
        }
        let proc = Process()
        proc.executableURL = firefox
        proc.arguments = ["-profile", profile.path, "-no-remote"]
        do {
            try proc.run()
            NSApp.terminate(nil)
        } catch {
            launchError = error.localizedDescription
        }
    }

    // MARK: Rename

    private func rename(from oldURL: URL, to newName: String) {
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            profiles = discoverProfiles(appDirectory: appDirectory)
        } catch {
            launchError = "Rename failed: \(error.localizedDescription)"
        }
    }

    // MARK: Duplicate

    private func duplicate(_ profile: URL) {
        let base = profile.lastPathComponent
        var n = 2
        var destURL: URL
        repeat {
            let name = "\(base) \(n)"
            destURL = profile.deletingLastPathComponent().appendingPathComponent(name)
            n += 1
        } while FileManager.default.fileExists(atPath: destURL.path)

        do {
            try FileManager.default.copyItem(at: profile, to: destURL)
            profiles = discoverProfiles(appDirectory: appDirectory)
        } catch {
            launchError = "Duplicate failed: \(error.localizedDescription)"
        }
    }

    // MARK: Delete

    private func prepareDelete(_ profile: URL) {
        var count = 0
        var bytes: Int64 = 0
        if let enumerator = FileManager.default.enumerator(
            at: profile,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                if let v = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                   v.isRegularFile == true {
                    count += 1
                    bytes += Int64(v.fileSize ?? 0)
                }
            }
        }
        deleteTarget    = profile
        deleteFileCount = count
        deleteTotalSize = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        showDeleteAlert = true
    }

    private func deleteProfile() {
        guard let target = deleteTarget else { return }
        deleteTarget = nil
        NSWorkspace.shared.recycle([target]) { [self] _, error in
            DispatchQueue.main.async {
                if let error {
                    self.launchError = "Move to Trash failed: \(error.localizedDescription)"
                } else {
                    self.profiles = discoverProfiles(appDirectory: self.appDirectory)
                }
            }
        }
    }

    // MARK: Create

    private func createProfile(named name: String) {
        let profilesDir = appDirectory.appendingPathComponent("profiles")
        do {
            try FileManager.default.createDirectory(at: profilesDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(
                at: profilesDir.appendingPathComponent(name),
                withIntermediateDirectories: false
            )
            profiles = discoverProfiles(appDirectory: appDirectory)
        } catch {
            launchError = "Create failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Profile Row

struct ProfileRow: View {
    let profile: URL
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            ProfileIconView(profile: profile, isHovered: isHovered)
                .frame(width: 24, height: 24)
            Text(profile.lastPathComponent)
                .font(.system(size: 14))
                .foregroundStyle(isHovered ? Color.accentColor : Color.primary)
            Spacer()
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Profile Icon

struct ProfileIconView: View {
    let profile: URL
    var isHovered: Bool = false

    private var image: NSImage {
        // 1. icon.png inside the profile folder (per-profile custom icon)
        if let img = NSImage(contentsOf: profile.appendingPathComponent("icon.png")) {
            return img
        }
        // 2. Bundled firefox-stylized-icon.png
        if let url = Bundle.main.url(forResource: "firefox-stylized-icon", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        // 3. macOS system folder icon as final fallback
        return NSWorkspace.shared.icon(forFile: profile.path)
    }

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            // colorMultiply(.white) is identity — preserves original colours when not hovered
            .colorMultiply(isHovered ? Color.accentColor : .white)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let onCreateProfile: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No profiles found")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button("Create new profile", action: onCreateProfile)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Rename Sheet

struct RenameSheet: View {
    let profile: URL
    let existingProfiles: [URL]
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var text: String
    @FocusState private var focused: Bool

    init(profile: URL, existingProfiles: [URL],
         onConfirm: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.profile          = profile
        self.existingProfiles = existingProfiles
        self.onConfirm        = onConfirm
        self.onCancel         = onCancel
        _text = State(initialValue: profile.lastPathComponent)
    }

    private var existingNames: [String] { existingProfiles.map(\.lastPathComponent) }
    private var trimmed: String { text.trimmingCharacters(in: .whitespaces) }
    private var isDuplicate: Bool { existingNames.contains(trimmed) && trimmed != profile.lastPathComponent }
    private var canConfirm: Bool  { !trimmed.isEmpty && trimmed != profile.lastPathComponent && !isDuplicate }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Profile")
                .font(.headline)

            TextField("Profile name", text: $text)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { if canConfirm { onConfirm(trimmed) } }

            if isDuplicate {
                Text("A profile with this name already exists.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Rename") { onConfirm(trimmed) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canConfirm)
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear { focused = true }
    }
}

// MARK: - Create Profile Sheet

struct CreateProfileSheet: View {
    let existingProfiles: [URL]
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @FocusState private var focused: Bool

    private var existingNames: [String] { existingProfiles.map(\.lastPathComponent) }
    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var isDuplicate: Bool { existingNames.contains(trimmed) }
    private var canCreate: Bool   { !trimmed.isEmpty && !isDuplicate }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Profile")
                .font(.headline)

            TextField("Profile name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit { if canCreate { onConfirm(trimmed) } }

            if isDuplicate {
                Text("A profile with this name already exists.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Create Profile") { onConfirm(trimmed) }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreate)
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear { focused = true }
    }
}

// MARK: - Profile Info Sheet

struct ProfileInfoSheet: View {
    let profile: URL
    let onDone: () -> Void

    @State private var fileCount  = 0
    @State private var totalSize  = "—"
    @State private var modifiedDate = "—"

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ───────────────────────────────────────────────────────
            VStack(spacing: 8) {
                ProfileIconView(profile: profile)
                    .frame(width: 48, height: 48)
                Text(profile.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // ── Info rows ────────────────────────────────────────────────────
            VStack(spacing: 0) {
                infoRow(label: "Modified", value: modifiedDate)
                Divider().padding(.leading, 16)
                infoRow(label: "Files", value: fileCount == 0
                    ? "Empty"
                    : "\(fileCount) file\(fileCount == 1 ? "" : "s")")
                Divider().padding(.leading, 16)
                infoRow(label: "Size", value: totalSize)
            }
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // ── Footer ───────────────────────────────────────────────────────
            HStack {
                Spacer()
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 300)
        .onAppear { computeInfo() }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func computeInfo() {
        // Folder's own modification date
        if let attrs = try? FileManager.default.attributesOfItem(atPath: profile.path),
           let date = attrs[.modificationDate] as? Date {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .short
            modifiedDate = fmt.string(from: date)
        }

        // Recursive file count + total size
        var count = 0
        var bytes: Int64 = 0
        if let enumerator = FileManager.default.enumerator(
            at: profile,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                if let v = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                   v.isRegularFile == true {
                    count += 1
                    bytes += Int64(v.fileSize ?? 0)
                }
            }
        }
        fileCount = count
        totalSize = bytes == 0
            ? "Empty"
            : ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Identifiable URL wrapper (for sheet(item:))

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: URL { url }
    init(_ url: URL) { self.url = url }
}

// MARK: - Window Drag Shim

/// Makes the window draggable from anywhere in the content area.
/// Required when using .hiddenTitleBar, because the normal drag region
/// (the title bar) is no longer visible.
struct WindowDragShim: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDragView { WindowDragView() }
    func updateNSView(_ nsView: WindowDragView, context: Context) {
        nsView.needsDisplay = true  // trigger updateLayer every render cycle
    }

    final class WindowDragView: NSView {
        // wantsUpdateLayer=true causes AppKit to call updateLayer() during the
        // render cycle, when self.layer is guaranteed to exist — unlike
        // viewDidMoveToWindow where the CALayer hasn't been created yet.
        override var wantsUpdateLayer: Bool { true }

        override func updateLayer() {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.isMovableByWindowBackground = true
            effectiveAppearance.performAsCurrentDrawingAppearance {
                window.backgroundColor = NSColor.windowBackgroundColor
                // Also paint the NSHostingView (contentView) layer directly.
                window.contentView?.wantsLayer = true
                window.contentView?.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            needsDisplay = true
            guard let window else { return }
            effectiveAppearance.performAsCurrentDrawingAppearance {
                window.contentView?.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
        }
    }
}

// MARK: - Start

FireprofileApp.main()
