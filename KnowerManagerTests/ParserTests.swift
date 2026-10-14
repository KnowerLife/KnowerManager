import XCTest
@testable import KnowerManager

/// Тесты парсеров ссылок (vless/vmess/ss/trojan/hysteria2/tuic/socks/http).
final class ParserTests: XCTestCase {

    // MARK: - VLESS

    func testVLESSParsesWebSocketTLS() {
        let link = "vless://11111111-2222-3333-4444-555555555555@example.com:443?type=ws&security=tls&sni=example.com&path=%2Fws&host=example.com&fp=chrome&alpn=h2%2Chttp%2F1.1#My%20VLESS"

        let profile = VLESSParser.shared.parse(link: link)
        XCTAssertNotNil(profile)
        guard let p = profile else { return }

        XCTAssertEqual(p.protocolType, .vless)
        XCTAssertEqual(p.name, "My VLESS")
        XCTAssertEqual(p.server, "example.com")
        XCTAssertEqual(p.port, 443)
        XCTAssertEqual(p.password, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(p.network, "ws")
        XCTAssertEqual(p.security, "tls")
        XCTAssertEqual(p.wsPath, "/ws")
        XCTAssertEqual(p.wsHost, "example.com")
        XCTAssertEqual(p.sni, "example.com")
        XCTAssertEqual(p.fingerprint, "chrome")
        XCTAssertEqual(p.alpn, "h2,http/1.1")
    }

    /// Регресс: формат `host:port/?query` (со слэшем перед запросом) раньше
    /// обнулял порт и профиль отбрасывался.
    func testVLESSParsesTrailingSlashBeforeQuery() {
        let link = "vless://11111111-2222-3333-4444-555555555555@example.com:8443/?type=grpc&security=reality&serviceName=grpcsvc&pbk=PUBKEY&sid=abcd&fp=chrome&spx=%2F#Reality"

        let profile = VLESSParser.shared.parse(link: link)
        XCTAssertNotNil(profile)
        guard let p = profile else { return }

        XCTAssertEqual(p.server, "example.com")
        XCTAssertEqual(p.port, 8443)
        XCTAssertEqual(p.network, "grpc")
        XCTAssertEqual(p.grpcServiceName, "grpcsvc")
        XCTAssertEqual(p.pbk, "PUBKEY")
        XCTAssertEqual(p.sid, "abcd")
        XCTAssertEqual(p.spiderX, "/")
        XCTAssertEqual(p.name, "Reality")
    }

    func testVLESSMissingAtReturnsNil() {
        XCTAssertNil(VLESSParser.shared.parse(link: "vless://example.com:443"))
    }

    // MARK: - Trojan

    func testTrojanParses() {
        let link = "trojan://secretpass@trojan.example.org:8443?security=tls&sni=trojan.example.org&type=tcp#Trojan%20Node"

        let profile = VLESSParser.shared.parse(link: link)
        XCTAssertNotNil(profile)
        guard let p = profile else { return }

        XCTAssertEqual(p.protocolType, .trojan)
        XCTAssertEqual(p.name, "Trojan Node")
        XCTAssertEqual(p.server, "trojan.example.org")
        XCTAssertEqual(p.port, 8443)
        XCTAssertEqual(p.password, "secretpass")
        XCTAssertEqual(p.security, "tls")
        XCTAssertEqual(p.sni, "trojan.example.org")
        XCTAssertEqual(p.network, "tcp")
    }

    // MARK: - VMess

    func testVMessParsesBase64JSON() {
        let json = #"{"v":"2","ps":"VMess Test","add":"vmess.example.com","port":"443","id":"uuid-1234","aid":"0","net":"ws","type":"none","host":"vmess.example.com","path":"/vpath","tls":"tls"}"#
        let link = "vmess://" + Data(json.utf8).base64EncodedString()

        let profile = VMessParser.shared.parse(link: link)
        XCTAssertNotNil(profile)
        guard let p = profile else { return }

        XCTAssertEqual(p.protocolType, .vmess)
        XCTAssertEqual(p.name, "VMess Test")
        XCTAssertEqual(p.server, "vmess.example.com")
        XCTAssertEqual(p.port, 443)
        XCTAssertEqual(p.password, "uuid-1234")
        XCTAssertEqual(p.network, "ws")
        XCTAssertEqual(p.security, "tls")
        XCTAssertEqual(p.wsPath, "/vpath")
        XCTAssertEqual(p.wsHost, "vmess.example.com")
        XCTAssertEqual(p.sni, "vmess.example.com")
    }

    func testVMessNumericPort() {
        let json = #"{"v":"2","ps":"N","add":"a.com","port":8443,"id":"id","net":"tcp"}"#
        let link = "vmess://" + Data(json.utf8).base64EncodedString()

        let profile = VMessParser.shared.parse(link: link)
        XCTAssertEqual(profile?.port, 8443)
        XCTAssertEqual(profile?.security, "none")
    }

    func testVMessInvalidBase64ReturnsNil() {
        XCTAssertNil(VMessParser.shared.parse(link: "vmess://not-valid-base64!!!"))
    }

    // MARK: - Shadowsocks

    func testShadowsocksSIP002Plain() {
        let link = "ss://aes-256-gcm:password@example.net:8388#SS%20Test"

        let profile = SSParser.shared.parse(link: link)
        XCTAssertNotNil(profile)
        guard let p = profile else { return }

        XCTAssertEqual(p.protocolType, .shadowsocks)
        XCTAssertEqual(p.name, "SS Test")
        XCTAssertEqual(p.method, "aes-256-gcm")
        XCTAssertEqual(p.password, "password")
        XCTAssertEqual(p.server, "example.net")
        XCTAssertEqual(p.port, 8388)
    }

    func testShadowsocksSIP002Base64UserInfo() {
        let userInfo = Data("aes-256-gcm:password".utf8).base64EncodedString()
        let link = "ss://\(userInfo)@example.net:8388#Encoded"

        let profile = SSParser.shared.parse(link: link)
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.method, "aes-256-gcm")
        XCTAssertEqual(profile?.password, "password")
        XCTAssertEqual(profile?.server, "example.net")
        XCTAssertEqual(profile?.port, 8388)
    }

