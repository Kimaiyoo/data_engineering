import os
import requests
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine

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

def transform_articles(articles):
    articles_df = pd.DataFrame(articles)
    articles_df.drop(columns={'source','urlToImage'}, inplace=True)

    return articles_df

def load_articles(articles_df):

    DB_HOST = os.getenv('DB_HOST')
    DB_PORT = os.getenv('DB_PORT')
    DB_NAME = os.getenv('DB_NAME')
    DB_USER = os.getenv('DB_USER')
    DB_PASS = os.getenv('DB_PASS')

    engine = create_engine(f'postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}')

    articles_df.to_sql('articles', con= engine, if_exists='replace', index=False)

def main():
    articles = extract_articles()
    articles_df = transform_articles(articles)
    load_articles(articles_df)
    print('ETL process completed successfully')


if __name__ == "__main__"  :
    main()

