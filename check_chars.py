import sys

file_path = r'c:\Antigravity\ByteCity App\bytecity_accounting\lib\core\constants\api_constants.dart'
try:
    with open(file_path, 'rb') as f:
        content = f.read()
        print(f"File size: {len(content)} bytes")
        print("Raw bytes around baseUrl:")
        # Look for the URL part
        search_term = b'AKfy'
        idx = content.find(search_term)
        if idx != -1:
            start = max(0, idx - 20)
            end = min(len(content), idx + 100)
            print(content[start:end])
            
            # Check for spaces or non-ascii
            url_segment = content[idx:idx+80]
            print(f"URL segment: {url_segment}")
            if b' ' in url_segment:
                print("!!! SPACE DETECTED IN URL ID !!!")
            for b in url_segment:
                if b < 32 or b > 126:
                    print(f"!!! HIDDEN/NON-ASCII CHAR DETECTED: {b} !!!")
        else:
            print("Could not find AKfy in file.")
except Exception as e:
    print(f"Error: {e}")
