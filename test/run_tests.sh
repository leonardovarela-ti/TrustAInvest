#!/bin/bash

# Parse command line arguments
VERBOSE=false
DEBUG_DOCKER=false

for arg in "$@"; do
  case $arg in
    --verbose)
      VERBOSE=true
      shift
      ;;
    --debug-docker)
      DEBUG_DOCKER=true
      shift
      ;;
    --help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --verbose       Show real-time output from all tests"
      echo "  --debug-docker  Show Docker container creation details"
      echo "  --help          Show this help message"
      exit 0
      ;;
    *)
      # Unknown option
      echo "Unknown option: $arg"
      echo "Use --help to see available options"
      exit 1
      ;;
  esac
done

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

# Function to generate a unique color for each test
get_test_color() {
    local colors=("${RED}" "${GREEN}" "${YELLOW}" "${BLUE}" "${PURPLE}" "${CYAN}" "${WHITE}")
    local index=$(( $1 % ${#colors[@]} ))
    echo "${colors[$index]}"
}

# Test directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Start timing
START_TIME=$(date +%s)

# Print header
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   TrustAInvest Integration Tests      ${NC}"
echo -e "${BLUE}=======================================${NC}"
echo

# Print configuration
echo -e "${BLUE}Starting test run at $(date)${NC}"
if $VERBOSE; then
    echo -e "${BLUE}Verbose mode: ON - showing real-time test output${NC}"
fi
if $DEBUG_DOCKER; then
    echo -e "${BLUE}Docker debug: ON - showing container creation details${NC}"
fi

# Function to check Docker resource usage
check_docker_resources() {
    echo -e "${BLUE}=======================================${NC}"
    echo -e "${BLUE}   Docker Resource Usage               ${NC}"
    echo -e "${BLUE}=======================================${NC}"
    
    # Get running container count
    local container_count=$(docker ps -q | wc -l)
    echo -e "Running containers: ${YELLOW}${container_count}${NC}"
    
    # Get container details
    echo -e "\nContainer details:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -v "NAMES"
    
    # Get Docker disk usage
    echo -e "\nDocker disk usage:"
    docker system df | grep -v "TYPE"
    
    echo -e "${BLUE}=======================================${NC}"
}

# Function to format elapsed time
format_time() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local hours=$((minutes / 60))
    local days=$((hours / 24))
    local rem_hours=$((hours % 24))
    local rem_minutes=$((minutes % 60))
    local rem_seconds=$((seconds % 60))
    
    if [ $days -gt 0 ]; then
        echo "${days}d ${rem_hours}h ${rem_minutes}m ${rem_seconds}s"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h ${rem_minutes}m ${rem_seconds}s"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${rem_seconds}s"
    else
        echo "${seconds}s"
    fi
}

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
MAX_CONCURRENT=15
COMPOSE_BAKE=true
echo -e "${YELLOW}Running tests in parallel (max $MAX_CONCURRENT at a time)...${NC}"

# Arrays to store PIDs of running tests
declare -a PIDS
declare -a TEST_NAMES
declare -a TEST_START_TIMES
declare -a TEST_COLORS

# Function to wait for a test to complete and process its result
wait_for_test() {
    local pid=$1
    local test_name=$2
    local log_file=$3
    local test_start_time=$4
    
    wait $pid
    local exit_code=$?
    local test_end_time=$(date +%s)
    local test_duration=$((test_end_time - test_start_time))
    local formatted_duration=$(format_time $test_duration)
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Test passed: ${test_name} (took ${formatted_duration})${NC}"
        echo "RESULT: PASSED (Duration: ${formatted_duration})" >> $log_file
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ Test failed: ${test_name} (took ${formatted_duration})${NC}"
        echo "RESULT: FAILED (Duration: ${formatted_duration})" >> $log_file
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    # Append test output to main log
    echo "Running test: $test_name (Duration: ${formatted_duration})" >> $RESULTS_FILE
    echo "----------------------------------------" >> $RESULTS_FILE
    cat $log_file >> $RESULTS_FILE
    echo "" >> $RESULTS_FILE
    echo "========================================" >> $RESULTS_FILE
    echo "" >> $RESULTS_FILE
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    # Calculate and display current elapsed time
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    local formatted_elapsed=$(format_time $elapsed)
    echo -e "${BLUE}Total elapsed time: ${formatted_elapsed}${NC}"
}

# Initial Docker resource check
if $DEBUG_DOCKER; then
    echo -e "${YELLOW}Initial Docker resource state:${NC}"
    check_docker_resources
fi

# Run tests in parallel with a maximum of MAX_CONCURRENT tests at a time
for TEST_SCRIPT in $TEST_SCRIPTS; do
    TEST_NAME=$(basename "$TEST_SCRIPT")
    LOG_FILE="results/${TEST_NAME}.log"
    
    # Check if we're already running MAX_CONCURRENT tests
    while [ ${#PIDS[@]} -ge $MAX_CONCURRENT ]; do
        echo -e "${YELLOW}Currently running ${#PIDS[@]} tests, waiting for a slot to open...${NC}"
        # List currently running tests
        echo -e "${YELLOW}Active tests: ${TEST_NAMES[*]}${NC}"
        
        # Calculate and display current elapsed time
        current_time=$(date +%s)
        elapsed=$((current_time - START_TIME))
        formatted_elapsed=$(format_time $elapsed)
        echo -e "${BLUE}Total elapsed time so far: ${formatted_elapsed}${NC}"
        
        # Wait for any test to finish
        for i in "${!PIDS[@]}"; do
            if ! kill -0 ${PIDS[$i]} 2>/dev/null; then
                # This test has finished
                echo -e "${YELLOW}Test ${TEST_NAMES[$i]} has completed, slot available${NC}"
                wait_for_test ${PIDS[$i]} ${TEST_NAMES[$i]} "results/${TEST_NAMES[$i]}.log" ${TEST_START_TIMES[$i]}
                # Remove this test from the arrays
                unset PIDS[$i]
                unset TEST_NAMES[$i]
                unset TEST_START_TIMES[$i]
                unset TEST_COLORS[$i]
                # Re-index the arrays
                PIDS=("${PIDS[@]}")
                TEST_NAMES=("${TEST_NAMES[@]}")
                TEST_START_TIMES=("${TEST_START_TIMES[@]}")
                TEST_COLORS=("${TEST_COLORS[@]}")
                break
            fi
        done
        # If we still have MAX_CONCURRENT tests running, wait a bit
        if [ ${#PIDS[@]} -ge $MAX_CONCURRENT ]; then
            sleep 1
        fi
    done
    
    # Start a new test
    test_start_time=$(date +%s)
    echo -e "${YELLOW}Starting test: ${TEST_NAME} (${#PIDS[@]}/${MAX_CONCURRENT} slots used)${NC}"
    echo -e "${YELLOW}Starting Docker containers for ${TEST_NAME} at $(date)${NC}"
    
    # Create a wrapper script to accurately measure test execution time
    WRAPPER_SCRIPT=$(mktemp)
    cat > "$WRAPPER_SCRIPT" << EOF
#!/bin/bash
# Record the actual start time of the test execution
ACTUAL_START_TIME=\$(date +%s)
echo "ACTUAL_TEST_START_TIME: \$ACTUAL_START_TIME" > "$LOG_FILE.timing"

# Run the actual test
"$TEST_SCRIPT" "\$@"
EXIT_CODE=\$?

# Record the actual end time
ACTUAL_END_TIME=\$(date +%s)
echo "ACTUAL_TEST_END_TIME: \$ACTUAL_END_TIME" >> "$LOG_FILE.timing"
echo "ACTUAL_TEST_EXIT_CODE: \$EXIT_CODE" >> "$LOG_FILE.timing"

exit \$EXIT_CODE
EOF
    chmod +x "$WRAPPER_SCRIPT"
    
    # Assign a unique color to this test
    test_color=$(get_test_color ${#TEST_NAMES[@]})
    
    if $VERBOSE; then
        # For verbose mode, we'll use a different approach that avoids named pipes
        # and ensures proper process tracking
        
        # Create a wrapper function to run the test with colored output
        run_test_with_output() {
            local test_script="$1"
            local test_name="$2"
            local color="$3"
            local log_file="$4"
            
            # Start with test headers
            echo "=== TEST START: $(date) ===" | tee -a "$log_file"
            if $DEBUG_DOCKER; then
                echo "=== DOCKER CONTAINERS BEING CREATED ===" | tee -a "$log_file"
            fi
            
            # Run the actual test script and capture its output
            # We use a different approach to ensure we get the correct exit code
            # Create a temporary file to store the exit code
            local exit_code_file=$(mktemp)
            
            # Run the test in a subshell that captures the exit code
            (
                # Run the test script
                "$test_script" 2>&1 | while IFS= read -r line; do
                    echo -e "${color}[${test_name}]${NC} $line" | tee -a "$log_file"
                done
                
                # Save the exit code of the test script to our temp file
                echo ${PIPESTATUS[0]} > "$exit_code_file"
            )
            
            # Read the exit code from the temp file
            local exit_code=$(cat "$exit_code_file")
            rm -f "$exit_code_file"
            
            echo "=== TEST END: $(date) ===" | tee -a "$log_file"
            return $exit_code
        }
        
        # Run the test with colored output
        run_test_with_output "$WRAPPER_SCRIPT" "$TEST_NAME" "$test_color" "$LOG_FILE" &
        PID=$!
    else
        # For non-verbose mode, run the test with output going only to the log file
        # but ensure we're properly tracking the process
        (
            echo "=== TEST START: $(date) ===" > "$LOG_FILE"
            if $DEBUG_DOCKER; then
                echo "=== DOCKER CONTAINERS BEING CREATED ===" >> "$LOG_FILE"
            fi
            "$WRAPPER_SCRIPT" >> "$LOG_FILE" 2>&1
            exit_code=$?
            echo "=== TEST END: $(date) ===" >> "$LOG_FILE"
            exit $exit_code
        ) &
        PID=$!
    fi
    
    PIDS+=($PID)
    TEST_NAMES+=($TEST_NAME)
    TEST_START_TIMES+=($test_start_time)
    TEST_COLORS+=($test_color)
    
    # Log the current state after starting a new test
    echo -e "${BLUE}Current test count: ${#PIDS[@]}/${MAX_CONCURRENT}${NC}"
    
    # Check Docker resources if debugging is enabled
    if $DEBUG_DOCKER; then
        if [ $((${#PIDS[@]} % 2)) -eq 0 ]; then  # Check every 2 tests
            echo -e "${YELLOW}Docker resource state after starting ${TEST_NAME}:${NC}"
            check_docker_resources
        fi
    fi
    
    # Optional: Add a small delay to prevent overwhelming Docker
    sleep 0.5
done

# Wait for remaining tests to finish
for i in "${!PIDS[@]}"; do
    wait_for_test ${PIDS[$i]} ${TEST_NAMES[$i]} "results/${TEST_NAMES[$i]}.log" ${TEST_START_TIMES[$i]}
done

# Final Docker resource check
if $DEBUG_DOCKER; then
    echo -e "${YELLOW}Final Docker resource state:${NC}"
    check_docker_resources
fi

# Create a detailed timing report
TIMING_FILE="results/timing_report.txt"
echo "TrustAInvest Integration Tests - Detailed Timing Report" > $TIMING_FILE
echo "Run at: $(date)" >> $TIMING_FILE
echo "=======================================" >> $TIMING_FILE
echo "" >> $TIMING_FILE

# Collect all test durations from timing files
echo "Individual Test Durations (Actual Execution Time):" >> $TIMING_FILE
echo "---------------------------------------------" >> $TIMING_FILE
for TEST_SCRIPT in $TEST_SCRIPTS; do
    TEST_NAME=$(basename "$TEST_SCRIPT")
    LOG_FILE="results/${TEST_NAME}.log"
    TIMING_DATA_FILE="${LOG_FILE}.timing"
    
    if [ -f "$TIMING_DATA_FILE" ]; then
        # Extract actual start and end times from timing file
        START_TIME=$(grep "ACTUAL_TEST_START_TIME:" "$TIMING_DATA_FILE" | cut -d' ' -f2)
        END_TIME=$(grep "ACTUAL_TEST_END_TIME:" "$TIMING_DATA_FILE" | cut -d' ' -f2)
        EXIT_CODE=$(grep "ACTUAL_TEST_EXIT_CODE:" "$TIMING_DATA_FILE" | cut -d' ' -f2)
        
        if [ -n "$START_TIME" ] && [ -n "$END_TIME" ]; then
            # Calculate actual duration
            ACTUAL_DURATION=$((END_TIME - START_TIME))
            FORMATTED_DURATION=$(format_time $ACTUAL_DURATION)
            
            # Get result (PASSED/FAILED)
            if [ "$EXIT_CODE" = "0" ]; then
                RESULT="PASSED"
            else
                RESULT="FAILED"
            fi
            
            printf "%-30s %-10s %s\n" "$TEST_NAME" "$RESULT" "$FORMATTED_DURATION" >> $TIMING_FILE
        else
            # Fallback to log file duration if timing data is incomplete
            DURATION=$(grep "Duration:" "$LOG_FILE" | head -1 | sed 's/.*Duration: //')
            if [ -z "$DURATION" ]; then
                DURATION="N/A"
            fi
            
            # Get result (PASSED/FAILED)
            if grep -q "RESULT: PASSED" "$LOG_FILE" 2>/dev/null; then
                RESULT="PASSED"
            else
                RESULT="FAILED"
            fi
            
            printf "%-30s %-10s %s (estimated)\n" "$TEST_NAME" "$RESULT" "$DURATION" >> $TIMING_FILE
        fi
    else
        # Fallback to log file duration if timing file doesn't exist
        DURATION=$(grep "Duration:" "$LOG_FILE" | head -1 | sed 's/.*Duration: //')
        if [ -z "$DURATION" ]; then
            DURATION="N/A"
        fi
        
        # Get result (PASSED/FAILED)
        if grep -q "RESULT: PASSED" "$LOG_FILE" 2>/dev/null; then
            RESULT="PASSED"
        else
            RESULT="FAILED"
        fi
        
        printf "%-30s %-10s %s (estimated)\n" "$TEST_NAME" "$RESULT" "$DURATION" >> $TIMING_FILE
    fi
done
echo "" >> $TIMING_FILE

# Add explanation of timing methods
echo "Note: 'Actual Execution Time' measures only the time the test script itself was running," >> $TIMING_FILE
echo "excluding any time spent waiting in the queue or for other tests to complete." >> $TIMING_FILE
echo "" >> $TIMING_FILE

# Generate summary report
SUMMARY_FILE="results/summary.txt"
echo "TrustAInvest Integration Tests Summary" > $SUMMARY_FILE
echo "Run at: $(date)" >> $SUMMARY_FILE
echo "=======================================" >> $SUMMARY_FILE
echo "Total tests:  $TOTAL_TESTS" >> $SUMMARY_FILE
echo "Passed tests: $PASSED_TESTS" >> $SUMMARY_FILE
echo "Failed tests: $FAILED_TESTS" >> $SUMMARY_FILE

# Calculate total execution time
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))
FORMATTED_DURATION=$(format_time $TOTAL_DURATION)

# Add total execution time to the summary
echo "Total execution time: $FORMATTED_DURATION" >> $SUMMARY_FILE
echo "" >> $SUMMARY_FILE

# Add explanation of timing
echo "Note: Total execution time is measured from the start of the test run to the end," >> $SUMMARY_FILE
echo "including all overhead and parallel execution benefits." >> $SUMMARY_FILE
echo "" >> $SUMMARY_FILE

# Add reference to timing report
echo "Detailed timing information available in results/timing_report.txt" >> $SUMMARY_FILE
echo "" >> $SUMMARY_FILE

if [ $FAILED_TESTS -eq 0 ]; then
    echo "All tests passed!" >> $SUMMARY_FILE
else
    echo "Some tests failed!" >> $SUMMARY_FILE
fi

# Generate HTML report with timing information
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
        .timing { color: #ff9900; font-weight: bold; }
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
        <p>Total execution time: <span class="timing">$FORMATTED_DURATION</span></p>
        <p><strong>Result: $([ $FAILED_TESTS -eq 0 ] && echo '<span class="passed">All tests passed!</span>' || echo '<span class="failed">Some tests failed!</span>')</strong></p>
    </div>
    
    <h2>Test Details</h2>
    <table>
        <tr>
            <th>Test</th>
            <th>Result</th>
            <th>Duration</th>
        </tr>
EOF

# Add test results to HTML report
for TEST_SCRIPT in $TEST_SCRIPTS; do
    TEST_NAME=$(basename "$TEST_SCRIPT")
    LOG_FILE="results/${TEST_NAME}.log"
    TIMING_DATA_FILE="${LOG_FILE}.timing"
    
    if grep -q "RESULT: PASSED" "$LOG_FILE" 2>/dev/null; then
        RESULT="<span class=\"passed\">PASSED</span>"
    else
        RESULT="<span class=\"failed\">FAILED</span>"
    fi
    
    # Try to get actual duration from timing file first
    if [ -f "$TIMING_DATA_FILE" ]; then
        START_TIME=$(grep "ACTUAL_TEST_START_TIME:" "$TIMING_DATA_FILE" | cut -d' ' -f2)
        END_TIME=$(grep "ACTUAL_TEST_END_TIME:" "$TIMING_DATA_FILE" | cut -d' ' -f2)
        
        if [ -n "$START_TIME" ] && [ -n "$END_TIME" ]; then
            # Calculate actual duration
            ACTUAL_DURATION=$((END_TIME - START_TIME))
            FORMATTED_DURATION=$(format_time $ACTUAL_DURATION)
            DURATION="<span class=\"timing\">${FORMATTED_DURATION}</span> (actual)"
        else
            # Fallback to log file duration
            DURATION=$(grep "Duration:" "$LOG_FILE" | head -1 | sed 's/.*Duration: //')
            if [ -z "$DURATION" ]; then
                DURATION="N/A"
            else
                DURATION="${DURATION} (estimated)"
            fi
        fi
    else
        # Fallback to log file duration
        DURATION=$(grep "Duration:" "$LOG_FILE" | head -1 | sed 's/.*Duration: //')
        if [ -z "$DURATION" ]; then
            DURATION="N/A"
        else
            DURATION="${DURATION} (estimated)"
        fi
    fi
    
    echo "<tr><td>$TEST_NAME</td><td>$RESULT</td><td>$DURATION</td></tr>" >> $HTML_REPORT
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
echo -e "Total execution time: ${YELLOW}${FORMATTED_DURATION}${NC}"

# Calculate sum of individual test times
SUM_TEST_TIMES=0
for TEST_SCRIPT in $TEST_SCRIPTS; do
    TEST_NAME=$(basename "$TEST_SCRIPT")
    TIMING_DATA_FILE="results/${TEST_NAME}.log.timing"
    
    if [ -f "$TIMING_DATA_FILE" ]; then
        # Extract actual start and end times from timing file
        START_TIME=$(grep "ACTUAL_TEST_START_TIME:" "$TIMING_DATA_FILE" | cut -d' ' -f2)
        END_TIME=$(grep "ACTUAL_TEST_END_TIME:" "$TIMING_DATA_FILE" | cut -d' ' -f2)
        
        if [ -n "$START_TIME" ] && [ -n "$END_TIME" ]; then
            # Calculate actual duration
            ACTUAL_DURATION=$((END_TIME - START_TIME))
            SUM_TEST_TIMES=$((SUM_TEST_TIMES + ACTUAL_DURATION))
        fi
    fi
done

# Format the sum of test times
SUM_FORMATTED=$(format_time $SUM_TEST_TIMES)
echo -e "Sum of individual test times: ${YELLOW}${SUM_FORMATTED}${NC}"
echo -e "Parallel execution saved: ${GREEN}$(format_time $((SUM_TEST_TIMES - TOTAL_DURATION)))${NC}"
echo

# Print individual test times
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   Individual Test Times (Actual)      ${NC}"
echo -e "${BLUE}=======================================${NC}"
for TEST_SCRIPT in $TEST_SCRIPTS; do
    TEST_NAME=$(basename "$TEST_SCRIPT")
    LOG_FILE="results/${TEST_NAME}.log"
    TIMING_DATA_FILE="${LOG_FILE}.timing"
    
    if [ -f "$TIMING_DATA_FILE" ]; then
        # Extract actual start and end times from timing file
        START_TIME=$(grep "ACTUAL_TEST_START_TIME:" "$TIMING_DATA_FILE" | cut -d' ' -f2)
        END_TIME=$(grep "ACTUAL_TEST_END_TIME:" "$TIMING_DATA_FILE" | cut -d' ' -f2)
        EXIT_CODE=$(grep "ACTUAL_TEST_EXIT_CODE:" "$TIMING_DATA_FILE" | cut -d' ' -f2)
        
        if [ -n "$START_TIME" ] && [ -n "$END_TIME" ]; then
            # Calculate actual duration
            ACTUAL_DURATION=$((END_TIME - START_TIME))
            FORMATTED_DURATION=$(format_time $ACTUAL_DURATION)
            
            # Get result (PASSED/FAILED)
            if [ "$EXIT_CODE" = "0" ]; then
                echo -e "${TEST_NAME}: ${GREEN}PASSED${NC} (actual runtime: ${YELLOW}${FORMATTED_DURATION}${NC})"
            else
                echo -e "${TEST_NAME}: ${RED}FAILED${NC} (actual runtime: ${YELLOW}${FORMATTED_DURATION}${NC})"
            fi
        else
            # Fallback to log file duration if timing data is incomplete
            DURATION=$(grep "Duration:" "$LOG_FILE" | head -1 | sed 's/.*Duration: //')
            if [ -z "$DURATION" ]; then
                DURATION="N/A"
            fi
            
            # Get result (PASSED/FAILED)
            if grep -q "RESULT: PASSED" "$LOG_FILE" 2>/dev/null; then
                echo -e "${TEST_NAME}: ${GREEN}PASSED${NC} (estimated: ${YELLOW}${DURATION}${NC})"
            else
                echo -e "${TEST_NAME}: ${RED}FAILED${NC} (estimated: ${YELLOW}${DURATION}${NC})"
            fi
        fi
    else
        # Fallback to log file duration if timing file doesn't exist
        DURATION=$(grep "Duration:" "$LOG_FILE" | head -1 | sed 's/.*Duration: //')
        if [ -z "$DURATION" ]; then
            DURATION="N/A"
        fi
        
        # Get result (PASSED/FAILED)
        if grep -q "RESULT: PASSED" "$LOG_FILE" 2>/dev/null; then
            echo -e "${TEST_NAME}: ${GREEN}PASSED${NC} (estimated: ${YELLOW}${DURATION}${NC})"
        else
            echo -e "${TEST_NAME}: ${RED}FAILED${NC} (estimated: ${YELLOW}${DURATION}${NC})"
        fi
    fi
done
echo

echo -e "Reports generated in ${YELLOW}results/${NC} directory"
echo -e "Detailed timing report: ${YELLOW}results/timing_report.txt${NC}"
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
