#Algoritmo Genético para rotulação L(3,2,1)
using Graphs
using Random
using Base.Threads

# Parametros do GA
struct GA_Parameters
    popsize::Int
    generations::Int
    elitism::Float64
    crossover::Float64
    mutation::Float64
end

# Indivíduo (cromossomo)
struct Individual
    genome::Vector{Int}
    fitness::Int
end

# Ordenação por fitness (menor é melhor)
Base.isless(a::Individual, b::Individual) = a.fitness < b.fitness

const Population = Vector{Individual}

# População inicial (cada indivíduo começa com fitness "infinito")
function init_population(n::Int, popsize::Int, rng::AbstractRNG)::Population
    pop = Vector{Individual}(undef, popsize)
    @inbounds for i in 1:popsize
        genome = randperm(rng, n)                       # permutação 1..n
        pop[i] = Individual(genome, typemax(Int))       # fitness inicial sentinela
    end
    return pop
end

# Avaliação: atualiza o fitness de cada indivíduo (in-place no vetor)
function evaluate!(population::Population, g::AbstractGraph, distsets)
    @threads for i in eachindex(population)
        _, span = greedy_l321(g, population[i].genome, distsets)  
        @inbounds population[i] = Individual(population[i].genome, span)    # atualiza fitness                    
    end
end                                    

# Seleção por torneio k=2: retorna índice do vencedor
function select(population::Population, rng::AbstractRNG)::Int
    n = length(population)           
    a = rand(rng, 1:n)             
    b = rand(rng, 1:n) 

    winner = (population[a].fitness <= population[b].fitness) ? a : b

    return winner
end

# Crossover OX (2 pontos)
function ox_two_point_crossover(p1::Individual, p2::Individual, rng::AbstractRNG)
    n = length(p1.genome)
    c1 = rand(rng, 1:n-1)
    c2 = rand(rng, (c1+1):n)

    # ---------- FILHO 1: segmento do p1, completa com p2 ----------
    child1 = fill(0, n)
    used1  = falses(n)

    @inbounds for i in c1:c2
        g = p1.genome[i]
        child1[i] = g
        used1[g] = true
    end

    idx = 1
    for g in p2.genome
        if !used1[g]
            while idx >= c1 && idx <= c2
                idx = c2 + 1
            end
            while idx <= n && child1[idx] != 0
                idx += 1
            end
            child1[idx] = g
            idx += 1
        end
    end

    # ---------- FILHO 2: segmento do p2, completa com p1 ----------
    child2 = fill(0, n)
    used2  = falses(n)

    @inbounds for i in c1:c2
        g = p2.genome[i]
        child2[i] = g
        used2[g] = true
    end

    idx = 1
    for g in p1.genome
        if !used2[g]
            while idx >= c1 && idx <= c2
                idx = c2 + 1
            end
            while idx <= n && child2[idx] != 0
                idx += 1
            end
            child2[idx] = g
            idx += 1
        end
    end
    return (Individual(child1, typemax(Int)), Individual(child2, typemax(Int)))
end

function mutate_swap(ind::Individual, mutation_rate::Float64, rng::AbstractRNG)::Individual
    # Se não passar na probabilidade, retorna o indivíduo como está
    if rand(rng) >= mutation_rate
        return ind
    end

    genome = copy(ind.genome)                 # copia para não alterar o pai
    n = length(genome)

    i = rand(rng, 1:n)                        # sorteia posição i
    j = rand(rng, 1:n)                        # sorteia posição j
    while j == i                              # garante i != j
        j = rand(rng, 1:n)
    end

    @inbounds genome[i], genome[j] = genome[j], genome[i]  # troca duas posições

    return Individual(genome, typemax(Int))   # fitness fica inválido até reavaliar
end

function run_ga_l321(params::GA_Parameters, g::AbstractGraph, distsets, seed::Int)
    rng = MersenneTwister(seed)                                   # RNG principal
    n = nv(g)                                                     # tamanho do genome

    # 1) inicializa população
    population = init_population(n, params.popsize, rng)           # Population

    # 2) avalia população inicial
    evaluate!(population, g, distsets)

    # guarda melhor global
    best_global = minimum(population)

    # para estatística (melhor fitness por geração)
    best_per_gen = Vector{Int}(undef, 0)

    for gen in 1:params.generations
        # ---- elitismo ----
        k = max(1, ceil(Int, params.elitism * params.popsize))     # tamanho da elite
        elites = partialsort(population, 1:k)                      # pega k melhores (usa isless)

        new_pop = Vector{Individual}(undef, params.popsize)        # nova população

        # copia elites
        @inbounds for i in 1:k
            new_pop[i] = elites[i]
        end

        # ---- gera filhos até completar população ----
        idx = k + 1                                                # próxima posição livre em new_pop
        while idx <= params.popsize
            # seleciona pais por torneio k=2
            p1 = population[ select(population, rng) ]
            p2 = population[ select(population, rng) ]

            # decide crossover
            if rand(rng) < params.crossover
                c1, c2 = ox_two_point_crossover(p1, p2, rng)       # 2 filhos
            else
                c1 = Individual(copy(p1.genome), typemax(Int))      # copia pai 1
                c2 = Individual(copy(p2.genome), typemax(Int))      # copia pai 2
            end

            # mutação swap (cada filho independentemente)
            c1 = mutate_swap(c1, params.mutation, rng)
            c2 = mutate_swap(c2, params.mutation, rng)

            # adiciona filhos (cuidando se falta só 1 vaga)
            new_pop[idx] = c1
            idx += 1
            if idx <= params.popsize
                new_pop[idx] = c2
                idx += 1
            end
        end

        # substitui população
        population = new_pop

        # avalia nova população
        evaluate!(population, g, distsets)

        # estatística: melhor da geração
        best_gen = minimum(population)
        push!(best_per_gen, best_gen.fitness)

        # atualiza melhor global
        if best_gen.fitness < best_global.fitness
            best_global = best_gen
        end
    end

    return best_global, best_per_gen
end