from extract import extract_prices
from transform import transform_data
from load import load_prices

def main():
    gas_data = extract_prices()
    gas_df = transform_data(gas_data)
    load_prices(gas_df)
    print("ETL process complete")

if __name__ == "__main__":
    main()
