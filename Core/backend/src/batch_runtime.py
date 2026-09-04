from http.server import HTTPServer, BaseHTTPRequestHandler
import os
import psycopg2
from psycopg2.extras import execute_batch
import json
from algos import *

POSTGRES_CONT_NAME = os.environ.get("POSTGRES_CONT_NAME")
POSTGRES_PORT = os.environ.get("POSTGRES_PORT")

conn = psycopg2.connect(
    host="POSTGRES_CONT_NAME", 
    port=POSTGRES_PORT,
    user="postgres",
    password="PASSWORD",
    dbname="postgres"
)

cursor = conn.cursor()

class SimpleHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        data = json.loads(body)
        exprs = data.get("exprs")
        batch = []
        query = '''
        INSERT INTO solved (expr, simplified)
        VALUES (%s, %s);
        '''

        for i in len(exprs):
            solved = evaluate(exprs[i])
            batch.append((exprs[i], solved))

        execute_batch(cursor, query, batch)
        conn.commit()
        
        self.send_response(200)
        self.end_headers()
        

server = HTTPServer(('0.0.0.0', 3000), SimpleHandler)
server.serve_forever()