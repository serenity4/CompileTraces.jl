module CompileTraces

using .Meta: isexpr

export @compile_traces, compile_traces, CompilationMetrics

"""
Object used to track various metrics related to compilation successes and failures for later introspection.

For example, you might want to test or assert that all or at least a certain number of traces were successfully compiled.

Public fields:
- `succeeded`: the number of statements that successfully compiled.
- `failed`: the number of statements that failed to compile.
- `skipped`: the number of statements that were avoided due to limitations in compilation. This should be very rare, and related to overloaded `Vararg` or despecialized arguments.
- `total`: the number of statements that were processed. This is the sum of all three other fields.
"""
mutable struct CompilationMetrics
  succeeded::Int64
  failed::Int64
  skipped::Int64
  total::Int64
end

CompilationMetrics() = CompilationMetrics(0, 0, 0, 0)

Base.:(==)(m1::CompilationMetrics, m2::CompilationMetrics) = m1.succeeded == m2.succeeded && m1.failed == m2.failed && m1.skipped == m2.skipped && m1.total == m2.total

function Base.show(io::IO, metrics::CompilationMetrics)
  print(io, CompilationMetrics, '(', "total: ", metrics.total, ", succeeded: ", metrics.succeeded, ", failed: ", metrics.failed, ", skipped: ", metrics.skipped, ')')
end

"""
    compile_traces(mod::Module, trace_files::AbstractString...; verbose=true, progress=true, warn=false, inline=false)
    compile_traces(mod::Module, trace_files::AbstractVector{<:AbstractString}; verbose=true, progress=true, warn=false, inline=false)

Execute a set of precompile statements from a trace file, returning a `CompilationMetrics` result.

`verbose = false` implies `progress = false`. Turn off `progress = false` when `\\r` is not well supported, i.e. in CI.

`warn = true` will emit a warning upon failure to precompile a given statement.
`warn` will be overriden and set to `true` if the value of the environment variable `JULIA_COMPILE_TRACES_WARN` is set to the name of the module, similarly to `JULIA_DEBUG`. Coma-separated values allow more than one name to be provided to potentially match several modules.

If `inline` is set to true, the `precompile(...)` directives will be executed in `mod`; otherwise, a new module is created inside `mod`, with a special namespace which allows referring to any module loaded in the Julia session. Which value to use for `inline` will depend on the format of trace files, which may be in one of two formats depending on how they were generated:
- Trace files generated by the command-line option `--trace-file=<file>`: they require the use of `inline = false`. All functions and most types are prefixed with their defining module, e.g. `Base.collect`, `Base.getindex`, etc. regardless of the scope in which code was evaluated.
- Trace files generated by [SnoopCompile.jl](https://github.com/timholy/SnoopCompile.jl) using `SnoopCompile.parcel` and later `SnoopCompile.write`: they require the use of `inline = true`. All functions and types are assumed to be in the scope of the package for which traces were generated.

The difference between the two formats is the scope assumed to be used when later executing the precompile directives. All trace files *must be in the same format*, but you can make two calls to `compile_traces` where each uses trace files of a different format.

!!! warning
    If the traces are meant to be compiled during package precompilation, then `mod` **must** be the module being precompiled (i.e. `@__MODULE__`). Otherwise, you will get the unfamous error:
    > ERROR: LoadError: Evaluation into the closed module <mod> breaks incremental compilation because the side effects will not be permanent. This is likely due to some other module mutating <mod> with `eval` during precompilation - don't do this.

Only the statements which are bound to known modules and types will be compiled. However, when using precompile statements from `--trace-file=<file>`, it is sufficient that top-level packages or modules are loaded in the session; if package A uses a type for B, B will already have been loaded with A, and so will be known to the session.

If generating a trace file from a script which includes types and functions defined in `Main`, it may be good practice to filter out traces which
contain `Main.`. Otherwise warnings will be raised, unless you really are compiling functions and types that are defined in the running session.
"""
function compile_traces end

compile_traces(mod::Module, trace_files::AbstractString...; verbose=true, progress=true, warn=false, inline=false) = compile_traces(mod, collect(trace_files); verbose, progress, warn, inline)

# Credits to PackageCompiler.jl for the core precompilation code.

function setup_staging_area(mod::Module)
  for (_pkgid, _mod) in Base.loaded_modules
    if !(_pkgid.name in ("Main", "Core", "Base"))
      try
        Core.eval(mod, :(const $(Symbol(_mod)) = $_mod))
      catch e
        str = sprint(showerror, e)
        # Skip redefinitions of modules corresponding to package extensions.
        # TODO: Investigate what is going on.
        contains(str, "invalid redefinition of constant anonymous.") || rethrow()
      end
    end
  end
end

