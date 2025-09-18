#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

LOG_DIR="$PROJECT_ROOT/logs"
PID_DIR="$SCRIPT_DIR/pids"

mkdir -p "$LOG_DIR" "$PID_DIR"

print_usage() {
  echo "사용법: $0 <start|status|stop|tail> [옵션]"
  echo "  start           예시 실험들을 nohup으로 실행합니다 (3개)"
  echo "  status          실행 중인 예시 실험들의 상태를 표시합니다"
  echo "  stop            실행 중인 예시 실험들을 종료합니다"
  echo "  tail <name>     logs/<name>.out 로그를 tail -f 로 확인합니다"
  echo "\n로그 디렉터리: $LOG_DIR"
  echo "PID 디렉터리 : $PID_DIR"
  echo "실행 전 가상환경 활성화/환경변수 설정을 권장합니다 (예: pyenv activate my_env)"
}

start_runs() {
  # 예시 1: ssac-bert lr=5e-4
  local name1="run_bert_lr5e-4"
  nohup python -u "$PROJECT_ROOT/src/main.py" \
    --run_name "ssac-bert" \
    --lr 5e-4 \
    > "$LOG_DIR/${name1}.out" 2>&1 & echo $! > "$PID_DIR/${name1}.pid"

  # 예시 2: ssac-bert lr=5e-3
  local name2="run_bert_lr5e-3"
  nohup python -u "$PROJECT_ROOT/src/main.py" \
    --run_name "ssac-bert" \
    --lr 5e-3 \
    > "$LOG_DIR/${name2}.out" 2>&1 & echo $! > "$PID_DIR/${name2}.pid"

  # 예시 3: roberta-large
  local name3="run_roberta"
  nohup python -u "$PROJECT_ROOT/src/main.py" \
    --model_name klue/roberta-large \
    --run_name "ssac-roberta" \
    --lr 3e-5 \
    > "$LOG_DIR/${name3}.out" 2>&1 & echo $! > "$PID_DIR/${name3}.pid"

  echo "시작 완료: ${name1}, ${name2}, ${name3}"
  echo "로그는 $LOG_DIR/*.out 에 저장됩니다."
}

status_runs() {
  local any=0
  for pidf in "$PID_DIR"/*.pid 2>/dev/null; do
    [ -f "$pidf" ] || continue
    any=1
    local name
    name=$(basename "$pidf" .pid)
    local pid
    pid=$(cat "$pidf" || echo "")
    if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
      echo "${name}: RUNNING (pid=$pid)"
    else
      echo "${name}: NOT RUNNING (pid 파일 존재)"
    fi
  done
  if [ $any -eq 0 ]; then
    echo "저장된 PID가 없습니다. ($PID_DIR)"
  fi
}

stop_runs() {
  local any=0
  for pidf in "$PID_DIR"/*.pid 2>/dev/null; do
    [ -f "$pidf" ] || continue
    any=1
    local name
    name=$(basename "$pidf" .pid)
    local pid
    pid=$(cat "$pidf" || echo "")
    if [ -n "$pid" ] && ps -p "$pid" >/dev/null 2>&1; then
      echo "종료 중: ${name} (pid=$pid)"
      kill "$pid" || true
      sleep 1
      if ps -p "$pid" >/dev/null 2>&1; then
        echo "강제 종료: ${name} (pid=$pid)"
        kill -9 "$pid" || true
      fi
    else
      echo "이미 종료됨: ${name}"
    fi
    rm -f "$pidf"
  done
  if [ $any -eq 0 ]; then
    echo "종료할 PID가 없습니다. ($PID_DIR)"
  fi
}

tail_log() {
  local name=${1:-}
  if [ -z "$name" ]; then
    echo "오류: 로그 이름이 필요합니다. 예) $0 tail run_bert_lr5e-4"; exit 1; fi
  local file="$LOG_DIR/${name}.out"
  if [ ! -f "$file" ]; then
    echo "로그 파일이 없습니다: $file"; exit 1; fi
  tail -f "$file"
}

cmd=${1:-}
case "$cmd" in
  start)
    start_runs
    ;;
  status)
    status_runs
    ;;
  stop)
    stop_runs
    ;;
  tail)
    shift || true
    tail_log "${1:-}"
    ;;
  *)
    print_usage
    ;;
esac


