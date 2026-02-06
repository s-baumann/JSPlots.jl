const DATASET_TEMPLATE = raw"""<script type="text/plain" id="___DDATA_LABEL___" data-format="___DATA_FORMAT___" data-src="___DATA_SRC___">___DATA1___</script>"""


const SEGMENT_SEPARATOR = """
<br>
<hr>
<br>
"""

"""
    convert_zoneddatetime_to_datetime(df::DataFrame)

Convert all ZonedDateTime columns in a DataFrame to DateTime by extracting the UTC datetime.
Returns a copy of the DataFrame with converted columns, leaving the original unchanged.

This ensures that temporal data displays properly in JavaScript visualizations, which expect
DateTime objects rather than timezone-aware ZonedDateTime objects.
"""
function convert_zoneddatetime_to_datetime(df::DataFrame)
    # Check if any columns need conversion
    needs_conversion = false
    for col in names(df)
        col_type = eltype(df[!, col])
        if col_type <: ZonedDateTime || (col_type isa Union && ZonedDateTime in Base.uniontypes(col_type))
            needs_conversion = true
            break
        end
    end

    # If no conversion needed, return original DataFrame
    if !needs_conversion
        return df
    end

    # Make a copy and convert ZonedDateTime columns
    df_converted = copy(df)
    for col in names(df_converted)
        col_type = eltype(df_converted[!, col])
        if col_type <: ZonedDateTime || (col_type isa Union && ZonedDateTime in Base.uniontypes(col_type))
            # Convert ZonedDateTime to DateTime (using UTC time)
            df_converted[!, col] = [ismissing(x) ? missing : DateTime(x, UTC) for x in df_converted[!, col]]
        end
    end

    return df_converted
end