function precompile_directives(statements)
  precompile_directives = Expr[]
  for statement in statements
    ps = Meta.parse(statement)
    !isexpr(ps, :call) && continue
    popfirst!(ps.args) # precompile(...)
    ps.head = :tuple
    l = ps.args[end]
    if (isexpr(l, :tuple) || isexpr(l, :curly)) && length(l.args) > 0 # Tuple{...} or (...)
      # XXX: precompile doesn't currently handle overloaded Vararg arguments very well.
      # Replacing N with a large number works around it.
      l = l.args[end]
      if isexpr(l, :curly) && length(l.args) == 2 && l.args[1] === :Vararg # Vararg{T}
        push!(l.args, 100) # form Vararg{T, 100} instead
      end
    end
    push!(precompile_directives, ps)
  end
  precompile_directives
end

function execute_precompile_directives!(metrics, mod, directives, verbose, progress, warn, n)
  verbose && print("Executing precompile statements...")
  timed = @timed for directive in directives
    local exc::Exception, succeeded::Union{Nothing,Bool}
    try
      signature = Core.eval(mod, directive)
      succeeded = execute_precompile_directive(signature)
    catch e
      # Cover against throwing precompile directives, just in case.
      # See https://github.com/JuliaLang/julia/issues/28808.
      e isa InterruptException && rethrow()
      exc = e
      succeeded = false
    finally
      isnothing(succeeded) ? (metrics.skipped += 1) : succeeded === true ? (metrics.succeeded += 1) : (metrics.failed += 1)
      progress && print("\rExecuting precompile statements... $(metrics.succeeded)/$n" * sprint(show_current_status, metrics; context = :color => true))
      if succeeded === false && warn
        println()
        @warn "failed to execute precompile($(join(directive.args, ", ")))" * (succeeded === false ? '\n' * sprint(showerror, exc) : "")
      end
    end
  end
  verbose && show_compilation_results(metrics, timed)
  metrics.total = metrics.succeeded + metrics.failed + metrics.skipped
end

function execute_precompile_directive(signature)
  # This is taken from https://github.com/JuliaLang/julia/blob/2c9e051c460dd9700e6814c8e49cc1f119ed8b41/contrib/generate_precompile.jl#L375-L393
  # XXX: precompile doesn't currently handle overloaded nospecialize arguments very well.
  # See https://github.com/JuliaLang/julia/issues/39902
  ms = length(signature) == 1 ? Base._methods_by_ftype(signature[1], 1, Base.get_world_counter()) : Base.methods(signature...)
  isnothing(ms) && return
  !isa(ms, Vector) && return

  precompile(signature...)
end

function show_compilation_results(metrics, timed)
  println()
  print("Successfully executed ")
  printstyled(metrics.succeeded; bold=true, color=:green)
  print(" precompile statements")
  show_current_status(stdout, metrics)
  println(" in ", trunc(timed.time, digits = 2), " seconds")
end

function show_current_status(io, metrics)
  (!iszero(metrics.failed) || !iszero(metrics.skipped)) && print(io, " (")
  if !iszero(metrics.failed)
    printstyled(io, metrics.failed; bold=true, color=:red)
    print(io, " failed")
  end
  if !iszero(metrics.skipped)
    !iszero(metrics.failed) && print(io, ", ")
    printstyled(io, metrics.skipped; bold = true, color=:yellow)
    print(io, " skipped")
  end
  (!iszero(metrics.failed) || !iszero(metrics.skipped)) && print(io, ")")
end

function execute_precompile_statements!(metrics, statements, verbose, progress, warn, mod, inline)
  n = length(statements)
  warn = warn || string(nameof(mod)) in split(get(ENV, "JULIA_COMPILE_TRACES_WARN", ""), ',')
  directives = precompile_directives(statements)
  metrics.skipped += length(statements) - length(directives)

  ex = :($execute_precompile_directives!($metrics, @__MODULE__, $directives, $verbose, $progress, $warn, $n))

  if inline
    Core.eval(mod, ex)
  else
    ex = quote
      module $(gensym("CompileStagingArea"))

      $setup_staging_area(@__MODULE__)
      $ex

    end # module
    end
    Core.eval(mod, Expr(:toplevel, ex.args...))
  end
end

function compile_traces(mod::Module, trace_files::AbstractVector{<:AbstractString}; verbose=true, progress=true, warn=false, inline=false)
  metrics = CompilationMetrics()
  statements = foldl((sts, file) -> append!(sts, eachline(file)), trace_files; init=String[])
  execute_precompile_statements!(metrics, statements, verbose, progress & verbose, warn, mod, inline)
  metrics
end

"""
Compile traces by calling [`compile_traces`](@ref) with `@__MODULE__` as first argument.
See the documentation of [`compile_traces`](@ref) for more information.

Keyword arguments can be parsed in any order in the form `name = value`.
"""
macro compile_traces(args...)
  fargs = Expr[]
  kwargs = Expr[]
  for arg in args
    if isexpr(arg, :(=))
      name, value = arg.args
      push!(kwargs, Expr(:kw, name, esc(value)))
    else
      push!(fargs, esc(arg))
    end
  end
  :(compile_traces($__module__, $(fargs...); $(kwargs...)))
end

end
