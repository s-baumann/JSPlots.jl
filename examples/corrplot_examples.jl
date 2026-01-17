using JSPlots, DataFrames, StableRNGs, Statistics

rng = StableRNG(777)

println("Creating CorrPlot examples...")

# Prepare header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/corrplot_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>CorrPlot (Correlation Plot with Dendrogram) Examples</h1>
<p>This page demonstrates the interactive CorrPlot chart type in JSPlots.</p>
<ul>
    <li><strong>Browser-based hierarchical clustering:</strong> Dendrogram computed dynamically in your browser</li>
    <li><strong>Dual correlation display:</strong> Pearson (upper right) and Spearman (lower left) correlations in one matrix</li>
    <li><strong>Julia-computed correlations:</strong> Use compute_correlations() and prepare_corrplot_data() convenience functions</li>
    <li><strong>Flexible clustering:</strong> Choose linkage method (Ward, Average, Single, Complete) in browser</li>
    <li><strong>Automatic ordering:</strong> Variables reordered by clustering for clearer patterns</li>
    <li><strong>Works with subsets:</strong> Dendrogram updates dynamically when you select a subset of variables</li>
</ul>
""")

# =============================================================================
# Example 1: Financial Metrics Correlation
# =============================================================================

example1_text = TextBlock("""
<h2>Example 1: Financial Metrics Correlation Analysis</h2>
<p>Analyze correlations between various financial metrics for companies.</p>
<p>This example demonstrates:</p>
<ul>
    <li>10 financial metrics tracked for 100 companies</li>
    <li>Computing both Pearson and Spearman correlations in Julia</li>
    <li>Hierarchical clustering with Ward linkage</li>
    <li>Compare Pearson vs Spearman correlations to detect non-linear relationships</li>
    <li>Variables automatically reordered by clustering to reveal patterns</li>
</ul>
""")

# Generate synthetic financial data
n_companies = 100
industries = ["Technology", "Healthcare", "Finance", "Manufacturing", "Retail"]
sizes = ["Small", "Medium", "Large"]

financial_data_rows = []

for company_id in 1:n_companies
    industry = rand(rng, industries)
    size = rand(rng, sizes)

    # Base metrics with correlations built in
    revenue = Float64(rand(rng, 100:10000))
    profit_margin = rand(rng, 0.05:0.001:0.30)
    profit = revenue * profit_margin

    # Operating metrics
    roa = profit_margin * rand(rng, 0.5:0.01:1.5)  # Return on Assets
    roe = roa * rand(rng, 1.2:0.01:2.5)  # Return on Equity (levered)
    debt_to_equity = rand(rng, 0.1:0.01:2.0)

    # Valuation metrics
    pe_ratio = rand(rng, 8:0.1:40)
    price_to_book = roe * pe_ratio / 15 * rand(rng, 0.7:0.01:1.3)

    # Efficiency metrics
    asset_turnover = revenue / (revenue * rand(rng, 0.3:0.01:1.5))
    inventory_turnover = rand(rng, 2:0.1:15)

    push!(financial_data_rows, (
        company_id = company_id,
        industry = industry,
        size = size,
        revenue = revenue,
        profit = profit,
        profit_margin = profit_margin * 100,  # Convert to percentage
        roa = roa * 100,
        roe = roe * 100,
        debt_to_equity = debt_to_equity,
        pe_ratio = pe_ratio,
        price_to_book = price_to_book,
        asset_turnover = asset_turnover,
        inventory_turnover = inventory_turnover
    ))
end

df_financial = DataFrame(financial_data_rows)

# Compute correlations for financial metrics
financial_vars = [:revenue, :profit, :profit_margin, :roa, :roe,
                  :debt_to_equity, :pe_ratio, :price_to_book,
                  :asset_turnover, :inventory_turnover]
cors1 = compute_correlations(df_financial, financial_vars)

# Prepare correlation data for CorrPlot
corr_data1 = prepare_corrplot_data(cors1.pearson, cors1.spearman, string.(financial_vars))

# Create correlation plot
corrplot1 = CorrPlot(:financial_corr, corr_data1, :financial_corr_data;
    title = "Financial Metrics Correlation Analysis",
    notes = "This correlation plot shows relationships between financial metrics. The dendrogram groups similar metrics based on correlation patterns using hierarchical clustering performed in your browser. Variables are automatically reordered by clustering to reveal correlation blocks. Top-right triangle shows Pearson correlations (linear relationships), while bottom-left shows Spearman correlations (rank-based, captures non-linear monotonic relationships). <strong>Try this:</strong> Change the clustering linkage method (Ward/Average/Single/Complete) to see different groupings, or select a subset of variables to see how the dendrogram updates dynamically."
)

# =============================================================================
# Example 2: Sales Performance Metrics
# =============================================================================

example2_text = TextBlock("""
<h2>Example 2: Sales Performance Metrics</h2>
<p>Examine correlations between sales KPIs using average linkage clustering.</p>
<p>Features:</p>
<ul>
    <li>Multiple sales metrics: revenue, units, conversion rate, customer satisfaction, etc.</li>
    <li>Average linkage clustering (different from Ward linkage in Example 1)</li>
    <li>Identify which metrics move together</li>
    <li>Detect leading indicators through correlation patterns</li>