const FULL_PAGE_TEMPLATE = raw"""
<!DOCTYPE html>
<html>
<head>
    <title>___TITLE_OF_PAGE___</title>
    <meta charset="UTF-8">

    <!-- External JavaScript libraries (loaded based on chart types used) -->
    ___JS_DEPENDENCIES___

    <style>
        body {
            margin: 0;
            padding: 20px;
            font-family: Arial, sans-serif;
        }
        #controls {
            display: flex;
            flex-wrap: wrap;
            margin-bottom: 20px;
            padding: 10px;
            background-color: #f0f0f0;
            border-radius: 5px;
        }
        #$div_id {
            width: 100%;
            height: 600px;
        }
    </style>
    ___EXTRA_STYLES___

    <!-- Prism.js language components for CodeBlocks -->
    ___PRISM_LANGUAGES___

</head>

<body>

<!-- Parquet support (loaded if using parquet dataformat) -->
___PARQUET_SCRIPT___

<script>
// Helper function to wait for parquet-wasm to be loaded
function waitForParquet() {
    return new Promise(function(resolve) {
        if (window.parquetReady) {
            resolve();
            return;
        }
        var checkInterval = setInterval(function() {
            if (window.parquetReady) {
                clearInterval(checkInterval);
                resolve();
            }
        }, 50);
    });
}

// Centralized data loading function
// Centralized date parsing function
// Converts various date formats to JavaScript Date objects
// This is the ONLY place in the package where date parsing happens
// Handles: ISO strings, Date objects (from Arrow/Parquet), timestamps, and day counts
function parseDatesInData(data) {
    if (!data || data.length === 0) return data;

    // Regex patterns for ISO date formats
    var datePattern = /^\d{4}-\d{2}-\d{2}$/;  // YYYY-MM-DD
    var datetimePattern = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/;  // YYYY-MM-DDTHH:MM:SS
    var timePattern = /^\d{2}:\d{2}:\d{2}(\.\d+)?$/;  // HH:MM:SS or HH:MM:SS.sss

    // Timestamp range for reasonable dates (2000-01-01 to 2100-01-01 in milliseconds)
    // Using year 2000 as minimum to avoid false positives with regular numeric values
    var MIN_TIMESTAMP_MS = 946684800000;  // 2000-01-01
    var MAX_TIMESTAMP_MS = 4102444800000;  // 2100-01-01

    // Day count range (for dates stored as days since epoch, e.g., from some Parquet files)
    // Reasonable range: 0 (1970-01-01) to ~47500 (~2100-01-01)
    var MIN_DAYS = 0;
    var MAX_DAYS = 50000;
    var MS_PER_DAY = 86400000;

    // Scan multiple rows to better detect column types (some rows might have missing values)
    var rowsToCheck = Math.min(10, data.length);
    var dateColumns = [];
    var timeColumns = [];
    var timestampColumns = [];
    var dayCountColumns = [];
    var alreadyDateColumns = [];

    // Helper to check if a numeric value looks like a timestamp (milliseconds since epoch)
    function looksLikeTimestamp(value) {
        return typeof value === 'number' && value >= MIN_TIMESTAMP_MS && value <= MAX_TIMESTAMP_MS && value > MAX_DAYS;
    }

    // Helper to check if a numeric value looks like a day count since epoch
    // DISABLED: This was too aggressive and incorrectly converted normal numeric values
    // (like Month=1, Year=2022, Sales=120) to dates. Only enable for columns with
    // explicit date-like names if needed in the future.
    function looksLikeDayCount(value) {
        return false;  // Disabled - too many false positives
    }

    // Build list of keys from first row
    var keys = Object.keys(data[0]);

    // Check each column across multiple rows
    keys.forEach(function(key) {
        var stringDateCount = 0;
        var timeCount = 0;
        var timestampCount = 0;
        var dayCountCount = 0;
        var alreadyDateCount = 0;
        var nonNullCount = 0;

        for (var i = 0; i < rowsToCheck; i++) {
            var value = data[i][key];
            if (value === null || value === undefined) continue;
            nonNullCount++;

            if (value instanceof Date) {
                alreadyDateCount++;
            } else if (typeof value === 'string') {
                if (datetimePattern.test(value) || datePattern.test(value)) {
                    stringDateCount++;
                } else if (timePattern.test(value)) {
                    timeCount++;
                }
            } else if (typeof value === 'number') {
                if (looksLikeTimestamp(value)) {
                    timestampCount++;
                } else if (looksLikeDayCount(value)) {
                    dayCountCount++;
                }
            }
        }

        // Classify column if majority of non-null values match a pattern
        var threshold = nonNullCount * 0.5;
        if (alreadyDateCount > threshold) {
            alreadyDateColumns.push(key);
        } else if (stringDateCount > threshold) {
            dateColumns.push(key);
        } else if (timeCount > threshold) {
            timeColumns.push(key);
        } else if (timestampCount > threshold) {
            timestampColumns.push(key);
        } else if (dayCountCount > threshold && dayCountCount >= 3) {
            // Be more conservative with day counts - require at least 3 matches
            dayCountColumns.push(key);
        }
    });

    // If no date/time columns found, return data unchanged
    if (dateColumns.length === 0 && timeColumns.length === 0 &&
        timestampColumns.length === 0 && dayCountColumns.length === 0 &&
        alreadyDateColumns.length === 0) {
        return data;
    }

    // Convert values in all rows
    return data.map(function(row) {
        var newRow = {};
        for (var key in row) {
            if (row.hasOwnProperty(key)) {
                var value = row[key];

                if (alreadyDateColumns.indexOf(key) !== -1) {
                    // Already a Date object - keep as is
                    newRow[key] = value;
                } else if (dateColumns.indexOf(key) !== -1 && typeof value === 'string') {
                    // ISO date string - convert to Date
                    newRow[key] = new Date(value);
                } else if (timeColumns.indexOf(key) !== -1 && typeof value === 'string') {
                    // Convert HH:MM:SS or HH:MM:SS.sss to milliseconds since midnight
                    var parts = value.split(':');
                    var hours = parseInt(parts[0], 10);
                    var minutes = parseInt(parts[1], 10);
                    var seconds = parseFloat(parts[2]);
                    newRow[key] = (hours * 3600 + minutes * 60 + seconds) * 1000;
                } else if (timestampColumns.indexOf(key) !== -1 && typeof value === 'number') {
                    // Timestamp in milliseconds - convert to Date
                    newRow[key] = new Date(value);
                } else if (dayCountColumns.indexOf(key) !== -1 && typeof value === 'number') {
                    // Day count since epoch - convert to Date
                    newRow[key] = new Date(value * MS_PER_DAY);
                } else {
                    newRow[key] = value;
                }
            }
        }
        return newRow;
    });
}

// Helper function to convert temporal values back to string format for categorical filtering
// Takes a value and returns the appropriate string representation
function temporalValueToString(value) {
    if (value instanceof Date) {
        // Convert Date to ISO string
        var year = value.getFullYear();
        var month = String(value.getMonth() + 1).padStart(2, '0');
        var day = String(value.getDate()).padStart(2, '0');
        var hours = String(value.getHours()).padStart(2, '0');
        var minutes = String(value.getMinutes()).padStart(2, '0');
        var seconds = String(value.getSeconds()).padStart(2, '0');

        // Check if this is a date-only value (time is midnight UTC)
        if (hours === '00' && minutes === '00' && seconds === '00') {
            return year + '-' + month + '-' + day;
        } else {
            return year + '-' + month + '-' + day + 'T' + hours + ':' + minutes + ':' + seconds;
        }
    } else if (typeof value === 'number' && value >= 0 && value < 86400000) {
        // Likely a Time value (milliseconds since midnight, less than 24 hours)
        var totalSeconds = Math.floor(value / 1000);
        var hours = Math.floor(totalSeconds / 3600);
        var minutes = Math.floor((totalSeconds % 3600) / 60);
        var seconds = totalSeconds % 60;
        var milliseconds = value % 1000;

        var timeStr = String(hours).padStart(2, '0') + ':' +
                      String(minutes).padStart(2, '0') + ':' +
                      String(seconds).padStart(2, '0');

        // Add decimal part if there are milliseconds
        if (milliseconds > 0) {
            timeStr += '.' + String(milliseconds);
        }

        return timeStr;
    } else {
        // Return as-is for other types
        return String(value);
    }
}

// Centralized observation counting and filtering function
// Applies filters incrementally while updating observation count displays
// Returns filtered data
// Now supports optional choice filters (single-select) in addition to categorical filters (multi-select)
function applyFiltersWithCounting(allData, chartTitle, categoricalFilters, continuousFilters, filters, rangeFilters, choiceFilters, choices) {
    var totalObs = allData.length;

    // Update total observation count
    var totalObsElement = document.getElementById(chartTitle + '_total_obs');
    if (totalObsElement) {
        totalObsElement.textContent = totalObs + ' observations';
    }

    // Apply filters incrementally to track observation counts
    var currentData = allData;

    // Apply choice filters first (single-select, exact match)
    if (choiceFilters && choices) {
        choiceFilters.forEach(function(col) {
            if (choices[col] !== undefined && choices[col] !== null && choices[col] !== '') {
                currentData = currentData.filter(function(row) {
                    var rowValueStr = temporalValueToString(row[col]);
                    return rowValueStr === choices[col];
                });
            }
        });
    }

    // Apply categorical filters and update counts
    categoricalFilters.forEach(function(col) {
        if (filters[col] && filters[col].length > 0) {
            currentData = currentData.filter(function(row) {
                var rowValueStr = temporalValueToString(row[col]);
                return filters[col].includes(rowValueStr);
            });
        }

        var countElement = document.getElementById(col + '_select_' + chartTitle + '_obs_count');
        if (countElement) {
            var pct = totalObs > 0 ? Math.round((currentData.length / totalObs) * 100) : 100;
            countElement.textContent = pct + '% (' + currentData.length + ') remaining';
        }
    });

    // Apply continuous filters and update counts
    continuousFilters.forEach(function(col) {
        if (rangeFilters[col]) {
            var range = rangeFilters[col];
            currentData = currentData.filter(function(row) {
                var rawValue = row[col];
                var value;
                if (rawValue instanceof Date) {
                    value = rawValue.getTime();
                } else {
                    value = parseFloat(rawValue);
                }
                return value >= range.min && value <= range.max;
            });
        }

        var countElement = document.getElementById(col + '_range_' + chartTitle + '_obs_count');
        if (countElement) {
            var pct = totalObs > 0 ? Math.round((currentData.length / totalObs) * 100) : 100;
            countElement.textContent = pct + '% (' + currentData.length + ') remaining';
        }
    });

    return currentData;
}

// Axis transformation functions
// These transform data values according to selected transformation type
function applyAxisTransform(values, transformType) {
    if (!values || values.length === 0) return [];

    switch(transformType) {
        case 'identity':
            return values;

        case 'log':
            return values.map(function(v) {
                return v > 0 ? Math.log(v) : NaN;
            });

        case 'z_score':
            // Z-score standardization: (x - mean) / std
            var numericVals = values.filter(function(v) { return !isNaN(v) && isFinite(v); });
            if (numericVals.length === 0) return values;

            var mean = numericVals.reduce(function(a, b) { return a + b; }, 0) / numericVals.length;
            var variance = numericVals.reduce(function(sum, v) {
                return sum + Math.pow(v - mean, 2);
            }, 0) / numericVals.length;
            var std = Math.sqrt(variance);

            if (std === 0) return values;

            return values.map(function(v) {
                if (isNaN(v) || !isFinite(v)) return NaN;
                return (v - mean) / std;
            });

        case 'quantile':
            // Rank-based transformation to [0, 1]
            // Create array of {value, originalIndex} pairs
            var indexedValues = values.map(function(v, i) {
                return { value: v, index: i };
            });

            // Filter out invalid values and sort
            var validValues = indexedValues.filter(function(item) {
                return !isNaN(item.value) && isFinite(item.value);
            }).sort(function(a, b) {
                return a.value - b.value;
            });

            if (validValues.length === 0) return values;

            // Assign ranks (0 to 1)
            var ranks = new Array(values.length).fill(NaN);
            validValues.forEach(function(item, rank) {
                // Map rank to [0, 1] where lowest = 0, highest = 1
                ranks[item.index] = validValues.length === 1 ? 0.5 : rank / (validValues.length - 1);
            });

            return ranks;

        case 'inverse_cdf':
            // Z-score followed by normal CDF transformation to [0, 1]
            var numericVals2 = values.filter(function(v) { return !isNaN(v) && isFinite(v); });
            if (numericVals2.length === 0) return values;

            var mean2 = numericVals2.reduce(function(a, b) { return a + b; }, 0) / numericVals2.length;
            var variance2 = numericVals2.reduce(function(sum, v) {
                return sum + Math.pow(v - mean2, 2);
            }, 0) / numericVals2.length;
            var std2 = Math.sqrt(variance2);

            if (std2 === 0) return values.map(function() { return 0.5; });

            return values.map(function(v) {
                if (isNaN(v) || !isFinite(v)) return NaN;
                var zscore = (v - mean2) / std2;
                return normalCDF(zscore);
            });

        case 'cumulative':
        case 'cumprod':
            // These are handled specially in chart code (computed per group)
            // Here they act as identity
            return values;

        default:
            return values;
    }
}

// Compute cumulative sum of values
// Returns array of same length: [y[0], y[0]+y[1], y[0]+y[1]+y[2], ...]
function computeCumulativeSum(values) {
    if (!values || values.length === 0) return [];
    var result = [];
    var sum = 0;
    for (var i = 0; i < values.length; i++) {
        var v = parseFloat(values[i]);  // Explicitly convert to number
        if (!isNaN(v) && isFinite(v)) {
            sum += v;
        }
        result.push(sum);
    }
    return result;
}

// Compute cumulative product of values for returns data
// For returns r_i, computes: cumprod(1 + r_i) - 1
// This converts returns to growth factors, compounds them, then converts back to cumulative return
// Example: returns [0.1, 0.2, -0.1] -> (1+r): [1.1, 1.2, 0.9] -> cumprod: [1.1, 1.32, 1.188] -> result: [0.1, 0.32, 0.188]
function computeCumulativeProduct(values) {
    if (!values || values.length === 0) return [];
    var result = [];
    var product = 1;
    for (var i = 0; i < values.length; i++) {
        var v = parseFloat(values[i]);  // Explicitly convert to number
        if (!isNaN(v) && isFinite(v)) {
            product *= (1 + v);  // Convert return to growth factor and multiply
        }
        result.push(product - 1);  // Convert back to cumulative return
    }
    return result;
}

// Compute Exponentially Weighted Moving Average
// weight: weight on newest observation, with warmup max(1/(i+1), weight)
function computeEWMA(values, weight) {
    var result = [];
    var ewma = NaN;
    for (var i = 0; i < values.length; i++) {
        var v = parseFloat(values[i]);
        var wt = Math.max(1 / (i + 1), weight);
        if (isNaN(v) || !isFinite(v)) {
            result.push(ewma);
        } else if (isNaN(ewma)) {
            ewma = v;
            result.push(ewma);
        } else {
            ewma = v * wt + ewma * (1 - wt);
            result.push(ewma);
        }
    }
    return result;
}

// Compute Exponentially Weighted Moving Standard Deviation
// Tracks EWMA of value and EWMA of value squared, std = sqrt(E[X^2] - E[X]^2)
// weight: weight on newest observation, with warmup max(1/(i+1), weight)
function computeEWMSTD(values, weight) {
    var result = [];
    var ewmaMean = NaN;
    var ewmaSq = NaN;
    for (var i = 0; i < values.length; i++) {
        var v = parseFloat(values[i]);
        var wt = Math.max(1 / (i + 1), weight);
        if (isNaN(v) || !isFinite(v)) {
            result.push(isNaN(ewmaMean) ? NaN : Math.sqrt(Math.max(0, ewmaSq - ewmaMean * ewmaMean)));
        } else if (isNaN(ewmaMean)) {
            ewmaMean = v;
            ewmaSq = v * v;
            result.push(0);
        } else {
            ewmaMean = v * wt + ewmaMean * (1 - wt);
            ewmaSq = (v * v) * wt + ewmaSq * (1 - wt);
            result.push(Math.sqrt(Math.max(0, ewmaSq - ewmaMean * ewmaMean)));
        }
    }
    return result;
}

// Compute Simple Moving Average over last windowSize periods
function computeSMA(values, windowSize) {
    var result = [];
    for (var i = 0; i < values.length; i++) {
        var start = Math.max(0, i - windowSize + 1);
        var sum = 0, count = 0;
        for (var j = start; j <= i; j++) {
            var v = parseFloat(values[j]);
            if (!isNaN(v) && isFinite(v)) { sum += v; count++; }
        }
        result.push(count > 0 ? sum / count : NaN);
    }
    return result;
}

// Compute a moving statistic on an array of values
// windowType: "fixed_interval" | "fixed_interval_around" | "exponential_decay"
// aggregation: "mean" | "std" | "skewness" | "kurtosis"
// parameter: window size (for fixed_interval/fixed_interval_around) or decay weight (for exponential_decay)
function computeMovingStatistic(values, windowType, aggregation, parameter) {
    if (!values || values.length === 0) return [];

    if (windowType === 'exponential_decay') {
        return computeEWMStatistic(values, aggregation, parameter);
    }

    var result = [];
    var windowSize = Math.max(1, Math.round(parameter));

    for (var i = 0; i < values.length; i++) {
        var start, end;
        if (windowType === 'fixed_interval') {
            // Backward-looking: [i - windowSize + 1, i]
            start = Math.max(0, i - windowSize + 1);
            end = i + 1;
        } else {
            // Centered: [i - half, i + half]
            var half = Math.floor(windowSize / 2);
            start = Math.max(0, i - half);
            end = Math.min(values.length, i + half + 1);
        }

        var windowValues = [];
        for (var j = start; j < end; j++) {
            var v = parseFloat(values[j]);
            if (!isNaN(v) && isFinite(v)) {
                windowValues.push(v);
            }
        }

        result.push(computeWindowAggregation(windowValues, aggregation));
    }
    return result;
}

// Compute aggregation over a window of values
function computeWindowAggregation(windowValues, aggregation) {
    var n = windowValues.length;
    if (n === 0) return NaN;

    var sum = 0;
    for (var i = 0; i < n; i++) sum += windowValues[i];
    var mean = sum / n;

    if (aggregation === 'mean') return mean;

    // For std, skewness, kurtosis we need central moments
    var m2 = 0, m3 = 0, m4 = 0;
    for (var i = 0; i < n; i++) {
        var d = windowValues[i] - mean;
        m2 += d * d;
        m3 += d * d * d;
        m4 += d * d * d * d;
    }

    var variance = n > 1 ? m2 / (n - 1) : 0;
    var stddev = Math.sqrt(variance);

    if (aggregation === 'std') return stddev;

    // Population moments for skewness/kurtosis
    var popM2 = m2 / n;
    var popM3 = m3 / n;
    var popM4 = m4 / n;

    if (popM2 === 0) return 0;

    if (aggregation === 'skewness') {
        return popM3 / Math.pow(popM2, 1.5);
    }

    if (aggregation === 'kurtosis') {
        // Excess kurtosis (normal = 0)
        return (popM4 / (popM2 * popM2)) - 3;
    }

    return NaN;
}

// Exponentially weighted moving statistic
// alpha is weight on the LATEST value: EWMA_t = alpha * x_t + (1 - alpha) * EWMA_{t-1}
function computeEWMStatistic(values, aggregation, alpha) {
    if (!values || values.length === 0) return [];
    var result = [];

    if (aggregation === 'mean') {
        var ewma = parseFloat(values[0]);
        result.push(isNaN(ewma) ? NaN : ewma);
        for (var i = 1; i < values.length; i++) {
            var v = parseFloat(values[i]);
            if (!isNaN(v) && isFinite(v)) {
                ewma = alpha * v + (1 - alpha) * ewma;
            }
            result.push(ewma);
        }
        return result;
    }

    // For std, skewness, kurtosis: track exponentially weighted moments
    var ewmMean = parseFloat(values[0]);
    var ewmVar = 0;
    var ewmM3 = 0;
    var ewmM4 = 0;

    result.push(0);  // First value: no variance/skew/kurtosis yet

    for (var i = 1; i < values.length; i++) {
        var v = parseFloat(values[i]);
        if (isNaN(v) || !isFinite(v)) {
            result.push(result[result.length - 1]);
            continue;
        }
        var delta = v - ewmMean;
        ewmMean = alpha * v + (1 - alpha) * ewmMean;
        var delta2 = v - ewmMean;
        ewmVar = (1 - alpha) * (ewmVar + alpha * delta * delta2);

        if (aggregation === 'std') {
            result.push(Math.sqrt(Math.max(0, ewmVar)));
        } else {
            var ewmStd = Math.sqrt(Math.max(0, ewmVar));
            ewmM3 = (1 - alpha) * (ewmM3 + alpha * delta * delta * delta);
            ewmM4 = (1 - alpha) * (ewmM4 + alpha * delta * delta * delta * delta);

            if (ewmStd > 0 && ewmVar > 0) {
                if (aggregation === 'skewness') {
                    result.push(ewmM3 / (ewmStd * ewmStd * ewmStd));
                } else {
                    // Excess kurtosis
                    result.push((ewmM4 / (ewmVar * ewmVar)) - 3);
                }
            } else {
                result.push(0);
            }
        }
    }
    return result;
}

// Compute quantile transformation of values (rank-based, maps to [0, 1])
function computeQuantileTransform(values) {
    if (!values || values.length === 0) return [];

    var indexedValues = values.map(function(v, i) {
        return { value: parseFloat(v), index: i };  // Explicitly convert to number
    });

    var validValues = indexedValues.filter(function(item) {
        return !isNaN(item.value) && isFinite(item.value);
    }).sort(function(a, b) {
        return a.value - b.value;
    });

    if (validValues.length === 0) return values;

    var ranks = new Array(values.length).fill(NaN);
    validValues.forEach(function(item, rank) {
        ranks[item.index] = validValues.length === 1 ? 0.5 : rank / (validValues.length - 1);
    });

    return ranks;
}

// Normal CDF (cumulative distribution function) for standard normal
function normalCDF(x) {
    // Using error function approximation
    var t = 1 / (1 + 0.2316419 * Math.abs(x));
    var d = 0.3989423 * Math.exp(-x * x / 2);
    var prob = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
    return x > 0 ? 1 - prob : prob;
}

// Inverse normal CDF (quantile function) for standard normal
function inverseNormalCDF(p) {
    // Rational approximation for inverse normal CDF
    // Valid for 0 < p < 1
    if (p <= 0 || p >= 1) {
        return NaN;
    }

    var a = [0, -3.969683028665376e+01, 2.209460984245205e+02,
             -2.759285104469687e+02, 1.383577518672690e+02,
             -3.066479806614716e+01, 2.506628277459239e+00];
    var b = [0, -5.447609879822406e+01, 1.615858368580409e+02,
             -1.556989798598866e+02, 6.680131188771972e+01,
             -1.328068155288572e+01];
    var c = [0, -7.784894002430293e-03, -3.223964580411365e-01,
             -2.400758277161838e+00, -2.549732539343734e+00,
             4.374664141464968e+00, 2.938163982698783e+00];
    var d = [0, 7.784695709041462e-03, 3.224671290700398e-01,
             2.445134137142996e+00, 3.754408661907416e+00];

    var q, r, result;

    if (p < 0.02425) {
        q = Math.sqrt(-2 * Math.log(p));
        result = (((((c[1] * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) * q + c[6]) /
                 ((((d[1] * q + d[2]) * q + d[3]) * q + d[4]) * q + 1);
    } else if (p > 0.97575) {
        q = Math.sqrt(-2 * Math.log(1 - p));
        result = -(((((c[1] * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) * q + c[6]) /
                  ((((d[1] * q + d[2]) * q + d[3]) * q + d[4]) * q + 1);
    } else {
        q = p - 0.5;
        r = q * q;
        result = (((((a[1] * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * r + a[6]) * q /
                 (((((b[1] * r + b[2]) * r + b[3]) * r + b[4]) * r + b[5]) * r + 1);
    }

    return result;
}

// Get axis label with transformation applied
function getAxisLabel(originalLabel, transformType) {
    switch(transformType) {
        case 'log':
            return 'log(' + originalLabel + ')';
        case 'z_score':
            return 'z(' + originalLabel + ')';
        case 'quantile':
            return 'quantile(' + originalLabel + ')';
        case 'inverse_cdf':
            return 'Φ(' + originalLabel + ')';
        case 'cumulative':
            return 'cumulative(' + originalLabel + ')';
        case 'cumprod':
            return 'cumprod(' + originalLabel + ')';
        case 'ewma':
            return 'ewma(' + originalLabel + ')';
        case 'ewmstd':
            return 'ewmstd(' + originalLabel + ')';
        case 'sma':
            return 'sma(' + originalLabel + ')';
        default:
            return originalLabel;
    }
}

// =============================================================================
// Expression Parser for ScatterTwo
// Supports: +, -, *, /, variable references (:var or var), and functions:
//   z(expr, [groups]) - z-score within groups
//   q(expr, [groups]) - quantile within groups
//   PCA1(var1, var2) - projection on first principal component
//   PCA2(var1, var2) - projection on second principal component
// =============================================================================

// Tokenizer for expression parsing
function tokenizeExpression(expr) {
    var tokens = [];
    var i = 0;
    while (i < expr.length) {
        var ch = expr[i];

        // Skip whitespace
        if (/\s/.test(ch)) { i++; continue; }

        // Operators and punctuation
        if ('+-*/(),[]'.indexOf(ch) !== -1) {
            tokens.push({ type: 'punct', value: ch });
            i++;
            continue;
        }

        // Numbers
        if (/[0-9.]/.test(ch)) {
            var num = '';
            while (i < expr.length && /[0-9.]/.test(expr[i])) {
                num += expr[i++];
            }
            tokens.push({ type: 'number', value: parseFloat(num) });
            continue;
        }

        // Variable with colon prefix :varname
        if (ch === ':') {
            i++; // skip colon
            var name = '';
            while (i < expr.length && /[a-zA-Z0-9_]/.test(expr[i])) {
                name += expr[i++];
            }
            tokens.push({ type: 'variable', value: name });
            continue;
        }

        // Identifiers (function names or variable names without colon)
        if (/[a-zA-Z_]/.test(ch)) {
            var ident = '';
            while (i < expr.length && /[a-zA-Z0-9_]/.test(expr[i])) {
                ident += expr[i++];
            }
            // Check if it's a function (followed by open paren)
            var j = i;
            while (j < expr.length && /\s/.test(expr[j])) j++;
            if (j < expr.length && expr[j] === '(') {
                tokens.push({ type: 'function', value: ident });
            } else {
                tokens.push({ type: 'variable', value: ident });
            }
            continue;
        }

        // Unknown character - skip
        i++;
    }
    return tokens;
}

// Simple recursive descent parser
function parseExpression(tokens, pos) {
    return parseAddSub(tokens, pos);
}

function parseAddSub(tokens, pos) {
    var result = parseMulDiv(tokens, pos);
    var node = result.node;
    pos = result.pos;

    while (pos < tokens.length && tokens[pos].type === 'punct' &&
           (tokens[pos].value === '+' || tokens[pos].value === '-')) {
        var op = tokens[pos].value;
        pos++;
        var right = parseMulDiv(tokens, pos);
        node = { type: 'binary', op: op, left: node, right: right.node };
        pos = right.pos;
    }
    return { node: node, pos: pos };
}

function parseMulDiv(tokens, pos) {
    var result = parseUnary(tokens, pos);
    var node = result.node;
    pos = result.pos;

    while (pos < tokens.length && tokens[pos].type === 'punct' &&
           (tokens[pos].value === '*' || tokens[pos].value === '/')) {
        var op = tokens[pos].value;
        pos++;
        var right = parseUnary(tokens, pos);
        node = { type: 'binary', op: op, left: node, right: right.node };
        pos = right.pos;
    }
    return { node: node, pos: pos };
}

function parseUnary(tokens, pos) {
    if (pos < tokens.length && tokens[pos].type === 'punct' && tokens[pos].value === '-') {
        pos++;
        var result = parseUnary(tokens, pos);
        return { node: { type: 'unary', op: '-', arg: result.node }, pos: result.pos };
    }
    return parsePrimary(tokens, pos);
}

function parsePrimary(tokens, pos) {
    if (pos >= tokens.length) {
        return { node: { type: 'number', value: 0 }, pos: pos };
    }

    var token = tokens[pos];

    // Number literal
    if (token.type === 'number') {
        return { node: { type: 'number', value: token.value }, pos: pos + 1 };
    }

    // Variable reference
    if (token.type === 'variable') {
        return { node: { type: 'variable', name: token.value }, pos: pos + 1 };
    }

    // Function call
    if (token.type === 'function') {
        var funcName = token.value;
        pos++; // skip function name
        if (pos < tokens.length && tokens[pos].value === '(') {
            pos++; // skip (
            var args = [];
            while (pos < tokens.length && tokens[pos].value !== ')') {
                // Check for array literal [...]
                if (tokens[pos].value === '[') {
                    pos++; // skip [
                    var arrayItems = [];
                    while (pos < tokens.length && tokens[pos].value !== ']') {
                        if (tokens[pos].type === 'variable') {
                            arrayItems.push(tokens[pos].value);
                        }
                        pos++;
                        if (pos < tokens.length && tokens[pos].value === ',') pos++;
                    }
                    if (pos < tokens.length && tokens[pos].value === ']') pos++;
                    args.push({ type: 'array', items: arrayItems });
                } else {
                    var argResult = parseExpression(tokens, pos);
                    args.push(argResult.node);
                    pos = argResult.pos;
                }
                if (pos < tokens.length && tokens[pos].value === ',') pos++;
            }
            if (pos < tokens.length && tokens[pos].value === ')') pos++;
            return { node: { type: 'function', name: funcName, args: args }, pos: pos };
        }
    }

    // Parenthesized expression
    if (token.type === 'punct' && token.value === '(') {
        pos++; // skip (
        var result = parseExpression(tokens, pos);
        pos = result.pos;
        if (pos < tokens.length && tokens[pos].value === ')') pos++;
        return { node: result.node, pos: pos };
    }

    // Default: return 0
    return { node: { type: 'number', value: 0 }, pos: pos + 1 };
}

// Evaluate parsed expression against data
// Returns an array of values, one per data row
function evaluateExpression(node, data) {
    if (!node) return data.map(function() { return 0; });

    switch (node.type) {
        case 'number':
            return data.map(function() { return node.value; });

        case 'variable':
            return data.map(function(row) {
                var val = row[node.name];
                return (typeof val === 'number') ? val : parseFloat(val) || 0;
            });

        case 'binary':
            var left = evaluateExpression(node.left, data);
            var right = evaluateExpression(node.right, data);
            return left.map(function(l, i) {
                var r = right[i];
                switch (node.op) {
                    case '+': return l + r;
                    case '-': return l - r;
                    case '*': return l * r;
                    case '/': return r !== 0 ? l / r : NaN;
                    default: return 0;
                }
            });

        case 'unary':
            var arg = evaluateExpression(node.arg, data);
            if (node.op === '-') {
                return arg.map(function(v) { return -v; });
            }
            return arg;

        case 'function':
            return evaluateFunction(node.name, node.args, data);

        default:
            return data.map(function() { return 0; });
    }
}

// Evaluate function calls
function evaluateFunction(name, args, data) {
    var lowerName = name.toLowerCase();

    // z(expr, [groups]) - z-score within groups
    if (lowerName === 'z') {
        var values = evaluateExpression(args[0], data);
        var groupCols = (args.length > 1 && args[1].type === 'array') ? args[1].items : [];
        return computeGroupedZScore(values, data, groupCols);
    }

    // q(expr, [groups]) - quantile within groups
    if (lowerName === 'q') {
        var values = evaluateExpression(args[0], data);
        var groupCols = (args.length > 1 && args[1].type === 'array') ? args[1].items : [];
        return computeGroupedQuantile(values, data, groupCols);
    }

    // PCA1(var1, var2) - first principal component
    if (lowerName === 'pca1') {
        if (args.length >= 2) {
            var v1 = evaluateExpression(args[0], data);
            var v2 = evaluateExpression(args[1], data);
            return computePCA(v1, v2, 1);
        }
        return data.map(function() { return 0; });
    }

    // PCA2(var1, var2) - second principal component
    if (lowerName === 'pca2') {
        if (args.length >= 2) {
            var v1 = evaluateExpression(args[0], data);
            var v2 = evaluateExpression(args[1], data);
            return computePCA(v1, v2, 2);
        }
        return data.map(function() { return 0; });
    }

    // r(y, x) - OLS residual (y - fitted)
    if (lowerName === 'r') {
        if (args.length >= 2) {
            var y = evaluateExpression(args[0], data);
            var x = evaluateExpression(args[1], data);
            return computeOLSResidual(y, x);
        }
        return data.map(function() { return 0; });
    }

    // f(y, x) - OLS fitted value
    if (lowerName === 'f') {
        if (args.length >= 2) {
            var y = evaluateExpression(args[0], data);
            var x = evaluateExpression(args[1], data);
            return computeOLSFitted(y, x);
        }
        return data.map(function() { return 0; });
    }

    // c(expr, min, max) - clamp values between min and max
    // Use Infinity or -Infinity to only set one bound
    if (lowerName === 'c') {
        if (args.length >= 3) {
            var values = evaluateExpression(args[0], data);
            var minVal = evaluateExpression(args[1], data);
            var maxVal = evaluateExpression(args[2], data);

            // Get min/max bounds (they're arrays from evaluateExpression, but should be constant)
            var lo = minVal[0];
            var hi = maxVal[0];

            return values.map(function(v) {
                if (isNaN(v)) return v;
                if (v < lo) return lo;
                if (v > hi) return hi;
                return v;
            });
        }
        return data.map(function() { return 0; });
    }

    // Unknown function - return zeros
    return data.map(function() { return 0; });
}

// Compute z-score within groups
function computeGroupedZScore(values, data, groupCols) {
    if (groupCols.length === 0) {
        // No grouping - compute global z-score
        var validVals = values.filter(function(v) { return !isNaN(v) && isFinite(v); });
        if (validVals.length === 0) return values;
        var mean = validVals.reduce(function(a, b) { return a + b; }, 0) / validVals.length;
        var variance = validVals.reduce(function(a, b) { return a + (b - mean) * (b - mean); }, 0) / validVals.length;
        var std = Math.sqrt(variance);
        if (std === 0) return values.map(function() { return 0; });
        return values.map(function(v) { return (v - mean) / std; });
    }

    // Group by specified columns
    var groups = {};
    data.forEach(function(row, i) {
        var key = groupCols.map(function(col) { return row[col]; }).join('|');
        if (!groups[key]) groups[key] = { indices: [], values: [] };
        groups[key].indices.push(i);
        groups[key].values.push(values[i]);
    });

    // Compute z-score within each group
    var result = new Array(values.length);
    Object.keys(groups).forEach(function(key) {
        var g = groups[key];
        var validVals = g.values.filter(function(v) { return !isNaN(v) && isFinite(v); });
        if (validVals.length === 0) {
            g.indices.forEach(function(i) { result[i] = NaN; });
            return;
        }
        var mean = validVals.reduce(function(a, b) { return a + b; }, 0) / validVals.length;
        var variance = validVals.reduce(function(a, b) { return a + (b - mean) * (b - mean); }, 0) / validVals.length;
        var std = Math.sqrt(variance);
        g.indices.forEach(function(idx, j) {
            result[idx] = std === 0 ? 0 : (g.values[j] - mean) / std;
        });
    });
    return result;
}

// Compute quantile within groups
function computeGroupedQuantile(values, data, groupCols) {
    if (groupCols.length === 0) {
        // No grouping - compute global quantile
        return computeQuantileTransform(values);
    }

    // Group by specified columns
    var groups = {};
    data.forEach(function(row, i) {
        var key = groupCols.map(function(col) { return row[col]; }).join('|');
        if (!groups[key]) groups[key] = { indices: [], values: [] };
        groups[key].indices.push(i);
        groups[key].values.push(values[i]);
    });

    // Compute quantile within each group
    var result = new Array(values.length);
    Object.keys(groups).forEach(function(key) {
        var g = groups[key];
        var quantiles = computeQuantileTransform(g.values);
        g.indices.forEach(function(idx, j) {
            result[idx] = quantiles[j];
        });
    });
    return result;
}

// Compute PCA projection
// component: 1 for first PC, 2 for second PC
function computePCA(v1, v2, component) {
    var n = v1.length;
    if (n === 0) return [];

    // Filter valid pairs
    var validIndices = [];
    for (var i = 0; i < n; i++) {
        if (!isNaN(v1[i]) && isFinite(v1[i]) && !isNaN(v2[i]) && isFinite(v2[i])) {
            validIndices.push(i);
        }
    }

    if (validIndices.length < 2) {
        return v1.map(function() { return 0; });
    }

    // Compute means
    var mean1 = 0, mean2 = 0;
    validIndices.forEach(function(i) {
        mean1 += v1[i];
        mean2 += v2[i];
    });
    mean1 /= validIndices.length;
    mean2 /= validIndices.length;

    // Compute covariance matrix elements
    var cov11 = 0, cov12 = 0, cov22 = 0;
    validIndices.forEach(function(i) {
        var d1 = v1[i] - mean1;
        var d2 = v2[i] - mean2;
        cov11 += d1 * d1;
        cov12 += d1 * d2;
        cov22 += d2 * d2;
    });
    cov11 /= validIndices.length;
    cov12 /= validIndices.length;
    cov22 /= validIndices.length;

    // Compute eigenvalues and eigenvectors of 2x2 covariance matrix
    // Using closed-form solution for 2x2 symmetric matrix
    var trace = cov11 + cov22;
    var det = cov11 * cov22 - cov12 * cov12;
    var discriminant = Math.sqrt(Math.max(0, trace * trace / 4 - det));
    var lambda1 = trace / 2 + discriminant; // larger eigenvalue
    var lambda2 = trace / 2 - discriminant; // smaller eigenvalue

    // Eigenvector for lambda1 (first PC)
    var ev1_x, ev1_y;
    if (Math.abs(cov12) > 1e-10) {
        ev1_x = lambda1 - cov22;
        ev1_y = cov12;
    } else {
        ev1_x = 1;
        ev1_y = 0;
    }
    var norm1 = Math.sqrt(ev1_x * ev1_x + ev1_y * ev1_y);
    if (norm1 > 0) { ev1_x /= norm1; ev1_y /= norm1; }

    // Eigenvector for lambda2 (second PC) - perpendicular to first
    var ev2_x = -ev1_y;
    var ev2_y = ev1_x;

    // Choose eigenvector based on component
    var ev_x = component === 1 ? ev1_x : ev2_x;
    var ev_y = component === 1 ? ev1_y : ev2_y;

    // Project all points onto the principal component
    var result = new Array(n);
    for (var i = 0; i < n; i++) {
        if (!isNaN(v1[i]) && isFinite(v1[i]) && !isNaN(v2[i]) && isFinite(v2[i])) {
            result[i] = (v1[i] - mean1) * ev_x + (v2[i] - mean2) * ev_y;
        } else {
            result[i] = NaN;
        }
    }
    return result;
}

// Compute OLS regression coefficients (y = alpha + beta * x)
// Returns {alpha, beta} or null if regression fails
function computeOLSCoefficients(y, x) {
    var n = y.length;
    if (n === 0 || n !== x.length) return null;

    // Filter to valid pairs only
    var validPairs = [];
    for (var i = 0; i < n; i++) {
        if (!isNaN(y[i]) && isFinite(y[i]) && !isNaN(x[i]) && isFinite(x[i])) {
            validPairs.push({ y: y[i], x: x[i] });
        }
    }

    if (validPairs.length < 2) return null;

    // Compute means
    var sumX = 0, sumY = 0;
    validPairs.forEach(function(p) {
        sumX += p.x;
        sumY += p.y;
    });
    var meanX = sumX / validPairs.length;
    var meanY = sumY / validPairs.length;

    // Compute beta = Cov(x,y) / Var(x)
    var covXY = 0, varX = 0;
    validPairs.forEach(function(p) {
        var dx = p.x - meanX;
        var dy = p.y - meanY;
        covXY += dx * dy;
        varX += dx * dx;
    });

    if (varX === 0) return null; // x has no variance

    var beta = covXY / varX;
    var alpha = meanY - beta * meanX;

    return { alpha: alpha, beta: beta };
}

// Compute OLS residuals: r(y, x) = y - fitted = y - (alpha + beta * x)
function computeOLSResidual(y, x) {
    var coef = computeOLSCoefficients(y, x);
    if (!coef) {
        return y.map(function() { return NaN; });
    }

    return y.map(function(yi, i) {
        if (isNaN(yi) || !isFinite(yi) || isNaN(x[i]) || !isFinite(x[i])) {
            return NaN;
        }
        var fitted = coef.alpha + coef.beta * x[i];
        return yi - fitted;
    });
}

// Compute OLS fitted values: f(y, x) = alpha + beta * x
function computeOLSFitted(y, x) {
    var coef = computeOLSCoefficients(y, x);
    if (!coef) {
        return y.map(function() { return NaN; });
    }

    return x.map(function(xi, i) {
        if (isNaN(y[i]) || !isFinite(y[i]) || isNaN(xi) || !isFinite(xi)) {
            return NaN;
        }
        return coef.alpha + coef.beta * xi;
    });
}

// Main function to evaluate an expression string against data
function evaluateExpressionString(exprString, data) {
    if (!exprString || exprString.trim() === '') {
        return data.map(function() { return 0; });
    }
    try {
        var tokens = tokenizeExpression(exprString);
        var parseResult = parseExpression(tokens, 0);
        return evaluateExpression(parseResult.node, data);
    } catch (e) {
        console.error('Expression parsing error:', e);
        return data.map(function() { return 0; });
    }
}

// =============================================================================
// End Expression Parser
// =============================================================================

// Setup aspect ratio control for a chart
// This should be called after the chart is first rendered
// Uses logarithmic scale for better precision at smaller aspect ratios
function setupAspectRatioControl(chartId, updateCallback) {
    var slider = document.getElementById(chartId + '_aspect_ratio_slider');
    var label = document.getElementById(chartId + '_aspect_ratio_label');

    if (!slider || !label) return; // Not all charts have aspect ratio control

    slider.addEventListener('input', function() {
        // Convert from log space to linear space
        var logValue = parseFloat(this.value);
        var aspectRatio = Math.exp(logValue);
        label.textContent = aspectRatio.toFixed(2);

        // Get current width of chart div
        var chartDiv = document.getElementById(chartId);
        if (!chartDiv) return;

        var width = chartDiv.offsetWidth;
        var height = width * aspectRatio;

        // Update chart layout with new height
        Plotly.relayout(chartId, { height: height });

        // Call the optional callback if provided
        if (updateCallback && typeof updateCallback === 'function') {
            updateCallback(height);
        }
    });

    // Trigger initial sizing
    var initialLogValue = parseFloat(slider.value);
    var initialAspectRatio = Math.exp(initialLogValue);
    label.textContent = initialAspectRatio.toFixed(2);
    var chartDiv = document.getElementById(chartId);
    if (chartDiv) {
        var width = chartDiv.offsetWidth;
        var height = width * initialAspectRatio;
        Plotly.relayout(chartId, { height: height });
    }
}

// This function parses data from embedded or external sources and returns a Promise
// Supports CSV (embedded/external), JSON (embedded/external), and Parquet (external) formats
// Usage: loadDataset('dataLabel').then(function(data) { /* use data */ });
// Note: Data elements have IDs prefixed with "data_" to avoid collisions with chart container IDs
function loadDataset(dataLabel) {
    return new Promise(function(resolve, reject) {
        // Sanitize the label: replace spaces and special chars with underscores
        var sanitizedLabel = dataLabel.replace(/[\s\-\.:/\\]/g, '_');
        var dataElementId = 'data_' + sanitizedLabel;
        var dataElement = document.getElementById(dataElementId);
        if (!dataElement) {
            reject(new Error('Data element not found: ' + dataElementId + ' (from label: ' + dataLabel + ')'));
            return;
        }

        var format = dataElement.getAttribute('data-format') || 'csv_embedded';
        var dataSrc = dataElement.getAttribute('data-src');

        // Handle external JSON files
        if (format === 'json_external' && dataSrc) {
            fetch(dataSrc)
                .then(function(response) {
                    if (!response.ok) {
                        throw new Error('Failed to load ' + dataSrc + ': ' + response.statusText);
                    }
                    return response.json();
                })
                .then(function(data) {
                    // Parse dates in JSON data (centralized)
                    resolve(parseDatesInData(data));
                })
                .catch(function(error) {
                    console.error('Error loading external JSON:', error);
                    reject(error);
                });
            return;
        }

        // Handle external Parquet files
        if (format === 'parquet' && dataSrc) {
            // Wait for parquet-wasm to be loaded first
            waitForParquet()
                .then(function() {
                    return fetch(dataSrc);
                })
                .then(function(response) {
                    if (!response.ok) {
                        throw new Error('Failed to load ' + dataSrc + ': ' + response.statusText);
                    }
                    return response.arrayBuffer();
                })
                .then(function(arrayBuffer) {
                    // Use parquet-wasm to read the file
                    var uint8Array = new Uint8Array(arrayBuffer);

                    // readParquet returns an Arrow Table
                    var wasmTable = window.parquetWasm.readParquet(uint8Array);

                    // Convert to Arrow IPC stream
                    var ipcStream = wasmTable.intoIPCStream();

                    // Use Apache Arrow JS to read the IPC stream
                    var arrowTable = window.Arrow.tableFromIPC(ipcStream);

                    // Convert Arrow Table to array of JavaScript objects
                    var data = [];
                    for (var i = 0; i < arrowTable.numRows; i++) {
                        var row = {};
                        arrowTable.schema.fields.forEach(function(field) {
                            var column = arrowTable.getChild(field.name);
                            var value = column.get(i);

                            // Convert BigInt to Number (Arrow returns BigInt for Int64)
                            if (typeof value === 'bigint') {
                                value = Number(value);
                            }

                            row[field.name] = value;
                        });
                        data.push(row);
                    }

                    // Parse dates in Parquet data (centralized date handling)
                    resolve(parseDatesInData(data));
                })
                .catch(function(error) {
                    console.error('Error loading external Parquet:', error);
                    reject(error);
                });
            return;
        }

        // Handle external CSV files
        if (format === 'csv_external' && dataSrc) {
            fetch(dataSrc)
                .then(function(response) {
                    if (!response.ok) {
                        throw new Error('Failed to load ' + dataSrc + ': ' + response.statusText);
                    }
                    return response.text();
                })
                .then(function(csvText) {
                    Papa.parse(csvText, {
                        header: true,
                        dynamicTyping: true,
                        skipEmptyLines: true,
                        complete: function(results) {
                            // Check for fatal errors only (not warnings)
                            var fatalErrors = results.errors.filter(function(err) {
                                return err.type !== 'Delimiter';
                            });

                            if (fatalErrors.length > 0) {
                                console.error('CSV parsing errors:', fatalErrors);
                                reject(fatalErrors);
                            } else if (results.data && results.data.length > 0) {
                                // Parse dates in CSV data (centralized)
                                resolve(parseDatesInData(results.data));
                            } else {
                                reject(new Error('No data parsed from CSV'));
                            }
                        },
                        error: function(error) {
                            console.error('CSV parsing error:', error);
                            reject(error);
                        }
                    });
                })
                .catch(function(error) {
                    console.error('Error loading external CSV:', error);
                    reject(error);
                });
            return;
        }

        // Handle embedded data
        var dataText = dataElement.textContent.trim();

        if (format === 'json_embedded') {
            // Parse JSON data
            try {
                var data = JSON.parse(dataText);
                // Parse dates in JSON data (centralized)
                resolve(parseDatesInData(data));
            } catch (error) {
                console.error('JSON parsing error:', error);
                reject(error);
            }
        } else if (format === 'csv_embedded') {
            // Parse CSV data using PapaParse
            Papa.parse(dataText, {
                header: true,
                dynamicTyping: true,
                skipEmptyLines: true,
                complete: function(results) {
                    // Check for fatal errors only (not warnings)
                    // PapaParse includes non-fatal warnings in errors array
                    var fatalErrors = results.errors.filter(function(err) {
                        // Filter out delimiter detection warnings - these aren't fatal
                        // (common for single-column CSVs)
                        return err.type !== 'Delimiter';
                    });

                    if (fatalErrors.length > 0) {
                        console.error('CSV parsing errors:', fatalErrors);
                        reject(fatalErrors);
                    } else if (results.data && results.data.length > 0) {
                        // Parse dates in CSV data (centralized)
                        resolve(parseDatesInData(results.data));
                    } else {
                        reject(new Error('No data parsed from CSV'));
                    }
                },
                error: function(error) {
                    console.error('CSV parsing error:', error);
                    reject(error);
                }
            });
        } else {
            reject(new Error('Unsupported data format: ' + format));
        }
    });
}

$(function(){

// Global fix for PivotTable.js filter box positioning issue
// See: https://github.com/nicolaskruchten/pivottable/issues/865
// The library calculates position incorrectly - we fix it by repositioning after creation
(function() {
    if (window._pvtFilterBoxFixApplied) return; // Only apply once
    window._pvtFilterBoxFixApplied = true;

    var lastClickedTriangle = null;

    // Helper function to reposition the filter box
    function repositionFilterBox($box, triangle) {
        if (!triangle || !$box.length) return;

        // Get triangle position relative to viewport
        var triangleRect = triangle.getBoundingClientRect();

        // Get box dimensions (use defaults if not yet rendered)
        var boxWidth = $box.outerWidth() || 300;
        var boxHeight = $box.outerHeight() || 400;

        // Calculate position relative to viewport (for position:fixed)
        var newLeft = triangleRect.left;
        var newTop = triangleRect.bottom + 5;

        // Adjust if it would go off the right edge
        if (newLeft + boxWidth > window.innerWidth - 20) {
            newLeft = triangleRect.right - boxWidth;
        }

        // Adjust if it would go off the bottom edge
        if (newTop + boxHeight > window.innerHeight - 20) {
            newTop = triangleRect.top - boxHeight - 5;
        }

        // Ensure minimum positions
        if (newLeft < 10) newLeft = 10;
        if (newTop < 10) newTop = 10;

        // Use position:fixed for viewport-relative positioning
        $box.css({
            'position': 'fixed',
            'left': newLeft + 'px',
            'top': newTop + 'px'
        });
    }

    // Capture which triangle was clicked
    $(document).on('click', '.pvtTriangle', function(e) {
        lastClickedTriangle = this;
    });

    // Watch for filter box creation and fix position
    var observer = new MutationObserver(function(mutations) {
        mutations.forEach(function(mutation) {
            mutation.addedNodes.forEach(function(node) {
                if (node.nodeType === 1 && $(node).hasClass('pvtFilterBox')) {
                    var $box = $(node);
                    var triangle = lastClickedTriangle;

                    // Apply the fix multiple times to ensure it sticks after PivotTable.js finishes
                    // The library may set position after initial render
                    var timings = [0, 10, 50, 100, 200];
                    timings.forEach(function(delay) {
                        setTimeout(function() {
                            repositionFilterBox($box, triangle);
                        }, delay);
                    });

                    // Also reposition on any style changes to the box (in case library updates position)
                    var styleObserver = new MutationObserver(function(styleMutations) {
                        repositionFilterBox($box, triangle);
                    });
                    styleObserver.observe(node, { attributes: true, attributeFilter: ['style'] });

                    // Disconnect the style observer when the filter box is removed
                    var removalObserver = new MutationObserver(function(mutations) {
                        mutations.forEach(function(mutation) {
                            mutation.removedNodes.forEach(function(removedNode) {
                                if (removedNode === node) {
                                    styleObserver.disconnect();
                                    removalObserver.disconnect();
                                    lastClickedTriangle = null;
                                }
                            });
                        });
                    });
                    removalObserver.observe(document.body, { childList: true, subtree: true });
                }
            });
        });
    });

    observer.observe(document.body, { childList: true, subtree: true });
})();

___FUNCTIONAL_BIT___

});
</script>

<!-- DATASETS -->

___DATASETS___

<!-- ACTUAL CONTENT -->

<h1>___PAGE_HEADER___</h1>
<p>___NOTES___</p>

___PIVOT_TABLES___

<hr><p align="right"><small>This page was created using <a href="https://github.com/s-baumann/JSPlots.jl">JSPlots.jl</a> v___VERSION___.</small></p>
</body>
</html>
"""

