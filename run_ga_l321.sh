#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="base"
ROOT_OUTPUT_DIR="results/ga_l321"
EXECUTABLE="./GA/main.jl"
JULIA_THREADS="auto"

SEED=1234
POP_FACTOR=2
CROSSOVER_RATE=0.90
MUTATION_RATE=0.20
ELITISM_RATE=0.10
MAX_GEN=200
TRIALS=30

[[ -d "$BASE_DIR" ]] || { echo "[ERRO] Pasta '$BASE_DIR' não existe."; exit 1; }
[[ -f "$EXECUTABLE" ]] || { echo "[ERRO] Arquivo '$EXECUTABLE' não encontrado. Ajuste EXECUTABLE no script."; exit 1; }

mkdir -p "$ROOT_OUTPUT_DIR"

echo "[INFO] BASE_DIR       = $BASE_DIR"
echo "[INFO] OUTPUT_DIR     = $ROOT_OUTPUT_DIR"
echo "[INFO] EXECUTABLE     = $EXECUTABLE"
echo "[INFO] JULIA_THREADS  = $JULIA_THREADS"
echo "[INFO] Params: seed=$SEED pop_factor=$POP_FACTOR cx=$CROSSOVER_RATE mut=$MUTATION_RATE elit=$ELITISM_RATE gen=$MAX_GEN trials=$TRIALS"
echo

count_lines() { wc -l < "$1" | tr -d ' '; }

total=0
skipped=0
processed=0
start_all=$(date +%s)

tmp_list=$(mktemp)

# Gera lista "<linhas>\t<caminho>" para ordenar por tamanho
find "$BASE_DIR" -type f -name "*.txt" | while IFS= read -r f; do
  echo -e "$(count_lines "$f")\t$f" >> "$tmp_list"
done

# Se não encontrou nada
if [[ ! -s "$tmp_list" ]]; then
  echo "[WARN] Nenhuma instância .txt encontrada em '$BASE_DIR'."
  rm -f "$tmp_list"
  exit 0
fi

# Ordena por número de linhas
sort -n "$tmp_list" -o "$tmp_list"

while IFS=$'\t' read -r nlines instance; do
  total=$((total+1))

  rel="${instance#$BASE_DIR/}"
  rel_dir="$(dirname "$rel")"
  instance_name="$(basename "$instance")"
  instance_stem="${instance_name%.*}"

  out_dir="$ROOT_OUTPUT_DIR/$rel_dir"
  mkdir -p "$out_dir"
  out_csv="$out_dir/${instance_stem}.csv"

  if [[ -f "$out_csv" ]]; then
    echo "[SKIP] $rel (csv já existe)"
    skipped=$((skipped+1))
    continue
  fi

  echo "[RUN ] $rel (linhas=$nlines)"
  echo "      -> $out_csv"

  julia --threads "$JULIA_THREADS" "$EXECUTABLE" \
    --instance "$instance" \
    --seed "$SEED" \
    --pop_factor "$POP_FACTOR" \
    --crossover_rate "$CROSSOVER_RATE" \
    --mutation_rate "$MUTATION_RATE" \
    --elitism_rate "$ELITISM_RATE" \
    --max_gen "$MAX_GEN" \
    --trials "$TRIALS" \
    --output "$out_csv"

  processed=$((processed+1))
done < "$tmp_list"

rm -f "$tmp_list"

end_all=$(date +%s)
elapsed=$((end_all - start_all))

echo
echo "[DONE] total=$total processed=$processed skipped=$skipped elapsed_sec=$elapsed"