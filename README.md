# PivotTable

This is a wrapper over PivotTableJS. You can use it to embed your data into a html page. Once in there you can visualise the data like a pivottable. You can see examples here https://pivottable.js.org/examples/index.html.

The functionality is quite similar to the python module. One change is that it is possible to put multiple different tables onto the same page (either sharing or not sharing data sources). It is also easy to change the colour mapping for use in HeatMap.

As an example see the following. This produces the file pivottable.html

```

using PivotTables, DataFrames, Dates

stockReturns = DataFrame(
    Symbol = ["RTX", "RTX", "RTX", "GOOG", "GOOG", "GOOG", "MSFT", "MSFT", "MSFT"],
    Date = Date.(["2023-01-01", "2023-01-02", "2023-01-03", "2023-01-01", "2023-01-02", "2023-01-03", "2023-01-01", "2023-01-02", "2023-01-03"]),
    Return = [0.01, -0.005, 0.002, 0.015, 0.01, -0.003, 0.008, 0.004, -0.002]
)   

correlations = DataFrame(
    Symbol1 = ["RTX", "RTX", "GOOG", "RTX", "GOOG", "MSFT", "GOOG", "MSFT", "MSFT",],
    Symbol2 = ["GOOG", "MSFT", "MSFT", "RTX", "GOOG", "MSFT", "RTX", "RTX", "GOOG",],
    Correlation = [-0.85, -0.75, 0.80, 1.0, 1.0, 1.0, -0.85, -0.75, 0.80]
)

exclusions = Dict(
    :Symbol => [:MSFT]
)


pt = PivotTable(:Returns_Over_Last_Few_Days, :stockReturns;
    rows = [:Symbol],
    cols = [:Date],
    vals = :Return,
    exclusions = exclusions,
    colour_map = Dict{Float64,String}([-0.05, 0.0, 0.05] .=> ["#9e0303", "#ffffff", "#00e32d"]),
    aggregatorName = :Average,
    rendererName = :Heatmap
)

pt2 = PivotTable(:Correlation_Matrix, :correlations;
    rows = [:Symbol1],
    cols = [:Symbol2],
    vals = :Correlation,
    colour_map = Dict{Float64,String}([-1.0, 0.0, 1.0] .=> ["#FF4545", "#ffffff", "#4F92FF"]),
    aggregatorName = :Average,
    rendererName = :Heatmap
)

pge = PivotTablePage(Dict{Symbol,DataFrame}(:stockReturns => stockReturns, :correlations => correlations), [pt, pt2])
create_pivot_table_html(pge,"pivottable.html")

```