function dataset_to_html(data_label::Symbol, df::DataFrame, format::Symbol=:csv_embedded)
    # Convert ZonedDateTime columns to DateTime for proper display
    df = convert_zoneddatetime_to_datetime(df)

    data_string = ""
    data_src = ""

    # Generate path - struct-extracted DataFrames (containing '.') use subfolder structure
    label_str = string(data_label)
    if contains(label_str, ".")
        parts = split(label_str, ".")
        parent_folder = parts[1]
        field_name = join(parts[2:end], ".")
        path_base = "data/$(parent_folder)/$(field_name)"
    else
        path_base = "data/$(label_str)"
    end

    if format == :csv_external
        # For external CSV, we just reference the file
        data_src = "$(path_base).csv"
        # No data content needed for external format
    elseif format == :json_external
        # For external JSON, we just reference the file
        data_src = "$(path_base).json"
        # No data content needed for external format
    elseif format == :parquet
        # For external Parquet, we just reference the file
        data_src = "$(path_base).parquet"
        # No data content needed for external format
    elseif format == :csv_embedded
        io_buffer = IOBuffer()
        CSV.write(io_buffer, df)
        data_string = String(take!(io_buffer))
    elseif format == :json_embedded
        # Convert DataFrame to array of dictionaries for JSON
        rows = []
        for row in eachrow(df)
            row_dict = Dict(String(col) => row[col] for col in names(df))
            push!(rows, row_dict)
        end
        # Pretty print JSON with indentation for readability
        data_string = JSON.json(rows, 2)
    else
        error("Unsupported format: $format")
    end

    # Escape only </script> to prevent premature script tag closing
    # Using <\/script> is safe in script tags and won't interfere with CSV/JSON parsing
    if !isempty(data_string)
        data_string_safe = replace(data_string, "</script>" => "<\\/script>")
        html_str = replace(DATASET_TEMPLATE, "___DATA1___" => "\n" * data_string_safe * "\n")
    else
        html_str = replace(DATASET_TEMPLATE, "___DATA1___" => "")
    end

    html_str = replace(html_str, "___DDATA_LABEL___" => sanitize_html_id(data_label, prefix="data_"))
    html_str = replace(html_str, "___DATA_FORMAT___" => string(format))
    html_str = replace(html_str, "___DATA_SRC___" => data_src)
    return html_str
