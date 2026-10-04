#!/bin/bash

# Verification script for Render backend deployment
# Проверка работоспособности backend на Render

API_URL="https://zairo-backend.onrender.com"
TIMEOUT=10

echo "========================================="
echo "🔍 ZAIRO Backend Verification Script"
echo "========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test endpoint
test_endpoint() {
    local name=$1
    local endpoint=$2
    local expected_status=$3

    echo -n "Testing $name... "

    response=$(curl -s -w "\n%{http_code}" --connect-timeout $TIMEOUT "$API_URL$endpoint" 2>&1)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "$expected_status" ]; then
        echo -e "${GREEN}✅ HTTP $http_code${NC}"
        echo "Response: $body" | head -3
        return 0
    else
        echo -e "${RED}❌ HTTP $http_code (expected $expected_status)${NC}"
        if [ ! -z "$body" ]; then
            echo "Response: $body" | head -3
        fi
        return 1
    fi
    echo ""
}

# 1. Health Check
echo "📊 1. HEALTH CHECK"
echo "---"
test_endpoint "Health" "/actuator/health" "200"
echo ""

# 2. Swagger UI
echo "📚 2. SWAGGER API DOCS"
echo "---"
test_endpoint "Swagger UI" "/swagger-ui/index.html" "200"
test_endpoint "OpenAPI JSON" "/v3/api-docs" "200"
echo ""

# 3. Cities API
echo "🌍 3. CITIES API"
echo "---"
echo "Testing GET /api/cities..."
curl -s -w "\nHTTP Status: %{http_code}\n" \
    "$API_URL/api/cities" | head -20
echo ""

# 4. Search API
echo "🔍 4. SEARCH API"
echo "---"
echo "Testing GET /api/search/services (with city=almaty)..."
curl -s -w "\nHTTP Status: %{http_code}\n" \
    "$API_URL/api/search/services?city=almaty&radius=50" | head -20
echo ""

# 5. Database check (indirect via API)
echo "🗄️  5. DATABASE CHECK"
echo "---"
echo "Checking if DB is responding (via Cities endpoint)..."
http_code=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/api/cities")
if [ "$http_code" = "200" ]; then
    echo -e "${GREEN}✅ Database is responding${NC}"
elif [ "$http_code" = "500" ]; then
    echo -e "${RED}❌ Database error (HTTP 500)${NC}"
    echo "Check Render logs for database connection errors"
else
    echo -e "${YELLOW}⚠️  Unexpected response: HTTP $http_code${NC}"
fi
echo ""

# 6. Authentication (optional)
echo "🔐 6. AUTHENTICATION (Optional)"
echo "---"
echo "POST /auth/signup test..."
curl -s -X POST "$API_URL/auth/signup" \
    -H "Content-Type: application/json" \
    -d '{"email":"test@test.com","password":"Test123!@#"}' \
    -w "\nHTTP Status: %{http_code}\n" | head -10
echo ""

# Summary
echo "========================================="
echo "✅ Verification Complete"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. If all tests pass → Cities are working ✅"
echo "2. If cities return empty → Check migrations (V69, V70)"
echo "3. If 500 errors → Check Render logs for DB connection"
echo "4. If endpoints not found → Restart Render service"
echo ""
