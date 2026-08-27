import requests
import re
from bs4 import BeautifulSoup

def main():
    content = open('tests/sample_data/counties1_live_check.html', encoding='utf-8').read()
    soup = BeautifulSoup(content, 'html.parser')
    scripts = [s.get('src') for s in soup.find_all('script') if s.get('src')]
    print('Total scripts:', len(scripts))
    for src in scripts:
        if 'fixtures' in src or 'search' in src or 'main' in src or 'theme' in src:
            url = src if src.startswith('http') else 'https://www.englandrugby.com' + src
            try:
                r = requests.get(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'}, timeout=10)
                if 'f_r_search' in r.text or 'autocomplete' in r.text or 'suggest' in r.text:
                    print('Found keywords in script:', url)
                    # Let's search for endpoint URLs or query parameters
                    endpoints = re.findall(r'\"(/[^\"]+)\"|\'(/[^\']+)\'', r.text)
                    for e in endpoints[:20]:
                        val = e[0] or e[1]
                        if 'api' in val or 'search' in val or 'suggest' in val:
                            print('  Endpoint candidate:', val)
            except Exception as e:
                print('Error fetching script:', url, e)

if __name__ == '__main__':
    main()