end



function generate_bat_launcher(html_filename::String)
    """
    @echo off
    REM JSPlots Launcher Script for Windows
    REM Tries browsers in order: Brave, Chrome, Firefox, then system default

    set "HTML_FILE=%~dp0$(html_filename)"

    REM Try Brave Browser
    where brave.exe >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo Opening with Brave Browser...
        start brave.exe --allow-file-access-from-files "%HTML_FILE%"
        exit /b
    )

    REM Try Chrome
    where chrome.exe >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo Opening with Google Chrome...
        start chrome.exe --allow-file-access-from-files "%HTML_FILE%"
        exit /b
    )

    REM Try Chrome in Program Files
    if exist "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe" (
        echo Opening with Google Chrome...
        start "" "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe" --allow-file-access-from-files "%HTML_FILE%"
        exit /b
    )

    REM Try Chrome in Program Files (x86)
    if exist "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe" (
        echo Opening with Google Chrome...
        start "" "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe" --allow-file-access-from-files "%HTML_FILE%"
        exit /b
    )

    REM Try Firefox
    where firefox.exe >nul 2>&1
    if %ERRORLEVEL% EQU 0 (
        echo Opening with Firefox...
        start firefox.exe "%HTML_FILE%"
        exit /b
    )

    REM Try Firefox in Program Files
    if exist "C:\\Program Files\\Mozilla Firefox\\firefox.exe" (
        echo Opening with Firefox...
        start "" "C:\\Program Files\\Mozilla Firefox\\firefox.exe" "%HTML_FILE%"
        exit /b
    )

    REM Fallback to default browser
    echo Opening with default browser...
    start "" "%HTML_FILE%"
    """
