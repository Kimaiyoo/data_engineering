import pandas as pd

def transform_articles(articles):
    articles_df = pd.DataFrame(articles)
    articles_df.drop(columns={'source','urlToImage'}, inplace=True)

    return articles_df