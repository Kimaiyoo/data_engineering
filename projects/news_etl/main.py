from extract import extract_articles
from transform import transform_articles
from load import load_articles

def main():
    articles = extract_articles()
    articles_df = transform_articles(articles)
    load_articles(articles_df)
    print('ETL process completed successfully')


if __name__ == "__main__"  :
    main()