end

function generate_sh_launcher(html_filename::String)
    """
    #!/bin/bash
    # JSPlots Launcher Script for Linux/macOS
    # Tries browsers in order: Brave, Chrome, Firefox, then system default

    SCRIPT_DIR="\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
    HTML_FILE="\$SCRIPT_DIR/$(html_filename)"

    # Create a temporary user data directory for Chromium-based browsers
    TEMP_USER_DIR="\$(mktemp -d)"

    # Try Brave Browser
    if command -v brave-browser &> /dev/null; then
        echo "Opening with Brave Browser..."
        brave-browser --allow-file-access-from-files --disable-web-security --user-data-dir="\$TEMP_USER_DIR" "\$HTML_FILE" &
        exit 0
    elif command -v brave &> /dev/null; then
        echo "Opening with Brave Browser..."
        brave --allow-file-access-from-files --disable-web-security --user-data-dir="\$TEMP_USER_DIR" "\$HTML_FILE" &
        exit 0
    fi

    # Try Google Chrome
    if command -v google-chrome &> /dev/null; then
        echo "Opening with Google Chrome..."
        google-chrome --allow-file-access-from-files --disable-web-security --user-data-dir="\$TEMP_USER_DIR" "\$HTML_FILE" &
        exit 0
    elif command -v chrome &> /dev/null; then
        echo "Opening with Chrome..."
        chrome --allow-file-access-from-files --disable-web-security --user-data-dir="\$TEMP_USER_DIR" "\$HTML_FILE" &
        exit 0
    fi

    # Try Chromium
    if command -v chromium-browser &> /dev/null; then
        echo "Opening with Chromium..."
        chromium-browser --allow-file-access-from-files --disable-web-security --user-data-dir="\$TEMP_USER_DIR" "\$HTML_FILE" &
        exit 0
    elif command -v chromium &> /dev/null; then
        echo "Opening with Chromium..."
        chromium --allow-file-access-from-files --disable-web-security --user-data-dir="\$TEMP_USER_DIR" "\$HTML_FILE" &
        exit 0
    fi

    # Try Firefox
    if command -v firefox &> /dev/null; then
        echo "Opening with Firefox..."
        firefox "\$HTML_FILE" &
        exit 0
    fi

    # Fallback to default browser
    echo "Opening with default browser..."
    if command -v xdg-open &> /dev/null; then
        xdg-open "\$HTML_FILE" &
    elif command -v open &> /dev/null; then
        # macOS
        open "\$HTML_FILE" &
    else
        echo "Could not find a suitable browser. Please open \$HTML_FILE manually."
        exit 1
    fi
    """
