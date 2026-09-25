import Darwin
import Foundation

enum LoopbackReceiver {
    static func listen() throws -> (Int32, UInt16) {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else { throw GoogleCalendarError.invalidCallback }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr = in_addr(s_addr: in_addr_t(INADDR_LOOPBACK).bigEndian)
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0, Darwin.listen(socket, 2) == 0 else {
            Darwin.close(socket)
            throw GoogleCalendarError.invalidCallback
        }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let status = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(socket, $0, &length)
            }
        }
        guard status == 0 else {
            Darwin.close(socket)
            throw GoogleCalendarError.invalidCallback
        }
        return (socket, UInt16(bigEndian: address.sin_port))
    }

    static func receive(socket: Int32, state: String) throws -> String {
        defer { Darwin.close(socket) }
        let deadline = Date().addingTimeInterval(180)
        while Date() < deadline {
            var descriptor = pollfd(fd: socket, events: Int16(POLLIN), revents: 0)
            let remaining = Int32(min(1000, max(1, Int(deadline.timeIntervalSinceNow * 1000))))
            let polled = Darwin.poll(&descriptor, 1, remaining)
            if polled == 0 || (polled < 0 && errno == EINTR) { continue }
            guard polled > 0, descriptor.revents & Int16(POLLIN) != 0 else {
                throw GoogleCalendarError.invalidCallback
            }
            let client = Darwin.accept(socket, nil, nil)
            guard client >= 0 else { continue }
            var noSignal: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
            var timeout = timeval(tv_sec: 2, tv_usec: 0)
            setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            var bytes = [UInt8](repeating: 0, count: 8192)
            var count = 0
            while count < bytes.count && !bytes.prefix(count).contains(10) {
                let available = bytes.count - count
                let received = bytes.withUnsafeMutableBytes { buffer in
                    Darwin.recv(client, buffer.baseAddress!.advanced(by: count), available, 0)
                }
                if received <= 0 { break }
                count += received
            }
            let request = String(decoding: bytes.prefix(count), as: UTF8.self)
            let parts = request.components(separatedBy: "\r\n").first?.split(separator: " ") ?? []
            guard parts.count >= 2, parts[0] == "GET",
                  let uri = URLComponents(string: "http://127.0.0.1\(parts[1])"),
                  uri.path == "/oauth2callback",
                  uri.queryItems?.first(where: { $0.name == "state" })?.value == state else {
                Darwin.close(client)
                continue
            }
            let code = uri.queryItems?.first(where: { $0.name == "code" })?.value
            let body = code == nil ? "<h2>Google Calendar sign-in was cancelled.</h2>"
                                   : "<h2>Connected to Glint. You can close this tab.</h2>"
            let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
            let payload = Data(response.utf8)
            payload.withUnsafeBytes { buffer in _ = Darwin.send(client, buffer.baseAddress, buffer.count, 0) }
            Darwin.close(client)
            guard let code else { throw GoogleCalendarError.invalidCallback }
            return code
        }
        throw GoogleCalendarError.signInTimedOut
    }
}
