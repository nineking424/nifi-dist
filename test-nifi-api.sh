#!/bin/bash

# NiFi API 테스트 스크립트
# 사용법: ./test-nifi-api.sh [BASE_URL] [VERBOSE]

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# 기본 설정
BASE_URL="${1:-http://nifi.nks.stjeong.com}"
VERBOSE="${2:-false}"
USERNAME="admin"
PASSWORD="ctsBtRBKHRAx69EqUghvvgEvjnaLjFEB"

# 헤더 출력
print_header() {
    local width=50
    local line=$(printf '=%.0s' $(seq 1 $width))
    echo -e "\n${MAGENTA}${line}${NC}"
    echo -e "${MAGENTA}${BOLD}$(printf '%*s' $(((width + ${#1}) / 2)) "$1")${NC}"
    echo -e "${MAGENTA}${line}${NC}"
}

# 섹션 구분선
print_section() {
    echo -e "\n${CYAN}━━━ $1 ━━━${NC}"
}

# 진행 상황 표시
print_progress() {
    echo -e "\n${YELLOW}⏳ $1...${NC}"
}

# 함수: 디버그 출력
debug() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1" >&2
    fi
}

print_header "NiFi REST API 테스트 스크립트"
echo -e "\n📍 ${BOLD}Base URL:${NC} ${GREEN}$BASE_URL${NC}"
echo -e "🔧 ${BOLD}Verbose mode:${NC} ${GREEN}$VERBOSE${NC}"
echo -e "🕐 ${BOLD}실행 시간:${NC} $(date '+%Y-%m-%d %H:%M:%S')"

# 함수: API 호출 및 결과 출력
test_api() {
    local method=$1
    local endpoint=$2
    local description=$3
    local data=$4
    local show_body=${5:-true}
    
    echo -e "\n${YELLOW}▶ ${description}${NC}"
    echo -e "  ${DIM}$method $endpoint${NC}"
    
    debug "API 호출: $method $BASE_URL$endpoint"
    [ ! -z "$data" ] && debug "요청 데이터: $data"
    
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
        echo -e "  ${GREEN}✅ 성공${NC} ${DIM}(HTTP $http_code)${NC}"
    else
        echo -e "  ${RED}❌ 실패${NC} ${DIM}(HTTP $http_code)${NC}"
    fi
    
    debug "응답 코드: $http_code"
    if [ "$VERBOSE" = "true" ] && [ ! -z "$body" ]; then
        debug "응답 내용: $(echo "$body" | head -c 500)$([ ${#body} -gt 500 ] && echo "... [truncated]")"
    fi
    
    # JSON pretty print (jq가 설치되어 있는 경우) - VERBOSE 모드일 때만
    if [ "$show_body" = "true" ] && [ ! -z "$body" ] && [ "$VERBOSE" = "true" ]; then
        if command -v jq &> /dev/null; then
            # 컴팩트한 출력을 위해 중요 정보만 표시
            if echo "$body" | jq -e . >/dev/null 2>&1; then
                echo -e "\n${DIM}응답 내용:${NC}"
                echo "$body" | jq -C '.' 2>/dev/null | sed 's/^/  /'
            else
                echo -e "\n${DIM}응답 내용:${NC}"
                echo "$body" | sed 's/^/  /'
            fi
        else
            echo -e "\n${DIM}응답 내용:${NC}"
            echo "$body" | sed 's/^/  /'
        fi
    fi
}

# 함수: Basic Auth 헤더 생성
get_auth_header() {
    echo "Basic $(echo -n "$USERNAME:$PASSWORD" | base64)"
}

# 1. 연결 확인
print_section "연결 확인"
echo -e "\n🔍 NiFi 서버 연결 테스트 중..."
debug "연결 확인: curl -s -f $BASE_URL/nifi/"
if curl -s -f "$BASE_URL/nifi/" > /dev/null; then
    echo -e "${GREEN}✅ NiFi UI에 접근 가능${NC}"
    debug "NiFi UI 연결 성공"
else
    echo -e "${RED}❌ NiFi에 연결할 수 없습니다.${NC}"
    debug "NiFi UI 연결 실패"
    echo -e "\n${YELLOW}💡 해결 방법:${NC}"
    echo -e "  • URL 확인: ${CYAN}$BASE_URL${NC}"
    echo -e "  • 다른 URL로 테스트: ${CYAN}$0 http://localhost:8080${NC}"
    echo -e "  • 포트 포워딩 확인: ${CYAN}kubectl port-forward -n nifi svc/nifi 8080:8080${NC}"
    exit 1
fi

# 2. API 정보 확인
print_section "API 기본 정보"
debug "API 기본 정보 섹션 시작"
test_api "GET" "/nifi-api/flow/about" "NiFi 버전 정보"

# 3. 현재 사용자 정보
debug "현재 사용자 정보 확인"
test_api "GET" "/nifi-api/flow/current-user" "현재 사용자 및 권한 정보"

# 4. 시스템 진단
print_section "시스템 상태"
debug "시스템 진단 섹션 시작"
test_api "GET" "/nifi-api/system-diagnostics" "시스템 리소스 및 상태" "" false

# 5. 플로우 상태
debug "플로우 상태 확인"
test_api "GET" "/nifi-api/flow/status" "전체 플로우 상태"

# 6. 프로세스 그룹
print_section "프로세스 그룹 및 컨트롤러"
debug "프로세스 그룹 섹션 시작"
test_api "GET" "/nifi-api/flow/process-groups/root" "루트 프로세스 그룹 정보" "" false

# 7. 컨트롤러 설정
debug "컨트롤러 설정 확인"
test_api "GET" "/nifi-api/controller/config" "컨트롤러 설정 정보"

# 8. 클러스터 정보 (클러스터 모드인 경우)
print_section "기타 정보"
debug "기타 정보 섹션 시작"
test_api "GET" "/nifi-api/flow/cluster/summary" "클러스터 요약 정보"

# 9. 카운터
debug "시스템 카운터 정보 확인"
test_api "GET" "/nifi-api/counters" "시스템 카운터 정보" "" false

# 10. 템플릿 목록
debug "템플릿 목록 확인"
test_api "GET" "/nifi-api/flow/templates" "사용 가능한 템플릿 목록"

# 요약
print_header "테스트 완료"
debug "모든 테스트 완료"
echo -e "\n${GREEN}✅ 모든 API 테스트가 완료되었습니다!${NC}"
echo -e "\n${BOLD}📌 추가 옵션:${NC}"
echo -e "  ${CYAN}•${NC} 디버그 모드: ${DIM}$0 <URL> true${NC}"
echo -e "  ${CYAN}•${NC} 다른 서버: ${DIM}$0 http://localhost:8080${NC}"
echo -e "  ${CYAN}•${NC} 인증 설정: ${DIM}스크립트 내 USERNAME/PASSWORD 수정${NC}"
echo -e "\n${BOLD}📖 참고 문서:${NC}"
echo -e "  ${CYAN}•${NC} NiFi REST API: ${DIM}https://nifi.apache.org/docs/nifi-docs/rest-api/index.html${NC}"
echo ""