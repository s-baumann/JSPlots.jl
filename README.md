# PivotTable

This is a wrapper over PivotTableJS. You can use it to embed your data into a html page. Once in there you can visualise the data like a pivottable. You can see examples here https://pivottable.js.org/examples/index.html.

The functionality is quite similar to the [python module](https://pypi.org/project/pivottablejs/). One change is that it is possible to put multiple different tables onto the same page (either sharing or not sharing data sources). It is also easy to change the colour mapping for use in HeatMap.

As an example see the following. This produces the file pivottable.html

```

using PivotTables, DataFrames, Dates

stockReturns = DataFrame(
    Symbol = ["RTX", "RTX", "RTX", "GOOG", "GOOG", "GOOG", "MSFT", "MSFT", "MSFT"],
    Date = Date.(["2023-01-01", "2023-01-02", "2023-01-03", "2023-01-01", "2023-01-02", "2023-01-03", "2023-01-01", "2023-01-02", "2023-01-03"]),
    Return = [10.01, -10.005, -0.5, 1.0, 0.01, -0.003, 0.008, 0.004, -0.002]
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

subframe = allcombinations(DataFrame, x = collect(1:6), y = collect(1:6)); subframe[!, :group] .= "A";
sf2 = deepcopy(subframe); sf2[!, :group] .= "B"
subframe[!, :z] = cos.(sqrt.(subframe.x .^ 2 .+  subframe.y .^ 2))
sf2[!, :z] = cos.(sqrt.(sf2.x .^ 2 .+  sf2.y .^ 1)) .- 1.0
subframe = vcat(subframe, sf2)

pt3 = PThreeDChart(:threeD, :subframe;
        x_col = :x,
        y_col = :y,
        z_col = :z,
        group_col = :group,
        title = "3D Surface Chart of shapes",
        x_label = "X directions",
        y_label = "Y dim",
        z_label = "Z directions",
        notes = "This is a 3D surface chart."
    )


df1 = DataFrame(
    date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
    x = 1:10,
    y = rand(10),
    color = [:A, :B, :A, :B, :A, :B, :A, :B, :A, :B]
)
df1[!, :categ] .=  [ :B, :B, :B, :B, :B, :A, :A, :A, :A, :C]
df1[!, :categ22] .= "Category_A"

df2 = DataFrame(
    date = Date(2024, 1, 1):Day(1):Date(2024, 1, 10),
    x = 1:10,
    y = rand(10),
    color = [:A, :B, :A, :B, :A, :B, :A, :B, :A, :B]
)
df2[!, :categ] .= [:A, :A, :A, :A, :A, :B, :B, :B, :B, :C]
df2[!, :categ22] .= "Category_B"
df = vcat(df1, df2)

pt00 = PChart(:pchart, df, :df;
            x_col=:x,
            y_col=:y,
            color_col=:color,
            filters=Dict(:categ => :A, :categ22 => "Category_A"),
            title="Line Chart",
            x_label="This is the x axis",
            y_label="This is the y axis")


# To plot both of these together we can do:
pge = PivotTablePage(Dict{Symbol,DataFrame}(:stockReturns => stockReturns, :correlations => correlations, :subframe => subframe, :df => df), [pt, pt00, pt2, pt3])
create_html(pge,"pivottable.html")


# Or if you are only charting one single pivottable you dont have to make a PivotTablePage, you can simply do:
create_html(pt, stockReturns, "only_one.html")


```


