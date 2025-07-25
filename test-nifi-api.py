#!/usr/bin/env python3
"""
NiFi REST API 테스트 스크립트
사용법: python3 test-nifi-api.py [BASE_URL]
"""

import sys
import json
import base64
import urllib.request
import urllib.error
from datetime import datetime

# ANSI 색상 코드
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    MAGENTA = '\033[0;35m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color

# 기본 설정
BASE_URL = sys.argv[1] if len(sys.argv) > 1 else "http://nifi.nks.stjeong.com"
USERNAME = "admin"
PASSWORD = "ctsBtRBKHRAx69EqUghvvgEvjnaLjFEB"

def print_header():
    """헤더 출력"""
    print(f"{Colors.BLUE}{'='*50}{Colors.NC}")
    print(f"{Colors.BLUE}       NiFi REST API 테스트 스크립트{Colors.NC}")
    print(f"{Colors.BLUE}{'='*50}{Colors.NC}")
    print(f"Base URL: {Colors.GREEN}{BASE_URL}{Colors.NC}")
    print(f"테스트 시작: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print()

def make_request(method, endpoint, data=None, headers=None):
    """API 요청 수행"""
    url = f"{BASE_URL}{endpoint}"
    
    if headers is None:
        headers = {}
    headers['Accept'] = 'application/json'
    
    if data:
        headers['Content-Type'] = 'application/json'
        data = json.dumps(data).encode('utf-8')
    
    request = urllib.request.Request(url, data=data, headers=headers)
    request.get_method = lambda: method
    
    try:
        response = urllib.request.urlopen(request)
        status_code = response.getcode()
        body = response.read().decode('utf-8')
        return status_code, body, None
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8'), str(e)
    except Exception as e:
        return None, None, str(e)

def test_api(method, endpoint, description, data=None, show_response=True):
    """API 엔드포인트 테스트"""
    print(f"\n{Colors.YELLOW}테스트:{Colors.NC} {description}")
    print(f"  {Colors.BLUE}{method}{Colors.NC} {BASE_URL}{endpoint}")
    
    status_code, body, error = make_request(method, endpoint, data)
    
    if error and status_code is None:
        print(f"  {Colors.RED}✗ 연결 실패{Colors.NC}: {error}")
        return False
    
    if 200 <= status_code < 300:
        print(f"  {Colors.GREEN}✓ 성공{Colors.NC} (HTTP {status_code})")
        success = True
    else:
        print(f"  {Colors.RED}✗ 실패{Colors.NC} (HTTP {status_code})")
        success = False
    
    if show_response and body:
        try:
            parsed = json.loads(body)
            print(f"\n{Colors.CYAN}응답:{Colors.NC}")
            print(json.dumps(parsed, indent=2, ensure_ascii=False))
        except:
            print(f"\n{Colors.CYAN}응답:{Colors.NC}")
            print(body[:500] + "..." if len(body) > 500 else body)
    
    return success

def check_connection():
    """NiFi 연결 확인"""
    print(f"\n{Colors.BLUE}=== 1. NiFi 연결 확인 ==={Colors.NC}")
    try:
        response = urllib.request.urlopen(f"{BASE_URL}/nifi/")
        if response.getcode() == 200:
            print(f"{Colors.GREEN}✓ NiFi UI에 접근 가능{Colors.NC}")
            return True
    except:
        print(f"{Colors.RED}✗ NiFi에 연결할 수 없습니다.{Colors.NC}")
        print(f"  URL을 확인하세요: {BASE_URL}")
        print(f"  또는 다른 URL로 테스트: python3 {sys.argv[0]} http://localhost:8080")
        return False

def run_tests():
    """모든 테스트 실행"""
    tests = [
        ("GET", "/nifi-api/flow/about", "NiFi 버전 정보"),
        ("GET", "/nifi-api/flow/current-user", "현재 사용자 및 권한 정보"),
        ("GET", "/nifi-api/system-diagnostics", "시스템 리소스 및 상태", False),
        ("GET", "/nifi-api/flow/status", "전체 플로우 상태"),
        ("GET", "/nifi-api/flow/process-groups/root", "루트 프로세스 그룹 정보", False),
        ("GET", "/nifi-api/controller/config", "컨트롤러 설정 정보"),
        ("GET", "/nifi-api/flow/cluster/summary", "클러스터 요약 정보"),
        ("GET", "/nifi-api/counters", "시스템 카운터 정보"),
        ("GET", "/nifi-api/flow/templates", "사용 가능한 템플릿 목록"),
        ("GET", "/nifi-api/flow/config", "플로우 설정 정보"),
    ]
    
    results = {"success": 0, "failed": 0}
    
    for i, test in enumerate(tests, 2):
        print(f"\n{Colors.BLUE}=== {i}. {test[2].split()[0]} ==={Colors.NC}")
        show_response = True if len(test) < 4 else test[3]
        if test_api(test[0], test[1], test[2], show_response=show_response):
            results["success"] += 1
        else:
            results["failed"] += 1
    
    return results

def print_summary(results):
    """테스트 요약 출력"""
    print(f"\n{Colors.BLUE}{'='*50}{Colors.NC}")
    print(f"{Colors.BLUE}             테스트 완료{Colors.NC}")
    print(f"{Colors.BLUE}{'='*50}{Colors.NC}")
    print(f"\n테스트 결과:")
    print(f"  {Colors.GREEN}성공: {results['success']}{Colors.NC}")
    print(f"  {Colors.RED}실패: {results['failed']}{Colors.NC}")
    print(f"\n추가 테스트 옵션:")
    print(f"  - 다른 서버 테스트: python3 {sys.argv[0]} https://nifi.example.com")
    print(f"  - 인증이 필요한 경우 스크립트 내 USERNAME/PASSWORD 수정")
    print(f"\n자세한 API 문서:")
    print(f"  https://nifi.apache.org/docs/nifi-docs/rest-api/index.html")

def main():
    """메인 함수"""
    print_header()
    
    if not check_connection():
        sys.exit(1)
    
    results = run_tests()
    print_summary(results)

if __name__ == "__main__":
    main()