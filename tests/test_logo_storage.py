import pytest
from rfu_parser.logo_storage import CustomLogoStorage

def test_custom_logo_crud():
    team_name = "Test Chiefs RFC"
    test_bytes = b"fake_png_data"
    
    # 1. Save logo
    url = CustomLogoStorage.save_logo(team_name, test_bytes, "logo.png")
    assert url is not None
    assert "/api/logos/" in url

    # 2. Retrieve logo
    retrieved_url = CustomLogoStorage.get_logo_for_team("Test Chiefs")
    assert retrieved_url == url

    # 3. Delete logo
    success = CustomLogoStorage.delete_logo("Test Chiefs")
    assert success is True

    # 4. Confirm deleted
    assert CustomLogoStorage.get_logo_for_team("Test Chiefs") is None