</ul>
""")

# Generate sales performance data
n_observations = 200
regions = ["North", "South", "East", "West"]
quarters = ["Q1", "Q2", "Q3", "Q4"]

sales_data_rows = []

for obs_id in 1:n_observations
    region = rand(rng, regions)
    quarter = rand(rng, quarters)

    # Correlated metrics
    leads = Float64(rand(rng, 50:500))
    conversion_rate = rand(rng, 0.10:0.001:0.40)
    units_sold = leads * conversion_rate * rand(rng, 0.8:0.01:1.2)
    avg_deal_size = Float64(rand(rng, 1000:100:8000))
    revenue = units_sold * avg_deal_size

    # Service metrics (partially correlated)
    customer_satisfaction = rand(rng, 3.0:0.1:5.0)
    response_time = 24 * (6 - customer_satisfaction) * rand(rng, 0.5:0.01:1.5)  # hours

    # Marketing metrics
    marketing_spend = revenue * rand(rng, 0.05:0.001:0.20)
    cac = marketing_spend / max(units_sold, 1)  # Customer acquisition cost

    # Operational metrics
    inventory_level = units_sold * rand(rng, 1.5:0.1:4.0)
    days_to_close = 30 * (1 / conversion_rate) * rand(rng, 0.01:0.001:0.03)

    push!(sales_data_rows, (
        observation_id = obs_id,
        region = region,
        quarter = quarter,
        leads = leads,
        conversion_rate = conversion_rate * 100,
        units_sold = units_sold,
        avg_deal_size = avg_deal_size,
        revenue = revenue,
        customer_satisfaction = customer_satisfaction,
        response_time_hours = response_time,
        marketing_spend = marketing_spend,
        cac = cac,
        inventory_level = inventory_level,
        days_to_close = days_to_close
    ))
end

df_sales = DataFrame(sales_data_rows)

# Compute correlations for sales metrics
sales_vars = [:leads, :conversion_rate, :units_sold, :avg_deal_size, :revenue,
              :customer_satisfaction, :response_time_hours, :marketing_spend,
              :cac, :inventory_level, :days_to_close]
cors2 = compute_correlations(df_sales, sales_vars)

# Prepare correlation data for CorrPlot
corr_data2 = prepare_corrplot_data(cors2.pearson, cors2.spearman, string.(sales_vars))

# Create correlation plot
corrplot2 = CorrPlot(:sales_corr, corr_data2, :sales_corr_data;
    title = "Sales Performance Metrics Correlation",
    notes = "Explore how different sales and operational metrics relate to each other. The dendrogram reveals which metrics cluster together using hierarchical clustering performed in your browser. For example, you might see that customer satisfaction groups with response time, while revenue metrics cluster separately. <strong>Try this:</strong> Change the clustering linkage method to Average or Single to see how it compares to Ward linkage."
)

# =============================================================================
# Example 3: Scientific Measurements with Different Linkage Methods
# =============================================================================

example3_text = TextBlock("""
<h2>Example 3: Scientific Measurements - Single Linkage Clustering</h2>
<p>This example demonstrates single linkage clustering (nearest neighbor).</p>
<p>Features:</p>
<ul>
    <li>Physical and chemical measurements from laboratory experiments</li>
    <li>Demonstrates 'single' linkage clustering</li>
    <li>Single linkage tends to create elongated clusters</li>
    <li>Compare this dendrogram shape to Ward (Example 1) and average (Example 2) linkage</li>
