# Algoritmo Genético para rotulação L(3,2,1)
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

include("selection_ops.jl")
include("crossover_ops.jl")
include("mutation_ops.jl")

# População inicial paralela com RNG local por indivíduo
# Cada indivíduo começa com fitness "infinito"
function init_population(n::Int, popsize::Int, seed::Int)::Population 
    pop = Vector{Individual}(undef, popsize)

    @threads for i in 1:popsize
        local_rng = MersenneTwister(seed + i)                   # RNG independente por indivíduo
        genome = randperm(local_rng, n)                         # permutação 1..n
        
        @inbounds pop[i] = Individual(genome, typemax(Int))     # fitness inicial sentinela
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

function run_ga_l321(params::GA_Parameters, g::AbstractGraph, distsets, seed::Int,  
                    selection_op, crossover_op, mutation_op)
    n = nv(g)

    # 1) inicializa população
    population = init_population(n, params.popsize, seed)

    # 2) avalia população inicial
    evaluate!(population, g, distsets)

    # guarda melhor global
    best_global = minimum(population)

    # para estatística (melhor fitness por geração)
    best_per_gen = Vector{Int}(undef, 0)

    for gen in 1:params.generations
        # ---- elitismo: preserva os k melhores ----
        k = max(1, ceil(Int, params.elitism * params.popsize))
        elites = partialsort(population, 1:k)

        # nova população
        new_pop = Vector{Individual}(undef, params.popsize)

        # copia elite para o início
        @inbounds for i in 1:k
            new_pop[i] = elites[i]
        end

        # quantidade de filhos e de pares
        nchildren = params.popsize - k
        npairs = cld(nchildren, 2)

        # gera pares de filhos em paralelo
        @threads for pair_id in 1:npairs
            # RNG local por par
            local_rng = MersenneTwister(seed + gen * 1_000_000 + pair_id)

            # posições fixas deste par
            pos1 = k + 2 * pair_id - 1
            pos2 = pos1 + 1

            # seleção de pais
            p1 = population[selection_op(population, local_rng)]
            p2 = population[selection_op(population, local_rng)]

            # crossover ou cópia direta
            if rand(local_rng) < params.crossover
                c1, c2 = crossover_op(p1, p2, local_rng)
            else
                c1 = Individual(copy(p1.genome), typemax(Int))
                c2 = Individual(copy(p2.genome), typemax(Int))
            end

            # mutação
            c1 = mutation_op(c1, params.mutation, local_rng)
            c2 = mutation_op(c2, params.mutation, local_rng)

            # grava filhos
            @inbounds begin
                new_pop[pos1] = c1
                if pos2 <= params.popsize
                    new_pop[pos2] = c2
                end
            end
        end

        # substitui população e avalia
        population = new_pop
        evaluate!(population, g, distsets)

        # melhor da geração
        best_gen = minimum(population)
        push!(best_per_gen, best_gen.fitness)

        # atualiza melhor global
        if best_gen.fitness < best_global.fitness
            best_global = best_gen
        end
    end

    return best_global, best_per_gen
end