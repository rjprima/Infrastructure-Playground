from http.server import HTTPServer, BaseHTTPRequestHandler
import os
import psycopg2
from psycopg2.extras import execute_batch
import json
from algos import *
import time
from threading import Thread

POSTGRES_CONT_NAME = os.environ.get("POSTGRES_CONT_NAME")
POSTGRES_PORT = os.environ.get("POSTGRES_PORT")
PASSWORD = os.environ.get("POSTGRES_PASSWORD")
LISTEN_PORT = os.environ.get("PORT")
USER = os.environ.get("USER")

class SimpleHandler(BaseHTTPRequestHandler):
    dbconn = None
    dbcursor = None

    def do_POST(self):
        if SimpleHandler.dbconn != None and SimpleHandler.dbcursor != None:
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            data = json.loads(body)
            exprs = data.get("exprs")
            batch = []
            query = '''
            INSERT INTO solved (expr, simplified)
            VALUES (%s, %s);
            '''

            for i in range(len(exprs)):
                solved = evaluate(exprs[i])
                batch.append((exprs[i], solved))

            execute_batch(SimpleHandler.dbcursor, query, batch)
            SimpleHandler.dbconn.commit()

            response_data = json.dumps({"status": "success"}).encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response_data)))
            self.end_headers()
        else:
            response_data = json.dumps({"status": "failure"}).encode('utf-8')
            self.send_response(503)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(response_data)))
            self.end_headers()

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
            break

    SimpleHandler.dbconn = conn
    SimpleHandler.dbcursor = conn.cursor()

if __name__ == "__main__":
    # 1. Start HTTP server immediately
    server = HTTPServer(('0.0.0.0', int(LISTEN_PORT)), SimpleHandler)
    server_thread = Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    connect_to_db()
    server_thread.join()