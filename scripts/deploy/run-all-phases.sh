#!/usr/bin/env bash
set -euo pipefail

# Orchestrator for deployment phase scripts. Tracks progress in .deploy-state and supports resume.

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ALL_PHASES=(phase0 phase1 phase2 phase3 phase4 phase5 phase6 phase7 phase8)
PHASE_SCRIPTS=(
  "scripts/deploy/00-phase0-local-prep.sh"
  "scripts/deploy/01-phase1-terraform.sh"
  "scripts/deploy/02-phase2-kubeconfig.sh"
  "scripts/deploy/03-phase3-core-addons.sh"
  "scripts/deploy/04-phase4-gatekeeper-policies.sh"
  "scripts/deploy/05-phase5-argocd-apps.sh"
  "scripts/deploy/06-phase6-monitoring.sh"
  "scripts/deploy/07-phase7-verification.sh"
  "scripts/deploy/08-phase8-threat-tests.sh"
)

usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Run deployment phases in order. State is stored in .deploy-state at repo root."
  echo ""
  echo "Options:"
  echo "  --from PHASE    Start from this phase (e.g. phase3). Earlier phases are not run."
  echo "  --reset         Delete .deploy-state and run from phase0."
  echo "  --status        Show which phases are done/pending and exit."
  echo "  --health        Run EKS health check (scripts/ops/eks-health-check.sh) and exit."
  echo "  --grafana       Start Grafana port-forward (scripts/ops/grafana-access.sh) and exit."
  echo "  --prometheus    Start Prometheus port-forward (scripts/ops/prometheus-access.sh) and exit."
  echo "  --help          Show this help."
  echo ""
  echo "Examples:"
  echo "  $0                    # Resume or start from phase0"
  echo "  $0 --status           # Print deployment progress"
  echo "  $0 --from phase4     # Run phase4 through phase8"
  echo "  $0 --reset            # Clear state and run all from phase0"
  echo "  $0 --health           # Run cluster health check"
  echo "  $0 --grafana          # Port-forward Grafana to localhost:3000"
  echo "  $0 --prometheus       # Port-forward Prometheus to localhost:9090"
}

resolve_repo_root() {
  if ! git rev-parse --show-toplevel &>/dev/null; then
    echo -e "${RED}Must run inside the project repository.${NC}"
    exit 1
  fi
  echo "$(git rev-parse --show-toplevel)"
}

state_file() {
  echo "$REPO_ROOT/.deploy-state"
}

read_state() {
  local f
  f="$(state_file)"
  if [[ -f "$f" ]]; then
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*#.*$ ]] && continue
      [[ "$line" =~ ^([^=]+)=(.*)$ ]] && echo "${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
    done < "$f"
  fi
}

is_phase_done() {
  local phase=$1
  read_state | grep -q "^${phase}=done$"
}

get_completed_phases() {
  local p
  for p in "${ALL_PHASES[@]}"; do
    is_phase_done "$p" && echo "$p"
  done
}

get_first_pending() {
  local p
  for p in "${ALL_PHASES[@]}"; do
    if ! is_phase_done "$p"; then
      echo "$p"
      return
    fi
  done
  echo ""
}

mark_done() {
  local phase=$1
  local f
  f="$(state_file)"
  if [[ -f "$f" ]] && grep -q "^${phase}=" "$f"; then
    sed -i "s/^${phase}=.*/${phase}=done/" "$f"
  else
    echo "${phase}=done" >> "$f"
  fi
}

validate_scripts() {
  local missing=()
  local s
  for s in "${PHASE_SCRIPTS[@]}"; do
    [[ -f "$REPO_ROOT/$s" ]] || missing+=("$s")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${RED}Missing phase scripts:${NC}"
    printf '%s\n' "${missing[@]}"
    exit 1
  fi
}

phase_index() {
  local phase=$1
  local i
  for i in "${!ALL_PHASES[@]}"; do
    [[ "${ALL_PHASES[i]}" == "$phase" ]] && { echo "$i"; return; }
  done
  echo -1
}