    func testShadowsocksLegacyWholeBase64() {
        let inner = "aes-128-gcm:testpass@1.2.3.4:9999"
        let link = "ss://" + Data(inner.utf8).base64EncodedString() + "#Legacy"

        let profile = SSParser.shared.parse(link: link)
        XCTAssertNotNil(profile)
        XCTAssertEqual(profile?.method, "aes-128-gcm")
        XCTAssertEqual(profile?.password, "testpass")
        XCTAssertEqual(profile?.server, "1.2.3.4")
        XCTAssertEqual(profile?.port, 9999)
        XCTAssertEqual(profile?.name, "Legacy")
    }

    func testShadowsocksInvalidCipherReturnsNil() {
        // Недопустимые символы в методе шифрования.
        let link = "ss://bad cipher!:pass@example.net:8388#Bad"
        XCTAssertNil(SSParser.shared.parse(link: link))
    }

    // MARK: - Hysteria2

    func testHysteria2Parses() {
        let link = "hysteria2://passw0rd@hy.example.com:443/?sni=hy.example.com&insecure=1&obfs=salamander&obfs-password=obfspass&alpn=h3&mport=20000-50000#HY2%20Node"

        let profile = Hysteria2Parser.shared.parse(link: link)
        XCTAssertNotNil(profile)
        guard let p = profile else { return }

        XCTAssertEqual(p.protocolType, .hysteria2)
        XCTAssertEqual(p.name, "HY2 Node")
        XCTAssertEqual(p.server, "hy.example.com")
        XCTAssertEqual(p.port, 443)
        XCTAssertEqual(p.password, "passw0rd")
        XCTAssertEqual(p.sni, "hy.example.com")
        XCTAssertEqual(p.allowInsecure, true)
        XCTAssertEqual(p.obfs, "salamander")
        XCTAssertEqual(p.obfsPassword, "obfspass")
        XCTAssertEqual(p.alpn, "h3")
        XCTAssertEqual(p.hy2Ports, "20000-50000")
    }

    // MARK: - TUIC