</ul>
""")

# Generate scientific measurement data
n_experiments = 150
temperatures = ["Low", "Medium", "High"]
pressures = ["Ambient", "Elevated", "High Pressure"]

science_data_rows = []

for exp_id in 1:n_experiments
    temp = rand(rng, temperatures)
    pressure = rand(rng, pressures)

    # Physical properties (highly correlated)
    density = rand(rng, 0.8:0.01:1.5)
    viscosity = density * rand(rng, 0.5:0.01:2.0)
    surface_tension = density * rand(rng, 20:0.5:80)

    # Thermal properties
    heat_capacity = rand(rng, 1.5:0.1:4.5)
    thermal_conductivity = heat_capacity * rand(rng, 0.1:0.01:0.8)

    # Chemical properties
    ph = rand(rng, 2.0:0.1:12.0)
    conductivity = (ph < 7 ? 14 - ph : ph) * rand(rng, 50:1:200)  # U-shaped

    # Spectroscopic measurements
    absorbance_280 = rand(rng, 0.1:0.01:2.0)
    absorbance_260 = absorbance_280 * rand(rng, 0.9:0.01:1.1)
    fluorescence = absorbance_280 * rand(rng, 100:5:500)

    push!(science_data_rows, (
        experiment_id = exp_id,
        temperature = temp,
        pressure = pressure,
        density = density,
        viscosity = viscosity,
        surface_tension = surface_tension,
        heat_capacity = heat_capacity,
        thermal_conductivity = thermal_conductivity,
        ph = ph,
        conductivity = conductivity,
        absorbance_280 = absorbance_280,
        absorbance_260 = absorbance_260,
        fluorescence = fluorescence
    ))
end

df_science = DataFrame(science_data_rows)

# Compute correlations for scientific measurements
science_vars = [:density, :viscosity, :surface_tension, :heat_capacity,
                :thermal_conductivity, :ph, :conductivity, :absorbance_280,
                :absorbance_260, :fluorescence]
cors3 = compute_correlations(df_science, science_vars)

# Prepare correlation data for CorrPlot
corr_data3 = prepare_corrplot_data(cors3.pearson, cors3.spearman, string.(science_vars))

# Create correlation plot
corrplot3 = CorrPlot(:science_corr, corr_data3, :science_corr_data;
    title = "Scientific Measurements Correlation",
    notes = "This correlation plot reveals clusters of related physical, thermal, chemical, and spectroscopic properties. The hierarchical clustering groups density-related properties together, thermal properties in another cluster, and spectroscopic measurements in a third cluster. The dual correlation display (Pearson vs Spearman) helps identify non-linear relationships. <strong>Try this:</strong> Switch to Single linkage to see elongated clusters formed by merging based on nearest neighbors, or try Complete linkage for more compact clusters."
)

# =============================================================================
# Example 4: Healthcare Patient Metrics
# =============================================================================

example4_text = TextBlock("""
<h2>Example 4: Healthcare Patient Metrics - Complete Linkage</h2>
<p>Analyze correlations between patient health indicators using complete linkage clustering.</p>
<p>This example includes:</p>
<ul>
    <li>Vital signs, lab results, and outcome metrics</li>
    <li>Complete linkage clustering (farthest neighbor)</li>
    <li>Identify risk factor correlations</li>
    <li>Compare linear (Pearson) vs monotonic (Spearman) relationships</li>
