import os
import requests
from dotenv import load_dotenv

load_dotenv()

def extract_articles():
    url = ('https://newsapi.org/v2/everything?'
            'q=Apple&'
            'from=2026-06-10&to=2026-06-11&'
            'sortBy=popularity&'
            f'apiKey={os.getenv('NEWS_API_KEY')}')

    response = requests.get(url)

    data =  response.json()

    articles = data['articles']

    return articles