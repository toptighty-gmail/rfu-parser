from types import SimpleNamespace

import pytest

from rfu_parser.lineup_sync import LineupSync, RfuBlocked, SupabaseRest

WAF_CHALLENGE = "<html><script>window.awsWafCookieDomainList = ['www.englandrugby.com'];</script></html>"


class FakeRfu:
    def __init__(self, status, text):
        self.response = SimpleNamespace(status_code=status, text=text, raise_for_status=lambda: None)

    def get(self, url, timeout):
        return self.response


def make_sync(status, text):
    sync = LineupSync(SupabaseRest("https://example.supabase.co", "eyJtest", dry_run=True),
                      delay=0, recheck_days=0, refresh=False, limit=None)
    sync.rfu = FakeRfu(status, text)
    return sync


@pytest.mark.parametrize("status,text", [(202, WAF_CHALLENGE), (200, WAF_CHALLENGE), (429, "Too Many Requests")])
def test_fetch_raises_on_rfu_challenge(status, text):
    with pytest.raises(RfuBlocked):
        make_sync(status, text).fetch("https://www.englandrugby.com/fixtures-and-results")


def test_fetch_returns_normal_page():
    assert make_sync(200, "<html>fixtures</html>").fetch("https://www.englandrugby.com/x") == "<html>fixtures</html>"


def test_secret_keys_are_not_sent_as_bearer_tokens():
    assert "Authorization" not in SupabaseRest("https://x.supabase.co", "sb_secret_abc").headers
    assert SupabaseRest("https://x.supabase.co", "eyJabc").headers["Authorization"] == "Bearer eyJabc"
