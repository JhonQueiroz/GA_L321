# Operadores de mutação
# todas as mutações devem receber: (ind, mutation_rate, rng) e retornar: um indivíduo

# SWAP: Troca duas posições
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

# Simple Inversion Mutation (SIM)
function mutate_inversion(ind::Individual, mutation_rate::Float64, rng::AbstractRNG)::Individual

    if rand(rng) >= mutation_rate
        return ind
    end

    genome = copy(ind.genome)                         # copia para não alterar o pai
    n = length(genome)

    i = rand(rng, 1:n-1)                              # i no máximo n-1
    j = rand(rng, (i+1):n)                            # j pelo menos i+1

    # Inverte o segmento [i..j] in-place (swap dos extremos indo para o centro)
    l = i
    r = j
    @inbounds while l < r
        genome[l], genome[r] = genome[r], genome[l]   # troca extremidades
        l += 1
        r -= 1
    end

    return Individual(genome, typemax(Int))       
end