end

function generate_readme_content(html_filename::String)
    """
    # JSPlots Project Launcher Instructions

    This zip file was generated by JSPlots.jl and contains the necessary data files and HTML page to view your plots.

    ## Viewing the Plots

    To view the plots, it is suggested to use one of the launcher scripts to avoid permissions errros that can occur (if you open without heightened permissions the browser won't let the html load data stored on the local disk)
    
    If you cannot use the launcher scripts and cannot launch your browser with higher permissions then you can try to remake the plots with dataformat = :csv_embedded or :json_embedded in JSPlots.jl.
    This stores the data in plaintext in the html file so no special permissions are needed to view the plots. That does mean the files are huge though.

    ## Pull requests

    Pull requests are welcome if you find any improvements. Feel free to submit them on the [JSPlots.jl GitHub repository](https://github.com/s-baumann/JSPlots.jl).
    """
end


"""
    generate_data_source_attribution(data_label::Symbol, dataformat::Symbol)

Generate HTML for data source attribution text.
Returns a small text element showing the data source based on the dataformat.
"""
function generate_data_source_attribution(data_label::Symbol, dataformat::Symbol)
    data_text = if dataformat == :parquet
        "Data: $(string(data_label)).parquet"
    elseif dataformat == :csv_external
        "Data: $(string(data_label)).csv"
    elseif dataformat == :json_external
        "Data: $(string(data_label)).json"
    else  # embedded formats
        "Data: $(string(data_label))"
    end

    return """<p style="text-align: right; font-size: 0.8em; color: #666; margin-top: -10px; margin-bottom: 10px;">$data_text</p>"""
end

"""
    generate_picture_attribution(image_path::String)

Generate HTML for picture source attribution text.
Returns a small text element showing the picture filename.
"""
function generate_picture_attribution(image_path::String)
    filename = basename(image_path)
    return """<p style="text-align: right; font-size: 0.8em; color: #666; margin-top: -10px; margin-bottom: 10px;">$filename</p>"""
end

