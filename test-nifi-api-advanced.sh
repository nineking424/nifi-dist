#!/bin/bash

# NiFi API 고급 테스트 스크립트
# 프로세서 생성, 수정, 삭제 등의 작업 테스트

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# 기본 설정
BASE_URL="${1:-http://nifi.nks.stjeong.com}"
PROCESS_GROUP_ID="root"
VERBOSE="${2:-false}"

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

print_header "NiFi API 고급 테스트 스크립트"
echo -e "\n📍 ${BOLD}Base URL:${NC} ${GREEN}$BASE_URL${NC}"
echo -e "🔧 ${BOLD}Verbose mode:${NC} ${GREEN}$VERBOSE${NC}"
echo -e "🕐 ${BOLD}실행 시간:${NC} $(date '+%Y-%m-%d %H:%M:%S')"

# 함수: 디버그 출력
debug() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1" >&2
    fi
}

# 함수: 프로세스 그룹 ID 가져오기
get_root_process_group_id() {
    local response=$(curl -s "$BASE_URL/nifi-api/flow/process-groups/root")
    echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
}

# 함수: 기존 테스트 프로세서 정리
cleanup_test_processors() {
    print_progress "기존 테스트 프로세서 정리"
    
    local response=$(curl -s "$BASE_URL/nifi-api/flow/process-groups/root")
    local processors=$(echo "$response" | jq -r '.processGroupFlow.flow.processors[] | select(.component.name | startswith("Test ")) | .component.id' 2>/dev/null)
    
    if [ -z "$processors" ]; then
        echo -e "  ${GREEN}정리할 프로세서가 없습니다${NC}"
        return
    fi
    
    for processor_id in $processors; do
        local processor_info=$(curl -s "$BASE_URL/nifi-api/processors/$processor_id")
        local processor_name=$(echo "$processor_info" | jq -r '.component.name' 2>/dev/null)
        local version=$(echo "$processor_info" | jq -r '.revision.version' 2>/dev/null)
        
        echo -e "  ${DIM}🗑  $processor_name${NC}"
        
        # 프로세서가 실행 중이면 먼저 중지
        local state=$(echo "$processor_info" | jq -r '.component.state' 2>/dev/null)
        if [ "$state" = "RUNNING" ]; then
            stop_processor "$processor_id" > /dev/null 2>&1
            sleep 1
        fi
        
        # 프로세서 삭제
        local delete_response=$(curl -s -X DELETE "$BASE_URL/nifi-api/processors/$processor_id?version=$version")
        if [ -z "$delete_response" ] || ! echo "$delete_response" | grep -q "error"; then
            echo -e "    ${GREEN}✅ 삭제 성공${NC}"
        else
            echo -e "    ${RED}❌ 삭제 실패${NC}"
            debug "Delete response: $delete_response"
        fi
    done
}

# 함수: 프로세서 생성
create_processor() {
    local pg_id=$1
    local name=$2
    local type=$3
    
    echo -e "\n${YELLOW}➕ 프로세서 생성:${NC} ${BOLD}$name${NC}" >&2
    
    local data=$(cat <<EOF
{
  "revision": {
    "version": 0
  },
  "component": {
    "type": "$type",
    "name": "$name",
    "position": {
      "x": 100,
      "y": 100
    }
  }
}
EOF
)
    
    debug "Creating processor with data: $data"
    
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$BASE_URL/nifi-api/process-groups/$pg_id/processors")
    
    debug "Create response: $response"
    
    processor_id=$(echo "$response" | jq -r '.id' 2>/dev/null)
    
    if [ ! -z "$processor_id" ] && [ "$processor_id" != "null" ]; then
        echo -e "  ${GREEN}✅ 생성 성공${NC} ${DIM}(ID: $processor_id)${NC}" >&2
        
        # 프로세서 타입에 따라 auto-terminate 설정
        if [[ "$type" == *"GenerateFlowFile"* ]] || [[ "$type" == *"LogMessage"* ]]; then
            echo -e "  ${DIM}⚙️  Auto-terminate 설정 중...${NC}" >&2
            set_auto_terminate "$processor_id" "success"
        fi
        
        # 프로세서 ID만 반환
        echo "$processor_id"
    else
        echo -e "  ${RED}❌ 생성 실패${NC}" >&2
        local error_msg=$(echo "$response" | jq -r '.message' 2>/dev/null || echo "$response")
        echo -e "  ${DIM}에러: $error_msg${NC}" >&2
        return 1
    fi
}

