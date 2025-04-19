#!/bin/bash

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

# Find all test scripts (excluding isolation tests)
TEST_SCRIPTS=$(find "$TEST_DIR" -name "*_test.sh" -type f | sort)

# Maximum number of concurrent tests
MAX_CONCURRENT=10
COMPOSE_BAKE=true
# Run tests in parallel
echo -e "${YELLOW}Running tests in parallel (max $MAX_CONCURRENT at a time)...${NC}"

# Array to store PIDs of running tests
declare -a PIDS
declare -a TEST_NAMES
declare -a TEST_STATUSES

# Function to wait for a test to complete and process its result
wait_for_test() {
    local pid=$1
    local test_name=$2
    local log_file=$3
    
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Test passed: ${test_name}${NC}"
        echo "RESULT: PASSED" >> $log_file
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ Test failed: ${test_name}${NC}"
        echo "RESULT: FAILED" >> $log_file
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # Append test output to main log
    echo "Running test: $test_name" >> $RESULTS_FILE
    echo "----------------------------------------" >> $RESULTS_FILE
    cat $log_file >> $RESULTS_FILE
    echo "" >> $RESULTS_FILE
    echo "========================================" >> $RESULTS_FILE
    echo "" >> $RESULTS_FILE
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

# Run tests in parallel with a maximum of MAX_CONCURRENT tests at a time
for TEST_SCRIPT in $TEST_SCRIPTS; do
    TEST_NAME=$(basename "$TEST_SCRIPT")
    LOG_FILE="results/${TEST_NAME}.log"
    
    # Check if we're already running MAX_CONCURRENT tests
    while [ ${#PIDS[@]} -ge $MAX_CONCURRENT ]; do
        # Wait for any test to finish
        for i in "${!PIDS[@]}"; do
            if ! kill -0 ${PIDS[$i]} 2>/dev/null; then
                # This test has finished
                wait_for_test ${PIDS[$i]} ${TEST_NAMES[$i]} "results/${TEST_NAMES[$i]}.log"
                # Remove this test from the arrays
                unset PIDS[$i]
                unset TEST_NAMES[$i]
                # Re-index the arrays
                PIDS=("${PIDS[@]}")
                TEST_NAMES=("${TEST_NAMES[@]}")
                break
            fi
        done
        # If we still have MAX_CONCURRENT tests running, wait a bit
        if [ ${#PIDS[@]} -ge $MAX_CONCURRENT ]; then
            sleep 1
        fi
    done
    
    # Start a new test
    echo -e "${YELLOW}Starting test: ${TEST_NAME}${NC}"
    "$TEST_SCRIPT" > "$LOG_FILE" 2>&1 &
    PID=$!
    PIDS+=($PID)
    TEST_NAMES+=($TEST_NAME)
done

# Wait for remaining tests to finish
for i in "${!PIDS[@]}"; do
    wait_for_test ${PIDS[$i]} ${TEST_NAMES[$i]} "results/${TEST_NAMES[$i]}.log"
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
    if grep -q "RESULT: PASSED" "results/${TEST_NAME}.log" 2>/dev/null; then
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

# Clean up any leftover Docker resources
echo -e "${YELLOW}Cleaning up any leftover Docker resources...${NC}"
# Find and remove any test-specific docker-compose files
find "$TEST_DIR" -name "docker-compose.*_test.sh.yml" -type f -delete

# Stop and remove any leftover containers from test projects
echo -e "${YELLOW}Stopping and removing any leftover containers...${NC}"
# Get a list of all test project names
TEST_PROJECTS=$(docker ps -a --format "{{.Names}}" | grep "test_.*_test" | cut -d'-' -f1 | sort -u)
for PROJECT in $TEST_PROJECTS; do
  echo -e "${YELLOW}Stopping project: $PROJECT${NC}"
  docker-compose -p "$PROJECT" down -v 2>/dev/null || true
done

# Remove any leftover containers that weren't caught by the project cleanup
echo -e "${YELLOW}Removing any remaining test containers...${NC}"
docker ps -a | grep "test_.*_test" | awk '{print $1}' | xargs -r docker rm -f

# Remove any test-specific networks
echo -e "${YELLOW}Removing any leftover networks...${NC}"
docker network prune -f --filter "name=test-network-*" > /dev/null 2>&1

# Remove any test-specific volumes
echo -e "${YELLOW}Removing any leftover volumes...${NC}"
docker volume prune -f --filter "name=postgres_data_*" --filter "name=redis_data_*" > /dev/null 2>&1

# Exit with appropriate status code
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
