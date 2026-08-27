import os
import sys
import requests
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

api_key = os.getenv("APISPORTS_API_KEY")

headers = {
    "x-apisports-key": api_key or ""
}

def check_status():
    url = "https://v1.rugby.api-sports.io/status"
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            errors = data.get("errors")
            if errors:
                print("API Key verification failed (API returned errors):")
                print(errors)
                return False
            
            account_info = data.get("response", {})
            print("✓ API Key is VALID!")
            print(f"Account Email: {account_info.get('account', {}).get('email', 'N/A')}")
            print(f"Subscription: {account_info.get('subscription', {}).get('plan', 'N/A')}")
            print(f"Daily Requests Limit: {account_info.get('requests', {}).get('limit_day', 0)}")
            print(f"Requests remaining today: {account_info.get('requests', {}).get('limit_day', 0) - account_info.get('requests', {}).get('current', 0)}")
            return True
        else:
            print(f"API Key verification failed with Status Code {response.status_code}")
            return False
    except Exception as e:
        print(f"Network error verifying key: {e}")
        return False

def check_leagues():
    url = "https://v1.rugby.api-sports.io/leagues"
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            data = response.json()
            leagues = data.get("response", [])
            print(f"\nTotal Leagues Found: {len(leagues)}")
            
            print("\nEnglish Rugby Union Leagues Covered:")
            england_leagues = [l for l in leagues if l.get("country", {}).get("name") == "England"]
            
            if england_leagues:
                for idx, league in enumerate(england_leagues, start=1):
                    l_info = league.get("league", {})
                    print(f"{idx}. {l_info.get('name')} (ID: {l_info.get('id')}) - Type: {l_info.get('type')}")
            else:
                print("No leagues found for England.")
        else:
            print(f"Failed to fetch leagues (Status Code {response.status_code})")
    except Exception as e:
        print(f"Error fetching leagues: {e}")

if __name__ == "__main__":
    print("Testing api-sports.io API Key...")
    if not api_key:
        print("Error: APISPORTS_API_KEY is not defined in the environment or .env file.")
        sys.exit(1)
    if check_status():
        check_leagues()