# 함수: Auto-terminate 설정
set_auto_terminate() {
    local processor_id=$1
    local relationship=$2
    
    # 현재 프로세서 정보 가져오기
    local current=$(curl -s "$BASE_URL/nifi-api/processors/$processor_id")
    local version=$(echo "$current" | jq -r '.revision.version' 2>/dev/null)
    
    # Auto-terminate 설정
    local data=$(cat <<EOF
{
  "revision": {
    "version": $version
  },
  "component": {
    "id": "$processor_id",
    "config": {
      "autoTerminatedRelationships": ["$relationship"]
    }
  }
}
EOF
)
    
    debug "Setting auto-terminate with data: $data"
    
    local response=$(curl -s -X PUT \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$BASE_URL/nifi-api/processors/$processor_id")
    
    if echo "$response" | jq -r '.component.relationships[] | select(.name == "'$relationship'") | .autoTerminate' 2>/dev/null | grep -q "true"; then
        echo -e "    ${GREEN}✅${NC} ${DIM}Auto-terminate 설정 성공${NC}" >&2
    else
        echo -e "    ${RED}❌${NC} ${DIM}Auto-terminate 설정 실패${NC}" >&2
        debug "Auto-terminate response: $response"
    fi
}

# 함수: 프로세서 시작
start_processor() {
    local processor_id=$1
    
    echo -e "\n${YELLOW}▶️ 프로세서 시작${NC}"
    
    # 먼저 현재 revision 가져오기
    local current=$(curl -s "$BASE_URL/nifi-api/processors/$processor_id")
    local version=$(echo "$current" | jq -r '.revision.version' 2>/dev/null)
    local state=$(echo "$current" | jq -r '.component.state' 2>/dev/null)
    
    # 이미 실행 중이면 스킵
    if [ "$state" = "RUNNING" ]; then
        echo -e "  ${GREEN}✅ 이미 실행 중${NC}"
        return 0
    fi
    
    # 유효성 검사
    local validation_errors=$(echo "$current" | jq -r '.component.validationErrors[]' 2>/dev/null)
    if [ ! -z "$validation_errors" ]; then
        echo -e "  ${RED}❌ 프로세서가 유효하지 않음:${NC}"
        echo "$validation_errors" | while read -r error; do
            echo -e "    ${DIM}• $error${NC}"
        done
        return 1
    fi
    
    local data=$(cat <<EOF
{
  "revision": {
    "version": $version
  },
  "state": "RUNNING",
  "disconnectedNodeAcknowledged": false
}
EOF
)
    
    debug "Starting processor with data: $data"
    
    response=$(curl -s -X PUT \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$BASE_URL/nifi-api/processors/$processor_id/run-status")
    
    debug "Start response: $response"
    
    if echo "$response" | jq -r '.component.state' 2>/dev/null | grep -q "RUNNING"; then
        echo -e "  ${GREEN}✅ 시작 성공${NC}"
    else
        echo -e "  ${RED}❌ 시작 실패${NC}"
        local error_msg=$(echo "$response" | jq -r '.message' 2>/dev/null || echo "알 수 없는 오류")
        echo -e "  ${DIM}에러: $error_msg${NC}"
    fi
}

# 함수: 프로세서 중지
stop_processor() {
    local processor_id=$1
    
    echo -e "\n${YELLOW}⏸️  프로세서 중지${NC}"
    
    # 먼저 현재 revision 가져오기
    local current=$(curl -s "$BASE_URL/nifi-api/processors/$processor_id")
    local version=$(echo "$current" | grep -o '"version":[0-9]*' | head -1 | cut -d':' -f2)
    
    local data=$(cat <<EOF
{
  "revision": {
    "version": $version
  },
  "state": "STOPPED",
  "disconnectedNodeAcknowledged": false
}
EOF
)
    
    response=$(curl -s -X PUT \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$BASE_URL/nifi-api/processors/$processor_id/run-status")
    
    if echo "$response" | grep -q "STOPPED"; then
        echo -e "  ${GREEN}✅ 중지 성공${NC}"
    else
        echo -e "  ${RED}❌ 중지 실패${NC}"
    fi
}

# 함수: 프로세서 삭제
delete_processor() {
    local processor_id=$1
    
    echo -e "\n${YELLOW}🗑  프로세서 삭제${NC}"
    
    # 먼저 현재 revision 가져오기
    local current=$(curl -s "$BASE_URL/nifi-api/processors/$processor_id")
    local version=$(echo "$current" | jq -r '.revision.version' 2>/dev/null)
    local state=$(echo "$current" | jq -r '.component.state' 2>/dev/null)
    
    debug "Processor state: $state, version: $version"
    
    # 프로세서가 실행 중이면 먼저 중지
    if [ "$state" = "RUNNING" ]; then
        stop_processor "$processor_id"
        sleep 1
        # 버전 다시 가져오기
        current=$(curl -s "$BASE_URL/nifi-api/processors/$processor_id")
        version=$(echo "$current" | jq -r '.revision.version' 2>/dev/null)
    fi
    
    response=$(curl -s -w "\n%{http_code}" -X DELETE \
        "$BASE_URL/nifi-api/processors/$processor_id?version=$version")
    
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')
    
    debug "Delete response code: $http_code, body: $body"
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
        echo -e "  ${GREEN}✅ 삭제 성공${NC}"
    else
        echo -e "  ${RED}❌ 삭제 실패${NC} ${DIM}(HTTP $http_code)${NC}"
        if [ ! -z "$body" ]; then
            local error_msg=$(echo "$body" | jq -r '.message' 2>/dev/null || echo "$body")
            echo -e "  ${DIM}에러: $error_msg${NC}"
        fi
    fi
}

# 메인 테스트 시작

# jq 설치 확인
if ! command -v jq &> /dev/null; then
    echo -e "\n${RED}⚠️  오류: jq가 설치되어 있지 않습니다.${NC}"
    echo -e "\n${YELLOW}💡 설치 방법:${NC}"
    echo -e "  ${CYAN}•${NC} macOS: ${DIM}brew install jq${NC}"
    echo -e "  ${CYAN}•${NC} Linux: ${DIM}apt-get install jq${NC}"
    exit 1
fi

# 기존 프로세서 정리
cleanup_test_processors

print_section "준비 작업"
echo -e "\n🔍 루트 프로세스 그룹 ID 가져오기..."
ROOT_PG_ID=$(get_root_process_group_id)
echo -e "  ${GREEN}✅${NC} ID: ${BOLD}$ROOT_PG_ID${NC}"

# GenerateFlowFile 프로세서 테스트
print_section "GenerateFlowFile 프로세서 테스트"
PROCESSOR_ID=$(create_processor "$ROOT_PG_ID" "Test GenerateFlowFile" "org.apache.nifi.processors.standard.GenerateFlowFile")

if [ ! -z "$PROCESSOR_ID" ]; then
    sleep 2
    start_processor "$PROCESSOR_ID"
    
    print_progress "5초 동안 실행 대기"
    for i in {1..5}; do
        echo -ne "\r  ${DIM}$i/5초...${NC}"
        sleep 1
    done
    echo -ne "\r            \r"
    
    stop_processor "$PROCESSOR_ID"
    sleep 2
    
    delete_processor "$PROCESSOR_ID"
fi

# LogMessage 프로세서 테스트
print_section "LogMessage 프로세서 테스트"
PROCESSOR_ID=$(create_processor "$ROOT_PG_ID" "Test LogMessage" "org.apache.nifi.processors.standard.LogMessage")

if [ ! -z "$PROCESSOR_ID" ]; then
    # 프로세서 설정 업데이트
    echo -e "\n${YELLOW}⚙️  프로세서 설정 업데이트${NC}"
    
    current=$(curl -s "$BASE_URL/nifi-api/processors/$PROCESSOR_ID")
    version=$(echo "$current" | jq -r '.revision.version' 2>/dev/null)
    
    data=$(cat <<EOF
{
  "revision": {
    "version": $version
  },
  "component": {
    "id": "$PROCESSOR_ID",
    "config": {
      "properties": {
        "log-level": "info",
        "log-message": "테스트 로그 메시지"
      }
    }
  }
}
EOF
)
    
    response=$(curl -s -X PUT \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$BASE_URL/nifi-api/processors/$PROCESSOR_ID")
    
    if echo "$response" | grep -q "테스트 로그 메시지"; then
        echo -e "  ${GREEN}✅ 설정 업데이트 성공${NC}"
    else
        echo -e "  ${RED}❌ 설정 업데이트 실패${NC}"
    fi
    
    sleep 2
    delete_processor "$PROCESSOR_ID"
fi

# 요약
print_header "고급 테스트 완료"
echo -e "\n${GREEN}✅ 모든 고급 API 테스트가 완료되었습니다!${NC}"
echo -e "\n${BOLD}📋 테스트한 기능:${NC}"
echo -e "  ${GREEN}✅${NC} 프로세서 생성 및 삭제"
echo -e "  ${GREEN}✅${NC} 프로세서 시작/중지 제어"
echo -e "  ${GREEN}✅${NC} 프로세서 설정 업데이트"
echo -e "  ${GREEN}✅${NC} Auto-terminate 관계 설정"
echo -e "\n${BOLD}📌 추가 옵션:${NC}"
echo -e "  ${CYAN}•${NC} 디버그 모드: ${DIM}$0 <URL> true${NC}"
echo -e "  ${CYAN}•${NC} 다른 서버: ${DIM}$0 http://localhost:8080${NC}"
echo ""