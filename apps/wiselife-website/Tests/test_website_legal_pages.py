from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
PROTOTYPE = ROOT


class WebsiteLegalPagesTests(unittest.TestCase):
    def test_privacy_page_explains_data_and_user_choices(self):
        page = PROTOTYPE / "privacy" / "index.html"
        self.assertTrue(page.is_file(), "privacy page must exist at /privacy")
        html = page.read_text(encoding="utf-8")
        for required in (
            "Privacy Policy", "Data we process", "locally", "external AI",
            "HealthKit", "Revoke", "delete", "excluded from iCloud device backups", "hello@wiselife.cloud",
            "EurekaLife App does not provide a cloud service",
            "All records, transcripts, photos, summaries and insights you create in the app stay on your iPhone by default",
            "EurekaLife does not operate a cloud service that receives, hosts or syncs personal records",
            "Only when you actively connect ChatGPT", "audio and photos are not sent to external AI",
        ):
            with self.subTest(required=required):
                self.assertIn(required, html)

    def test_terms_page_describes_limits_and_purchase(self):
        page = PROTOTYPE / "terms" / "index.html"
        self.assertTrue(page.is_file(), "terms page must exist at /terms")
        html = page.read_text(encoding="utf-8")
        for required in (
            "Terms of Service", "AI results", "medical", "recording", "App Store", "hello@wiselife.cloud",
            "EurekaLife App does not provide a cloud service", "does not receive or host this content",
        ):
            with self.subTest(required=required):
                self.assertIn(required, html)

    def test_homepage_links_to_policy_pages(self):
        html = (PROTOTYPE / "iphone-day.html").read_text(encoding="utf-8")
        self.assertIn('href="privacy/"', html)
        self.assertIn('href="terms/"', html)
        self.assertIn("EurekaLife App 不提供云端服务", html)
        self.assertIn("你在 App 中创建的所有记录、转写、照片、总结和洞察默认保存在 iPhone 本机", html)
        self.assertIn("Apple Watch 录音会传回配对 iPhone 后保存", html)
        self.assertNotIn("是否使用云端、交给哪一个服务", html)
        self.assertNotIn("不依赖自建服务器", html)

    def test_cloud_service_promise_is_localized(self):
        story_copy = (PROTOTYPE / "wiselife-story-locales.js").read_text(encoding="utf-8")
        site_copy = (PROTOTYPE / "wiselife-site-locales.js").read_text(encoding="utf-8")
        for required in (
            "EurekaLife has no cloud service; your daily records stay on your phone.",
            "EurekaLife はクラウドサービスを提供しません。日々の記録はスマートフォンに保存されます。",
        ):
            with self.subTest(required=required):
                self.assertIn(required, story_copy)
        for required in (
            "All records, transcripts, photos, summaries and insights stay on your iPhone by default.",
            "すべての記録、文字起こし、写真、要約、インサイトは通常 iPhone 本体に保存されます。",
        ):
            with self.subTest(required=required):
                self.assertIn(required, site_copy)


if __name__ == "__main__":
    unittest.main()
