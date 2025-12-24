using JSPlots, DataFrames

println("Creating Multi-Language CodeBlock examples...")

# Header
header = TextBlock("""
<a href="https://github.com/s-baumann/JSPlots.jl/blob/main/examples/codeblock_multilang_examples.jl" style="color: blue; font-weight: bold;">See here for the example code that generated this page</a>
<h1>Multi-Language CodeBlock Examples</h1>
<p>CodeBlock supports displaying code in multiple programming languages with proper syntax highlighting.</p>
<p>Supported languages: <strong>Julia</strong>, <strong>Python</strong>, <strong>R</strong>, <strong>C++</strong>, <strong>C</strong>, <strong>Java</strong>, <strong>JavaScript</strong>, <strong>SQL</strong>, and <strong>PostgreSQL (PL/pgSQL)</strong></p>
<p>Unsupported languages can also be displayed (e.g., Fortran) - they will show with a language label but without syntax highlighting.</p>
<p>Note: Only Julia code can be executed. Code in other languages is for display purposes only.</p>
""")

# Julia Example (executable)
julia_section = TextBlock("""
<h2>1. Julia Code (Executable)</h2>
<p>Julia code can be both displayed and executed.</p>
""")

julia_code = """
function fibonacci(n)
    if n <= 1
        return n
    end
    return fibonacci(n-1) + fibonacci(n-2)
end

# Calculate Fibonacci numbers
[fibonacci(i) for i in 0:10]
"""

julia_cb = CodeBlock(julia_code, Val(:code), language="julia",
    notes="Julia Fibonacci function - can be executed with cb()")

# Python Example
python_section = TextBlock("""
<h2>2. Python Code (Display Only)</h2>
<p>Python code is displayed with proper syntax highlighting but cannot be executed.</p>
""")

python_code = """
def merge_sort(arr):
    if len(arr) <= 1:
        return arr

    mid = len(arr) // 2
    left = merge_sort(arr[:mid])
    right = merge_sort(arr[mid:])

    return merge(left, right)

def merge(left, right):
    result = []
    i = j = 0

    while i < len(left) and j < len(right):
        if left[i] < right[j]:
            result.append(left[i])
            i += 1
        else:
            result.append(right[j])
            j += 1

    result.extend(left[i:])
    result.extend(right[j:])
    return result

# Example usage
numbers = [64, 34, 25, 12, 22, 11, 90]
sorted_numbers = merge_sort(numbers)
print(f"Sorted array: {sorted_numbers}")
"""

python_cb = CodeBlock(python_code, Val(:code), language="python",
    notes="Python merge sort implementation")

# R Example
r_section = TextBlock("""
<h2>3. R Code (Display Only)</h2>
<p>R statistical code with proper syntax highlighting.</p>
""")

r_code = """
# Multiple linear regression in R
# Load the mtcars dataset
data(mtcars)

# Fit a linear model
model <- lm(mpg ~ cyl + hp + wt, data = mtcars)

# Display the summary
summary(model)

# Create a plot
plot(model\$fitted.values, model\$residuals,
     main = "Residual Plot",
     xlab = "Fitted Values",
     ylab = "Residuals")
abline(h = 0, col = "red", lty = 2)

# Calculate predictions
new_data <- data.frame(cyl = c(4, 6, 8), hp = c(110, 150, 200), wt = c(2.5, 3.0, 3.5))
predictions <- predict(model, newdata = new_data)
print(predictions)
"""

r_cb = CodeBlock(r_code, Val(:code), language="r",
    notes="R linear regression analysis on mtcars dataset")

# SQL Example
sql_section = TextBlock("""
<h2>4. SQL Code (Display Only)</h2>
<p>SQL queries with proper syntax highlighting.</p>
""")

