# Operadores de mutação
# todas as mutações devem receber: (ind, mutation_rate, rng) e retornar: um indivíduo

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
