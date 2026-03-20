# Operadores de seleção
# todas as seleções devem receber: (population, rng) e retornar: índice do indivíduo escolhido


# Seleção por torneio k=2: retorna índice do vencedor
function selection_tournament(population::Population, rng::AbstractRNG)::Int
    n = length(population)           
    a = rand(rng, 1:n)             
    b = rand(rng, 1:n) 

    winner = (population[a].fitness <= population[b].fitness) ? a : b

    return winner
end

# Seleção por roleta
function selection_roulette(population::Population, rng::AbstractRNG)::Int
    n = length(population)

    # vetor de pesos dos indivíduos
    weights = Vector{Float64}(undef, n)
    total_weight = 0.0

    @inbounds for i in 1:n
        w = 1.0 / (population[i].fitness + 1.0) # transforma o fitness em um peso 
        weights[i] = w
        total_weight += w
    end

    # sorteia ponto na roleta
    r = rand(rng) * total_weight

    acc = 0.0   # acumula os pesos novamente, agora para descobrir em qual faixa o valor r caiu.
    @inbounds for i in 1:n
        acc += weights[i]
        if acc >= r
            return i
        end
    end

    # fallback numérico
    return n
end