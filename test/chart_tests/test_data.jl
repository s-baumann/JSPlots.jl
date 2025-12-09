# Shared test data used across multiple test files
using DataFrames, Dates

# Create test data
test_df = DataFrame(
    x = 1:10,
    y = rand(10),
    category = repeat(["A", "B"], 5),
    color = repeat(["Red", "Blue"], 5),
    date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10)
)

test_df_with_symbols = DataFrame(
    x = 1:5,
    y = rand(5),
    symbol_col = [:A, :B, :C, :D, :E]
)

test_df_with_missing = DataFrame(
    x = [1, 2, 3, missing, 5],
    y = [1.0, missing, 3.0, 4.0, 5.0],
    category = ["A", "B", missing, "D", "E"]
)
