#!/bin/bash

# NiFi API 테스트 스크립트
# 사용법: ./test-nifi-api.sh [BASE_URL]

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 기본 설정
BASE_URL="${1:-http://nifi.nks.stjeong.com}"
USERNAME="admin"
PASSWORD="ctsBtRBKHRAx69EqUghvvgEvjnaLjFEB"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}   NiFi REST API 테스트 스크립트${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "Base URL: ${GREEN}$BASE_URL${NC}"
echo ""

# 함수: API 호출 및 결과 출력
test_api() {
    local method=$1
    local endpoint=$2
    local description=$3
    local data=$4
    
    echo -e "\n${YELLOW}테스트:${NC} $description"
    echo -e "  ${BLUE}$method${NC} $BASE_URL$endpoint"
    
    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X $method \
            -H "Accept: application/json" \
            "$BASE_URL$endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" -X $method \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "$BASE_URL$endpoint")
    fi
    
    # HTTP 상태 코드 추출
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo -e "  ${GREEN}✓ 성공${NC} (HTTP $http_code)"
    else
        echo -e "  ${RED}✗ 실패${NC} (HTTP $http_code)"
    fi
    
    # JSON pretty print (jq가 설치되어 있는 경우)
    if command -v jq &> /dev/null && [ ! -z "$body" ]; then
        echo "$body" | jq '.' 2>/dev/null || echo "$body"
    else
        echo "$body"
    fi
}

# 함수: Basic Auth 헤더 생성
get_auth_header() {
    echo "Basic $(echo -n "$USERNAME:$PASSWORD" | base64)"
}

# 1. 연결 확인
echo -e "\n${BLUE}=== 1. NiFi 연결 확인 ===${NC}"
if curl -s -f "$BASE_URL/nifi/" > /dev/null; then
    echo -e "${GREEN}✓ NiFi UI에 접근 가능${NC}"
else
    echo -e "${RED}✗ NiFi에 연결할 수 없습니다.${NC}"
    echo -e "  URL을 확인하세요: $BASE_URL"
    echo -e "  또는 다른 URL로 테스트: $0 http://localhost:8080"
    exit 1
fi

# 2. API 정보 확인
echo -e "\n${BLUE}=== 2. API 정보 확인 ===${NC}"
test_api "GET" "/nifi-api/flow/about" "NiFi 버전 정보"

# 3. 현재 사용자 정보
echo -e "\n${BLUE}=== 3. 현재 사용자 정보 ===${NC}"
test_api "GET" "/nifi-api/flow/current-user" "현재 사용자 및 권한 정보"

# 4. 시스템 진단
echo -e "\n${BLUE}=== 4. 시스템 진단 ===${NC}"
test_api "GET" "/nifi-api/system-diagnostics" "시스템 리소스 및 상태"

# 5. 플로우 상태
echo -e "\n${BLUE}=== 5. 플로우 상태 ===${NC}"
test_api "GET" "/nifi-api/flow/status" "전체 플로우 상태"

# 6. 프로세스 그룹
echo -e "\n${BLUE}=== 6. 프로세스 그룹 ===${NC}"
test_api "GET" "/nifi-api/flow/process-groups/root" "루트 프로세스 그룹 정보"

# 7. 컨트롤러 설정
echo -e "\n${BLUE}=== 7. 컨트롤러 설정 ===${NC}"
test_api "GET" "/nifi-api/controller/config" "컨트롤러 설정 정보"

# 8. 클러스터 정보 (클러스터 모드인 경우)
echo -e "\n${BLUE}=== 8. 클러스터 정보 ===${NC}"
test_api "GET" "/nifi-api/flow/cluster/summary" "클러스터 요약 정보"

# 9. 카운터
echo -e "\n${BLUE}=== 9. 카운터 ===${NC}"
test_api "GET" "/nifi-api/counters" "시스템 카운터 정보"

# 10. 템플릿 목록
echo -e "\n${BLUE}=== 10. 템플릿 ===${NC}"
test_api "GET" "/nifi-api/flow/templates" "사용 가능한 템플릿 목록"

# 요약
echo -e "\n${BLUE}======================================${NC}"
echo -e "${BLUE}          테스트 완료${NC}"
echo -e "${BLUE}======================================${NC}"
echo -e "\n추가 테스트 옵션:"
echo -e "  - 다른 서버 테스트: $0 https://nifi.example.com"
echo -e "  - 인증이 필요한 경우 스크립트 내 USERNAME/PASSWORD 수정"
echo -e "\n자세한 API 문서:"
echo -e "  https://nifi.apache.org/docs/nifi-docs/rest-api/index.html"