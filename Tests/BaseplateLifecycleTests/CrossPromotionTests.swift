import Foundation
import Testing

@testable import BaseplateLifecycle

@Suite struct AppStoreCampaignLinkTests {

    @Test func full_link_with_provider_and_campaign() {
        let builder = AppStoreCampaignLink(providerToken: "264080")
        let url = builder.url(appStoreID: "327084738", campaignToken: "ios_share_sheet")
        #expect(
            url.absoluteString
                == "https://apps.apple.com/app/id327084738?pt=264080&ct=ios_share_sheet&mt=8")
    }

    @Test func omits_provider_token_when_unset() {
        let url = AppStoreCampaignLink().url(appStoreID: "327084738", campaignToken: "x")
        #expect(url.absoluteString == "https://apps.apple.com/app/id327084738?ct=x&mt=8")
    }

    @Test func bare_link_has_only_mt() {
        let url = AppStoreCampaignLink().url(appStoreID: "327084738")
        #expect(url.absoluteString == "https://apps.apple.com/app/id327084738?mt=8")
    }

    @Test func campaign_token_whitespace_becomes_underscores() {
        #expect(
            AppStoreCampaignLink.sanitizedCampaignToken("ios share sheet") == "ios_share_sheet")
    }

    @Test func campaign_token_truncated_to_40_chars() {
        let long = String(repeating: "a", count: 60)
        #expect(AppStoreCampaignLink.sanitizedCampaignToken(long).count == 40)
    }

    @Test func nil_and_empty_campaign_token_yield_empty() {
        #expect(AppStoreCampaignLink.sanitizedCampaignToken(nil) == "")
        #expect(AppStoreCampaignLink.sanitizedCampaignToken("") == "")
    }

    @Test func attribution_configured_flag() {
        #expect(AppStoreCampaignLink().attributionConfigured == false)
        #expect(AppStoreCampaignLink(providerToken: "").attributionConfigured == false)
        #expect(AppStoreCampaignLink(providerToken: "1").attributionConfigured == true)
    }

    @Test func url_for_portfolio_app_uses_its_token() {
        let app = PortfolioApp(
            name: "A", tagline: "", appStoreID: "111",
            icon: .systemName("a.circle"), campaignToken: "cross promo")
        let url = AppStoreCampaignLink(providerToken: "9").url(for: app)
        #expect(url.absoluteString == "https://apps.apple.com/app/id111?pt=9&ct=cross_promo&mt=8")
    }
}

@Suite struct PortfolioAppTests {

    @Test func id_is_app_store_id() {
        let app = PortfolioApp(
            name: "A", tagline: "t", appStoreID: "555", icon: .systemName("a.circle"))
        #expect(app.id == "555")
    }

    @Test func excluding_current_app_filters_it_out() {
        let portfolio = [
            PortfolioApp(name: "A", tagline: "", appStoreID: "1", icon: .systemName("a.circle")),
            PortfolioApp(name: "B", tagline: "", appStoreID: "2", icon: .systemName("b.circle")),
            PortfolioApp(name: "C", tagline: "", appStoreID: "3", icon: .systemName("c.circle")),
        ]
        #expect(portfolio.excludingApp(withID: "2").map(\.name) == ["A", "C"])
    }

    @Test func excluding_missing_id_returns_all() {
        let portfolio = [
            PortfolioApp(name: "A", tagline: "", appStoreID: "1", icon: .systemName("a.circle"))
        ]
        #expect(portfolio.excludingApp(withID: "999").count == 1)
    }

    @Test func excluding_from_empty_is_empty() {
        let portfolio: [PortfolioApp] = []
        #expect(portfolio.excludingApp(withID: "1").isEmpty)
    }
}