sql_code = """
-- Complex customer analytics query
WITH customer_metrics AS (
    SELECT
        c.customer_id,
        c.name,
        COUNT(DISTINCT o.order_id) as total_orders,
        SUM(o.total_amount) as lifetime_value,
        AVG(o.total_amount) as avg_order_value,
        MAX(o.order_date) as last_order_date
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_date >= DATE_SUB(CURRENT_DATE, INTERVAL 1 YEAR)
    GROUP BY c.customer_id, c.name
),
customer_segments AS (
    SELECT
        *,
        CASE
            WHEN lifetime_value > 10000 THEN 'VIP'
            WHEN lifetime_value > 5000 THEN 'Premium'
            WHEN lifetime_value > 1000 THEN 'Standard'
            ELSE 'Basic'
        END as segment
    FROM customer_metrics
)
SELECT
    segment,
    COUNT(*) as customer_count,
    AVG(total_orders) as avg_orders_per_customer,
    SUM(lifetime_value) as segment_revenue
FROM customer_segments
GROUP BY segment
ORDER BY segment_revenue DESC;
"""

sql_cb = CodeBlock(sql_code, Val(:code), language="sql",
    notes="SQL customer segmentation and analytics query")

# C++ Example
cpp_section = TextBlock("""
<h2>5. C++ Code (Display Only)</h2>
<p>C++ code with proper syntax highlighting.</p>
""")

cpp_code = """
#include <iostream>
#include <vector>
#include <algorithm>
#include <numeric>

// Template class for a simple generic stack
template<typename T>
class Stack {
private:
    std::vector<T> elements;

public:
    void push(const T& element) {
        elements.push_back(element);
    }

    T pop() {
        if (elements.empty()) {
            throw std::out_of_range("Stack is empty");
        }
        T top = elements.back();
        elements.pop_back();
        return top;
    }

    bool empty() const {
        return elements.empty();
    }

    size_t size() const {
        return elements.size();
    }
};

int main() {
    // Example usage
    Stack<int> numbers;

    // Push numbers
    for (int i = 1; i <= 5; ++i) {
        numbers.push(i * 10);
    }

    // Pop and print
    while (!numbers.empty()) {
        std::cout << numbers.pop() << " ";
    }
    std::cout << std::endl;

    return 0;
}
"""

cpp_cb = CodeBlock(cpp_code, Val(:code), language="c++",
    notes="C++ template stack implementation")

# PostgreSQL PL/pgSQL Example
postgresql_section = TextBlock("""
<h2>6. PostgreSQL PL/pgSQL Code (Display Only)</h2>
<p>PostgreSQL procedural language code with proper syntax highlighting.</p>
""")

plpgsql_code = raw"""
-- Stored procedure for inventory management
CREATE OR REPLACE FUNCTION reorder_inventory()
RETURNS TABLE(product_id INT, product_name VARCHAR, reorder_quantity INT)
LANGUAGE plpgsql AS $$
DECLARE
    product_record RECORD;
    days_of_stock NUMERIC;
BEGIN
    FOR product_record IN
        SELECT p.id, p.name, p.current_stock, p.reorder_level,
               p.avg_daily_sales, p.lead_time_days
        FROM products p
        WHERE p.current_stock < p.reorder_level
        ORDER BY p.name
    LOOP
        -- Calculate days of stock remaining
        days_of_stock := product_record.current_stock / NULLIF(product_record.avg_daily_sales, 0);

        -- Calculate reorder quantity
        -- Order enough for lead time plus 7 days buffer
        product_id := product_record.id;
        product_name := product_record.name;
        reorder_quantity := CEIL(
            product_record.avg_daily_sales * (product_record.lead_time_days + 7)
            - product_record.current_stock
        );

        -- Insert into reorder queue
        INSERT INTO reorder_queue (product_id, quantity, requested_date)
        VALUES (product_id, reorder_quantity, CURRENT_TIMESTAMP)
        ON CONFLICT (product_id) DO UPDATE
        SET quantity = reorder_quantity,
            requested_date = CURRENT_TIMESTAMP;

        RETURN NEXT;
    END LOOP;
END;
$$;

-- Execute the reorder function
SELECT * FROM reorder_inventory();
"""

