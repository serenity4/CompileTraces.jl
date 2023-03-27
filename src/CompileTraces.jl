module CompileTraces

export compile_traces

compile_traces(statement_files::AbstractString...; verbose=true, progress=true, warn=true) = compile_traces(collect(statement_files); verbose, progress, warn)

# Credits to PackageCompiler.jl for most of the following code.

function compile_traces(statement_files::AbstractVector{<:AbstractString}; verbose=true, progress=true, warn=true)
  ex = quote
    using Base.Meta
    PrecompileStagingArea = Module()
    for (_pkgid, _mod) in Base.loaded_modules
      if !(_pkgid.name in ("Main", "Core", "Base"))
        try
          eval(PrecompileStagingArea, :(const $(Symbol(_mod)) = $_mod))
        catch
          str = sprint(showerror)
          # Skip redefinitions of modules corresponding to package extensions.
          # TODO: Investigate what is going on.
          contains(str, "Invalid redefinition of anonymous.") || rethrow()
        end
      end
    end
    local n_succeeded = 0
    local n_failed = 0
    statements = foldl((sts, file) -> append!(sts, eachline(file)), $statement_files; init=String[])
    $verbose && print("Executing precompile statements...")
    for statement in statements
      try
        # This is taken from https://github.com/JuliaLang/julia/blob/2c9e051c460dd9700e6814c8e49cc1f119ed8b41/contrib/generate_precompile.jl#L375-L393
        ps = Meta.parse(statement)
        isexpr(ps, :call) || continue
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
        ps = Core.eval(PrecompileStagingArea, ps)
        # XXX: precompile doesn't currently handle overloaded nospecialize arguments very well.
        # Skipping them avoids the warning.
        ms = length(ps) == 1 ? Base._methods_by_ftype(ps[1], 1, Base.get_world_counter()) : Base.methods(ps...)
        ms isa Vector || continue
        precompile(ps...)
        n_succeeded += 1
        $progress || continue
        print("\rExecuting precompile statements... $n_succeeded/$(length(statements))")
        if !iszero(n_failed)
          print(" (failed: ")
          printstyled(n_failed; bold=true, color=:red)
          print(')')
        end
      catch e
        # See julia issue #28808
        e isa InterruptException && rethrow()
        n_failed += 1
        $warn || continue
        println()
        @warn "failed to execute $statement\n$(sprint(showerror, e))"
      end
    end
    if $verbose
      println()
      print("Successfully precompiled ")
      printstyled(n_succeeded; bold=true, color=:green)
      print(" statements")
      if !iszero(n_failed)
        print(" (")
        printstyled(n_failed; bold=true, color=:red)
        print(" failed)")
      end
      println()
    end
  end

  Core.eval(Module(), ex)
end

end
