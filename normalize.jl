#!/usr/bin/env julia
# normalize.jl
#
# Uso:
#   julia normalize.jl --input "$HOME/Desktop/GA_L321_JULIA/base" \
#                      --output "$HOME/Desktop/GA_L321_JULIA/base_norm"

using Printf

# ------------------ util ------------------
canon(u::Int, v::Int) = (u < v) ? (u, v) : (v, u)

function clean_edges_undirected(edges::Vector{Tuple{Int,Int}})
    S = Set{Tuple{Int,Int}}()
    for (u,v) in edges
        u == v && continue
        push!(S, canon(u,v))
    end
    return sort!(collect(S))
end

is_comment_default(s::AbstractString) = isempty(s) || startswith(s, "#") || startswith(s, "%") || startswith(s, "c")
is_comment_as(s::AbstractString) = isempty(s) || startswith(s, "#")

function ensure_n_bounds(n::Int, edges::Vector{Tuple{Int,Int}})
    maxv = n
    for (u,v) in edges
        maxv = max(maxv, u, v)
    end
    return maxv
end

function n_from_filename(fname::AbstractString)
    m = match(r"_n(\d+)", fname)
    return m === nothing ? 0 : parse(Int, m.captures[1])
end

function relpath_safe(p::String, base::String)
    try
        return relpath(p, base)
    catch
        return basename(p)
    end
end

# ------------------ CELAR-like (var.txt / ctr.txt) ------------------
function read_n_from_var_txt(var_path::String)::Int
    max_id = 0
    for line in eachline(var_path)
        s = strip(line)
        is_comment_default(s) && continue
        isempty(s) && continue
        parts = split(s)
        id = parse(Int, parts[1])
        max_id = max(max_id, id)
    end
    max_id == 0 && error("Não consegui inferir n do var.txt: $var_path")
    return max_id
end

function read_edges_from_ctr_txt(ctr_path::String)::Vector{Tuple{Int,Int}}
    edges = Tuple{Int,Int}[]
    for line in eachline(ctr_path)
        s = strip(line)
        is_comment_default(s) && continue
        isempty(s) && continue
        p = split(s)
        length(p) < 2 && continue
        u = parse(Int, p[1]); v = parse(Int, p[2])
        push!(edges, (u,v))
    end
    return edges
end

function normalize_celar_like_instance(inst_dir::String, out_path::String)
    var_path = joinpath(inst_dir, "var.txt")
    ctr_path = joinpath(inst_dir, "ctr.txt")
    isfile(var_path) || return false, "sem var.txt"
    isfile(ctr_path) || return false, "sem ctr.txt"

    n = read_n_from_var_txt(var_path)
    edges = clean_edges_undirected(read_edges_from_ctr_txt(ctr_path))
    n = ensure_n_bounds(n, edges)

    write_normalized(out_path, n, edges)
    return true, @sprintf("n=%d m=%d", n, length(edges))
end

# ------------------ DIMACS (.col / .col.txt) ------------------
function read_dimacs(path::String)
    n_decl = 0
    edges = Tuple{Int,Int}[]
    open(path, "r") do io
        for line in eachline(io)
            s = strip(line)
            isempty(s) && continue
            startswith(s, "c") && continue
            if startswith(s, "p")
                parts = split(s)
                if length(parts) >= 4
                    n_decl = parse(Int, parts[end-1])
                end
            elseif startswith(s, "e")
                parts = split(s)
                length(parts) >= 3 || continue
                u = parse(Int, parts[2]); v = parse(Int, parts[3])
                push!(edges, (u,v))
            end
        end
    end
    edges = clean_edges_undirected(edges)
    if n_decl == 0
        n_decl = ensure_n_bounds(0, edges)
    else
        n_decl = ensure_n_bounds(n_decl, edges)
    end
    return n_decl, edges
end

# ------------------ Generic edge-list (CUBIC / HB) ------------------
function read_edgelist_pairs(path::String; comment_fn=is_comment_default)
    edges = Tuple{Int,Int}[]
    minv = typemax(Int)
    maxv = typemin(Int)

    for line in eachline(path)
        s = strip(line)
        comment_fn(s) && continue
        p = split(s)
        length(p) < 2 && continue
        u = parse(Int, p[1]); v = parse(Int, p[2])
        push!(edges, (u,v))
        minv = min(minv, u, v)
        maxv = max(maxv, u, v)
    end
    isempty(edges) && return 0, Tuple{Int,Int}[], false
    zero_based = (minv == 0) || any(e -> (e[1]==0 || e[2]==0), edges)
    return maxv, edges, zero_based
end

# ------------------ AS-graphs (renumerar 1..n) ------------------
function normalize_asgraph_file(infile::String, out_path::String)
    verts = Set{Int}()
    edges = Set{Tuple{Int,Int}}()

    open(infile, "r") do io
        for line in eachline(io)
            s = strip(line)
            is_comment_as(s) && continue
            p = split(s)
            length(p) < 2 && continue
            u = parse(Int, p[1]); v = parse(Int, p[2])
            u == v && continue
            push!(verts, u); push!(verts, v)
            push!(edges, canon(u,v))
        end
    end

    vlist = sort!(collect(verts))
    mapv = Dict{Int,Int}(v => i for (i,v) in enumerate(vlist))
    edges_list = sort!(collect(edges))

    mkpath(dirname(out_path))
    open(out_path, "w") do io
        @printf(io, "%d %d\n", length(vlist), length(edges_list))
        for (u,v) in edges_list
            @printf(io, "%d %d\n", mapv[u], mapv[v])
        end
    end
    return true, @sprintf("n=%d m=%d", length(vlist), length(edges_list))
end

