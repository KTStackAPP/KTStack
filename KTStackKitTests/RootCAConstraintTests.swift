import KTStackCore
import XCTest
@testable import KTStackKit

final class RootCAConstraintTests: XCTestCase {
    private func pem(_ body: String) -> Data {
        Data(body.utf8)
    }

    func testAcceptsMkcertRootCA() {
        XCTAssertNil(RootCAConstraint.validateKTStackRootCA(pemData: pem(Self.mkcertRootCA)))
    }

    func testRejectsLeafCertAsNotSelfSigned() {
        XCTAssertEqual(RootCAConstraint.validateKTStackRootCA(pemData: pem(Self.mkcertLeaf)), .notSelfSigned)
    }

    func testRejectsSelfSignedNonCACert() {
        XCTAssertEqual(RootCAConstraint.validateKTStackRootCA(pemData: pem(Self.selfSignedNonCA)), .notCertificateAuthority)
    }

    func testRejectsForeignSelfSignedCA() {
        XCTAssertEqual(RootCAConstraint.validateKTStackRootCA(pemData: pem(Self.foreignRootCA)), .organizationMismatch)
    }

    func testRejectsUnparseableBytes() {
        XCTAssertEqual(RootCAConstraint.validateKTStackRootCA(pemData: pem("not a certificate at all")), .notSingleCertificate)
    }

    func testRejectsMultipleCertificates() {
        XCTAssertEqual(RootCAConstraint.validateKTStackRootCA(pemData: pem(Self.mkcertRootCA + Self.mkcertLeaf)), .notSingleCertificate)
    }

    private static let mkcertRootCA = """
    -----BEGIN CERTIFICATE-----
    MIIEujCCAyKgAwIBAgIRAJvbQ35HjPq029weIKzDlkYwDQYJKoZIhvcNAQELBQAw
    dTEeMBwGA1UEChMVbWtjZXJ0IGRldmVsb3BtZW50IENBMSUwIwYDVQQLDBxuZ3V5
    ZW5raG9pQE1hY0Jvb2tOZ3V5ZW5LaG9pMSwwKgYDVQQDDCNta2NlcnQgbmd1eWVu
    a2hvaUBNYWNCb29rTmd1eWVuS2hvaTAeFw0yNjA2MTEwNjUzNDFaFw0zNjA2MTEw
    NjUzNDFaMHUxHjAcBgNVBAoTFW1rY2VydCBkZXZlbG9wbWVudCBDQTElMCMGA1UE
    Cwwcbmd1eWVua2hvaUBNYWNCb29rTmd1eWVuS2hvaTEsMCoGA1UEAwwjbWtjZXJ0
    IG5ndXllbmtob2lATWFjQm9va05ndXllbktob2kwggGiMA0GCSqGSIb3DQEBAQUA
    A4IBjwAwggGKAoIBgQDSZH8YU0CuJ1c8iOtv/ZweHwLaIiv04hBircGOlpw/zeAN
    52q95EbQACkpfNVyCOJka6WjvE7IY97AFtkSCS1lgSur17kWtUgsvrO69i1N4S/Y
    KFccdKg/vecyK+DesDIPVWWqgerpBQvp0q0Cm4m+3YE+SuiJugL/04TVszwqbtzb
    zzhF1O6wAr0MfBD8HVGBY5b0TupQcYWabCgavx3EnV6wPUbKN2ktkLD/thcp0Ra9
    vp7hbHPdJEPkM8HeQ9hH2aZB++G42XlTcLqutDDpgwxj1nclcyG0IODvj2wlAT3l
    t/qziF+A5q7A27yLpcy8LNveSiAv0x4H3xtbp4aUYS1hf/fPEELrWK/fiRYgU401
    ybQ69DlWkwBT8bbioBeHHgX7IVRaV9r5JaIwfzvO6LhwNK3W9ooUkY7wrdRtwDt7
    G6cwkabST4vux/uS4Q8triZ6oqVgbsQPQ+uJGqodbb4CC7l4rWiISwmR/ZI0F9+n
    XqCStaLTjju4GBKMMzECAwEAAaNFMEMwDgYDVR0PAQH/BAQDAgIEMBIGA1UdEwEB
    /wQIMAYBAf8CAQAwHQYDVR0OBBYEFGFO60VghDtxqtq1SDiisRXaXUbUMA0GCSqG
    SIb3DQEBCwUAA4IBgQCQ9pXlqrYHaIwfzfkRi4dCz5xeRPCoXDJiWJC03jyTr6y/
    ljrFtAP6E2TE+o+SX4bjw8u4qDJmFBduCiNLm/05Hk46MdHyovjrTgBXiSs43U/A
    z+KUyVf2lGrUU2Y80OSNXr3R1tNKbS5RNk0SoFwrxTpK2CASBA5Zl5YJtYof//at
    riDPnZJYd8A2GvWKYSzrtnRWjMRxbIXbiV/AVBA1jm5AXHEtqUeKLhCV6b6po74O
    gcj8ELAuwygjRuY3SpxFXaqXpS0tT81C9y05l5IDqUz7ktLbc+AtNEbzkjS9IsA2
    S9Dft6V4wACWHr7dsgSVvP/sJdiIBYNeduNARP/dwmjTuzKhVhNVpiPFtcXjct+/
    aYjQleAJIYFQm2LjvQYmQXVNRpm5scf3cCeDlAPwF0dCrrZwazeeSMpqVQjlD4hZ
    lJGaUgp0pC4sgIZbaSM+yUDHdfn+MGmWQh4M7LKyz6gifrKTg2mkgqBlGdZoTHob
    DNVz+Dp1afhBkJC12Gk=
    -----END CERTIFICATE-----

    """

