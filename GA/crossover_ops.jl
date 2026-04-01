# Operadores de crossover
# todas os cruzamentos devem receber: (p1, p2, rng) e retornar: (c1, c2)

# CROSSOVER: Order Crossover (OX) - 2 pontos
function ox_two_point_crossover(p1::Individual, p2::Individual, rng::AbstractRNG)

    n = length(p1.genome)                              # número de genes do cromossomo

    c1 = rand(rng, 1:n-1)                              # ponto de corte 1
    c2 = rand(rng, (c1+1):n)                           # ponto de corte 2 (garante c2 > c1)

    # ---------- FILHO 1: copia segmento do p1 e completa com p2 (preservando ordem) ---------

    child1 = fill(0, n)                                
    used1  = falses(n)                                 # used1[g] = true se o valor g já foi usado no filho 1

    @inbounds for i in c1:c2                           # percorre somente o intervalo copiado
        g = p1.genome[i]                               # gene do pai 1 na posição i
        child1[i] = g                                  # fixa esse gene no filho 1, na mesma posição i
        used1[g] = true                                # marca o valor g como já utilizado (para evitar duplicata)
    end

    idx = 1                                             # ponteiro para a próxima posição livre em child1

    for g in p2.genome                                  # varre os genes do pai 2 na ordem em que aparecem
        if !used1[g]                                    # só tenta inserir se g ainda não estiver no filho 1
            
            while idx >= c1 && idx <= c2                # evita sobrescrever o trecho fixo [c1..c2]
                idx = c2 + 1                            # avança idx para a primeira posição após o segmento
            end

            while idx <= n && child1[idx] != 0          # caso idx já esteja ocupada por algum valor
                idx += 1                                # continua procurando a próxima posição livre
            end

            child1[idx] = g                             # insere o gene g na posição livre encontrada
            idx += 1                                    # avança idx para a próxima posição candidata
        end
    end

    # ----------------- FILHO 2: processo simétrico (segmento do p2, completa com p1) ----------

    child2 = fill(0, n)                                 # filho 2 inicialmente vazio (0 = não preenchido)
    used2  = falses(n)                                  # marca genes já usados no filho 2

    @inbounds for i in c1:c2
        g = p2.genome[i]                                # gene do pai 2 na posição i
        child2[i] = g                                   # fixa no filho 2
        used2[g] = true                                 # marca como usado
    end

    idx = 1                                             # ponteiro para a próxima posição livre em child2

    for g in p1.genome
        if !used2[g]                                    # só insere se não estiver usado no segmento
            while idx >= c1 && idx <= c2                # não preencher dentro do intervalo fixo
                idx = c2 + 1
            end
            while idx <= n && child2[idx] != 0          # encontra próxima posição vazia
                idx += 1
            end
            child2[idx] = g                             # insere g
            idx += 1
        end
    end

    return (Individual(child1, typemax(Int)), Individual(child2, typemax(Int)))
end

# Crossover: Partially Mapped Crossover (PMX)
function pmx_crossover(p1::Individual, p2::Individual, rng::AbstractRNG)

    n = length(p1.genome)                              # tamanho do cromossomo

    cp1 = rand(rng, 1:n-1)                             # ponto de corte 1
    cp2 = rand(rng, (cp1+1):n)                         # ponto de corte 2 (cp2 > cp1)

    # --------------- FILHO 1: segmento do pai 1, completa com pai 2 -------

    child1  = fill(0, n)                               # 0 = posição vazia
    in_seg1 = falses(n)                                # in_seg1[x]=true se x está no segmento copiado (pai 1)
    map12   = fill(0, n)                               # map12[a]=b   (pai1_seg_value -> pai2_seg_value)

    # Copia segmento do pai 1 e cria mapeamento a -> b entre os segmentos
    @inbounds for i in cp1:cp2
        a = p1.genome[i]                               # valor no segmento do pai 1
        b = p2.genome[i]                               # valor correspondente no segmento do pai 2
        child1[i] = a                                  # fixa segmento no filho 1
        in_seg1[a] = true                              # marca valor como presente no segmento
        map12[a] = b                                   # mapeamento para resolver conflitos
    end

    # Preenche fora do segmento usando pai 2; se conflitar, aplica map12 em cadeia
    @inbounds for i in 1:n
        (i >= cp1 && i <= cp2) && continue             # não mexe no segmento fixo
        g = p2.genome[i]                               # candidato do pai 2

        # Se g já está no segmento copiado (pai 1), troca via map12 até não conflitar
        while in_seg1[g]
            g = map12[g]                               # g é um valor do segmento do pai 1, então map12[g] existe
        end

        child1[i] = g                                  # escreve gene válido
    end

    # --------------- FILHO 2: segmento do pai 2, completa com pai 1 (simétrico) -------

    child2  = fill(0, n)
    in_seg2 = falses(n)                                # marca valores do segmento copiado (pai 2)
    map21   = fill(0, n)                               # map21[b]=a   (pai2_seg_value -> pai1_seg_value)

    @inbounds for i in cp1:cp2
        a = p1.genome[i]                               # valor no segmento do pai 1
        b = p2.genome[i]                               # valor no segmento do pai 2
        child2[i] = b                                  # filho 2 copia segmento do pai 2
        in_seg2[b] = true                              # marca valor como presente no segmento
        map21[b] = a                                   # mapeamento inverso para resolver conflitos no filho 2
    end

    @inbounds for i in 1:n
        (i >= cp1 && i <= cp2) && continue
        g = p1.genome[i]                               # candidato do pai 1

        while in_seg2[g]                               # conflito: g está no segmento copiado do pai 2
            g = map21[g]                               # mapeia b -> a até sair do conjunto do segmento
        end

        child2[i] = g
    end

    return (Individual(child1, typemax(Int)), Individual(child2, typemax(Int)))
end