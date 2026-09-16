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

class SimpleHandler(BaseHTTPRequestHandler):
    dbconn = None
    dbcursor = None
    waiting_mode = False
    batch = []

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
    # 1. Start HTTP server immediately
    server = HTTPServer(('0.0.0.0', int(LISTEN_PORT)), SimpleHandler)
    server_thread = Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    connect_to_db()
    server_thread.join()