plpgsql_cb = CodeBlock(plpgsql_code, Val(:code), language="postgresql",
    notes="PostgreSQL stored procedure for automated inventory reordering")

# C Example
c_section = TextBlock("""
<h2>7. C Code (Display Only)</h2>
<p>Classic C code with proper syntax highlighting.</p>
""")

c_code = """
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Structure for a simple linked list
typedef struct Node {
    int data;
    struct Node* next;
} Node;

// Function to create a new node
Node* create_node(int data) {
    Node* new_node = (Node*)malloc(sizeof(Node));
    if (new_node == NULL) {
        fprintf(stderr, "Memory allocation failed\\n");
        exit(1);
    }
    new_node->data = data;
    new_node->next = NULL;
    return new_node;
}

// Function to insert at the beginning
void insert_at_beginning(Node** head, int data) {
    Node* new_node = create_node(data);
    new_node->next = *head;
    *head = new_node;
}

// Function to print the list
void print_list(Node* head) {
    Node* current = head;
    printf("List: ");
    while (current != NULL) {
        printf("%d -> ", current->data);
        current = current->next;
    }
    printf("NULL\\n");
}

// Function to free the list
void free_list(Node** head) {
    Node* current = *head;
    Node* next;

    while (current != NULL) {
        next = current->next;
        free(current);
        current = next;
    }
    *head = NULL;
}

int main() {
    Node* head = NULL;

    // Insert some nodes
    for (int i = 1; i <= 5; i++) {
        insert_at_beginning(&head, i * 10);
    }

    print_list(head);
    free_list(&head);

    return 0;
}
"""

c_cb = CodeBlock(c_code, Val(:code), language="c",
    notes="C linked list implementation with memory management")

# Java Example
java_section = TextBlock("""
<h2>8. Java Code (Display Only)</h2>
<p>Java code with proper syntax highlighting.</p>
""")

java_code = """
import java.util.*;
import java.util.stream.Collectors;

/**
 * Generic Binary Search Tree implementation
 * @param <T> Type of elements stored in the tree
 */
public class BinarySearchTree<T extends Comparable<T>> {
    private class Node {
        T data;
        Node left, right;

        Node(T data) {
            this.data = data;
            this.left = null;
            this.right = null;
        }
    }

    private Node root;

    public BinarySearchTree() {
        this.root = null;
    }

    // Insert a value into the tree
    public void insert(T value) {
        root = insertRec(root, value);
    }

    private Node insertRec(Node node, T value) {
        if (node == null) {
            return new Node(value);
        }

        int cmp = value.compareTo(node.data);
        if (cmp < 0) {
            node.left = insertRec(node.left, value);
        } else if (cmp > 0) {
            node.right = insertRec(node.right, value);
        }

        return node;
    }

    // In-order traversal
    public List<T> inorderTraversal() {
        List<T> result = new ArrayList<>();
        inorderRec(root, result);
        return result;
    }

    private void inorderRec(Node node, List<T> result) {
        if (node != null) {
            inorderRec(node.left, result);
            result.add(node.data);
            inorderRec(node.right, result);
        }
    }

    // Search for a value
    public boolean contains(T value) {
        return containsRec(root, value);
    }

    private boolean containsRec(Node node, T value) {
        if (node == null) {
            return false;
        }

        int cmp = value.compareTo(node.data);
        if (cmp == 0) {
            return true;
        } else if (cmp < 0) {
            return containsRec(node.left, value);
        } else {
            return containsRec(node.right, value);
        }
    }

    public static void main(String[] args) {
        BinarySearchTree<Integer> bst = new BinarySearchTree<>();
        int[] values = {50, 30, 70, 20, 40, 60, 80};

        for (int value : values) {
            bst.insert(value);
        }

        System.out.println("Inorder traversal: " + bst.inorderTraversal());
        System.out.println("Contains 40: " + bst.contains(40));
        System.out.println("Contains 100: " + bst.contains(100));
    }
}
"""