"""
    create_html(obj, [df], outfile_path::String)

Creates an HTML file from a JSPlotPage, Pages, or a single plot.

# Arguments
- `obj`: A JSPlotPage, Pages object, or a single plot (PivotTable, LineChart, etc.)
- `df`: DataFrame (required for single plots that need data)
- `outfile_path::String`: Path where the HTML file will be saved (default: `"pivottable.html"`)

# Single Plot Usage
```julia
create_html(plot, dataframe, "output.html")
```

# JSPlotPage Usage
```julia
page = JSPlotPage(dataframes_dict, plots_array)
create_html(page, "output.html")
```

# Pages (Multi-page) Usage
```julia
report = Pages(coverpage, [page1, page2])
create_html(report, "index.html")
```
"""
function create_html(pt::JSPlotPage, outfile_path::String="pivottable.html";
                     manifest::Union{String,Nothing}=nothing,
                     manifest_entry::Union{ManifestEntry,Nothing}=nothing)
    # Collect extra styles needed for TextBlock, Notes, Picture, and Table
    extra_styles = ""
    has_textblock = any(p -> isa(p, TextBlock), pt.pivot_tables)
    has_notes = any(p -> isa(p, Notes), pt.pivot_tables)
    has_picture = any(p -> isa(p, Picture), pt.pivot_tables)
    has_table = any(p -> isa(p, Table), pt.pivot_tables)

    if has_textblock
        extra_styles *= TEXTBLOCK_STYLE
    end
    if has_notes
        extra_styles *= NOTES_STYLE
    end
    if has_picture
        extra_styles *= PICTURE_STYLE
    end
    if has_table
        extra_styles *= TABLE_STYLE
    end

    # Collect Prism.js language components needed for CodeBlocks (base Prism is in JS_DEP_PRISM)
    prism_languages = JSPlots.get_languages_from_codeblocks(pt.pivot_tables)
    prism_scripts = if isempty(prism_languages)
        ""
    else
        join(["""    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-$lang.min.js"></script>"""
              for lang in prism_languages], "\n")
    end

    # Collect JavaScript dependencies from all plot types on this page
    all_js_deps = reduce(vcat, js_dependencies.(pt.pivot_tables); init=String[])

    # Add dataformat-specific dependencies (PapaParse for CSV formats)
    if pt.dataformat in [:csv_embedded, :csv_external]
        append!(all_js_deps, JS_DEP_CSV)
    end

    unique_js_deps = unique(all_js_deps)
    js_dependencies_html = isempty(unique_js_deps) ? "" : join(["    " * dep for dep in unique_js_deps], "\n")

    # Parquet support script (only needed for parquet dataformat)
    parquet_script = if pt.dataformat == :parquet
        join(JS_DEP_PARQUET, "\n")
    else
        ""
    end

    # Handle external formats (csv_external, json_external, parquet) differently
    if pt.dataformat in [:csv_external, :json_external, :parquet]
        # For external formats, create a subfolder structure
        # e.g., "generated_html_examples/pivottable.html" becomes
        #       "generated_html_examples/pivottable/pivottable.html"

        original_dir = dirname(outfile_path)
        original_name = basename(outfile_path)
        name_without_ext = splitext(original_name)[1]

        # Create the project folder: original_dir/name_without_ext/
        project_dir = isempty(original_dir) ? name_without_ext : joinpath(original_dir, name_without_ext)
        if !isdir(project_dir)
            mkpath(project_dir)
        end

        # HTML file goes in the project folder with the same name
        actual_html_path = joinpath(project_dir, original_name)

        # Create data subdirectory within project folder
        data_dir = joinpath(project_dir, "data")
        if !isdir(data_dir)
            mkpath(data_dir)
        end

        # Get list of dataframes referenced by charts
        referenced_data = reduce(vcat, dependencies.(pt.pivot_tables); init=Symbol[])
        # If no charts reference any data, save all dataframes; otherwise only save referenced ones
        files_to_do = isempty(referenced_data) ? collect(keys(pt.dataframes)) : intersect(collect(keys(pt.dataframes)), referenced_data)
        # Save all dataframes as separate files based on format
        # Uses save_dataframe helper which handles subfolder structure for struct-extracted DataFrames
        for data_label in files_to_do
            df = pt.dataframes[data_label]
            save_dataframe(data_label, df, data_dir, pt.dataformat)
        end

        # Generate HTML content - handle Picture types specially
        data_set_bit   = isempty(pt.dataframes) ? "" : reduce(*, [dataset_to_html(k, v, pt.dataformat) for (k,v) in pt.dataframes])
        functional_bit = ""
        table_bit = ""

        for (i, pti) in enumerate(pt.pivot_tables)
            sp = i == 1 ? "" : SEGMENT_SEPARATOR
            if isa(pti, Picture)
                # Generate Picture HTML based on dataformat
                if !isempty(pti.functional_html)
                    functional_bit *= pti.functional_html
                end
                table_bit *= sp * generate_picture_html(pti, pt.dataformat, project_dir)
                # Add picture attribution only for single-image Pictures
                if pti.image_path !== nothing
                    table_bit *= "<br>" * generate_picture_attribution(pti.image_path)
                end
            elseif isa(pti, TextBlock)
                # Generate TextBlock HTML, handling images if present
                if !isempty(pti.images)
                    table_bit *= sp * generate_textblock_html(pti, pt.dataformat, project_dir)
                else
                    # No images, use original appearance_html for backward compatibility
                    table_bit *= sp * replace(TEXTBLOCK_TEMPLATE, "___HTML_CONTENT___" => pti.html_content)
                end
                # TextBlock has no functional HTML
            elseif isa(pti, Notes)
                # Generate Notes HTML and JavaScript based on dataformat
                notes_result = generate_notes_html(pti, pt.dataformat, project_dir)
                table_bit *= sp * notes_result.html
                if !isempty(notes_result.js)
                    functional_bit *= notes_result.js
                end
            elseif isa(pti, Slides)
                # Generate Slides HTML based on dataformat
                functional_bit *= pti.functional_html
                table_bit *= sp * generate_slides_html(pti, pt.dataformat, project_dir)
                # Slides has no data attribution (uses :no_data label)
            elseif isa(pti, Table)
                functional_bit *= pti.functional_html
                table_bit *= sp * pti.appearance_html
                # Add table attribution (Table is self-contained, use chart_title)
                table_bit *= """<br><p style="text-align: right; font-size: 0.8em; color: #666; margin-top: -10px; margin-bottom: 10px;">Data: $(string(pti.chart_title))</p>"""
            elseif hasfield(typeof(pti), :data_label)
                functional_bit *= pti.functional_html
                table_bit *= sp * pti.appearance_html
                # Add data source attribution for charts with data_label
                table_bit *= "<br>" * generate_data_source_attribution(pti.data_label, pt.dataformat)
            else
                functional_bit *= pti.functional_html
                table_bit *= sp * pti.appearance_html
            end
        end

        # Get package version
        version_str = try
            string(pkgversion(JSPlots))
        catch
            "unknown"
        end

        full_page_html = replace(FULL_PAGE_TEMPLATE, "___DATASETS___" => data_set_bit)
        full_page_html = replace(full_page_html, "___PIVOT_TABLES___" => table_bit)
        full_page_html = replace(full_page_html, "___FUNCTIONAL_BIT___" => functional_bit)
        full_page_html = replace(full_page_html, "___TITLE_OF_PAGE___" => pt.tab_title)
        full_page_html = replace(full_page_html, "___PAGE_HEADER___" => pt.page_header)
        full_page_html = replace(full_page_html, "___NOTES___" => pt.notes)
        full_page_html = replace(full_page_html, "___EXTRA_STYLES___" => extra_styles)
        full_page_html = replace(full_page_html, "___JS_DEPENDENCIES___" => js_dependencies_html)
        full_page_html = replace(full_page_html, "___PRISM_LANGUAGES___" => prism_scripts)
        full_page_html = replace(full_page_html, "___PARQUET_SCRIPT___" => parquet_script)
        full_page_html = replace(full_page_html, "___VERSION___" => version_str)

        # Save HTML file
        open(actual_html_path, "w") do outfile
            write(outfile, full_page_html)
        end
        println("HTML page saved to $actual_html_path")

        # Generate launcher scripts in the project folder
        bat_path = joinpath(project_dir, "open.bat")
        sh_path = joinpath(project_dir, "open.sh")
        readme_path = joinpath(project_dir, "README.md")

        open(bat_path, "w") do f
            write(f, generate_bat_launcher(original_name))
        end

        open(sh_path, "w") do f
            write(f, generate_sh_launcher(original_name))
        end
        open(readme_path, "w") do f
            write(f, generate_readme_content(original_name))
        end
        # Make shell script executable on Unix-like systems
        try
            chmod(sh_path, 0o755)
        catch
            # Silently fail on Windows
        end


    else
        # Original embedded format logic
        data_set_bit   = isempty(pt.dataframes) ? "" : reduce(*, [dataset_to_html(k, v, pt.dataformat) for (k,v) in pt.dataframes])
        functional_bit = ""
        table_bit = ""



        for (i, pti) in enumerate(pt.pivot_tables)
            sp = i == 1 ? "" : SEGMENT_SEPARATOR
            if isa(pti, Picture)
                # Generate Picture HTML based on dataformat (embedded)
                if !isempty(pti.functional_html)
                    functional_bit *= pti.functional_html
                end
                table_bit *= sp * generate_picture_html(pti, pt.dataformat, "")
                # Add picture attribution only for single-image Pictures
                if pti.image_path !== nothing
                    table_bit *= "<br>" * generate_picture_attribution(pti.image_path)
                end
            elseif isa(pti, TextBlock)
                # Generate TextBlock HTML, handling images if present
                if !isempty(pti.images)
                    table_bit *= sp * generate_textblock_html(pti, pt.dataformat, "")
                else
                    # No images, use original template for backward compatibility
                    table_bit *= sp * replace(TEXTBLOCK_TEMPLATE, "___HTML_CONTENT___" => pti.html_content)
                end
                # TextBlock has no functional HTML
            elseif isa(pti, Notes)
                # Generate Notes HTML and JavaScript based on dataformat (embedded)
                notes_result = generate_notes_html(pti, pt.dataformat, "")
                table_bit *= sp * notes_result.html
                if !isempty(notes_result.js)
                    functional_bit *= notes_result.js
                end
            elseif isa(pti, Slides)
                # Generate Slides HTML based on dataformat (embedded)
                functional_bit *= pti.functional_html
                table_bit *= sp * generate_slides_html(pti, pt.dataformat, "")
                # Slides has no data attribution (uses :no_data label)
            elseif isa(pti, Table)
                functional_bit *= pti.functional_html
                table_bit *= sp * pti.appearance_html
                # Add table attribution (Table is self-contained, use chart_title)
                table_bit *= """<br><p style="text-align: right; font-size: 0.8em; color: #666; margin-top: -10px; margin-bottom: 10px;">Data: $(string(pti.chart_title))</p>"""
            elseif hasfield(typeof(pti), :data_label)
                functional_bit *= pti.functional_html
                table_bit *= sp * pti.appearance_html
                # Add data source attribution for charts with data_label
                table_bit *= "<br>" * generate_data_source_attribution(pti.data_label, pt.dataformat)
            else
                functional_bit *= pti.functional_html
                table_bit *= sp * pti.appearance_html
            end
        end

        # Get package version
        version_str = try
            string(pkgversion(JSPlots))
        catch
            "unknown"
        end

        full_page_html = replace(FULL_PAGE_TEMPLATE, "___DATASETS___" => data_set_bit)
        full_page_html = replace(full_page_html, "___PIVOT_TABLES___" => table_bit)
        full_page_html = replace(full_page_html, "___FUNCTIONAL_BIT___" => functional_bit)
        full_page_html = replace(full_page_html, "___TITLE_OF_PAGE___" => pt.tab_title)
        full_page_html = replace(full_page_html, "___PAGE_HEADER___" => pt.page_header)
        full_page_html = replace(full_page_html, "___NOTES___" => pt.notes)
        full_page_html = replace(full_page_html, "___EXTRA_STYLES___" => extra_styles)
        full_page_html = replace(full_page_html, "___JS_DEPENDENCIES___" => js_dependencies_html)
        full_page_html = replace(full_page_html, "___PRISM_LANGUAGES___" => prism_scripts)
        full_page_html = replace(full_page_html, "___PARQUET_SCRIPT___" => parquet_script)
        full_page_html = replace(full_page_html, "___VERSION___" => version_str)

        open(outfile_path, "w") do outfile
            write(outfile, full_page_html)
        end

        println("Saved to $outfile_path")

        # Add to manifest if specified
        if manifest !== nothing && manifest_entry !== nothing
            add_to_manifest(manifest, manifest_entry; fill_missing=true)
        end
    end

    # Clean up temporary files for Picture and Slides objects
    for pti in pt.pivot_tables
        if isa(pti, Picture) && pti.is_temp
            try
                rm(pti.image_path, force=true)
            catch e
                @warn "Could not delete temporary file $(pti.image_path): $e"
            end
        elseif isa(pti, Slides) && pti.is_temp
            # Clean up temp directory with all generated slides
            for img_file in pti.image_files
                try
                    rm(img_file, force=true)
                catch e
                    @warn "Could not delete temporary slide file $(img_file): $e"
                end
            end
            # Try to remove the temp directory if empty
            try
                temp_dir = dirname(first(pti.image_files))
                if isdir(temp_dir)
                    rm(temp_dir, force=true, recursive=true)
                end
            catch e
                @warn "Could not delete temporary directory: $e"
            end
        end
    end
end

function create_html(pt::JSPlotsType, dd::DataFrame, outfile_path::String="pivottable.html")
    pge = JSPlotPage(Dict{Symbol,DataFrame}(pt.data_label => dd), [pt])
    create_html(pge,outfile_path)
end

# Convenience method for Table (no DataFrame needed - it's embedded in the Table)
function create_html(pt::Table, outfile_path::String="pivottable.html")
    pge = JSPlotPage(Dict{Symbol,DataFrame}(), [pt])
    create_html(pge,outfile_path)
end

# Convenience method for Picture (no DataFrame needed)
function create_html(pt::Picture, outfile_path::String="pivottable.html")
    pge = JSPlotPage(Dict{Symbol,DataFrame}(), [pt])
    create_html(pge,outfile_path)
end

