from http.server import HTTPServer, BaseHTTPRequestHandler
import os
import psycopg2
from psycopg2.extras import execute_batch
import json
from algos import *
import time
from threading import Thread
import random

POSTGRES_CONT_NAME = os.environ.get("POSTGRES_CONT_NAME")
POSTGRES_PORT = os.environ.get("POSTGRES_PORT")
PASSWORD = os.environ.get("POSTGRES_PASSWORD")
LISTEN_PORT = os.environ.get("PORT")
USER = os.environ.get("USER")

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
    dbconn = None
    dbcursor = None
    waiting_mode = False
    batch = []
    health_endpoint = HealthEndpoint()

    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        data = json.loads(body)
        query = '''
        INSERT INTO solved (expr, simplified)
        VALUES (%s, %s);
        '''

        if data.get("purpose") == "pause":
            SimpleHandler.dbconn = None
            SimpleHandler.dbcursor = None
            SimpleHandler.waiting_mode = True

            response_data = json.dumps({"status": "success"}).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response_data)))
            self.end_headers()
            self.wfile.write(response_data)

        elif data.get("purpose") == "restore":

            response_data = json.dumps({"status": "success"}).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response_data)))
            self.end_headers()
            self.wfile.write(response_data)
            
            connect_to_db()
            time.sleep(random.randint(1,10)/1000)
            if len(SimpleHandler.batch) != 0:
                execute_batch(SimpleHandler.dbcursor, query, SimpleHandler.batch)
                SimpleHandler.dbconn.commit()
                SimpleHandler.batch = []

        elif data.get("purpose") == "expr_batch" and SimpleHandler.dbconn != None and SimpleHandler.dbcursor != None:
            exprs = data.get("exprs")

            for i in range(len(exprs)):
                solved = evaluate(exprs[i])
                SimpleHandler.batch.append((exprs[i], solved))

            if SimpleHandler.waiting_mode == False:
                execute_batch(SimpleHandler.dbcursor, query, SimpleHandler.batch)
                SimpleHandler.dbconn.commit()
                SimpleHandler.batch = []

            response_data = json.dumps({"status": "success"}).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response_data)))
            self.end_headers()
            self.wfile.write(response_data)

        else:
            response_data = json.dumps({"status": "failure"}).encode('utf-8')
            self.send_response(503)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response_data)))
            self.end_headers()
            self.wfile.write(response_data)

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

def connect_to_db():
    backoff = 1

    while backoff < 65:
        time.sleep(backoff)
        try: 
            conn = psycopg2.connect(
                host=POSTGRES_CONT_NAME, 
                port=POSTGRES_PORT,
                user=USER,
                password=PASSWORD,
                dbname="simplified_expressions"
            )
        except:
            backoff *= 2
            if backoff >= 65:
                raise RuntimeError("connection to database could not be made")
        else:
            print("successfully connected")
            break

    SimpleHandler.dbconn = conn
    SimpleHandler.dbcursor = conn.cursor()

if __name__ == "__main__":
    server = HTTPServer(('0.0.0.0', int(LISTEN_PORT)), SimpleHandler)
    server_thread = Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    connect_to_db()
    server_thread.join()