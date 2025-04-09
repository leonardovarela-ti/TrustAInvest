#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Print header
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   TrustAInvest Integration Tests      ${NC}"
echo -e "${BLUE}=======================================${NC}"
echo

# Run all test scripts
echo -e "${YELLOW}Running all integration tests...${NC}"
echo

# Create results directory if it doesn't exist
mkdir -p results

# Initialize counters and results file
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
RESULTS_FILE="results/test_results.log"

# Initialize results file
echo "TrustAInvest Integration Test Results" > $RESULTS_FILE
echo "Run at: $(date)" >> $RESULTS_FILE
echo "=======================================" >> $RESULTS_FILE
echo "" >> $RESULTS_FILE

# Find all test scripts
TEST_SCRIPTS=$(find "$TEST_DIR" -name "*_test.sh" -type f | sort)

# Run each test script
for TEST_SCRIPT in $TEST_SCRIPTS; do
    TEST_NAME=$(basename "$TEST_SCRIPT")
    echo -e "${YELLOW}Running test: ${TEST_NAME}${NC}"
    
    # Run the test script and capture output
    echo "Running test: $TEST_NAME" >> $RESULTS_FILE
    echo "----------------------------------------" >> $RESULTS_FILE
    echo -e "${YELLOW}Running ${TEST_NAME}...${NC}"
    TEST_OUTPUT=$("$TEST_SCRIPT" 2>&1)
    TEST_RESULT=$?
    
    # Log test output
    echo "$TEST_OUTPUT" >> $RESULTS_FILE
    
    # Process test result
    if [ $TEST_RESULT -eq 0 ]; then
        echo -e "${GREEN}✓ Test passed: ${TEST_NAME}${NC}"
        echo "RESULT: PASSED" >> $RESULTS_FILE
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ Test failed: ${TEST_NAME}${NC}"
        echo "RESULT: FAILED" >> $RESULTS_FILE
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo "" >> $RESULTS_FILE
    echo "========================================" >> $RESULTS_FILE
    echo "" >> $RESULTS_FILE
    echo
done

# Generate summary report
SUMMARY_FILE="results/summary.txt"
echo "TrustAInvest Integration Tests Summary" > $SUMMARY_FILE
echo "Run at: $(date)" >> $SUMMARY_FILE
echo "=======================================" >> $SUMMARY_FILE
echo "Total tests:  $TOTAL_TESTS" >> $SUMMARY_FILE
echo "Passed tests: $PASSED_TESTS" >> $SUMMARY_FILE
echo "Failed tests: $FAILED_TESTS" >> $SUMMARY_FILE
echo "" >> $SUMMARY_FILE

if [ $FAILED_TESTS -eq 0 ]; then
    echo "All tests passed!" >> $SUMMARY_FILE
else
    echo "Some tests failed!" >> $SUMMARY_FILE
fi

# Generate HTML report
HTML_REPORT="results/report.html"
cat > $HTML_REPORT << EOF
<!DOCTYPE html>
<html>
<head>
    <title>TrustAInvest Integration Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .summary { margin: 20px 0; padding: 10px; background-color: #f5f5f5; border-radius: 5px; }
        .passed { color: green; }
        .failed { color: red; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
    </style>
</head>
<body>
    <h1>TrustAInvest Integration Test Report</h1>
    <p>Run at: $(date)</p>
    
    <div class="summary">
        <h2>Summary</h2>
        <p>Total tests: $TOTAL_TESTS</p>
        <p>Passed tests: <span class="passed">$PASSED_TESTS</span></p>
        <p>Failed tests: <span class="failed">$FAILED_TESTS</span></p>
        <p><strong>Result: $([ $FAILED_TESTS -eq 0 ] && echo '<span class="passed">All tests passed!</span>' || echo '<span class="failed">Some tests failed!</span>')</strong></p>
    </div>
    
    <h2>Test Details</h2>
    <table>
        <tr>
            <th>Test</th>
            <th>Result</th>
        </tr>
EOF

# Add test results to HTML report
for TEST_SCRIPT in $TEST_SCRIPTS; do
    TEST_NAME=$(basename "$TEST_SCRIPT")
    if grep -q "Running test: $TEST_NAME.*RESULT: PASSED" $RESULTS_FILE; then
        RESULT="<span class=\"passed\">PASSED</span>"
    else
        RESULT="<span class=\"failed\">FAILED</span>"
    fi
    
    echo "<tr><td>$TEST_NAME</td><td>$RESULT</td></tr>" >> $HTML_REPORT
done

# Close HTML report
cat >> $HTML_REPORT << EOF
    </table>
</body>
</html>
EOF

# Print summary to console
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   Test Summary                        ${NC}"
echo -e "${BLUE}=======================================${NC}"
echo -e "Total tests:  ${TOTAL_TESTS}"
echo -e "Passed tests: ${GREEN}${PASSED_TESTS}${NC}"
echo -e "Failed tests: ${RED}${FAILED_TESTS}${NC}"
echo
echo -e "Reports generated in ${YELLOW}results/${NC} directory"
echo

# Exit with appropriate status code
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