java_cb = CodeBlock(java_code, Val(:code), language="java",
    notes="Java generic Binary Search Tree implementation")

# JavaScript Example
javascript_section = TextBlock("""
<h2>9. JavaScript Code (Display Only)</h2>
<p>Modern JavaScript (ES6+) code with proper syntax highlighting.</p>
""")

javascript_code = """
// Asynchronous data fetching and processing
class DataProcessor {
    constructor(apiUrl) {
        this.apiUrl = apiUrl;
        this.cache = new Map();
    }

    // Fetch data with caching
    async fetchData(endpoint) {
        const cacheKey = `\${this.apiUrl}/\${endpoint}`;

        if (this.cache.has(cacheKey)) {
            console.log('Returning cached data');
            return this.cache.get(cacheKey);
        }

        try {
            const response = await fetch(cacheKey);
            if (!response.ok) {
                throw new Error(`HTTP error! status: \${response.status}`);
            }
            const data = await response.json();
            this.cache.set(cacheKey, data);
            return data;
        } catch (error) {
            console.error('Failed to fetch data:', error);
            throw error;
        }
    }

    // Process data with array methods
    processUsers(users) {
        return users
            .filter(user => user.active)
            .map(user => ({
                id: user.id,
                name: user.name,
                email: user.email,
                joinDate: new Date(user.created_at)
            }))
            .sort((a, b) => b.joinDate - a.joinDate)
            .slice(0, 10);
    }

    // Aggregate data
    aggregateByCategory(items) {
        return items.reduce((acc, item) => {
            const category = item.category || 'uncategorized';
            acc[category] = acc[category] || [];
            acc[category].push(item);
            return acc;
        }, {});
    }
}

// Usage example
const processor = new DataProcessor('https://api.example.com');

async function displayTopUsers() {
    try {
        const users = await processor.fetchData('users');
        const topUsers = processor.processUsers(users);

        topUsers.forEach(user => {
            console.log(`\${user.name} - \${user.email}`);
        });
    } catch (error) {
        console.error('Error displaying users:', error);
    }
}

displayTopUsers();
"""

javascript_cb = CodeBlock(javascript_code, Val(:code), language="javascript",
    notes="Modern JavaScript with async/await and array methods")

# Rust Example
rust_section = TextBlock("""
<h2>10. Rust Code - Memory Safety and Ownership</h2>
<p>Rust provides memory safety without garbage collection through its ownership system.</p>
<p>This example demonstrates ownership, borrowing, pattern matching, and iterators.</p>
""")

rust_code = """
// A simple implementation of a Result type validator
// demonstrating Rust's pattern matching and error handling

#[derive(Debug)]
enum ParseError {
    InvalidFormat,
    OutOfRange,
}

struct DataPoint {
    timestamp: i64,
    value: f64,
}

impl DataPoint {
    fn new(timestamp: i64, value: f64) -> Result<Self, ParseError> {
        if value < 0.0 || value > 100.0 {
            return Err(ParseError::OutOfRange);
        }
        Ok(DataPoint { timestamp, value })
    }
}

fn parse_data(input: &str) -> Result<Vec<DataPoint>, ParseError> {
    input
        .lines()
        .filter(|line| !line.trim().is_empty())
        .map(|line| {
            let parts: Vec<&str> = line.split(',').collect();
            if parts.len() != 2 {
                return Err(ParseError::InvalidFormat);
            }

            let timestamp = parts[0]
                .trim()
                .parse::<i64>()
                .map_err(|_| ParseError::InvalidFormat)?;

            let value = parts[1]
                .trim()
                .parse::<f64>()
                .map_err(|_| ParseError::InvalidFormat)?;

            DataPoint::new(timestamp, value)
        })
        .collect()
}

fn calculate_statistics(data: &[DataPoint]) -> (f64, f64) {
    let sum: f64 = data.iter().map(|dp| dp.value).sum();
    let mean = sum / data.len() as f64;

    let variance: f64 = data
        .iter()
        .map(|dp| (dp.value - mean).powi(2))
        .sum::<f64>() / data.len() as f64;

    (mean, variance.sqrt())
}

fn main() {
    let input = "1609459200,45.5\\n1609545600,52.3\\n1609632000,48.9";

    match parse_data(input) {
        Ok(data) => {
            let (mean, std_dev) = calculate_statistics(&data);
            println!("Mean: {:.2}, Std Dev: {:.2}", mean, std_dev);
        }
        Err(e) => eprintln!("Error parsing data: {:?}", e),
    }
}
"""

