#!/bin/bash

# NiFi API 고급 테스트 스크립트
# 프로세서 생성, 수정, 삭제 등의 작업 테스트

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# 기본 설정
BASE_URL="${1:-http://nifi.nks.stjeong.com}"
PROCESS_GROUP_ID="root"

echo -e "${MAGENTA}======================================${NC}"
echo -e "${MAGENTA}  NiFi API 고급 테스트 스크립트${NC}"
echo -e "${MAGENTA}======================================${NC}"
echo -e "Base URL: ${GREEN}$BASE_URL${NC}"
echo ""

# 함수: 프로세스 그룹 ID 가져오기
get_root_process_group_id() {
    local response=$(curl -s "$BASE_URL/nifi-api/flow/process-groups/root")
    echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4
}

# 함수: 프로세서 생성
create_processor() {
    local pg_id=$1
    local name=$2
    local type=$3
    
    echo -e "\n${YELLOW}프로세서 생성:${NC} $name"
    
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
    
    response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$BASE_URL/nifi-api/process-groups/$pg_id/processors")
    
    processor_id=$(echo "$response" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ ! -z "$processor_id" ]; then
        echo -e "  ${GREEN}✓ 생성 성공${NC} - ID: $processor_id"
        echo "$processor_id"
    else
        echo -e "  ${RED}✗ 생성 실패${NC}"
        echo "$response" | head -n 5
        echo ""
    fi
}

# 함수: 프로세서 시작
start_processor() {
    local processor_id=$1
    
    echo -e "\n${YELLOW}프로세서 시작:${NC} $processor_id"
    
    # 먼저 현재 revision 가져오기
    local current=$(curl -s "$BASE_URL/nifi-api/processors/$processor_id")
    local version=$(echo "$current" | grep -o '"version":[0-9]*' | head -1 | cut -d':' -f2)
    
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
    
    response=$(curl -s -X PUT \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$BASE_URL/nifi-api/processors/$processor_id/run-status")
    
    if echo "$response" | grep -q "RUNNING"; then
        echo -e "  ${GREEN}✓ 시작 성공${NC}"
    else
        echo -e "  ${RED}✗ 시작 실패${NC}"
    fi
}

# 함수: 프로세서 중지
stop_processor() {
    local processor_id=$1
    
    echo -e "\n${YELLOW}프로세서 중지:${NC} $processor_id"
    
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
        echo -e "  ${GREEN}✓ 중지 성공${NC}"
    else
        echo -e "  ${RED}✗ 중지 실패${NC}"
    fi
}

# 함수: 프로세서 삭제
delete_processor() {
    local processor_id=$1
    
    echo -e "\n${YELLOW}프로세서 삭제:${NC} $processor_id"
    
    # 먼저 현재 revision 가져오기
    local current=$(curl -s "$BASE_URL/nifi-api/processors/$processor_id")
    local version=$(echo "$current" | grep -o '"version":[0-9]*' | head -1 | cut -d':' -f2)
    
    response=$(curl -s -X DELETE \
        "$BASE_URL/nifi-api/processors/$processor_id?version=$version")
    
    if [ -z "$response" ] || ! echo "$response" | grep -q "error"; then
        echo -e "  ${GREEN}✓ 삭제 성공${NC}"
    else
        echo -e "  ${RED}✗ 삭제 실패${NC}"
        echo "$response" | head -n 3
    fi
}

# 메인 테스트 시작
echo -e "\n${BLUE}=== 루트 프로세스 그룹 ID 가져오기 ===${NC}"
ROOT_PG_ID=$(get_root_process_group_id)
echo -e "루트 프로세스 그룹 ID: ${GREEN}$ROOT_PG_ID${NC}"

# GenerateFlowFile 프로세서 테스트
echo -e "\n${BLUE}=== GenerateFlowFile 프로세서 테스트 ===${NC}"
PROCESSOR_ID=$(create_processor "$ROOT_PG_ID" "Test GenerateFlowFile" "org.apache.nifi.processors.standard.GenerateFlowFile" | tail -1)

if [ ! -z "$PROCESSOR_ID" ]; then
    sleep 2
    start_processor "$PROCESSOR_ID"
    
    echo -e "\n${YELLOW}5초 동안 실행 중...${NC}"
    sleep 5
    
    stop_processor "$PROCESSOR_ID"
    sleep 2
    
    delete_processor "$PROCESSOR_ID"
fi

# LogMessage 프로세서 테스트
echo -e "\n${BLUE}=== LogMessage 프로세서 테스트 ===${NC}"
PROCESSOR_ID=$(create_processor "$ROOT_PG_ID" "Test LogMessage" "org.apache.nifi.processors.standard.LogMessage" | tail -1)

if [ ! -z "$PROCESSOR_ID" ]; then
    # 프로세서 설정 업데이트
    echo -e "\n${YELLOW}프로세서 설정 업데이트${NC}"
    
    current=$(curl -s "$BASE_URL/nifi-api/processors/$PROCESSOR_ID")
    version=$(echo "$current" | grep -o '"version":[0-9]*' | head -1 | cut -d':' -f2)
    
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
        echo -e "  ${GREEN}✓ 설정 업데이트 성공${NC}"
    else
        echo -e "  ${RED}✗ 설정 업데이트 실패${NC}"
    fi
    
    sleep 2
    delete_processor "$PROCESSOR_ID"
fi

# 요약
echo -e "\n${MAGENTA}======================================${NC}"
echo -e "${MAGENTA}         고급 테스트 완료${NC}"
echo -e "${MAGENTA}======================================${NC}"
echo -e "\n테스트한 기능:"
echo -e "  ✓ 프로세서 생성"
echo -e "  ✓ 프로세서 시작/중지"
echo -e "  ✓ 프로세서 설정 업데이트"
echo -e "  ✓ 프로세서 삭제"