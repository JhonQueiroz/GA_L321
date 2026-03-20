# Operadores de crossover
# todas os cruzamentos devem receber: (p1, p2, rng) e retornar: (c1, c2)

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



# Partially Mapped Crossover (PMX) 