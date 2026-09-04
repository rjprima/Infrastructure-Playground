import urllib.request
import json
import os

command = ""

url = os.environ.get('NGINX_ROUTE_URL')

batch = []

headers = {
    "Content-Type": "application/json",
    "User-Agent": "NativePythonApp/1.0"
}

while command != "2":
    print("1. input from file\n2. quit")
    command = input()
    if command == "1":
        print("please input absolute file path")
        path = input()
        with open(path) as f:
            for i in f:
                line = i.strip()
                batch.append(line)
                if len(batch) == 10:
                    payload = {"exprs": batch}
                    encoded_data = json.dumps(payload).encode('utf-8')
                    req = urllib.request.Request(url, data=encoded_data, headers=headers, method="POST")
                    urllib.request.urlopen(req, timeout=5)
    else:
        print("invalid command")