phase_display_name() {
  case "$1" in
    phase0) echo "local prep" ;;
    phase1) echo "Terraform (EKS)" ;;
    phase2) echo "kubeconfig" ;;
    phase3) echo "core add-ons" ;;
    phase4) echo "Gatekeeper policies" ;;
    phase5) echo "Argo CD apps" ;;
    phase6) echo "monitoring" ;;
    phase7) echo "verification" ;;
    phase8) echo "threat tests" ;;
    *) echo "$1" ;;
  esac
}

run_phase() {
  local phase=$1
  local idx
  idx=$(phase_index "$phase")
  [[ "$idx" -ge 0 ]] || { echo -e "${RED}Unknown phase: $phase${NC}"; exit 1; }
  local script="${PHASE_SCRIPTS[$idx]}"
  local path="$REPO_ROOT/$script"

  echo ""
  echo "======================================"
  echo "Running $phase: $(phase_display_name "$phase")"
  echo "======================================"
  if bash "$path"; then
    mark_done "$phase"
    echo -e "${GREEN}Phase $phase completed.${NC}"
    return 0
  else
    echo -e "${RED}Phase $phase failed.${NC}"
    echo "Fix the error and rerun:"
    echo "  $0"
    exit 1
  fi
}

print_status() {
  echo "Deployment progress:"
  echo ""
  local p
  for p in "${ALL_PHASES[@]}"; do
    if is_phase_done "$p"; then
      echo -e "  $p  ${GREEN}DONE${NC}"
    else
      echo -e "  $p  ${YELLOW}PENDING${NC}"
    fi
  done
}

main() {
  local from_phase=""
  local do_reset=false
  local do_status=false
  local do_health=false
  local do_grafana=false
  local do_prometheus=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)
        [[ $# -gt 1 ]] || { echo -e "${RED}--from requires PHASE${NC}"; usage; exit 1; }
        from_phase="$2"
        shift 2
        ;;
      --reset)
        do_reset=true
        shift
        ;;
      --status)
        do_status=true
        shift
        ;;
      --health)
        do_health=true
        shift
        ;;
      --grafana)
        do_grafana=true
        shift
        ;;
      --prometheus)
        do_prometheus=true
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo -e "${RED}Unknown option: $1${NC}"
        usage
        exit 1
        ;;
    esac
  done

  REPO_ROOT="$(resolve_repo_root)"
  cd "$REPO_ROOT"

  if [[ "$do_health" == true ]]; then
    bash "$REPO_ROOT/scripts/ops/eks-health-check.sh"
    exit 0
  fi
  if [[ "$do_grafana" == true ]]; then
    bash "$REPO_ROOT/scripts/ops/grafana-access.sh"
    exit 0
  fi
  if [[ "$do_prometheus" == true ]]; then
    bash "$REPO_ROOT/scripts/ops/prometheus-access.sh"
    exit 0
  fi

  validate_scripts

  if [[ "$do_status" == true ]]; then
    print_status
    exit 0
  fi

  if [[ "$do_reset" == true ]]; then
    rm -f "$(state_file)"
    echo -e "${YELLOW}State reset. Starting from phase0.${NC}"
    from_phase="phase0"
  fi

  local start_phase="phase0"
  if [[ -n "$from_phase" ]]; then
    if [[ $(phase_index "$from_phase") -lt 0 ]]; then
      echo -e "${RED}Invalid --from phase: $from_phase${NC}"
      exit 1
    fi
    start_phase="$from_phase"
  else
    if [[ -f "$(state_file)" ]]; then
      local completed
      completed=($(get_completed_phases))
      if [[ ${#completed[@]} -gt 0 ]]; then
        echo "Detected completed phases:"
        printf '  %s\n' "${completed[@]}"
        local first_pending
        first_pending=$(get_first_pending)
        if [[ -z "$first_pending" ]]; then
          echo -e "${GREEN}All phases already completed.${NC}"
          exit 0
        fi
        echo "Resuming from $first_pending"
        start_phase="$first_pending"
      fi
    fi
  fi

  local idx
  idx=$(phase_index "$start_phase")
  local i
  for (( i=idx; i<${#ALL_PHASES[@]}; i++ )); do
    run_phase "${ALL_PHASES[$i]}"
  done

  echo ""
  echo "======================================"
  echo -e "${GREEN}All phases completed successfully${NC}"
  echo "======================================"
}

main "$@"