    private static let mkcertLeaf = """
    -----BEGIN CERTIFICATE-----
    MIIELTCCApWgAwIBAgIQZt2Tkc2b7Xh8q7qgBqjb9jANBgkqhkiG9w0BAQsFADB1
    MR4wHAYDVQQKExVta2NlcnQgZGV2ZWxvcG1lbnQgQ0ExJTAjBgNVBAsMHG5ndXll
    bmtob2lATWFjQm9va05ndXllbktob2kxLDAqBgNVBAMMI21rY2VydCBuZ3V5ZW5r
    aG9pQE1hY0Jvb2tOZ3V5ZW5LaG9pMB4XDTI2MDYxMTA3MTQ0N1oXDTI4MDkxMTA3
    MTQ0N1owUDEnMCUGA1UEChMebWtjZXJ0IGRldmVsb3BtZW50IGNlcnRpZmljYXRl
    MSUwIwYDVQQLDBxuZ3V5ZW5raG9pQE1hY0Jvb2tOZ3V5ZW5LaG9pMIIBIjANBgkq
    hkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA63dkzYkiZkOU/6GlSvPq3RdUtrjtb6Fh
    9Up9hLA8OvhYyi9a7YY6ke4G86z0sTHLxM4QgwRXd0GYZ2Z4CDOTpxeBnPH9TCNd
    5v3kob6QCCY0GWvECorPNrpFqcw15wMAF77+fbu6pENtP3Rw9n+c4n11ktBQgGzC
    VycIXwkdRoP6GumIcGfe5nYci6E+KFV5dP4Dc3xxBfJHmJddisVfPvJuHqbv+gb/
    hDxYcLiUl8he0wFAH4GsnuE5aorupinam4GmJ+RQSDpaw9hw9nM10cHtkIFayn14
    0LEhN4betAFANnnlxUpbki/e7lpuKRnYBEsF6XKv/pxHuwLbJmhyQwIDAQABo14w
    XDAOBgNVHQ8BAf8EBAMCBaAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwHwYDVR0jBBgw
    FoAUYU7rRWCEO3Gq2rVIOKKxFdpdRtQwFAYDVR0RBA0wC4IJZGVtby50ZXN0MA0G
    CSqGSIb3DQEBCwUAA4IBgQClaAggGN3hRyRo+06YUUY9eJIGOPMUCkaGovBKe4gj
    XmgXYgdy80T11Yx/Tr32+BrVFfe31DxcUw0/ZhOrbxOpWAhx/eNmqzMgBSBaMWeX
    2QGZd9g3oEQiyB7c48pkaSNtb+8AMD+Ny5do9aXwc/Ap7ZU1RKOOnbYEK1xTT77L
    oXFK2Qqqnp71lkwSPOGvNrBhZqTUGoPfQ2RbhqaNM+V8tVGXsKZ/Uagt1Bg3A/h2
    gjWUABUBWOLiK7OMBjOe9/t3NE0Bea1WXi5xvNZvDRNOofZ0fyZUI+5CAOaQuNbR
    /EStCVkm0KPfbe4gUwL+Yv4XaWtTN83/f5Ddz6BAVjay9+Sqxb22rqu6xYkoM+eY
    zl71ruUs8MYxJ7iUJxsPu+cHvahinPKPaOAmjMdI0DfXJ+jbwFVWkWImzE2FT5Dd
    JHAVhc4fhp12L12H8bbg6QoBnj4mlFDa3qVu/Im7+IRu0ACDEutqXbg+01oo6geq
    6lodMNad/BgeIhI/cFJODUQ=
    -----END CERTIFICATE-----

    """