    func testTUICParses() {
        let link = "tuic://uuid-abc:tuicpass@tuic.example.com:443/?sni=tuic.example.com&alpn=h3&congestion_control=bbr&udp_relay_mode=native&allow_insecure=1&fp=chrome#TUIC%20Node"

        let profile = TUICParser.shared.parse(link: link)
        XCTAssertNotNil(profile)
        guard let p = profile else { return }

        XCTAssertEqual(p.protocolType, .tuic)
        XCTAssertEqual(p.name, "TUIC Node")
        XCTAssertEqual(p.server, "tuic.example.com")
        XCTAssertEqual(p.port, 443)
        XCTAssertEqual(p.password, "uuid-abc")
        XCTAssertEqual(p.tuicPassword, "tuicpass")
        XCTAssertEqual(p.sni, "tuic.example.com")
        XCTAssertEqual(p.allowInsecure, true)
        XCTAssertEqual(p.alpn, "h3")
        XCTAssertEqual(p.tuicCongestion, "bbr")
        XCTAssertEqual(p.tuicUDPRelayMode, "native")
        XCTAssertEqual(p.fingerprint, "chrome")
    }

    // MARK: - SOCKS / HTTP

    func testSOCKSParses() {
        let link = "socks5://user:pass@127.0.0.1:1080#SOCKS"

        let profile = SOCKSProxyParser.shared.parse(link: link)
        XCTAssertNotNil(profile)
        guard let p = profile else { return }

        XCTAssertEqual(p.protocolType, .socks)
        XCTAssertEqual(p.name, "SOCKS")
        XCTAssertEqual(p.server, "127.0.0.1")
        XCTAssertEqual(p.port, 1080)
        XCTAssertEqual(p.method, "user")
        XCTAssertEqual(p.password, "pass")
    }

    func testHTTPProxyParses() {
        let link = "http://user:pass@proxy.example.com:8080#HTTP"

        let profile = HTTPProxyParser.shared.parse(link: link)
        XCTAssertNotNil(profile)
        guard let p = profile else { return }

        XCTAssertEqual(p.protocolType, .http)
        XCTAssertEqual(p.name, "HTTP")
        XCTAssertEqual(p.server, "proxy.example.com")
        XCTAssertEqual(p.port, 8080)
        XCTAssertEqual(p.method, "user")
        XCTAssertEqual(p.password, "pass")
        XCTAssertNil(p.security)
    }

    func testHTTPSProxySetsTLS() {
        let link = "https://user:pass@secure.example.com:8443#HTTPS"

        let profile = HTTPProxyParser.shared.parse(link: link)
        XCTAssertEqual(profile?.protocolType, .http)
        XCTAssertEqual(profile?.security, "tls")
        XCTAssertEqual(profile?.port, 8443)
    }

    func testHTTPWithoutUserInfoReturnsNil() {
        XCTAssertNil(HTTPProxyParser.shared.parse(link: "http://example.com:8080#NoAuth"))
    }

    // MARK: - LinkParser (списки ссылок)

    func testLinkParserParsesMultipleLinks() {
        let text = """
        vless://11111111-2222-3333-4444-555555555555@a.example.com:443?type=tcp&security=tls#A
        trojan://pass@b.example.com:8443?security=tls#B
        ss://aes-256-gcm:password@c.example.net:8388#C
        """

        let profiles = LinkParser.parseLinks(from: text)
        XCTAssertEqual(profiles.count, 3)
        XCTAssertEqual(profiles.map { $0.server }, ["a.example.com", "b.example.com", "c.example.net"])
    }

    func testLinkParserDecodesWholeSubscriptionBase64() {
        let raw = "vless://11111111-2222-3333-4444-555555555555@a.example.com:443?type=tcp&security=tls#A"
        let text = Data(raw.utf8).base64EncodedString()

        let profiles = LinkParser.parseLinks(from: text)
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.server, "a.example.com")
    }

    func testLinkParserHandlesHTMLBreaks() {
        let text = "vless://11111111-2222-3333-4444-555555555555@a.example.com:443#A<br>trojan://pass@b.example.com:8443#B"
        let profiles = LinkParser.parseLinks(from: text)
        XCTAssertEqual(profiles.count, 2)
    }

    func testLinkParserIgnoresGarbage() {
        XCTAssertTrue(LinkParser.parseLinks(from: "just some text without links").isEmpty)
    }
}