rust_cb = CodeBlock(rust_code, Val(:code), language="rust",
    notes="Demonstrates Rust's ownership, pattern matching, and functional iterators")

# Fortran Example (unsupported language)
fortran_section = TextBlock("""
<h2>11. Fortran Code - Unsupported Language Example</h2>
<p>This demonstrates how CodeBlock handles languages that don't have syntax highlighting support.</p>
<p>The code is displayed with the language label, but without syntax highlighting (shown as plain text).</p>
""")

fortran_code = """
! Matrix multiplication in Fortran
PROGRAM MatrixMultiplication
    IMPLICIT NONE

    INTEGER, PARAMETER :: N = 3
    REAL, DIMENSION(N,N) :: A, B, C
    INTEGER :: i, j, k

    ! Initialize matrices A and B
    DATA A /1.0, 2.0, 3.0, &
            4.0, 5.0, 6.0, &
            7.0, 8.0, 9.0/

    DATA B /9.0, 8.0, 7.0, &
            6.0, 5.0, 4.0, &
            3.0, 2.0, 1.0/

    ! Initialize result matrix C to zero
    C = 0.0

    ! Perform matrix multiplication
    DO i = 1, N
        DO j = 1, N
            DO k = 1, N
                C(i,j) = C(i,j) + A(i,k) * B(k,j)
            END DO
        END DO
    END DO

    ! Print result
    PRINT *, 'Result Matrix C:'
    DO i = 1, N
        PRINT '(3F10.2)', (C(i,j), j = 1, N)
    END DO

END PROGRAM MatrixMultiplication
"""

fortran_cb = CodeBlock(fortran_code, Val(:code), language="fortran",
    notes="Fortran 90 matrix multiplication - displayed without syntax highlighting")

# Comparison Section
comparison_section = TextBlock("""
<h2>Language Comparison</h2>
<p>Here's the same algorithm (binary search) implemented in different languages:</p>
""")

julia_binsearch = """
function binary_search(arr::Vector, target)
    left, right = 1, length(arr)

    while left <= right
        mid = div(left + right, 2)

        if arr[mid] == target
            return mid
        elseif arr[mid] < target
            left = mid + 1
        else
            right = mid - 1
        end
    end

    return nothing  # Not found
end
"""

python_binsearch = """
def binary_search(arr, target):
    left, right = 0, len(arr) - 1

    while left <= right:
        mid = (left + right) // 2

        if arr[mid] == target:
            return mid
        elif arr[mid] < target:
            left = mid + 1
        else:
            right = mid - 1

    return None  # Not found
"""

cpp_binsearch = """
int binary_search(const std::vector<int>& arr, int target) {
    int left = 0;
    int right = arr.size() - 1;

    while (left <= right) {
        int mid = left + (right - left) / 2;

        if (arr[mid] == target) {
            return mid;
        } else if (arr[mid] < target) {
            left = mid + 1;
        } else {
            right = mid - 1;
        }
    }

    return -1;  // Not found
}
"""