</ul>
""")

# Generate healthcare patient data
n_patients = 180
age_groups = ["18-30", "31-45", "46-60", "61-75", "76+"]
conditions = ["Healthy", "Diabetes", "Hypertension", "Both"]

patient_data_rows = []

for patient_id in 1:n_patients
    age_group = rand(rng, age_groups)
    condition = rand(rng, conditions)

    # Vital signs
    systolic_bp = Float64(rand(rng, 110:160))
    diastolic_bp = systolic_bp * rand(rng, 0.55:0.01:0.75)
    heart_rate = rand(rng, 55:110)

    # Lab results
    glucose = condition in ["Diabetes", "Both"] ? rand(rng, 140:250) : rand(rng, 80:125)
    hba1c = 4.0 + (glucose - 80) * 0.03 * rand(rng, 0.8:0.01:1.2)

    cholesterol_total = Float64(rand(rng, 150:280))
    ldl = cholesterol_total * rand(rng, 0.5:0.01:0.7)
    hdl = cholesterol_total * rand(rng, 0.15:0.01:0.30)
    triglycerides = (cholesterol_total - ldl - hdl) * 5 * rand(rng, 0.7:0.01:1.3)

    # Derived metrics
    bmi = rand(rng, 18.5:0.5:38.0)

    # Outcome metric
    cardiovascular_risk = (systolic_bp - 110) * 0.5 + (ldl - 100) * 0.3 +
                          (glucose - 90) * 0.2 + bmi * 0.8 + rand(rng, -20:30)

    push!(patient_data_rows, (
        patient_id = patient_id,
        age_group = age_group,
        condition = condition,
        systolic_bp = systolic_bp,
        diastolic_bp = diastolic_bp,
        heart_rate = heart_rate,
        glucose = glucose,
        hba1c = hba1c,
        cholesterol_total = cholesterol_total,
        ldl = ldl,
        hdl = hdl,
        triglycerides = triglycerides,
        bmi = bmi,
        cardiovascular_risk = cardiovascular_risk
    ))
end

df_patients = DataFrame(patient_data_rows)

# Compute correlations for patient health metrics
patient_vars = [:systolic_bp, :diastolic_bp, :heart_rate, :glucose, :hba1c,
                :cholesterol_total, :ldl, :hdl, :triglycerides, :bmi, :cardiovascular_risk]
cors4 = compute_correlations(df_patients, patient_vars)

# Prepare correlation data for CorrPlot
corr_data4 = prepare_corrplot_data(cors4.pearson, cors4.spearman, string.(patient_vars))

# Create correlation plot
corrplot4 = CorrPlot(:patient_corr, corr_data4, :patient_corr_data;
    title = "Patient Health Metrics Correlation",
    notes = "This correlation analysis helps identify relationships between vital signs, lab results, and cardiovascular risk. The hierarchical clustering reveals natural groupings: blood pressure metrics cluster together, lipid panel values form another group, and glucose-related metrics cluster separately. Compare Pearson (upper right) vs Spearman (lower left) correlations to see if relationships are linear or non-linear. <strong>Try this:</strong> Switch to Complete linkage clustering (farthest neighbor) to see compact, well-separated clusters."
)

# =============================================================================
# Example 6: Advanced CorrPlot - Economic Indicators Across Regions
# =============================================================================

example6_text = TextBlock("""
<h2>Example 5: Advanced CorrPlot - Economic Indicators Across Regions</h2>
<p>Compare economic indicator correlations across different geographic regions:</p>
<ul>
    <li><strong>Three regional scenarios:</strong> North America, Europe, Asia-Pacific</li>
    <li><strong>Variable selection:</strong> Choose which economic indicators to analyze</li>
    <li><strong>Compare patterns:</strong> See how indicator relationships vary by region</li>
    <li>Useful for international portfolio analysis and macroeconomic research</li>
</ul>
<p><strong>Insights to explore:</strong></p>
<ul>
    <li>How does GDP correlate with unemployment differently across regions?</li>
    <li>Are inflation-interest rate relationships similar globally?</li>
    <li>Which indicators cluster together in each region?</li>