    private static let foreignRootCA = """
    -----BEGIN CERTIFICATE-----
    MIIC5jCCAc6gAwIBAgIJAPCm2PA1kvPqMA0GCSqGSIb3DQEBCwUAMCgxEjAQBgNV
    BAoMCUV2aWwgQ29ycDESMBAGA1UEAwwJZXZpbCByb290MB4XDTI2MDYyMzA1MDQw
    N1oXDTM2MDYyMDA1MDQwN1owKDESMBAGA1UECgwJRXZpbCBDb3JwMRIwEAYDVQQD
    DAlldmlsIHJvb3QwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDPxm6S
    HMg+PiHNjqSqbRTLn1Ss7/Bn5IbtfO1siB8xRC8j9GLy0Ixka1qyxXIcmKpaKxtx
    nuDBKI08YHkbuh8mqNPVYxelcDJeNkno43rZsHlY3Oc2vmTfSsfMyldzBI8OjhK5
    gNbYUhXaLhpqCCabmgP/QAwmqFLSbTpzMsxHPfYRKsmA4JMHOYMawvZN6zdtqo48
    +Zc/4OKKFOLaCjEhMA5Nw8Sar8kRE5BRr3UMiqXSLwA3I+1zgsopeKgJmPKPjn6H
    pPs2EvD0pFX95UfzImbrVvqF6/IWM5cRorPQ0+meSBX4gX33oXMqNpEUiqotLIbw
    mg/ZfX1/eFcA7wfvAgMBAAGjEzARMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcN
    AQELBQADggEBABCunhKi5CXvprFYFoLbF14KyC3+VLkm9lMFuM1Fx095RTNJHB8m
    lZvrDPBs/TbJ9O5kgOnS70ilrSCtc1WuTTqr8m13rDYw74avlZH/apQcR296IzbQ
    9CbdnepkhntVVmC5VboEMAiPWzwmCP+TTcJpHgrMI0OD5PKRUeraBwywTu5ZA8jr
    N4F1EuNAF8FDe6Yo04XmUQsVeZUWzm9mrbWJW3iJ8fqpDLz19Z45so26+2ehKyHe
    zg/nv0w6M844IzgxRbUM4k2xXhILvC2VMKqqD5qzfemAzd6ewL6UcDf+PF1LGlpr
    u+ue6AaHhSv13P4dkcGGqoIQPGanXwJSnig=
    -----END CERTIFICATE-----

    """

    private static let selfSignedNonCA = """
    -----BEGIN CERTIFICATE-----
    MIIC/TCCAeWgAwIBAgIJALFV9H/9qdF+MA0GCSqGSIb3DQEBCwUAMDUxHjAcBgNV
    BAoMFW1rY2VydCBkZXZlbG9wbWVudCBDQTETMBEGA1UEAwwKZmFrZSBub25jQTAe
    Fw0yNjA2MjMwNTA1MjlaFw0zNjA2MjAwNTA1MjlaMDUxHjAcBgNVBAoMFW1rY2Vy
    dCBkZXZlbG9wbWVudCBDQTETMBEGA1UEAwwKZmFrZSBub25jQTCCASIwDQYJKoZI
    hvcNAQEBBQADggEPADCCAQoCggEBAKePjXV6FbfRj0AMFh8dwJAYLqoDxfh5WZme
    MkgITTSS2YOcEwGFlMAoylLoortV5t7ligq8CkGPHvCr3lqa9nvepAyfjZlKlsR9
    toNNl1Jm3snFaC5GIARADZKbEWPwpukkxCBkfHueiZfn9mSh9uiFBwL42c+0btxS
    /tmRC2zk/hVA7gnst12Z6zgXoxYeFcfxwW78Ow5QvKfwChOFED8rbFc+SFZi0Ela
    gCYmrG6EDwam7R9l0MzFL7evQibbNFfPOCsFyttc1mZSX8rjilHunv/Qe1pj4UIS
    ZaFXmHBEHZudTlJK6tUFN6s5H1hiIyd0LMxa3xyKpme7DEtJh00CAwEAAaMQMA4w
    DAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAQEApxjZ5A/SMJHkaM6LC6g2
    tmUaFzyxHnHrTsOj+/LGXB7uLqqD53Tb7aEYQYwgWhkm69EZmLPpIGtL+OYx1TAM
    ZBQDAkSfDeuUBq4xRNQ2SBWxFrwA5e+j1xAH8MyN7Z7RkCKSvVmA9oBY6/HOIvOd
    atFiAHtnB3h9xSaw5lyINR3Ed8QgTvi6jQzYNcHRciRLCpoCggxHMTQPTQX88zsX
    FooBRGPOWDu0+jfSChRAdNGjj0+IW1nX/T3u/0/AdYnqqYiApwvGM9ZlZn3jB/5N
    xxLTOWxl5hqQ6VTM0m+jI2ddwxwen1pu0sYmtcxZu7mv+FK8RD+Ac4/JMY74jD2K
    +g==
    -----END CERTIFICATE-----

    """
}