"""
    generate_page_html(page::JSPlotPage, dataframes::Dict{Symbol,DataFrame}, dataformat::Symbol, project_dir::String="")

Helper function to generate HTML content for a single page without creating folders.
Returns the HTML string directly.
"""
function generate_page_html(page::JSPlotPage, dataframes::Dict{Symbol,DataFrame}, dataformat::Symbol, project_dir::String="")
    # Collect extra styles
    extra_styles = ""
    has_textblock = any(p -> isa(p, TextBlock), page.pivot_tables)
    has_notes = any(p -> isa(p, Notes), page.pivot_tables)
    has_picture = any(p -> isa(p, Picture), page.pivot_tables)
    has_table = any(p -> isa(p, Table), page.pivot_tables)

    if has_textblock
        extra_styles *= TEXTBLOCK_STYLE
    end
    if has_notes
        extra_styles *= NOTES_STYLE
    end
    if has_picture
        extra_styles *= PICTURE_STYLE
    end
    if has_table
        extra_styles *= TABLE_STYLE
    end

    # Collect Prism.js language components needed for CodeBlocks
    prism_languages = JSPlots.get_languages_from_codeblocks(page.pivot_tables)
    prism_scripts = if isempty(prism_languages)
        ""
    else
        join(["""    <script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-$lang.min.js"></script>"""
              for lang in prism_languages], "\n")
    end

    # Collect JavaScript dependencies from all plot types on this page
    all_js_deps = reduce(vcat, js_dependencies.(page.pivot_tables); init=String[])

    # Add dataformat-specific dependencies (PapaParse for CSV formats)
    if dataformat in [:csv_embedded, :csv_external]
        append!(all_js_deps, JS_DEP_CSV)
    end

    unique_js_deps = unique(all_js_deps)
    js_dependencies_html = isempty(unique_js_deps) ? "" : join(["    " * dep for dep in unique_js_deps], "\n")

    # Parquet support script (only needed for parquet dataformat)
    parquet_script = if dataformat == :parquet
        join(JS_DEP_PARQUET, "\n")
    else
        ""
    end

    # Generate datasets HTML
    data_set_bit = isempty(dataframes) ? "" : reduce(*, [dataset_to_html(k, v, dataformat) for (k,v) in dataframes])

    # Generate functional and appearance HTML for plots
    functional_bit = ""
    table_bit = ""

    for (i, pti) in enumerate(page.pivot_tables)
        sp = i == 1 ? "" : SEGMENT_SEPARATOR

        if isa(pti, Picture)
            # Pictures are embedded as base64 for simplicity in multi-page context
            if !isempty(pti.functional_html)
                functional_bit *= pti.functional_html
            end
            table_bit *= sp * generate_picture_html(pti, :csv_embedded, "")
            if pti.image_path !== nothing
                table_bit *= "<br>" * generate_picture_attribution(pti.image_path)
            end
        elseif isa(pti, TextBlock)
            if !isempty(pti.images)
                table_bit *= sp * generate_textblock_html(pti, :csv_embedded, "")
            else
                table_bit *= sp * replace(TEXTBLOCK_TEMPLATE, "___HTML_CONTENT___" => pti.html_content)
            end
        elseif isa(pti, Notes)
            # Generate Notes HTML and JavaScript based on dataformat
            notes_result = generate_notes_html(pti, dataformat, project_dir)
            table_bit *= sp * notes_result.html
            if !isempty(notes_result.js)
                functional_bit *= notes_result.js
            end
        elseif isa(pti, Slides)
            # Slides always use external images in slides/ directory
            functional_bit *= pti.functional_html
            table_bit *= sp * generate_slides_html(pti, dataformat, project_dir)
        elseif isa(pti, Table)
            functional_bit *= pti.functional_html
            table_bit *= sp * pti.appearance_html
            table_bit *= """<br><p style="text-align: right; font-size: 0.8em; color: #666; margin-top: -10px; margin-bottom: 10px;">Data: $(string(pti.chart_title))</p>"""
        elseif hasfield(typeof(pti), :data_label)
            functional_bit *= pti.functional_html
            table_bit *= sp * pti.appearance_html
            table_bit *= "<br>" * generate_data_source_attribution(pti.data_label, dataformat)
        else
            if hasfield(typeof(pti), :functional_html)
                functional_bit *= pti.functional_html
            end
            table_bit *= sp * pti.appearance_html
        end
    end

    # Build full page HTML
    # Get package version
    version_str = try
        string(pkgversion(@__MODULE__))
    catch
        "unknown"
    end

    full_page_html = replace(FULL_PAGE_TEMPLATE, "___DATASETS___" => data_set_bit)
    full_page_html = replace(full_page_html, "___PIVOT_TABLES___" => table_bit)
    full_page_html = replace(full_page_html, "___FUNCTIONAL_BIT___" => functional_bit)
    full_page_html = replace(full_page_html, "___TITLE_OF_PAGE___" => page.tab_title)
    full_page_html = replace(full_page_html, "___PAGE_HEADER___" => page.page_header)
    full_page_html = replace(full_page_html, "___NOTES___" => page.notes)
    full_page_html = replace(full_page_html, "___EXTRA_STYLES___" => extra_styles)
    full_page_html = replace(full_page_html, "___JS_DEPENDENCIES___" => js_dependencies_html)
    full_page_html = replace(full_page_html, "___PRISM_LANGUAGES___" => prism_scripts)
    full_page_html = replace(full_page_html, "___PARQUET_SCRIPT___" => parquet_script)
    full_page_html = replace(full_page_html, "___VERSION___" => version_str)

    return full_page_html
end

"""
    save_dataframe(data_label::Symbol, df::DataFrame, data_dir::String, dataformat::Symbol)

Helper function to save a single DataFrame in the specified format.
Supports subfolder storage for struct-extracted DataFrames (labels containing '.').
For example, `Symbol("my_struct.field")` saves to `data/my_struct/field.parquet`.
"""
function save_dataframe(data_label::Symbol, df::DataFrame, data_dir::String, dataformat::Symbol)
    # Convert ZonedDateTime columns to DateTime for proper display
    df = convert_zoneddatetime_to_datetime(df)

    # Check if this is a struct-extracted DataFrame (contains '.')
    # Struct-extracted DataFrames use subfolder structure: data/struct_name/field.parquet
    label_str = string(data_label)
    if contains(label_str, ".")
        # Split on '.' to get parent folder and field name
        parts = split(label_str, ".")
        parent_folder = parts[1]
        field_name = join(parts[2:end], ".")  # Handle unlikely case of multiple dots

        # Create subfolder
        subfolder = joinpath(data_dir, parent_folder)
        if !isdir(subfolder)
            mkpath(subfolder)
        end

        file_base = field_name
        target_dir = subfolder
    else
        file_base = label_str
        target_dir = data_dir
    end

    if dataformat == :csv_external
        file_path = joinpath(target_dir, "$(file_base).csv")
        CSV.write(file_path, df)
        println("  Data saved to $file_path")
    elseif dataformat == :json_external
        file_path = joinpath(target_dir, "$(file_base).json")
        rows = []
        for row in eachrow(df)
            row_dict = Dict(String(col) => row[col] for col in names(df))
            push!(rows, row_dict)
        end
        open(file_path, "w") do f
            write(f, JSON.json(rows, 2))
        end
        println("  Data saved to $file_path")
    elseif dataformat == :parquet
        file_path = joinpath(target_dir, "$(file_base).parquet")
        con = DBInterface.connect(DuckDB.DB)

        # Convert Symbol columns to String (ZonedDateTime already converted above)
        df_converted = copy(df)
        for col in names(df_converted)
            col_type = eltype(df_converted[!, col])
            if col_type <: Symbol || (col_type isa Union && Symbol in Base.uniontypes(col_type))
                df_converted[!, col] = string.(df_converted[!, col])
            end
        end

        DuckDB.register_data_frame(con, df_converted, "temp_table")
        DBInterface.execute(con, "COPY temp_table TO '$file_path' (FORMAT PARQUET)")
        DBInterface.close!(con)
        println("  Data saved to $file_path")
    end
end

# Method for Pages - creates multiple HTML files with shared data in a flat structure
function create_html(jsp::Pages, outfile_path::String="index.html";
                     manifest::Union{String,Nothing}=nothing,
                     manifest_entry::Union{ManifestEntry,Nothing}=nothing)
    # Extract directory and base name
    original_dir = dirname(outfile_path)
    original_name = basename(outfile_path)
    name_without_ext = splitext(original_name)[1]

    # Create project folder (flat structure: all HTML files at same level)
    project_dir = isempty(original_dir) ? name_without_ext : joinpath(original_dir, name_without_ext)
    if !isdir(project_dir)
        mkpath(project_dir)
    end

    # Collect all unique dataframes across all pages
    all_dataframes = Dict{Symbol, DataFrame}()
    merge!(all_dataframes, jsp.coverpage.dataframes)
    for page in jsp.pages
        merge!(all_dataframes, page.dataframes)
    end

    # If using external data format, create data directory and save each datasource once
    if jsp.dataformat in [:csv_external, :json_external, :parquet]
        data_dir = joinpath(project_dir, "data")
        if !isdir(data_dir)
            mkpath(data_dir)
        end

        # Collect all data dependencies across all pages
        all_dependencies = Set{Symbol}()
        for pt in jsp.coverpage.pivot_tables
            union!(all_dependencies, dependencies(pt))
        end
        for page in jsp.pages
            for pt in page.pivot_tables
                union!(all_dependencies, dependencies(pt))
            end
        end

        # Save each unique datasource only once
        for data_label in all_dependencies
            if haskey(all_dataframes, data_label)
                save_dataframe(data_label, all_dataframes[data_label], data_dir, jsp.dataformat)
            end
        end
    end

    # Generate coverpage HTML
    coverpage_path = joinpath(project_dir, original_name)
    coverpage_html = generate_page_html(jsp.coverpage, all_dataframes, jsp.dataformat, project_dir)
    open(coverpage_path, "w") do f
        write(f, coverpage_html)
    end
    println("Created coverpage: $coverpage_path")

    # Generate each subpage HTML using sanitized tab_title
    # Note: We need to use the same sanitize_filename function used in Pages.jl
    # to ensure links match filenames
    for (i, page) in enumerate(jsp.pages)
        sanitized_name = sanitize_filename(page.tab_title)
        page_filename = "$(sanitized_name).html"
        page_path = joinpath(project_dir, page_filename)
        page_html = generate_page_html(page, all_dataframes, jsp.dataformat, project_dir)
        open(page_path, "w") do f
            write(f, page_html)
        end
        println("Created page '$(page.tab_title)': $page_path")
    end

    # Generate launcher scripts at project root
    bat_path = joinpath(project_dir, "open.bat")
    sh_path = joinpath(project_dir, "open.sh")
    readme_path = joinpath(project_dir, "README.md")

    open(bat_path, "w") do f
        write(f, generate_bat_launcher(original_name))
    end

    open(sh_path, "w") do f
        write(f, generate_sh_launcher(original_name))
    end

    open(readme_path, "w") do f
        write(f, generate_readme_content(original_name))
    end

    # Make shell script executable on Unix-like systems
    try
        chmod(sh_path, 0o755)
    catch
        # Silently fail on Windows
    end

    println("\nMulti-page project created:")
    println("  Location: $project_dir")
    println("  Main page: $original_name")
    println("  Subpages: $(length(jsp.pages))")
    for page in jsp.pages
        sanitized_name = sanitize_filename(page.tab_title)
        println("    - $(page.tab_title): $(sanitized_name).html")
    end
    if jsp.dataformat in [:csv_external, :json_external, :parquet]
        println("  Data format: $(jsp.dataformat) (shared in data/ folder)")
    else
        println("  Data format: $(jsp.dataformat) (embedded in each HTML)")
    end

    # Add to manifest if specified
    if manifest !== nothing && manifest_entry !== nothing
        add_to_manifest(manifest, manifest_entry; fill_missing=true)
    end
end
