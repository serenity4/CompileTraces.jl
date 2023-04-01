using CompileTraces
using Test
using Test: Fail

trace_file(name) = joinpath(@__DIR__, "traces", name * ".jl")

tmp = tempname()

function fact(n::Int)
  n >= 0 || error("n must be non-negative")
  n == 0 && return 1
  n * fact(n - 1)
end

run(`julia --trace-compile=$tmp -e 'function fact(n::Int)
        n >= 0 || error("n must be non-negative")
        n == 0 && return 1
        n * fact(n-1)
    end; fact(10)'
`)

function capture_stdout(f)
  mktemp() do _, io
    redirect_stdout(f, io)
    seekstart(io)
    return read(io, String)
  end
end

@testset "CompileTraces.jl" begin
  nologs = (; verbose = false, progress = false, warn = false)

  @testset "Compilation of traces generated via --trace-file=<file>" begin
    metrics = compile_traces(@__MODULE__, tmp)
    @test metrics.succeeded ≥ 1
    @test metrics.failed == 0
    @test metrics.skipped == 0
    @test metrics.succeeded == metrics.total
    @test isa(repr(metrics), String)
  end

  @testset "Setting up of staging areas" begin
    # We need to compile something that comes from `Test`.
    # `Test` is already in scope here, so `inline = true` will work.
    metrics = compile_traces(@__MODULE__, trace_file("with_deps"); inline = true, nologs...)
    @test metrics.succeeded == 1
    # However, it won't on a new module.
    metrics = compile_traces(Module(), trace_file("with_deps"); inline = true, nologs...)
    @test metrics.failed == 1
    # Unless we setup the staging module with `inline = false`.
    metrics = compile_traces(Module(), trace_file("with_deps"); inline = false, nologs...)
    @test metrics.succeeded == 1
  end

  @testset "Behavior of `inline` parameter" begin
    # Test that we can compile traces inline when everything is in scope, which correspond to SnoopCompile's traces.
    metrics = compile_traces(@__MODULE__, trace_file("inline"); nologs..., inline = true)
    @test metrics.succeeded == 1
    # However, such traces need to be run in the relevant scope, so test that it fails on a new module which therefore has the wrong scope.
    metrics = compile_traces(Module(), trace_file("inline"); inline = true, nologs...)
    @test metrics.failed == 1
  end

  @testset "Output & logging" begin
    captured = capture_stdout(() -> compile_traces(Module(), tmp; verbose=false))
    @test contains(captured, "Executing precompile directives...") && !contains(captured, "Successfully compiled")
    captured = capture_stdout(() -> compile_traces(Module(), tmp; progress=false))
    @test contains(captured, "Executing precompile directives...") && contains(captured, "Successfully compiled")
    captured = capture_stdout(() -> compile_traces(Module(), tmp; progress=false, verbose=false))
    @test isempty(captured)
    varname = VERSION ≥ v"1.9" ? "`doesnotexist`" : "doesnotexist"
    metrics = @test_logs (:warn, "failed to execute precompile(Tuple{typeof(Base.doesnotexist), Int64})\nUndefVarError: $varname not defined") match_mode=:any compile_traces(@__MODULE__, trace_file("error"))
    @test metrics.succeeded == 1
    @test metrics.failed == 2
    @test_logs compile_traces(Module(), trace_file("error"); warn=false)
  end
end;