</ul>
""")

# Generate economic indicator data for three regions
n_months = 120  # 10 years of monthly data
indicators = ["GDP_Growth", "Unemployment", "Inflation", "Interest_Rate",
              "Manufacturing_Index", "Consumer_Confidence", "Exports", "Imports"]

# Function to generate correlated economic data for a region
function generate_regional_data(rng, n_months, correlation_strength)
    data = zeros(n_months, length(indicators))

    for month in 1:n_months
        # Economic cycle factor
        cycle = sin(2π * month / 48) * correlation_strength  # 4-year cycle

        # GDP Growth (base economic indicator)
        gdp_growth = 2.0 + cycle + randn(rng) * 0.5
        data[month, 1] = gdp_growth

        # Unemployment (negative correlation with GDP)
        data[month, 2] = 6.0 - cycle * 1.5 + randn(rng) * 0.8

        # Inflation
        data[month, 3] = 2.5 + cycle * 0.8 + randn(rng) * 0.6

        # Interest Rate (follows inflation)
        data[month, 4] = 3.0 + data[month, 3] * 0.5 + randn(rng) * 0.4

        # Manufacturing Index
        data[month, 5] = 50.0 + gdp_growth * 3 + randn(rng) * 2.0

        # Consumer Confidence
        data[month, 6] = 100.0 + gdp_growth * 5 - data[month, 2] * 2 + randn(rng) * 5.0

        # Exports
        data[month, 7] = 100.0 + cycle * 10 + randn(rng) * 8.0

        # Imports
        data[month, 8] = 95.0 + cycle * 12 + randn(rng) * 8.0
    end

    return DataFrame(data, indicators)
end

# Generate data for three regions with different correlation patterns
df_northam = generate_regional_data(rng, n_months, 1.0)   # Strong cyclical correlation
df_europe = generate_regional_data(rng, n_months, 0.7)    # Moderate correlation
df_asia = generate_regional_data(rng, n_months, 0.5)      # Weaker correlation

# Create scenarios for each region
indicator_syms = Symbol.(indicators)

# Compute correlations for each region
cors_na = compute_correlations(df_northam, indicator_syms)
corr_data_na = prepare_corrplot_data(cors_na.pearson, cors_na.spearman, indicators, scenario="North America")

cors_eu = compute_correlations(df_europe, indicator_syms)
corr_data_eu = prepare_corrplot_data(cors_eu.pearson, cors_eu.spearman, indicators, scenario="Europe")

cors_ap = compute_correlations(df_asia, indicator_syms)
corr_data_ap = prepare_corrplot_data(cors_ap.pearson, cors_ap.spearman, indicators, scenario="Asia-Pacific")

# Combine all scenarios
econ_corr_data = vcat(corr_data_na, corr_data_eu, corr_data_ap)

# Create advanced CorrPlot with scenarios
corrplot6 = CorrPlot(:econ_advanced, econ_corr_data, :econ_adv_data;
    title = "Economic Indicators - Regional Comparison",
    notes = "Compare how economic indicators correlate across North America, Europe, and Asia-Pacific. Switch between regions using the scenario selector to see different correlation patterns. The dendrogram updates automatically showing how indicators cluster in each region. Select specific indicators to focus your analysis. Notice how GDP Growth correlates differently with other indicators in each region, reflecting different economic structures and policies. <strong>Try this:</strong> Change the linkage method to see how clustering patterns differ.",
    scenario_col = :scenario,
    default_scenario = "North America",
    default_variables = ["GDP_Growth", "Unemployment", "Inflation", "Interest_Rate"],
    allow_manual_order = true
)

# =============================================================================
# Example 7: Advanced CorrPlot - Climate Variables Across Seasons
# =============================================================================

example7_text = TextBlock("""
<h2>Example 6: Advanced CorrPlot - Climate Variables by Season</h2>
<p>Analyze how climate variable correlations change across seasons:</p>
<ul>
    <li><strong>Four seasonal scenarios:</strong> Spring, Summer, Fall, Winter</li>
    <li><strong>Interactive variable selection:</strong> Focus on specific climate factors</li>
    <li><strong>Seasonal patterns:</strong> See how temperature-humidity relationships vary</li>
    <li>Demonstrates that correlation structure can change with context (season)</li>
