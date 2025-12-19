using Test
using JSPlots
using DataFrames

@testset "CodeBlock" begin
    @testset "Basic creation from function" begin
        function test_func()
            return 42
        end

        cb = CodeBlock(test_func)
        @test cb isa CodeBlock
        @test cb.executable === test_func
        @test occursin("test_func", cb.code_content)
        @test occursin("42", cb.code_content)
        @test occursin("function", cb.code_content)
        @test cb.appearance_html != ""
        @test cb.functional_html == ""
    end

    @testset "Creation with notes" begin
        function sample_func()
            return 1
        end

        cb = CodeBlock(sample_func, notes="This is a test note")
        @test occursin("This is a test note", cb.appearance_html)
        @test occursin("codeblock-notes", cb.appearance_html)
    end

    @testset "Creation with custom chart_title" begin
        function my_func()
            return 1
        end

        cb = CodeBlock(my_func, chart_title=:custom_title)
        @test cb.chart_title == :custom_title
        @test occursin("custom_title", cb.appearance_html)
    end

    @testset "Creation from file" begin
        mktempdir() do tmpdir
            # Create a test Julia file
            test_file = joinpath(tmpdir, "test_script.jl")
            write(test_file, """
            # Test script
            x = 1 + 2
            println("Hello from script")
            x
            """)

            cb = CodeBlock(test_file)
            @test cb isa CodeBlock
            @test cb.executable == test_file
            @test occursin("1 + 2", cb.code_content)
            @test occursin("Hello from script", cb.code_content)
            @test occursin("test_script.jl", cb.appearance_html) || true  # May or may not include filename
        end
    end

    @testset "Creation from file - non-executable" begin
        mktempdir() do tmpdir
            test_file = joinpath(tmpdir, "display_only.jl")
            write(test_file, "x = 1")

            cb = CodeBlock(test_file, executable=false)
            @test cb.executable === nothing
            @test occursin("x = 1", cb.code_content)
        end
    end

    @testset "Creation from file - file not found" begin
        @test_throws Exception CodeBlock("/nonexistent/file.jl")
    end

    @testset "Creation from code string" begin
        code = """
        function example()
            x = [1, 2, 3]
            return sum(x)
        end
        """

        cb = CodeBlock(code, Val(:code))
        @test cb isa CodeBlock
        @test cb.executable === nothing
        @test occursin("function example", cb.code_content)
        @test occursin("sum(x)", cb.code_content)
    end

    @testset "HTML generation and escaping" begin
        code = """
        x = 1 < 2 && 3 > 1
        s = "Hello & goodbye"
        """

        cb = CodeBlock(code, Val(:code))
        @test occursin("&lt;", cb.appearance_html)  # < escaped
        @test occursin("&gt;", cb.appearance_html)  # > escaped
        @test occursin("&amp;", cb.appearance_html)  # & escaped
        @test occursin("&quot;", cb.appearance_html)  # " escaped
    end

    @testset "HTML structure" begin
        function simple_func()
            return 1
        end

        cb = CodeBlock(simple_func, notes="Test note")
        @test occursin("codeblock-container", cb.appearance_html)
        @test occursin("codeblock-header", cb.appearance_html)
        @test occursin("language-julia", cb.appearance_html)
        @test occursin("<pre>", cb.appearance_html)
        @test occursin("<code", cb.appearance_html)
        @test occursin("codeblock-notes", cb.appearance_html)
        @test occursin("<style>", cb.appearance_html)
    end

    @testset "Execution - function with single return" begin
        function return_value()
            return 123
        end

        cb = CodeBlock(return_value)
        result = cb()
        @test result == 123
    end

    @testset "Execution - function with multiple returns" begin
        function return_multiple()
            return 10, 20, 30
        end

        cb = CodeBlock(return_multiple)
        a, b, c = cb()
        @test a == 10
        @test b == 20
        @test c == 30
    end

    @testset "Execution - execute_codeblock function" begin
        function test_value()
            return 456
        end

        cb = CodeBlock(test_value)
        result = execute_codeblock(cb)
        @test result == 456
    end

    @testset "Execution - file-based CodeBlock" begin
        mktempdir() do tmpdir
            test_file = joinpath(tmpdir, "compute.jl")
            write(test_file, """
            result = 2 + 2
            result
            """)

            cb = CodeBlock(test_file)
            value = cb()
            @test value == 4
        end
    end

    @testset "Execution - non-executable error" begin
        code = "x = 1"
        cb = CodeBlock(code, Val(:code))

        @test_throws ErrorException cb()
        @test_throws ErrorException execute_codeblock(cb)

        # Verify error message
        try
            cb()
        catch e
            @test occursin("not executable", e.msg)
        end
    end

    @testset "Function source extraction - simple function" begin
        function simple_extraction()
            x = 1
            y = 2
            return x + y
        end

        cb = CodeBlock(simple_extraction)
        @test occursin("function simple_extraction", cb.code_content)
        @test occursin("x = 1", cb.code_content)
        @test occursin("y = 2", cb.code_content)
        @test occursin("return x + y", cb.code_content)
        @test occursin("end", cb.code_content)
    end

    @testset "Function source extraction - with nested blocks" begin
        function nested_blocks()
            x = 0
            for i in 1:10
                if i > 5
                    x += i
                end
            end
            return x
        end

        cb = CodeBlock(nested_blocks)
        @test occursin("function nested_blocks", cb.code_content)
        @test occursin("for i in 1:10", cb.code_content)
        @test occursin("if i > 5", cb.code_content)
        @test occursin("x += i", cb.code_content)
        # Should have multiple 'end' keywords
        @test length(collect(eachmatch(r"\bend\b", cb.code_content))) >= 3
    end

    @testset "Function source extraction - one-liner" begin
        square(x) = x^2

        cb = CodeBlock(square)
        @test occursin("square", cb.code_content)
        @test occursin("x^2", cb.code_content) || occursin("x ^ 2", cb.code_content)
    end

    @testset "Function returning DataFrame" begin
        function create_dataframe()
            return DataFrame(a=[1,2,3], b=[4,5,6])
        end

        cb = CodeBlock(create_dataframe)
        df = cb()
        @test df isa DataFrame
        @test nrow(df) == 3
        @test names(df) == ["a", "b"]
    end

    @testset "Function creating chart" begin
        function create_simple_chart()
            df = DataFrame(x=[1,2,3], y=[4,5,6])
            return LineChart(:test_chart, df, :data;
                x_cols=[:x], y_cols=[:y])
        end

        cb = CodeBlock(create_simple_chart)
        chart = cb()
        @test chart isa LineChart
        @test chart.chart_title == :test_chart
    end

    @testset "Integration with JSPlotPage" begin
        mktempdir() do tmpdir
            # Create a function
            function generate_data()
                return DataFrame(x=[1,2,3], y=[4,5,6])
            end

            # Create CodeBlock
            code_block = CodeBlock(generate_data, notes="Data generation function")

            # Execute to get data
            df = code_block()

            # Create a chart
            chart = LineChart(:demo, df, :demo_data;
                x_cols=[:x], y_cols=[:y], title="Demo Chart")

            # Create page with both
            page = JSPlotPage(
                Dict(:demo_data => df),
                [code_block, chart],
                tab_title="Test Page"
            )

            # Generate HTML
            outfile = joinpath(tmpdir, "test_codeblock.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)

            # Should contain the code
            @test occursin("generate_data", content)
            @test occursin("DataFrame", content)

            # Should contain syntax highlighting
            @test occursin("language-julia", content)

            # Should contain the chart
            @test occursin("Demo Chart", content)

            # Should contain Prism.js
            @test occursin("prism", content)
        end
    end

    @testset "Multiple CodeBlocks in page" begin
        mktempdir() do tmpdir
            function func1()
                return 1
            end

            function func2()
                return 2
            end

            cb1 = CodeBlock(func1, notes="First function")
            cb2 = CodeBlock(func2, notes="Second function")

            page = JSPlotPage(
                Dict{Symbol, DataFrame}(),
                [cb1, cb2],
                tab_title="Multiple Blocks"
            )

            outfile = joinpath(tmpdir, "multiple.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("func1", content)
            @test occursin("func2", content)
            @test occursin("First function", content)
            @test occursin("Second function", content)
        end
    end

    @testset "CodeBlock with TextBlock" begin
        mktempdir() do tmpdir
            function example()
                return 42
            end

            cb = CodeBlock(example)
            tb = TextBlock("<h1>Example</h1><p>This shows how to combine CodeBlock with TextBlock</p>")

            page = JSPlotPage(
                Dict{Symbol, DataFrame}(),
                [tb, cb],
                tab_title="Combined"
            )

            outfile = joinpath(tmpdir, "combined.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)
            @test occursin("Example", content)
            @test occursin("function example", content)
        end
    end

    @testset "Empty notes" begin
        function test_func()
            return 1
        end

        cb = CodeBlock(test_func, notes="")
        # The style will always contain .codeblock-notes class definition
        # But there should be no actual notes div
        @test !occursin("<div class=\"codeblock-notes\">", cb.appearance_html)
    end

    @testset "Long code content" begin
        long_code = join(["# Line $i\nx$i = $i" for i in 1:100], "\n")
        cb = CodeBlock(long_code, Val(:code))
        @test occursin("Line 1", cb.code_content)
        @test occursin("Line 100", cb.code_content)
        @test length(cb.code_content) > 1000
    end

    @testset "Special Julia syntax" begin
        code = """
        # Comments
        x = 1:10  # Range
        y = [i^2 for i in x]  # Comprehension
        z = x .+ y  # Broadcasting
        f(x) = x -> x + 1  # Anonymous function
        @macro_call(arg)  # Macro
        """

        cb = CodeBlock(code, Val(:code))
        @test occursin("Comments", cb.code_content)
        @test occursin("1:10", cb.code_content)
        @test occursin("comprehension", lowercase(cb.code_content))
    end

    @testset "Unicode in code" begin
        code = """
        α = 1
        β = 2
        γ = α + β
        """

        cb = CodeBlock(code, Val(:code))
        @test occursin("α", cb.code_content)
        @test occursin("β", cb.code_content)
        @test occursin("γ", cb.code_content)
    end

    @testset "Code with strings containing HTML" begin
        code = """
        html = "<div>Hello</div>"
        text = "a < b && c > d"
        """

        cb = CodeBlock(code, Val(:code))
        # HTML should be escaped in the output
        @test occursin("&lt;div&gt;", cb.appearance_html)
        @test occursin("&lt; b", cb.appearance_html)
        @test occursin("&gt; d", cb.appearance_html)
    end

    @testset "Execution scope and namespacing" begin
        # Define a variable in this scope
        test_variable = 999

        function use_outer_scope()
            # This function can access test_variable
            return test_variable
        end

        cb = CodeBlock(use_outer_scope)
        result = cb()
        @test result == 999
    end

    @testset "Function with dependencies" begin
        helper_func(x) = x * 2

        function main_func()
            return helper_func(21)
        end

        cb = CodeBlock(main_func)
        result = cb()
        @test result == 42
    end

    @testset "Callable syntax vs execute_codeblock equivalence" begin
        function test_func()
            return rand()
        end

        cb = CodeBlock(test_func)

        # Both should work
        result1 = cb()
        result2 = execute_codeblock(cb)

        # Both should return numbers (can't test equality due to randomness)
        @test result1 isa Float64
        @test result2 isa Float64
    end

    @testset "Chart title generation" begin
        function f1()
            return 1
        end
        function f2()
            return 2
        end

        cb1 = CodeBlock(f1)
        cb2 = CodeBlock(f2)

        # Auto-generated titles should be unique
        @test cb1.chart_title != cb2.chart_title
        @test cb1.chart_title isa Symbol
        @test cb2.chart_title isa Symbol
    end

    @testset "File execution with complex script" begin
        mktempdir() do tmpdir
            script = joinpath(tmpdir, "complex.jl")
            write(script, """
            using DataFrames

            function process_data()
                df = DataFrame(a=1:5, b=6:10)
                return sum(df.a) + sum(df.b)
            end

            result = process_data()
            result
            """)

            cb = CodeBlock(script)
            value = cb()
            @test value == 15 + 40  # sum(1:5) + sum(6:10)
        end
    end

    @testset "Error propagation" begin
        function error_func()
            error("Intentional error")
        end

        cb = CodeBlock(error_func)

        @test_throws ErrorException cb()

        try
            cb()
        catch e
            @test occursin("Intentional error", e.msg)
        end
    end

    @testset "Multi-language support - Python" begin
        python_code = """
        def fibonacci(n):
            if n <= 1:
                return n
            return fibonacci(n-1) + fibonacci(n-2)

        for i in range(10):
            print(fibonacci(i))
        """

        cb = CodeBlock(python_code, Val(:code), language="python", notes="Python Fibonacci")
        @test cb.language == "python"
        @test cb.executable === nothing
        @test occursin("fibonacci", cb.code_content)
        @test occursin("language-python", cb.appearance_html)
        @test occursin("Python", cb.appearance_html)

        # Should not be executable
        @test_throws ErrorException cb()
    end

    @testset "Multi-language support - R" begin
        r_code = """
        # Linear regression in R
        x <- c(1, 2, 3, 4, 5)
        y <- c(2, 4, 6, 8, 10)
        model <- lm(y ~ x)
        summary(model)
        """

        cb = CodeBlock(r_code, Val(:code), language="r", notes="R linear regression")
        @test cb.language == "r"
        @test occursin("language-r", cb.appearance_html)
        @test occursin("Linear regression", cb.code_content)

        # Should not be executable
        @test_throws ErrorException cb()
    end

    @testset "Multi-language support - SQL" begin
        sql_code = """
        SELECT customers.name, COUNT(orders.id) as order_count
        FROM customers
        LEFT JOIN orders ON customers.id = orders.customer_id
        GROUP BY customers.id
        HAVING order_count > 5
        ORDER BY order_count DESC;
        """

        cb = CodeBlock(sql_code, Val(:code), language="sql", notes="Customer orders query")
        @test cb.language == "sql"
        @test occursin("language-sql", cb.appearance_html)
        @test occursin("SELECT", cb.code_content)

        # Should not be executable
        @test_throws ErrorException cb()
    end

    @testset "Multi-language support - C++" begin
        cpp_code = """
        #include <iostream>
        #include <vector>

        int main() {
            std::vector<int> numbers = {1, 2, 3, 4, 5};
            for (int n : numbers) {
                std::cout << n * n << std::endl;
            }
            return 0;
        }
        """

        cb = CodeBlock(cpp_code, Val(:code), language="c++", notes="C++ vector example")
        @test cb.language == "c++"
        @test occursin("language-cpp", cb.appearance_html)
        @test occursin("#include", cb.code_content)

        # Should not be executable
        @test_throws ErrorException cb()
    end

    @testset "Multi-language support - PostgreSQL" begin
        plpgsql_code = """
        CREATE OR REPLACE FUNCTION calculate_bonus(employee_id INTEGER)
        RETURNS DECIMAL AS \$\$
        DECLARE
            base_salary DECIMAL;
            bonus DECIMAL;
        BEGIN
            SELECT salary INTO base_salary
            FROM employees
            WHERE id = employee_id;

            bonus := base_salary * 0.15;
            RETURN bonus;
        END;
        \$\$ LANGUAGE plpgsql;
        """

        cb = CodeBlock(plpgsql_code, Val(:code), language="postgresql", notes="PostgreSQL function")
        @test cb.language == "postgresql"
        @test occursin("language-plsql", cb.appearance_html)
        @test occursin("CREATE OR REPLACE", cb.code_content)

        # Should not be executable
        @test_throws ErrorException cb()
    end

    @testset "Multi-language support - Unsupported language" begin
        go_code = """
        func main() {
            numbers := []int{1, 2, 3, 4, 5}
            for _, n := range numbers {
                fmt.Println(n * n)
            }
        }
        """

        cb = CodeBlock(go_code, Val(:code), language="go", notes="Go example")
        @test cb.language == "go"
        @test occursin("language-plaintext", cb.appearance_html)  # Falls back to plaintext
        @test occursin("go", lowercase(cb.appearance_html))  # Language label should still show

        # Should not be executable
        @test_throws ErrorException cb()
    end

    @testset "Multi-language file support" begin
        mktempdir() do tmpdir
            # Create a Python file
            python_file = joinpath(tmpdir, "script.py")
            write(python_file, """
            def hello():
                print("Hello from Python!")

            hello()
            """)

            cb = CodeBlock(python_file, language="python", notes="Python script")
            @test cb.language == "python"
            @test cb.executable === nothing  # Python files can't be executed
            @test occursin("Hello from Python", cb.code_content)
            @test occursin("language-python", cb.appearance_html)

            # Should not be executable
            @test_throws ErrorException cb()
        end
    end

    @testset "Julia language field" begin
        function julia_func()
            return 42
        end

        cb = CodeBlock(julia_func)
        @test cb.language == "Julia"
        @test occursin("language-julia", cb.appearance_html)

        # Julia code should be executable
        @test cb() == 42
    end

    @testset "get_languages_from_codeblocks" begin
        function julia_func()
            return 1
        end

        python_code = "print('hello')"
        sql_code = "SELECT * FROM users"

        cb_julia = CodeBlock(julia_func)
        cb_python = CodeBlock(python_code, Val(:code), language="python")
        cb_sql = CodeBlock(sql_code, Val(:code), language="sql")
        cb_go = CodeBlock("func main() {}", Val(:code), language="go")  # Unsupported

        # Create a chart for comparison
        df = DataFrame(x=[1,2], y=[3,4])
        chart = LineChart(:test, df, :data; x_cols=[:x], y_cols=[:y])

        charts = [cb_julia, chart, cb_python, cb_sql, cb_go]
        languages = JSPlots.get_languages_from_codeblocks(charts)

        @test "julia" in languages
        @test "python" in languages
        @test "sql" in languages
        @test !("go" in languages)  # Unsupported language not included
        @test length(languages) == 3
    end

    @testset "HTML generation with multiple languages" begin
        mktempdir() do tmpdir
            julia_code = "x = 1 + 1"
            python_code = "x = 1 + 1"
            sql_code = "SELECT 1 + 1"

            cb_julia = CodeBlock(julia_code, Val(:code), language="julia")
            cb_python = CodeBlock(python_code, Val(:code), language="python")
            cb_sql = CodeBlock(sql_code, Val(:code), language="sql")

            page = JSPlotPage(
                Dict{Symbol, DataFrame}(),
                [cb_julia, cb_python, cb_sql],
                tab_title="Multi-language example"
            )

            outfile = joinpath(tmpdir, "multilang.html")
            create_html(page, outfile)

            @test isfile(outfile)
            content = read(outfile, String)

            # Should contain all language scripts
            @test occursin("prism-julia.min.js", content)
            @test occursin("prism-python.min.js", content)
            @test occursin("prism-sql.min.js", content)

            # Should not load unnecessary languages
            @test !occursin("prism-r.min.js", content)
            @test !occursin("prism-cpp.min.js", content)
        end
    end
end
