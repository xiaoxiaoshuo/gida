#!/usr/bin/env python3
"""
Test Bing search for cryptocurrency prices
"""

import re
from openclaw.tools import web_fetch

def extract_price_from_bing(content, symbol):
    """Extract price from Bing search results"""
    # Look for price patterns in the content
    # Common patterns: $70,762.00, $70762, 70,762.00 USD, etc.
    price_patterns = [
        r'\$([\d,]+\.?\d*)',  # $70,762.00 or $70762
        r'([\d,]+\.?\d*)\s*USD',  # 70,762.00 USD
        r'USD\s*([\d,]+\.?\d*)',  # USD 70,762.00
    ]
    
    for pattern in price_patterns:
        matches = re.findall(pattern, content)
        if matches:
            for match in matches:
                # Clean the price string
                price_str = match.replace(',', '')
                try:
                    price = float(price_str)
                    # Validate reasonable ranges for different symbols
                    if symbol == 'BTC' and 50000 <= price <= 100000:
                        return price
                    elif symbol == 'ETH' and 1000 <= price <= 5000:
                        return price
                    elif symbol == 'SOL' and 50 <= price <= 200:
                        return price
                    elif symbol == 'GOLD' and 1500 <= price <= 10000:
                        return price
                    elif symbol == 'OIL' and 40 <= price <= 200:
                        return price
                except ValueError:
                    continue
    
    return None

def test_bing_search():
    """Test Bing search for various assets"""
    test_cases = [
        ('BTC', 'bitcoin price usd today'),
        ('ETH', 'ethereum price usd today'),
        ('SOL', 'solana sol crypto price usd'),
        ('GOLD', 'gold price usd today'),
        ('OIL', 'crude oil price usd today'),
    ]
    
    for symbol, query in test_cases:
        print(f"\n=== Testing {symbol} ===")
        url = f'https://cn.bing.com/search?q={query}'
        
        try:
            result = web_fetch(url, maxChars=5000)
            if result.get('status') == 200:
                content = result.get('text', '')
                price = extract_price_from_bing(content, symbol)
                
                if price:
                    print(f"✓ {symbol}: ${price}")
                else:
                    print(f"✗ {symbol}: Could not extract price")
                    # Show a snippet of the content for debugging
                    print(f"Content preview: {content[:500]}...")
            else:
                print(f"✗ {symbol}: HTTP {result.get('status')}")
        except Exception as e:
            print(f"✗ {symbol}: Error - {e}")

if __name__ == "__main__":
    test_bing_search()