# ------------------ writer ------------------
function write_normalized(out_path::String, n::Int, edges::Vector{Tuple{Int,Int}})
    mkpath(dirname(out_path))
    open(out_path, "w") do io
        @printf(io, "%d %d\n", n, length(edges))
        for (u,v) in edges
            @printf(io, "%d %d\n", u, v)
        end
    end
end

# ------------------ CLI + driver ------------------
function parse_args(args)
    input = ""
    output = ""
    i = 1
    while i <= length(args)
        if args[i] == "--input" && i < length(args)
            input = args[i+1]; i += 2
        elseif args[i] == "--output" && i < length(args)
            output = args[i+1]; i += 2
        else
            i += 1
        end
    end
    if isempty(input) || isempty(output)
        println("Uso: julia normalize.jl --input <benchmark_dir> --output <out_dir>")
        exit(1)
    end
    return input, output
end

function main(args)
    input, outdir = parse_args(args)
    isdir(input) || error("Input não é pasta: $input")
    mkpath(outdir)

    # pastas que usam var.txt/ctr.txt
    CELAR_LIKE = Set(["CELAR","celar","SUBCELAR","subcelar","DUTtest14","duttest14","DELFT","delft","SURPRISE","surprise"])

    println("[INFO] input : $input")
    println("[INFO] output: $outdir")

    ok = 0
    skip = 0

    for (root, _dirs, files) in walkdir(input)
        base_folder = splitpath(root)[end]

        # 1) CELAR-like: instância é pasta com var.txt + ctr.txt
        if base_folder in CELAR_LIKE
            # aqui root é a pasta "CELAR" em si; queremos as subpastas de instâncias
            continue
        end
        # detecta se esta pasta é uma instância CELAR-like (tem var.txt+ctr.txt) e algum ancestral é CELAR-like
        has_var = "var.txt" in files
        has_ctr = "ctr.txt" in files
        if has_var && has_ctr
            # verifica se algum ancestral é CELAR-like
            parts = splitpath(root)
            is_celar_like = any(p -> p in CELAR_LIKE, parts)
            if is_celar_like
                rel = relpath_safe(root, input)
                inst_name = splitpath(root)[end]
                out_path = joinpath(outdir, rel, inst_name * ".txt")
                success, msg = normalize_celar_like_instance(root, out_path)
                if success
                    println(@sprintf("[OK] %s -> %s (%s)", rel, out_path, msg))
                    ok += 1
                else
                    println(@sprintf("[SKIP] %s (%s)", rel, msg))
                    skip += 1
                end
                continue
            end
        end

        # 2) DIMACS: arquivos .col / .col.txt
        for f in files
            lf = lowercase(f)
            if endswith(lf, ".col") || endswith(lf, ".col.txt")
                full = joinpath(root, f)
                relf = relpath_safe(full, input)
                stem = splitext(relf)[1]
                out_path = joinpath(outdir, stem * ".txt")
                n, edges = read_dimacs(full)
                write_normalized(out_path, n, edges)
                println(@sprintf("[OK] %s -> %s (DIMACS n=%d m=%d)", relf, out_path, n, length(edges)))
                ok += 1
            end
        end

        # 3) CUBIC: edge-list .txt em pasta CUBIC (detecção por ancestral)
        if any(p -> lowercase(p) == "cubic", splitpath(root))
            for f in files
                endswith(lowercase(f), ".txt") || continue
                full = joinpath(root, f)
                relf = relpath_safe(full, input)
                stem = splitext(relf)[1]
                out_path = joinpath(outdir, stem * ".txt")

                maxv, edges_raw, zero_based = read_edgelist_pairs(full; comment_fn=is_comment_default)
                isempty(edges_raw) && continue
                edges = clean_edges_undirected(edges_raw)
                if zero_based
                    edges = [(u+1, v+1) for (u,v) in edges]
                    maxv += 1
                end
                nname = n_from_filename(f)
                n = max(nname, maxv)
                write_normalized(out_path, n, edges)
                println(@sprintf("[OK] %s -> %s (CUBIC n=%d m=%d)", relf, out_path, n, length(edges)))
                ok += 1
            end
        end

        # 4) Harwell-Boeing Small Instances: edge-list .txt (detecção por ancestral)
        if any(p -> lowercase(p) == "harwell-boeing-small-instances", splitpath(root))
            for f in files
                endswith(lowercase(f), ".txt") || continue
                full = joinpath(root, f)
                relf = relpath_safe(full, input)
                stem = splitext(relf)[1]
                out_path = joinpath(outdir, stem * ".txt")

                maxv, edges_raw, zero_based = read_edgelist_pairs(full; comment_fn=is_comment_default)
                isempty(edges_raw) && continue
                edges = clean_edges_undirected(edges_raw)
                if zero_based
                    edges = [(u+1, v+1) for (u,v) in edges]
                    maxv += 1
                end
                n = maxv
                write_normalized(out_path, n, edges)
                println(@sprintf("[OK] %s -> %s (HB n=%d m=%d)", relf, out_path, n, length(edges)))
                ok += 1
            end
        end

        # 5) AS-graphs: arquivos .txt com # (detecção por ancestral)
        if any(p -> lowercase(p) == "as-graphs", splitpath(root))
            for f in files
                endswith(lowercase(f), ".txt") || continue
                full = joinpath(root, f)
                relf = relpath_safe(full, input)
                stem = splitext(relf)[1]
                out_path = joinpath(outdir, stem * ".txt")

                success, msg = normalize_asgraph_file(full, out_path)
                success && println(@sprintf("[OK] %s -> %s (AS %s)", relf, out_path, msg))
                ok += 1
            end
        end
    end

    println(@sprintf("[DONE] ok=%d skip=%d", ok, skip))
end

main(ARGS)