</ul>
<p><strong>Key observations:</strong></p>
<ul>
    <li>Temperature-humidity correlations differ by season</li>
    <li>Precipitation patterns cluster differently in summer vs winter</li>
    <li>Solar radiation shows different relationships across seasons</li>
</ul>
""")

# Generate climate data for four seasons
n_observations = 90  # Days per season
climate_vars = ["Temperature", "Humidity", "Pressure", "Wind_Speed",
                "Precipitation", "Cloud_Cover", "Solar_Radiation", "UV_Index"]

function generate_seasonal_climate(rng, season_name, n_obs)
    # Different base values and correlations for each season
    if season_name == "Spring"
        temp_base, temp_var = 15.0, 8.0
        humid_factor = -0.3  # Negative correlation with temp
    elseif season_name == "Summer"
        temp_base, temp_var = 28.0, 6.0
        humid_factor = 0.4   # Positive correlation (humid heat)
    elseif season_name == "Fall"
        temp_base, temp_var = 16.0, 7.0
        humid_factor = -0.2
    else  # Winter
        temp_base, temp_var = 5.0, 5.0
        humid_factor = 0.2
    end

    data = zeros(n_obs, length(climate_vars))

    for obs in 1:n_obs
        # Temperature
        temp = temp_base + randn(rng) * temp_var
        data[obs, 1] = temp

        # Humidity (seasonal relationship with temperature)
        data[obs, 2] = 60.0 + humid_factor * (temp - temp_base) * 2 + randn(rng) * 15.0

        # Pressure
        data[obs, 3] = 1013.0 + randn(rng) * 10.0

        # Wind Speed
        data[obs, 4] = 15.0 + randn(rng) * 8.0

        # Precipitation (higher with lower pressure)
        data[obs, 5] = max(0, (1020 - data[obs, 3]) * 0.5 + randn(rng) * 3.0)

        # Cloud Cover (correlated with precipitation)
        data[obs, 6] = min(100, data[obs, 5] * 8 + randn(rng) * 20.0)

        # Solar Radiation (seasonal and cloud dependent)
        seasonal_solar = season_name in ["Summer", "Spring"] ? 800.0 : 400.0
        data[obs, 7] = max(0, seasonal_solar - data[obs, 6] * 3 + randn(rng) * 100.0)

        # UV Index (follows solar radiation)
        data[obs, 8] = max(0, data[obs, 7] / 150 + randn(rng) * 1.5)
    end

    return DataFrame(data, climate_vars)
end

# Generate data for each season
df_spring = generate_seasonal_climate(rng, "Spring", n_observations)
df_summer = generate_seasonal_climate(rng, "Summer", n_observations)
df_fall = generate_seasonal_climate(rng, "Fall", n_observations)
df_winter = generate_seasonal_climate(rng, "Winter", n_observations)

# Compute correlations for each season
climate_syms = Symbol.(climate_vars)

cors_spring = compute_correlations(df_spring, climate_syms)
corr_data_spring = prepare_corrplot_data(cors_spring.pearson, cors_spring.spearman, climate_vars, scenario="Spring")

cors_summer = compute_correlations(df_summer, climate_syms)
corr_data_summer = prepare_corrplot_data(cors_summer.pearson, cors_summer.spearman, climate_vars, scenario="Summer")

cors_fall = compute_correlations(df_fall, climate_syms)
corr_data_fall = prepare_corrplot_data(cors_fall.pearson, cors_fall.spearman, climate_vars, scenario="Fall")

cors_winter = compute_correlations(df_winter, climate_syms)
corr_data_winter = prepare_corrplot_data(cors_winter.pearson, cors_winter.spearman, climate_vars, scenario="Winter")

# Combine all seasons
climate_corr_data = vcat(corr_data_spring, corr_data_summer, corr_data_fall, corr_data_winter)

# Create advanced CorrPlot with seasonal scenarios
corrplot7 = CorrPlot(:climate_advanced, climate_corr_data, :climate_adv_data;
    title = "Climate Variable Correlations - Seasonal Analysis",
    notes = "Explore how climate variable correlations change across seasons. Switch between Spring, Summer, Fall, and Winter using the scenario selector to see seasonal patterns. The dendrogram updates dynamically showing how variables cluster in each season. Notice how Temperature-Humidity correlations flip between seasons (negative in Spring/Fall, positive in Summer/Winter). Use variable selection to focus on specific climate factors. Try manual ordering to group related variables by type (temperature-related, precipitation-related, etc.).",
    scenario_col = :scenario,
    default_scenario = "Summer",
    default_variables = ["Temperature", "Humidity", "Solar_Radiation", "UV_Index"],
    allow_manual_order = true
)

# =============================================================================
# Summary
# =============================================================================

summary = TextBlock("""
<h2>Summary</h2>
<p>The CorrPlot chart type provides:</p>
<ul>
    <li><strong>Browser-based hierarchical clustering:</strong> Dendrogram computed dynamically in your browser, updates instantly when you change variables or linkage method</li>
    <li><strong>Dual correlation display:</strong>
        <ul>
            <li>Top-right triangle: Pearson correlation (measures linear relationships)</li>
            <li>Bottom-left triangle: Spearman correlation (measures monotonic relationships, robust to outliers)</li>
        </ul>
    </li>
    <li><strong>Julia-computed correlations:</strong> Use compute_correlations() for both Pearson and Spearman, then prepare_corrplot_data() to format for CorrPlot</li>
    <li><strong>Flexible clustering:</strong> Choose linkage method in browser (Ward, Average, Single, Complete) and see dendrogram update instantly</li>
    <li><strong>Works with subsets:</strong> Select any subset of variables and dendrogram reclusters automatically</li>
    <li><strong>Multiple scenarios:</strong> Compare correlations across different conditions (regions, seasons, etc.) using the scenario selector</li>
    <li><strong>Automatic ordering:</strong> Variables reordered by clustering results for clearer visualization of correlation blocks</li>
