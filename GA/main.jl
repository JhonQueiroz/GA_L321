using Graphs
using ArgParse
using CSV
using DataFrames
using Base.Threads

include("../GREEDY/greedy.jl")
include("ga.jl")  

function read_graph(filename::String)
    open(filename, "r") do io
        n, m = parse.(Int, split(strip(readline(io))))
        g = SimpleGraph(n)

        for line in eachline(io)
            u, v = parse.(Int, split(line))
            u == v && continue
            add_edge!(g, u, v)
        end
        return g
    end
end

function parse_command_line()
    settings = ArgParseSettings()

    @add_arg_table settings begin
        "--instance"
            help = "Caminho para a instância no formato: primeira linha 'n m', demais linhas 'u v'"
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

    graph = read_graph(instance)
    distsets = precompute_distsets(graph)  # MUITO IMPORTANTE: pré-cálculo 1 vez

    popsize = max(2, floor(Int, nv(graph) / pop_factor))

    params = GA_Parameters(
        popsize,
        max_gen,
        elitism_rate,
        crossover_rate,
        mutation_rate
    )

    # Definição dos operadores
    selection_op = selection_roulette
    crossover_op = ox_two_point_crossover
    mutation_op  = mutate_swap

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

    output_curve = replace(output_file, ".csv" => "_curve.csv")
    isfile(output_curve) && error("Arquivo $output_curve já existe")

    df_curve_header = DataFrame(
        trial = Int[],
        seed = Int[],
        graph = String[],
        gen = Int[],
        bestSpan_gen = Int[]
    )
    CSV.write(output_curve, df_curve_header)

    # --------------------------
    # Warm-up (fora da medição)
    # --------------------------
    best_warm, _ = run_ga_l321(params, graph, distsets, seed, selection_op, crossover_op, mutation_op)  # warmup para JIT
    # (não usa resultado)

    for t in 1:trials
        trial_seed = seed + t

        start = time()
        best, best_per_gen = run_ga_l321(params, graph, distsets, trial_seed, selection_op, crossover_op, mutation_op)
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

        df_curve = DataFrame(
            trial = fill(t, length(best_per_gen)),
            seed = fill(trial_seed, length(best_per_gen)),
            graph = fill(instance_name, length(best_per_gen)),
            gen = collect(1:length(best_per_gen)),
            bestSpan_gen = best_per_gen
        )
        CSV.write(output_curve, df_curve; append=true)
    end
end

main()