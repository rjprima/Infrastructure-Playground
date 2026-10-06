import urllib.request
import json
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread

HEALTH_PORT = os.environ.get("HEALTH_PORT")

class HealthEndpoint:
    def __init__(self):
        self.is_v2 = os.path.exists('/sys/fs/cgroup/cgroup.controllers')

    def get_memory_usage(self) -> int:
        try:
            if self.is_v2:
                path = '/sys/fs/cgroup/memory.current'
            else:
                path = '/sys/fs/cgroup/memory/memory.usage_in_bytes'

            with open(path, 'r') as f:
                return int(f.read().strip())
        except (FileNotFoundError, ValueError):
            return 0

    def get_cpu_util(self) -> float:
        try:
            if self.is_v2:
                with open('/sys/fs/cgroup/cpu.stat', 'r') as f:
                    for line in f:
                        if line.startswith('usage_usec'):
                            microseconds = int(line.split()[1])
                            return microseconds / 1_000_000.0
            else:
                with open('/sys/fs/cgroup/cpu/cpuacct.usage', 'r') as f:
                    nanoseconds = int(f.read().strip())
                    return nanoseconds / 1_000_000_000.0
        except (FileNotFoundError, ValueError):
            return 0.0

class SimpleHandler(BaseHTTPRequestHandler):
    health_endpoint = HealthEndpoint()
    def do_GET(self):
        memory_usage = SimpleHandler.health_endpoint.get_memory_usage()
        cpu_util = SimpleHandler.health_endpoint.get_cpu_util()

        response = (
            f'# HELP app_memory_usage_bytes Current memory usage in bytes\n'
            f'# TYPE app_memory_usage_bytes gauge\n'
            f'app_memory_usage_bytes {memory_usage}\n\n'
            f'# HELP app_cpu_usage_seconds_total Total cumulative CPU time spent in'
            f' seconds\n'
            f'# TYPE app_cpu_usage_seconds_total counter\n'
            f'app_cpu_usage_seconds_total {cpu_util}\n'
        )

        self.send_response(200)
        self.send_header('Content-Type', 'text/plain; version=0.0.4; charset=utf-8')
        self.send_header('Content-Length', str(len(response.encode('utf-8'))))
        self.end_headers()
        self.wfile.write(response.encode("utf-8"))

command = ""

url = "http://" + os.environ.get('NGINX_CONT_NAME') + ":" + os.environ.get('NGINX_PORT')

batch = []

headers = {
    "Content-Type": "application/json",
    "User-Agent": "NativePythonApp/1.0"
}

if __name__ == "__main__":
    HTTPServer.allow_reuse_address = True
    server = HTTPServer(('0.0.0.0', int(HEALTH_PORT)), SimpleHandler)
    server_thread = Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
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
                        payload = {"purpose":"expr_batch", "exprs": batch}
                        encoded_data = json.dumps(payload).encode('utf-8')
                        req = urllib.request.Request(url, data=encoded_data, headers=headers, method="POST")
                        urllib.request.urlopen(req, timeout=5)
                        batch = []
                if len(batch) != 0:
                    payload = {"purpose":"expr_batch", "exprs": batch}
                    encoded_data = json.dumps(payload).encode('utf-8')
                    req = urllib.request.Request(url, data=encoded_data, headers=headers, method="POST")
                    urllib.request.urlopen(req, timeout=5)
                    batch = []
        else:
            print("invalid command")