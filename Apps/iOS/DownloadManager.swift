import Foundation
import UIKit
import AVKit
import SwiftUI
import MahiFinCore

final class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate, @unchecked Sendable {
    static weak var current: DownloadManager?
    static var backgroundCompletion: (() -> Void)?
    @Published private(set) var records: [DownloadRecord]
    let root: URL
    private let disk: DiskStore
    private let resumeStore = KeychainTokens()
    private var tasks: [UUID: URLSessionDownloadTask] = [:]
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "MahiFin.original-downloads.v1")
        config.sessionSendsLaunchEvents = true; config.isDiscretionary = false
        config.allowsCellularAccess = true // Individual requests enforce user's policy.
        config.waitsForConnectivity = true
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()
    init(root: URL) throws {
        self.root = root; disk = try DiskStore(root: root)
        records = try disk.load([DownloadRecord].self, name: "manifest.json") ?? []
        super.init(); Self.current = self
        session.getAllTasks { [weak self] activeTasks in
            DispatchQueue.main.async {
                guard let self else { return }
                for task in activeTasks {
                    guard let id = task.taskDescription.flatMap(UUID.init(uuidString:)), let download = task as? URLSessionDownloadTask else { task.cancel(); continue }
                    guard self.records.contains(where: { $0.id == id && $0.taskID == task.taskIdentifier && $0.state != .complete }) else { task.cancel(); continue }
                    self.tasks[id] = download
                }
                for index in self.records.indices where self.records[index].state == .downloading && self.tasks[self.records[index].id] == nil {
                    self.records[index].state = .failed; self.records[index].failure = "interrupted"
                }
                self.persist()
            }
        }
    }
    func enqueue(account: Account, item: MediaItem, source: MediaSource, request: URLRequest, cellular: Bool) throws {
        guard !records.contains(where: { $0.account == account.id && $0.item.Id == item.Id }) else { return }
        guard source.IsRemote != true, source.RequiresOpening != true else { throw ClientError.unavailable }
        let available = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage ?? 0
        guard let size = source.Size, size > 0, available > size + 50_000_000 else { throw ClientError.storage }
        let record = DownloadRecord(account: account.id, item: item, source: source)
        records.append(record)
        try disk.save(records, name: "manifest.json")
        try start(id: record.id, request: request, cellular: cellular)
    }
    func start(id: UUID, request: URLRequest, cellular: Bool) throws {
        guard let index = records.firstIndex(where: { $0.id == id }), records[index].state != .complete else { return }
        var request = request; request.allowsCellularAccess = cellular
        let task: URLSessionDownloadTask
        let resumeKey = "download-resume:" + id.uuidString
        if records[index].state == .paused,
           let encoded = try resumeStore.read(account: resumeKey), let data = Data(base64Encoded: encoded) {
            task = session.downloadTask(withResumeData: data)
            try resumeStore.remove(account: resumeKey)
        } else {
            task = session.downloadTask(with: request)
            records[index].received = 0
        }
        try resumeStore.remove(account: resumeKey)
        task.taskDescription = id.uuidString; tasks[id] = task
        records[index].state = .downloading; records[index].taskID = task.taskIdentifier; records[index].failure = nil
        try disk.save(records, name: "manifest.json"); task.resume()
    }
    func pause(id: UUID) {
        guard let index = records.firstIndex(where: { $0.id == id }), records[index].state == .downloading else { return }
        records[index].state = .paused; persist()
        tasks[id]?.cancel(byProducingResumeData: { [weak self] data in
            guard let self, let data else { return }
            // Apple's opaque resume data can include authentication headers. Keep it in Keychain too.
            DispatchQueue.main.async {
                guard self.records.contains(where: { $0.id == id && $0.state == .paused }) else { return }
                do { try self.resumeStore.write(data.base64EncodedString(), account: "download-resume:" + id.uuidString) }
                catch { self.persist() /* The durable manifest stays paused; a fresh transfer remains possible. */ }
            }
        })
    }
    func pause(account: String) { for record in records where record.account == account { pause(id: record.id) } }
    func delete(id: UUID, account: String) throws {
        guard let index = records.firstIndex(where: { $0.id == id && $0.account == account }) else { throw ClientError.unavailable }
        tasks[id]?.cancel(); tasks[id] = nil
        if let filename = records[index].filename, filename.hasPrefix(id.uuidString + "."), !filename.contains("/") {
            try FileManager.default.removeItem(at: root.appendingPathComponent(filename))
        }
        try resumeStore.remove(account: "download-resume:" + id.uuidString)
        records.remove(at: index); try disk.save(records, name: "manifest.json")
    }
    private func persist() {
        do { try disk.save(records, name: "manifest.json") }
        catch { /* Retain visible state and report a storage category without logging private paths. */
            for index in records.indices where records[index].state == .downloading { records[index].failure = "storage" }
        }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = downloadTask.taskDescription.flatMap(UUID.init(uuidString:)), let index = records.firstIndex(where: { $0.id == id }) else { return }
        guard records[index].taskID == downloadTask.taskIdentifier else { return }
        let oldMegabyte = records[index].received / 1_000_000
        records[index].received = totalBytesWritten
        // Preserve the authoritative original size; a short response cannot redefine success.
        if oldMegabyte != totalBytesWritten / 1_000_000 { persist() }
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = downloadTask.taskDescription.flatMap(UUID.init(uuidString:)), let index = records.firstIndex(where: { $0.id == id }) else { return }
        guard records[index].taskID == downloadTask.taskIdentifier else { return }
        var movedFile: URL?
        do {
            guard let response = downloadTask.response as? HTTPURLResponse, response.statusCode == 200 else { throw ClientError.invalidResponse }
            let containers: Set<String> = ["mp4", "mov", "m4v", "mkv", "webm", "avi", "ts"]
            guard let ext = records[index].source.Container?.lowercased(), containers.contains(ext) else { throw ClientError.unavailable }
            let filename = id.uuidString + "." + ext
            let destination = root.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
            try FileManager.default.moveItem(at: location, to: destination)
            movedFile = destination
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: destination.path)
            var protected = destination; var values = URLResourceValues(); values.isExcludedFromBackup = true
            try protected.setResourceValues(values)
            let size = (try destination.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            guard DownloadIntegrity.isComplete(bytes: size, originalSize: records[index].source.Size, responseSize: downloadTask.countOfBytesExpectedToReceive) else { throw ClientError.invalidResponse }
            records[index].filename = filename; records[index].state = .complete; records[index].received = size
        } catch {
            if let movedFile { try? FileManager.default.removeItem(at: movedFile) }
            records[index].state = .failed; records[index].failure = "storage-or-response"
        }
        persist()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = task.taskDescription.flatMap(UUID.init(uuidString:)), let index = records.firstIndex(where: { $0.id == id }) else { return }
        guard records[index].taskID == task.taskIdentifier else { return }
        tasks[id] = nil
        if error != nil && records[index].state != .paused {
            records[index].state = .failed; records[index].failure = "network-or-auth"; persist()
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        let old = task.originalRequest?.url
        completionHandler(request.url?.scheme == "https" && request.url?.host == old?.host && request.url?.port == old?.port ? request : nil)
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        Self.backgroundCompletion?(); Self.backgroundCompletion = nil
    }
}
final class MobileAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        DownloadManager.backgroundCompletion = completionHandler
    }
}
struct AirPlayPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView(); view.prioritizesVideoDevices = true; view.tintColor = .systemMint; return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
struct DownloadsView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View { DownloadList(manager: model.downloads).environmentObject(model) }
}
private struct DownloadList: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var manager: DownloadManager
    var body: some View {
        List {
            let account = model.active?.id ?? ""
            let visible = manager.records.filter { $0.account == account }
            if visible.isEmpty { Text("download.empty") }
            ForEach(visible) { record in
                VStack(alignment: .leading, spacing: 12) {
                    Text(record.item.Name).font(.headline)
                    Text(LocalizedStringKey("download." + record.state.rawValue))
                    ProgressView(value: Double(record.received), total: Double(max(1, record.expected)))
                    if record.state == .complete, let url = try? record.localURL(root: manager.root, activeAccount: account) {
                        NavigationLink("player.play") { PlaybackView(item: record.item, localURL: url, localSource: record.source) }
                    } else if record.state == .downloading {
                        Button("download.pause") { manager.pause(id: record.id) }
                    } else {
                        Button("retry") {
                            do { try manager.start(id: record.id, request: model.client().originalRequest(item: record.item.Id), cellular: model.cellularDownloads) }
                            catch { model.show(error) }
                        }
                    }
                    Button("download.delete", role: .destructive) {
                        do { try manager.delete(id: record.id, account: account) } catch { model.show(error) }
                    }
                }
            }
        }.navigationTitle("nav.downloads")
    }
}