</ul>

<h3>Basic Workflow (Examples 1-4)</h3>
<pre><code>
# 1. Compute correlations
vars = [:var1, :var2, :var3, :var4]
cors = compute_correlations(df, vars)

# 2. Prepare correlation data for CorrPlot
corr_data = prepare_corrplot_data(cors.pearson, cors.spearman, string.(vars))

# 3. Create correlation plot (clustering happens in browser!)
corrplot = CorrPlot(:my_corr, corr_data, :my_data;
                    title="My Correlation Analysis",
                    notes="Description...")
</code></pre>

<h3>Advanced Workflow with Multiple Scenarios (Examples 5-7)</h3>
<pre><code>
# 1. Compute correlations for each scenario
cors1 = compute_correlations(df1, vars)
corr_data1 = prepare_corrplot_data(cors1.pearson, cors1.spearman, labels, scenario="Short-term")

cors2 = compute_correlations(df2, vars)
corr_data2 = prepare_corrplot_data(cors2.pearson, cors2.spearman, labels, scenario="Long-term")

cors3 = compute_correlations(df3, vars)
corr_data3 = prepare_corrplot_data(cors3.pearson, cors3.spearman, labels, scenario="Volatility")

# 2. Combine scenarios
all_corr_data = vcat(corr_data1, corr_data2, corr_data3)

# 3. Create CorrPlot with scenario selector
corrplot = CorrPlot(:advanced, all_corr_data, :adv_data;
                    scenario_col=:scenario,
                    title="Advanced Analysis",
                    default_scenario="Short-term",
                    default_variables=["var1", "var2", "var3"],
                    allow_manual_order=true)
</code></pre>

