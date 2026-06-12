import os
import json
from dotenv import load_dotenv
import http.client

load_dotenv()

conn = http.client.HTTPSConnection("api.collectapi.com")

def extract_prices():
    headers = {
        'content-type': "application/json",
        'authorization': os.getenv('API_KEY')
        }

    conn.request("GET", "/gasPrice/stateUsaPrice?state=WA", headers=headers)

    res = conn.getresponse()
    data = res.read()

    # str to dict
    data = json.loads(data)

    gas_data = data['result']['cities']

    return gas_data
