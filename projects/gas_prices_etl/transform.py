import pandas as pd

def transform_data(gas_data):
    gas_df = pd.DataFrame(gas_data)

    # drop lowername
    gas_df=gas_df.drop(columns=["lowername"])

    # name to cities
    gas_df.rename(columns={"name": "cities"}, inplace=True)

    return gas_df

