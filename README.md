# GA-L321
Algoritmo Genético para o Problema da Rotulação L(3,2,1) em Grafos.

Este projeto implementa um algoritmo genético baseado em permutação (PBGA), utilizando:
- Seleção por torneio binário (k = 2)
- Cruzamento Order Crossover (OX) de 2 pontos (gerando 2 filhos)
- Mutação Swap (troca de duas posições)
- Elitismo (preservação parcial)

A avaliação (fitness) é feita por um algoritmo guloso para rotulação L(3,2,1), onde o fitness é o *span* (maior rótulo atribuído), e o objetivo é minimizá-lo.

## Requisitos
O projeto foi desenvolvido em Julia. Você deve ter o Julia instalado e os seguintes pacotes disponíveis:

- Graphs.jl
- ArgParse.jl
- CSV.jl
- DataFrames.jl
- Random.jl

## Estrutura esperada (padrão)
- `base/` : diretório contendo as instâncias (edge-list `.txt`, uma aresta por linha: `u v`)
- `results/ga_l321/` : diretório onde os CSVs de saída serão gerados
- `GA/main.jl` : script principal (CLI) do GA
- `GA/ga_l321.jl` : implementação do GA
- `GREEDY/greedy_l321.jl` : implementação do guloso e do pré-cálculo `distsets`
- `run_ga_l321.sh` : script para execução em lote

## Execução
Para executar o GA em lote (percorrendo recursivamente `base/` e gerando CSVs em `results/ga_l321/`):

```bash
chmod +x run_ga_l321.sh
./run_ga_l321.sh
