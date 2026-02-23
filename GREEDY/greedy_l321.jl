using Graphs

# ==============================================================================
# FUNÇÃO AUXILIAR 1: BFS Limitada (Busca em Largura)
# Objetivo: Encontrar vizinhos a distância exata de 1, 2 e 3 saltos.
# ==============================================================================
function nodes_by_distance_upto3(g::AbstractGraph, s::Int)
    n = nv(g)
    dist = fill(-1, n)   # Inicializa vetor de distâncias com -1 (não visitado)
    dist[s] = 0          # A distância do vértice para ele mesmo é 0
    q = Int[s]           # Fila para controlar a visitação (começa com a origem 's')

    # Loop da busca em largura (BFS)
    head = 1
    while head <= length(q)
        v = q[head]; head += 1 # Remove o primeiro da fila
        dv = dist[v]

        # não expande além de 3
        dv == 3 && continue

        # Itera sobre os vizinhos do vértice atual 'v'
        for u in neighbors(g, v)
            if dist[u] == -1   # Se 'u' ainda não foi visitado
                dist[u] = dv + 1
                push!(q, u)   # Adiciona na fila para processar depois
            end
        end
    end

    # Separa os vértices encontrados em listas específicas por distância
    d1 = Int[]; d2 = Int[]; d3 = Int[]
    @inbounds for v in 1:n
        dist[v] == 1 && push!(d1, v)
        dist[v] == 2 && push!(d2, v)
        dist[v] == 3 && push!(d3, v)
    end
    return d1, d2, d3
end

# ==============================================================================
# PRÉ-CÁLCULO: computa D1, D2, D3 para cada vértice (uma vez por grafo)
# ==============================================================================
function precompute_distsets(g::AbstractGraph)
    n = nv(g)
    distsets = Vector{Tuple{Vector{Int},Vector{Int},Vector{Int}}}(undef, n)
    for v in 1:n
        distsets[v] = nodes_by_distance_upto3(g, v)
    end
    return distsets
end

# ==============================================================================
# FUNÇÕES AUXILIARES 2: Gerenciamento do Vetor 'used' (Memória)
# Objetivo: Controlar quais rótulos estão proibidos para o vértice atual.
# Nota: Em Julia, vetores começam no índice 1. Como rótulos podem ser 0,
# usamos a lógica: Índice do Vetor = Rótulo + 1.
# ==============================================================================

# Garante que o vetor 'used' tenha tamanho suficiente para verificar o índice 'idx'
@inline function ensure_used!(used::Vector{Bool}, idx::Int)
    # Garante que used tenha tamanho >= idx
    if idx > length(used)
        old = length(used)
        resize!(used, idx)     # Aumenta o tamanho do vetor
        fill!(view(used, old+1:idx), false)     # Preenche os novos espaços com false (livre)
    end
end

# Marca um intervalo [a..b] como PROIBIDO (true)
@inline function mark_range!(used::Vector{Bool}, a::Int, b::Int)
    # Ajustes de limites (rótulos não podem ser negativos)
    a < 0 && (a = 0)
    b < 0 && return   # Se o limite superior for negativo, não há o que marcar

    # Garante que o vetor aguenta o maior índice (b + 1)
    ensure_used!(used, b + 1)

    # Marca todos os rótulos no intervalo como usados/proibidos
    @inbounds for L in a:b
        used[L + 1] = true
    end
end

# Desmarca um intervalo [a..b], liberando-o (false)
# Usado para limpar o vetor 'used' para o próximo vértice sem precisar recriar o array
@inline function unmark_range!(used::Vector{Bool}, a::Int, b::Int)
    # Desmarca [a..b]
    a < 0 && (a = 0)
    b < 0 && return

    # Se o intervalo pede para desmarcar algo além do tamanho atual do vetor, ajustamos 'b'
    b + 1 > length(used) && (b = length(used) - 1)

    @inbounds for L in a:b
        used[L + 1] = false
    end
end

# ==============================================================================
# FUNÇÃO PRINCIPAL: Algoritmo Guloso L(3,2,1)
# ==============================================================================
function greedy_l321(g::AbstractGraph, sequence::Vector{Int}, distsets)
    n = nv(g)
    labels = fill(-1, n)    # Vetor final de rótulos (-1 indica não rotulado)
    Δ = maximum(degree(g, v) for v in 1:n) # Calcula o grau máximo do grafo
    used = fill(false, max(64, 8*Δ + 32)) # Vetor de rótulos proibidos

    maxlabel = 0    # Variável para rastrear o maior rótulo usado (Span)

    # ---------------------------------------------------------
    # LOOP GULOSO: Processa cada vértice na ordem definida
    # ---------------------------------------------------------
    for v in sequence
        # Recupera as listas de vizinhos pré-calculadas
        d1, d2, d3 = distsets[v]

        # =====================================================
        # ETAPA (A): MARCAR RÓTULOS PROIBIDOS
        # Olhamos apenas para vizinhos que já possuem rótulo (labels[w] >= 0)
        # =====================================================

        # Regra Distância 1: Diferença deve ser >= 3.
        # Proibimos o intervalo [Lw - 2 até Lw + 2]
        for w in d1
            lw = labels[w]
            lw >= 0 && mark_range!(used, lw - 2, lw + 2)
        end

        # Regra Distância 2: Diferença deve ser >= 2.
        # Proibimos o intervalo [Lw - 1 até Lw + 1]
        for w in d2
            lw = labels[w]
            lw >= 0 && mark_range!(used, lw - 1, lw + 1)
        end

        # Regra Distância 3: Diferença deve ser >= 1 (apenas distintos).
        # Proibimos exatamente o valor Lw
        for w in d3
            lw = labels[w]
            lw >= 0 && mark_range!(used, lw, lw)
        end

        # =====================================================
        # ETAPA (B): ESCOLHER O MENOR RÓTULO LIVRE (MEX)
        # =====================================================
        L = 0
        ensure_used!(used, 1)  # Garante que existe posição para o 0

        # Incrementa L enquanto a posição used[L+1] estiver marcada como true
        while used[L + 1]
            L += 1
            ensure_used!(used, L + 1)   # Se L cresceu muito, expande o vetor used
        end

        labels[v] = L
        maxlabel = max(maxlabel, L)     # Atualiza o Span global se necessário

        # =====================================================
        # ETAPA (C): LIMPEZA (RESET)
        # Desmarcamos as proibições que fizemos na etapa A.
        # Isso deixa o vetor 'used' limpo (tudo false) para o próximo vértice 'v'.
        # É mais rápido do que recriar o vetor 'used' do zero.
        # =====================================================
        for w in d1
            lw = labels[w]
            lw >= 0 && unmark_range!(used, lw - 2, lw + 2)
        end
        for w in d2
            lw = labels[w]
            lw >= 0 && unmark_range!(used, lw - 1, lw + 1)
        end
        for w in d3
            lw = labels[w]
            lw >= 0 && unmark_range!(used, lw, lw)
        end
    end

    return labels, maxlabel
end