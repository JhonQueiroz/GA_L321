using Graphs
using ArgParse
using Random
using CSV
using DataFrames
using Base.Threads

include("../GREEDY/greedy_l321.jl")
include("ga_l321.jl")  

function read_simple_graph(filename::String)
    edges = Tuple{Int,Int}[]
    vertices = Set{Int}()

    for linha in eachline(filename)
        s = strip(linha)
        isempty(s) && continue
        u, v = parse.(Int, split(s))
        push!(edges, (u, v))
        push!(vertices, u)
        push!(vertices, v)
    end

    vertex_map = Dict{Int,Int}()
    for (i, v) in enumerate(sort!(collect(vertices)))
        vertex_map[v] = i
    end

    g = SimpleGraph(length(vertices))
    for (u, v) in edges
        add_edge!(g, vertex_map[u], vertex_map[v])
    end
    return g
end

function parse_command_line()
    settings = ArgParseSettings()

    @add_arg_table settings begin
        "--instance"
            help = "Caminho para o arquivo de instância (edge-list normalizado)"
            arg_type = String
            required = true

        "--seed"
            help = "Semente base"
            arg_type = Int
            default = 1234

        "--pop_factor"
            help = "Denominador para popsize = floor(n/pop_factor)"
            arg_type = Int
            default = 2

        "--crossover_rate"
            help = "Taxa de cruzamento (OX)"
            arg_type = Float64
            default = 0.9

        "--mutation_rate"
            help = "Taxa de mutação (swap)"
            arg_type = Float64
            default = 0.2

        "--elitism_rate"
            help = "Taxa de elitismo"
            arg_type = Float64
            default = 0.1

        "--max_gen"
            help = "Máx. gerações"
            arg_type = Int
            default = 200

        "--trials"
            help = "Número de execuções independentes"
            arg_type = Int
            default = 30

        "--output"
            help = "Arquivo CSV de saída"
            arg_type = String
            default = "result_l321.csv"
    end

    return parse_args(settings)
end

function main()
    println("[INFO] Threads disponíveis: $(nthreads())")

    args = parse_command_line()

    instance        = args["instance"]
    seed            = args["seed"]
    pop_factor      = args["pop_factor"]
    crossover_rate  = args["crossover_rate"]
    mutation_rate   = args["mutation_rate"]
    elitism_rate    = args["elitism_rate"]
    max_gen         = args["max_gen"]
    trials          = args["trials"]
    output_file     = args["output"]

    graph = read_simple_graph(instance)
    distsets = precompute_distsets(graph)  # MUITO IMPORTANTE: pré-cálculo 1 vez

    popsize = max(2, floor(Int, nv(graph) / pop_factor))

    params = GA_Parameters(
        popsize,
        max_gen,
        elitism_rate,
        crossover_rate,
        mutation_rate
    )

    isfile(output_file) && error("Arquivo $output_file já existe")

    df_header = DataFrame(
        trial = Int[],
        seed = Int[],
        graph = String[],
        n = Int[],
        m = Int[],
        density = Float64[],
        bestSpan = Int[],
        time_sec = Float64[]
    )
    CSV.write(output_file, df_header)

    # --------------------------
    # Warm-up (fora da medição)
    # --------------------------
    Random.seed!(seed)
    best_warm, _ = run_ga_l321(params, graph, distsets, seed)  # warmup para JIT
    # (não usa resultado)

    Random.seed!(seed)

    for t in 1:trials
        trial_seed = seed + t

        start = time()
        best, _ = run_ga_l321(params, graph, distsets, trial_seed)
        elapsed = time() - start

        instance_name = basename(instance)
        density = (2 * ne(graph)) / (nv(graph) * (nv(graph) - 1))

        df_row = DataFrame(
            trial = t,
            seed = trial_seed,
            graph = instance_name,
            n = nv(graph),
            m = ne(graph),
            density = density,
            bestSpan = best.fitness,
            time_sec = elapsed
        )
        CSV.write(output_file, df_row; append=true)
    end
end

main()