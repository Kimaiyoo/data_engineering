# JSON to CSV Data Pipeline
## Goal
The goal of this project is to extract nested JSON data from web URLs and REST APIs, and transform it into clean, flat CSV files that are ready for data analysis.

## Workflow
The project follows a straightforward, four-step data processing pipeline:

1. **Extraction**: Fetch raw JSON data from web endpoints using HTTP requests.

2. **Parsing**: Convert the JSON response into native Python lists and dictionaries.

3. **Structuring**: Load the parsed data into a Pandas DataFrame. Use normalization and explosion techniques to flatten nested dictionaries (like metadata) and unpack nested arrays (like product lists or reviews).

4. **Export**: Save the final, structured DataFrame as a .csv file.

## Data Resources
The pipeline processes data from two distinct sources to handle different JSON structures:

- **Synthetic Data**: A custom JSON dataset generated using [Mockaroo](https://mockaroo.com/) and accessed via a raw GitHub URL.

- **Live API Data**: Deeply nested JSON data fetched from the [DummyJSON API](https://dummyjson.com) (specifically the `/products` and `/carts ` endpoints).

## Tech Stack
- Python 

- Pandas (For data structuring, flattening and DataFrame manipulation)

- Requests (For fetching JSON data over the web)