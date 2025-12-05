
struct Chart3d <: JSPlotsType
    chart_title::Symbol
    data_label::Symbol
    functional_html::String
    appearance_html::String
    function Chart3d(chart_title::Symbol, data_label::Symbol;
                            height::Int=600,
                            x_col::Symbol=:x,
                            y_col::Symbol=:y,
                            z_col::Symbol=:z,
                            group_col::Symbol=:group,
                            title::String="3D Chart",
                            x_label::String="",
                            y_label::String="",
                            z_label::String="",
                            notes::String="")
       

        functional_html = """
            // Load and parse CSV data using centralized parser
            loadDataset('$data_label').then(function(data3d) {
                // ========== 3D SURFACE PLOT CONFIGURATION ==========
                // Define your column names here
                const x = '$x_col';
                const y = '$y_col';
                const z = '$z_col';
                const group = '$group_col';
                // ===================================================
                        
                        // Get unique groups
                        const uniqueGroups = [...new Set(data3d.map(row => row[group]))].sort();
                        
                        // Define a set of distinct color gradients
                        const colorGradients = [
                            // Blue gradient
                            [[0, 'rgb(8,48,107)'], [0.25, 'rgb(33,102,172)'], [0.5, 'rgb(67,147,195)'], [0.75, 'rgb(146,197,222)'], [1, 'rgb(209,229,240)']],
                            // Red-Orange gradient
                            [[0, 'rgb(127,0,0)'], [0.25, 'rgb(189,0,38)'], [0.5, 'rgb(227,74,51)'], [0.75, 'rgb(252,141,89)'], [1, 'rgb(253,204,138)']],
                            // Green gradient
                            [[0, 'rgb(0,68,27)'], [0.25, 'rgb(0,109,44)'], [0.5, 'rgb(35,139,69)'], [0.75, 'rgb(116,196,118)'], [1, 'rgb(199,233,192)']],
                            // Purple gradient
                            [[0, 'rgb(63,0,125)'], [0.25, 'rgb(106,81,163)'], [0.5, 'rgb(158,154,200)'], [0.75, 'rgb(188,189,220)'], [1, 'rgb(218,218,235)']],
                            // Yellow-Orange gradient
                            [[0, 'rgb(102,37,6)'], [0.25, 'rgb(153,52,4)'], [0.5, 'rgb(217,95,14)'], [0.75, 'rgb(254,153,41)'], [1, 'rgb(254,217,142)']],
                            // Teal gradient
                            [[0, 'rgb(1,70,54)'], [0.25, 'rgb(1,102,94)'], [0.5, 'rgb(2,129,138)'], [0.75, 'rgb(54,175,172)'], [1, 'rgb(178,226,226)']],
                            // Pink-Magenta gradient
                            [[0, 'rgb(73,0,106)'], [0.25, 'rgb(123,50,148)'], [0.5, 'rgb(194,165,207)'], [0.75, 'rgb(231,212,232)'], [1, 'rgb(247,242,247)']],
                            // Brown gradient
                            [[0, 'rgb(84,48,5)'], [0.25, 'rgb(140,81,10)'], [0.5, 'rgb(191,129,45)'], [0.75, 'rgb(223,194,125)'], [1, 'rgb(246,232,195)']],
                        ];
                        
                        // Function to create z matrix for a group
                        function createSurface(groupData, colorscale, name) {
                            const xVals = [...new Set(groupData.map(row => row[x]))].sort((a,b) => a-b);
                            const yVals = [...new Set(groupData.map(row => row[y]))].sort((a,b) => a-b);
                            
                            const zMatrix = [];
                            for (let i = 0; i < yVals.length; i++) {
                                zMatrix[i] = [];
                                for (let j = 0; j < xVals.length; j++) {
                                    const point = groupData.find(row => row[x] === xVals[j] && row[y] === yVals[i]);
                                    zMatrix[i][j] = point ? point[z] : null;
                                }
                            }
                            
                            return {
                                z: zMatrix,
                                x: xVals,
                                y: yVals,
                                type: 'surface',
                                name: name,
                                colorscale: colorscale,
                                showscale: false
                            };
                        }
                    
                    // Create a surface for each group
                    const plotData = uniqueGroups.map((grp, index) => {
                        const groupData = data3d.filter(row => row[$group_col] === grp);
                        const colorscale = colorGradients[index % colorGradients.length];
                        return createSurface(groupData, colorscale, `Group \${grp}`);
                    });
                    
                    const layout = {
                        title: '$chart_title',
                        autosize: true,
                        height: $height,
                        scene: {
                            xaxis: { title: '$x_label' },
                            yaxis: { title: '$y_label' },
                            zaxis: { title: '$z_label' }
                        },
                        showlegend: false,
                    };
                    
                Plotly.newPlot('$chart_title', plotData, layout);
            }).catch(function(error) {
                console.error('Error loading data for chart $chart_title:', error);
            });


        """

        appearance_html = """
        <h2>$title</h2>
        <p>$notes</p>       
        <!-- Chart -->
        <div id="$chart_title"></div>
        """

        new(chart_title, data_label, functional_html, appearance_html)
    end
end



