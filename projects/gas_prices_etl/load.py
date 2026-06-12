import os
from dotenv import load_dotenv
from sqlalchemy import create_engine,text

load_dotenv()

def load_prices(gas_df):
    DB_HOST = os.getenv('DB_HOST')
    DB_PORT = os.getenv('DB_PORT')
    DB_NAME = os.getenv('DB_NAME')
    DB_USER = os.getenv('DB_USER')
    DB_PASS = os.getenv('DB_PASS')

    engine = create_engine(f'postgresql+psycopg2://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}')

    with engine.connect() as conn:
            result = conn.execute(text('select 1;'))
            for i in result:
                print(i)

    gas_df.to_sql('gas_prices1',  engine, schema='public', if_exists='replace', index=False)