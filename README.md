# NiFi Kubernetes Distribution

Apache NiFi를 Kubernetes에 배포하기 위한 구성 파일들입니다.

## 프로젝트 구조

```
.
├── README.md                    # 이 파일
├── instruction.md               # 상세 배포 가이드
├── statefulset.yaml            # NiFi StatefulSet 정의
├── service.yaml                # NiFi Service 정의
├── ingress.yaml                # NiFi Ingress 정의
├── test-nifi-api.sh            # 기본 API 테스트 스크립트
└── test-nifi-api-advanced.sh   # 고급 API 테스트 스크립트 (프로세서 CRUD)
```

## 주요 특징

- **StatefulSet**: NiFi 인스턴스의 안정적인 상태 유지
- **Persistent Volumes**: 5개의 PVC로 데이터 영속성 보장
  - nifi-data (5Gi)
  - nifi-logs (2Gi)
  - nifi-flowfile-repo (10Gi)
  - nifi-content-repo (20Gi)
  - nifi-provenance-repo (10Gi)
- **Ingress**: nifi.nks.stjeong.com 도메인으로 외부 접근
- **Anonymous Access**: 개발 환경을 위한 익명 접근 허용

## 빠른 시작

```bash
# 네임스페이스 생성
kubectl create namespace nifi

# 모든 리소스 배포
kubectl apply -f .

# 배포 상태 확인
kubectl get all -n nifi
```

## 접속 정보

- **웹 UI**: http://nifi.nks.stjeong.com
- **기본 계정**: admin / ctsBtRBKHRAx69EqUghvvgEvjnaLjFEB

## API 테스트

```bash
# 기본 API 테스트
./test-nifi-api.sh

# 고급 기능 테스트 (프로세서 생성/삭제)
./test-nifi-api-advanced.sh
```

자세한 내용은 [instruction.md](instruction.md)를 참조하세요.