julia_bs_cb = CodeBlock(julia_binsearch, Val(:code), language="julia", notes="Binary search in Julia")
python_bs_cb = CodeBlock(python_binsearch, Val(:code), language="python", notes="Binary search in Python")
cpp_bs_cb = CodeBlock(cpp_binsearch, Val(:code), language="c++", notes="Binary search in C++")

# Summary
summary = TextBlock("""
<h2>Summary</h2>
<p>This page demonstrated CodeBlock with multiple programming languages:</p>
<ul>
    <li><strong>Julia:</strong> Full support with syntax highlighting AND execution</li>
    <li><strong>Python:</strong> Syntax highlighting for display</li>
    <li><strong>R:</strong> Syntax highlighting for statistical code</li>
    <li><strong>SQL:</strong> Syntax highlighting for database queries</li>
    <li><strong>C++:</strong> Syntax highlighting for systems programming</li>
    <li><strong>PostgreSQL PL/pgSQL:</strong> Syntax highlighting for database procedures</li>
    <li><strong>C:</strong> Syntax highlighting for classic C code</li>
    <li><strong>Java:</strong> Syntax highlighting for Java code</li>
    <li><strong>JavaScript:</strong> Syntax highlighting for modern JS (ES6+)</li>
    <li><strong>Rust:</strong> Syntax highlighting for Rust code with ownership/borrowing</li>
    <li><strong>Fortran:</strong> Example of unsupported language (no syntax highlighting)</li>
</ul>
<p><strong>Key Features:</strong></p>
<ul>
    <li>Automatic language detection and appropriate Prism.js component loading</li>
    <li>Only loads syntax highlighters for languages actually used in the page</li>
    <li>Execution restricted to Julia code only for security</li>
    <li>Support for unsupported languages (displayed without syntax highlighting but with language label)</li>
</ul>
<p><strong>Usage:</strong></p>
<pre style="background-color: #f5f5f5; padding: 10px; border-radius: 5px;">
# Display Python code
python_code = \"\"\"
def hello():
    print("Hello, World!")
\"\"\"
cb = CodeBlock(python_code, Val(:code), language="python")

# Display SQL from file
cb = CodeBlock("query.sql", language="sql")

# Julia code (executable)
function my_func()
    return 42
end
cb = CodeBlock(my_func)
result = cb()  # Returns 42
</pre>
""")

# Create page
page = JSPlotPage(
    Dict{Symbol,DataFrame}(),
    [
        header,
        julia_section, julia_cb,
        python_section, python_cb,
        r_section, r_cb,
        sql_section, sql_cb,
        cpp_section, cpp_cb,
        postgresql_section, plpgsql_cb,
        c_section, c_cb,
        java_section, java_cb,
        javascript_section, javascript_cb,
        rust_section, rust_cb,
        fortran_section, fortran_cb,
        comparison_section, julia_bs_cb, python_bs_cb, cpp_bs_cb,
        summary
    ],
    tab_title = "Multi-Language CodeBlock Examples"
)

create_html(page, "generated_html_examples/codeblock_multilang_examples.html")

println("\n" * "="^60)
println("Multi-Language CodeBlock examples created successfully!")
println("="^60)
println("\nFile created: generated_html_examples/codeblock_multilang_examples.html")
println("\nThis page includes:")
println("  • Julia code (executable)")
println("  • Python code (merge sort)")
println("  • R code (linear regression)")
println("  • SQL code (customer analytics)")
println("  • C++ code (template stack)")
println("  • PostgreSQL PL/pgSQL code (inventory management)")
println("  • C code (linked list)")
println("  • Java code (binary search tree)")
println("  • JavaScript code (async data processing)")
println("  • Rust code (ownership and error handling)")
println("  • Fortran code (unsupported language example)")
println("  • Side-by-side language comparison (binary search)")
println("  • All with proper syntax highlighting!")
println("\nNote: Only loads Prism.js components for languages actually used.")
