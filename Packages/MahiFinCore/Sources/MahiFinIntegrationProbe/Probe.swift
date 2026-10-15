import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import MahiFinCore

// Test executable only: never linked into either app. Credentials/output live in
// the disposable runner's private directory, never stdout or CI artifacts.
struct ProbeFailure: Error {
    let line: UInt
    init(line: UInt = #line) { self.line = line }
}
func require(_ value: Bool, line: UInt = #line) throws { if !value { throw ProbeFailure(line: line) } }
struct ProbeOutput: Codable {
    var token: String
    var urls: [String: String] = [:]
    var checks: [String] = []
}
actor LostWriteResponse: HTTPTransport {
    private var dropped = false
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let response = try await URLSessionTransport().send(request)
        if !dropped, request.httpMethod == "POST", request.url?.path.contains("/UserData") == true {
            dropped = true
            throw URLError(.networkConnectionLost) // Fault injected AFTER real server commit.
        }
        return response
    }
}
@main struct IntegrationProbe {
    static func main() async {
        var phase = "configuration"
        do {
            let env = ProcessInfo.processInfo.environment
            guard env["MAHIFIN_DISPOSABLE"] == "1", let raw = env["MAHIFIN_TEST_SERVER"],
                  let server = URL(string: raw), server.scheme == "https", server.host == "127.0.0.1",
                  let password = env["MAHIFIN_TEST_PASSWORD"], let otherPassword = env["MAHIFIN_OTHER_PASSWORD"],
                  let directory = env["MAHIFIN_PRIVATE_OUTPUT"] else { throw ProbeFailure() }
            let root = URL(fileURLWithPath: directory)
            let path = root.appendingPathComponent("probe-private.json")
            func save(_ output: ProbeOutput) throws { try JSONEncoder().encode(output).write(to: path, options: .atomic) }
            let anonymous = try JellyfinClient(server: server, deviceID: "integration-owner")
            phase = "public-system-info"
            let info = try await anonymous.systemInfo()
            phase = "owner-authentication"
            let auth = try await anonymous.authenticate(username: "fixture-owner", password: password)
            let account = Account(server: server, serverID: info.Id, userID: auth.User.Id, name: "Invented")
            let client = try JellyfinClient(server: server, token: auth.AccessToken, deviceID: "integration-owner")
            var output = ProbeOutput(token: auth.AccessToken)
            try save(output)
            phase = "wrong-password-rejection"
            do { _ = try await anonymous.authenticate(username: "fixture-owner", password: UUID().uuidString); throw ProbeFailure() }
            catch ClientError.unauthorized {} // Real rejected password, not a fixture response.
            phase = "other-user-authentication"
            let otherAnonymous = try JellyfinClient(server: server, deviceID: "integration-other")
            let otherAuth = try await otherAnonymous.authenticate(username: "fixture-other", password: otherPassword)
            let other = try JellyfinClient(server: server, token: otherAuth.AccessToken, deviceID: "integration-other")
            output.checks.append("real-password-authentication-and-rejection")

            phase = "catalog"
            let movies = try await client.items(user: auth.User.Id, route: .movies)
            let series = try await client.items(user: auth.User.Id, route: .series)
            let views = try await client.items(user: auth.User.Id, route: .views)
            try require(movies.Items.count == 3 && series.Items.count == 1 && views.Items.count == 2)
            guard let original = movies.Items.first(where: { $0.Name == "Fixture Original" }),
                  let remux = movies.Items.first(where: { $0.Name == "Fixture Copy 4K" }),
                  let audio = movies.Items.first(where: { $0.Name == "Fixture Audio 4K" }),
                  let show = series.Items.first else { throw ProbeFailure() }
            let episodes = try await client.items(user: auth.User.Id, route: .episodes(show.Id))
            try require(episodes.Items.count == 2)
            let search = try await client.items(user: auth.User.Id, route: .search("Fixture Original"))
            try require(search.Items.contains(where: { $0.Id == original.Id }))
            let paged = try await client.items(user: auth.User.Id, route: .movies, start: 2)
            try require(paged.Items.count == 1 && paged.TotalRecordCount == 3)
            output.checks.append("real-movies-series-views-search-pagination-episodes")

            phase = "history"
            try await client.setFavorite(user: auth.User.Id, item: original.Id, favorite: true)
            let queue = try HistoryQueue(disk: DiskStore(root: root.appendingPathComponent("history")))
            try await queue.record(account: account.id, item: original.Id, seconds: 720, completed: false, device: "integration")
            let lostClient = try JellyfinClient(server: server, token: auth.AccessToken, deviceID: "integration-owner", transport: LostWriteResponse())
            let lost = await HistorySync.run(queue: queue, remote: lostClient, account: account)
            try require(lost.issue == "network")
            let replay = await HistorySync.run(queue: queue, remote: client, account: account)
            let pending = await queue.pending(account: account.id)
            try require(replay.acknowledged == 1 && pending.isEmpty)
            let fresh = try await client.item(user: auth.User.Id, id: original.Id)
            try require(fresh.position == 720 && fresh.UserData?.IsFavorite == true && fresh.UserData?.Played != true)
            let restored = try HistoryQueue(disk: DiskStore(root: root.appendingPathComponent("history")))
            let cached = await restored.latest(account: account.id, item: original.Id)
            try require(cached?.ticks == 7_200_000_000)
            let otherItem = try await other.item(user: otherAuth.User.Id, id: original.Id)
            try require(otherItem.position == 0 && otherItem.UserData?.IsFavorite != true)
            let resume = try await client.items(user: auth.User.Id, route: .resume)
            try require(resume.Items.contains(where: { $0.Id == original.Id && $0.position == 720 }))
            // Real session progress/stop and next-up; no physical playback is implied.
            let episode = episodes.Items[0]
            let episodeInfo = try await client.playbackInfo(user: auth.User.Id, item: episode.Id)
            let event = SessionEvent(item: episode.Id, source: episodeInfo.MediaSources.first?.Id, session: episodeInfo.PlaySessionId ?? UUID().uuidString, seconds: 720, paused: true)
            try await client.report(event, endpoint: "Playing")
            try await client.report(event, endpoint: "Playing/Progress")
            try await client.report(event, endpoint: "Playing/Stopped")
            try await client.savePosition(user: auth.User.Id, item: episode.Id, ticks: 0, date: Date(), completed: true)
            let next = try await client.items(user: auth.User.Id, route: .nextUp)
            try require(next.Items.contains(where: { $0.Id == episodes.Items[1].Id }))
            output.checks.append("real-offline-replay-lost-response-resume-profile-isolation-next-up")

            phase = "original-download"
            let originalInfo = try await client.playbackInfo(user: auth.User.Id, item: original.Id)
            guard let originalSource = originalInfo.MediaSources.first else { throw ProbeFailure() }
            let transport = URLSessionTransport()
            let request = try client.originalRequest(item: original.Id)
            let (bytes, response) = try await transport.send(request)
            try require(response.statusCode == 200 && Int64(bytes.count) == originalSource.Size)
            try bytes.write(to: root.appendingPathComponent("download-original.mkv"))
            var range = request; range.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
            let (prefix, partial) = try await transport.send(range)
            try require(partial.statusCode == 206 && prefix == Data(bytes.prefix(1024)))
            range.setValue("bytes=1024-", forHTTPHeaderField: "Range")
            let (remainder, resumed) = try await transport.send(range)
            try require(resumed.statusCode == 206 && prefix + remainder == bytes)
            try require(DownloadIntegrity.isComplete(bytes: Int64(bytes.count), originalSize: originalSource.Size, responseSize: resumed.expectedContentLength, status: 206, contentRange: resumed.value(forHTTPHeaderField: "Content-Range")))
            var slow = request; slow.setValue("1", forHTTPHeaderField: "X-MahiFin-Test-Slow")
            let transfer = Task { try await transport.send(slow) }
            try await Task.sleep(for: .milliseconds(100)); transfer.cancel()
            do { _ = try await transfer.value; throw ProbeFailure() }
            catch is CancellationError {}
            catch let error as URLError where error.code == .cancelled {}
            output.urls["original"] = try client.directURL(item: original.Id, source: originalSource).absoluteString
            output.checks.append("real-original-size-byte-ranges-resume-cancel")

            phase = "conversion-contract"
            for (mode, item) in [(ConversionMode.remux, remux), (.audioOnly, audio), (.video, remux)] {
                let playback = try await client.playbackInfo(user: auth.User.Id, item: item.Id)
                guard let source = playback.MediaSources.first else { throw ProbeFailure() }
                var grant: VideoConsent?
                if mode == .video {
                    do { _ = try client.conversionURL(account: account, item: item.Id, source: source, session: "declined", mode: mode); throw ProbeFailure() }
                    catch ClientError.unavailable {}
                    // Explicit automated grant only in this test executable. The app's
                    // real human Cancel/Accept UI is separately exercised by XCUITest.
                    try require(env["MAHIFIN_TEST_ACCEPT_VIDEO"] == "1")
                    grant = .accept(account: account.id, item: item.Id, source: source.Id)
                }
                let session = playback.PlaySessionId ?? UUID().uuidString
                output.urls[mode.rawValue] = try client.conversionURL(account: account, item: item.Id, source: source, session: session, mode: mode, consent: grant).absoluteString
                output.urls[mode.rawValue + "Cleanup"] = try client.url("Videos/ActiveEncodings", query: ["DeviceId": client.deviceID, "PlaySessionId": session]).absoluteString
            }
            output.checks.append("real-playback-info-production-conversion-urls-denied-without-grant")
            try save(output)
            print("INTEGRATION: Swift real-server probe passed")
        } catch {
            // Do not stringify Error/URLRequest: these can include token-bearing URLs.
            print("INTEGRATION: Swift probe FAILED at \(phase)")
            if let error = error as? ClientError {
                // This enum contains only fixed cases or an integer status.
                print("INTEGRATION: client category \(String(describing: error))")
            } else if let error = error as? URLError {
                print("INTEGRATION: transport code \(error.code.rawValue)")
                if phase == "public-system-info" {
                    // This anonymous request has no token/password. Curl's reason
                    // is needed for Linux TLS/protocol diagnosis; redact any URL.
                    let reason = error.localizedDescription.replacingOccurrences(
                        of: #"[a-zA-Z][a-zA-Z0-9+.-]*://\S+"#, with: "[URL]", options: .regularExpression)
                        .replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
                    print("INTEGRATION: anonymous transport reason \(reason.prefix(300))")
                }
            } else if error is DecodingError {
                print("INTEGRATION: response decoding failed")
            } else if let error = error as? ProbeFailure {
                print("INTEGRATION: contract assertion failed at source line \(error.line)")
            }
            exit(1)
        }
    }
}
