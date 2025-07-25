# NiFi Kubernetes 배포 가이드

## 네임스페이스 생성

```bash
kubectl create namespace nifi
```

## 배포

### 전체 리소스 배포
```bash
kubectl apply -f .
```

### 개별 리소스 배포
```bash
kubectl apply -f statefulset.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml
```

## 상태 확인

### Pod 상태 확인
```bash
kubectl get pods -n nifi
kubectl describe pod nifi-0 -n nifi
```

### StatefulSet 상태 확인
```bash
kubectl get statefulset -n nifi
kubectl describe statefulset nifi -n nifi
```

### 서비스 상태 확인
```bash
kubectl get svc -n nifi
kubectl describe svc nifi -n nifi
```

### Ingress 상태 확인
```bash
kubectl get ingress -n nifi
kubectl describe ingress nifi-ingress -n nifi
```

### PVC (Persistent Volume Claims) 확인
```bash
kubectl get pvc -n nifi
kubectl describe pvc -n nifi
```

## 로그 확인

### 실시간 로그 보기
```bash
kubectl logs -f nifi-0 -n nifi
```

### 이전 로그 보기
```bash
kubectl logs nifi-0 -n nifi --previous
```

## 접속

### NiFi UI 접속
- 외부 접속: https://nifi.nks.stjeong.com
- 기본 계정: admin / ctsBtRBKHRAx69EqUghvvgEvjnaLjFEB

### Pod 내부 접속
```bash
kubectl exec -it nifi-0 -n nifi -- /bin/bash
```

### 포트 포워딩으로 로컬 접속
```bash
kubectl port-forward nifi-0 8080:8080 -n nifi
```
그 후 http://localhost:8080 으로 접속

## 스케일링

### 레플리카 수정 (주의: NiFi는 클러스터 설정이 필요)
```bash
kubectl scale statefulset nifi --replicas=3 -n nifi
```

## 업데이트

### 이미지 업데이트
```bash
kubectl set image statefulset/nifi nifi=apache/nifi:1.24.0 -n nifi
```

### 롤아웃 상태 확인
```bash
kubectl rollout status statefulset/nifi -n nifi
```

### 롤아웃 히스토리
```bash
kubectl rollout history statefulset/nifi -n nifi
```

## 삭제

### 전체 리소스 삭제
```bash
kubectl delete -f .
```

### 개별 리소스 삭제
```bash
kubectl delete statefulset nifi -n nifi
kubectl delete svc nifi nifi-headless -n nifi
kubectl delete ingress nifi-ingress -n nifi
```

### PVC 삭제 (데이터 손실 주의!)
```bash
kubectl delete pvc -l app=nifi -n nifi
```

### 네임스페이스 삭제 (모든 리소스 삭제됨)
```bash
kubectl delete namespace nifi
```

## 트러블슈팅

### 이벤트 확인
```bash
kubectl get events -n nifi --sort-by='.lastTimestamp'
```

### 리소스 사용량 확인
```bash
kubectl top pod -n nifi
kubectl top node
```

### NiFi 설정 파일 확인
```bash
kubectl exec nifi-0 -n nifi -- cat /opt/nifi/nifi-current/conf/nifi.properties
```

### PV 상태 확인
```bash
kubectl get pv
kubectl describe pv <pv-name>
```