<h3>Interactive Features</h3>
<ul>
    <li><strong>Dynamic Clustering:</strong> Hierarchical clustering computed in browser - works with any subset of variables</li>
    <li><strong>Linkage Method Selector:</strong> Choose Ward, Average, Single, or Complete linkage and see dendrogram update instantly</li>
    <li><strong>Multiple Scenarios:</strong> Switch between different correlation analyses using dropdown (Examples 5-7)</li>
    <li><strong>Variable Selection:</strong> Multi-select box to choose which variables to display</li>
    <li><strong>Manual Ordering:</strong> Toggle to "Order manually" to enable drag-drop reordering</li>
    <li><strong>Alphabetical Ordering:</strong> Sort variables alphabetically if preferred</li>
</ul>

<h3>Linkage Methods</h3>
<ul>
    <li><strong>Ward (:ward):</strong> Minimizes within-cluster variance, creates compact clusters (Examples 1, 5-7)</li>
    <li><strong>Average (:average):</strong> Uses average distance between clusters, balanced approach (Example 2)</li>
    <li><strong>Single (:single):</strong> Nearest neighbor, can create elongated clusters (Example 3)</li>
    <li><strong>Complete (:complete):</strong> Farthest neighbor, creates compact, well-separated clusters (Example 4)</li>
</ul>

<h3>Use Cases</h3>
<ul>
    <li><strong>Financial analysis:</strong> Stock correlations across time horizons (Example 5), portfolio diversification</li>
    <li><strong>Economic research:</strong> Compare regional indicator relationships (Example 6)</li>
    <li><strong>Climate science:</strong> Seasonal correlation patterns (Example 7)</li>
    <li><strong>Scientific research:</strong> Discover relationships between experimental measurements (Example 3)</li>
    <li><strong>Healthcare:</strong> Analyze patient metrics and identify risk factor correlations (Example 4)</li>
    <li><strong>Feature selection:</strong> Identify redundant variables for machine learning</li>
</ul>

<h3>Interpretation Tips</h3>
<ul>
    <li><strong>Dendrogram:</strong> Variables that merge early (low height) are highly correlated</li>
    <li><strong>Pearson vs Spearman:</strong> If they differ significantly, the relationship may be non-linear</li>
    <li><strong>Clustering:</strong> Reveals natural groupings of related variables</li>
    <li><strong>Correlation blocks:</strong> After reordering, look for dark red/blue blocks indicating groups of correlated variables</li>
    <li><strong>Scenario switching:</strong> Compare how correlations change across contexts (time, region, season)</li>
    <li><strong>Variable selection:</strong> Focus analysis on specific subsets of interest</li>
    <li><strong>Manual ordering:</strong> Create custom groupings by sector, type, or hypothesis</li>
</ul>
""")

# =============================================================================
# Create the page
# =============================================================================

# Output to the main generated_html_examples directory
output_dir = joinpath(dirname(@__DIR__), "generated_html_examples")
if !isdir(output_dir)
    mkpath(output_dir)
end

# Correlation data was already prepared in each example above
# corr_data1, corr_data2, corr_data3, corr_data4, econ_corr_data (corr_data6), climate_corr_data (corr_data7)

# Create data dictionary with all correlation data
data_dict = Dict{Symbol, Any}(
    :financial_corr_data => corr_data1,
    :sales_corr_data => corr_data2,
    :science_corr_data => corr_data3,
    :patient_corr_data => corr_data4,
    :econ_adv_data => econ_corr_data,
    :climate_adv_data => climate_corr_data
)

# Create embedded format
page = JSPlotPage(
    data_dict,
    [header,
     example1_text, corrplot1,
     example2_text, corrplot2,
     example3_text, corrplot3,
     example4_text, corrplot4,
     example6_text, corrplot6,
     example7_text, corrplot7,
     summary];
    dataformat=:csv_embedded
)

output_file = joinpath(output_dir, "corrplot_examples.html")
create_html(page, output_file)
println("Created: $output_file")

println("\nCorrPlot examples complete!")
println("Open the HTML file in a browser to see the interactive correlation plots with dendrograms.")
println("\nCompare the different linkage methods (Ward, Average, Single, Complete) across the four examples!")
