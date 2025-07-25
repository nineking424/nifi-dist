# ZooKeeper Kubernetes 배포 가이드

## 네임스페이스 생성

```bash
kubectl create namespace nifi
```

## 배포

### 전체 리소스 배포
```bash
kubectl apply -f ./zookeeper/
```

### 개별 리소스 배포
```bash
kubectl apply -f ./zookeeper/statefulset.yaml
kubectl apply -f ./zookeeper/service.yaml
kubectl apply -f ./zookeeper/ingress.yaml
```

## 상태 확인

### Pod 상태 확인
```bash
kubectl get pods -n nifi -l app=zookeeper
kubectl describe pod zookeeper-0 -n nifi
```

### StatefulSet 상태 확인
```bash
kubectl get statefulset zookeeper -n nifi
kubectl describe statefulset zookeeper -n nifi
```

### 서비스 상태 확인
```bash
kubectl get svc -n nifi -l app=zookeeper
kubectl describe svc zookeeper -n nifi
```

### Ingress 상태 확인
```bash
kubectl get ingress zookeeper-ingress -n nifi
kubectl describe ingress zookeeper-ingress -n nifi
```

### PVC (Persistent Volume Claims) 확인
```bash
kubectl get pvc -n nifi -l app=zookeeper
kubectl describe pvc -n nifi
```

## 로그 확인

### 실시간 로그 보기
```bash
kubectl logs -f zookeeper-0 -n nifi
kubectl logs -f zookeeper-1 -n nifi
kubectl logs -f zookeeper-2 -n nifi
```

### 모든 ZooKeeper Pod 로그
```bash
kubectl logs -f -l app=zookeeper -n nifi
```

## 접속 및 관리

### ZooKeeper CLI 접속
```bash
kubectl exec -it zookeeper-0 -n nifi -- kafka-console-consumer --bootstrap-server localhost:9092 --topic __consumer_offsets
```

### ZooKeeper 상태 확인
```bash
kubectl exec -it zookeeper-0 -n nifi -- sh -c 'echo "ruok" | nc localhost 2181'
kubectl exec -it zookeeper-1 -n nifi -- sh -c 'echo "ruok" | nc localhost 2181'
kubectl exec -it zookeeper-2 -n nifi -- sh -c 'echo "ruok" | nc localhost 2181'
```

### ZooKeeper 클러스터 상태
```bash
kubectl exec -it zookeeper-0 -n nifi -- sh -c 'echo "stat" | nc localhost 2181'
```

### ZooKeeper 리더 확인
```bash
kubectl exec -it zookeeper-0 -n nifi -- sh -c 'echo "srvr" | nc localhost 2181 | grep Mode'
kubectl exec -it zookeeper-1 -n nifi -- sh -c 'echo "srvr" | nc localhost 2181 | grep Mode'
kubectl exec -it zookeeper-2 -n nifi -- sh -c 'echo "srvr" | nc localhost 2181 | grep Mode'
```

### Pod 내부 접속
```bash
kubectl exec -it zookeeper-0 -n nifi -- /bin/bash
```

### 포트 포워딩으로 로컬 접속
```bash
kubectl port-forward zookeeper-0 2181:2181 -n nifi
```

## 스케일링

### 레플리카 수정 (홀수 개수 권장)
```bash
kubectl scale statefulset zookeeper --replicas=5 -n nifi
```

## 업데이트

### 이미지 업데이트
```bash
kubectl set image statefulset/zookeeper zookeeper=confluentinc/cp-zookeeper:7.5.0 -n nifi
```

### 롤아웃 상태 확인
```bash
kubectl rollout status statefulset/zookeeper -n nifi
```

### 롤아웃 히스토리
```bash
kubectl rollout history statefulset/zookeeper -n nifi
```

## ZooKeeper 클러스터 관리

### 앙상블 멤버 확인
```bash
kubectl exec -it zookeeper-0 -n nifi -- sh -c 'echo "conf" | nc localhost 2181'
```

### 연결된 클라이언트 확인
```bash
kubectl exec -it zookeeper-0 -n nifi -- sh -c 'echo "cons" | nc localhost 2181'
```

### 감시 중인 경로 확인
```bash
kubectl exec -it zookeeper-0 -n nifi -- sh -c 'echo "wchs" | nc localhost 2181'
```

### ZooKeeper 데이터 덤프
```bash
kubectl exec -it zookeeper-0 -n nifi -- sh -c 'echo "dump" | nc localhost 2181'
```

## 삭제

### 전체 리소스 삭제
```bash
kubectl delete -f ./zookeeper/
```

### 개별 리소스 삭제
```bash
kubectl delete statefulset zookeeper -n nifi
kubectl delete svc zookeeper zookeeper-headless -n nifi
kubectl delete ingress zookeeper-ingress -n nifi
kubectl delete configmap zookeeper-tcp -n nifi
```

### PVC 삭제 (데이터 손실 주의!)
```bash
kubectl delete pvc -l app=zookeeper -n nifi
```

## 트러블슈팅

### 이벤트 확인
```bash
kubectl get events -n nifi --sort-by='.lastTimestamp' --field-selector involvedObject.name=zookeeper-0
```

### 리소스 사용량 확인
```bash
kubectl top pod -n nifi -l app=zookeeper
```

### ZooKeeper 설정 확인
```bash
kubectl exec zookeeper-0 -n nifi -- env | grep ZOOKEEPER
```

### myid 파일 확인
```bash
kubectl exec zookeeper-0 -n nifi -- cat /var/lib/zookeeper/data/myid
kubectl exec zookeeper-1 -n nifi -- cat /var/lib/zookeeper/data/myid
kubectl exec zookeeper-2 -n nifi -- cat /var/lib/zookeeper/data/myid
```

### 네트워크 연결 테스트
```bash
kubectl exec -it zookeeper-0 -n nifi -- nc -zv zookeeper-1.zookeeper-headless.nifi.svc.cluster.local 2888
kubectl exec -it zookeeper-0 -n nifi -- nc -zv zookeeper-2.zookeeper-headless.nifi.svc.cluster.local 2888
```

## 외부 접속

- ZooKeeper UI (필요시): http://zookeeper.nks.stjeong.com
- 직접 연결: zookeeper.nks.stjeong.com:2181