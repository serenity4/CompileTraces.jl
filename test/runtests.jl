using CompileTraces
using Test
using Test: Fail

trace_file(name) = joinpath(@__DIR__, "traces", name * ".jl")

tmp = trace_file("fact")

function fact(n::Int)
  n >= 0 || error("n must be non-negative")
  n == 0 && return 1
  n * fact(n - 1)
end

run(`$(Base.julia_cmd()) --trace-compile=$tmp --startup-file=no -e 'function fact(n::Int)
        n >= 0 || error("n must be non-negative")
        n == 0 && return 1
        n * fact(n-1)
    end; fact(10)'
`)

function capture_stdout(f; color = false)
  mktemp() do _, io
    print_io = color ? IOContext(io, :color => true) : io
    redirect_stdout(f, print_io)
    seekstart(io)
    return read(io, String)
  end
end

@testset "CompileTraces.jl" begin
  @testset "CompilationMetrics" begin
    metrics = CompilationMetrics(1, 4, 2, 7)
    @test isa(repr(metrics), String)
    captured = capture_stdout(() -> CompileTraces.show_compilation_results(metrics, @timed sleep(0.2)), color = true)
    @test contains(captured, "\nSuccessfully executed \e[32m\e[1m1\e[22m\e[39m precompile statements (\e[31m\e[1m4\e[22m\e[39m failed, \e[33m\e[1m2\e[22m\e[39m skipped) in 0.2") && endswith(captured, " seconds\n")
  end

  @testset "Compilation of traces generated via --trace-file=<file>" begin
    metrics = compile_traces(@__MODULE__, tmp)
    @test metrics.succeeded ≥ 1
    @test metrics.failed == 0
    @test metrics.skipped == 0
    @test metrics.succeeded == metrics.total
  end

  @testset "Setting up of staging areas" begin
    # We need to compile something that comes from `Test`.
    # `Test` is already in scope here, so `inline = true` will work.
    metrics = compile_traces(@__MODULE__, trace_file("with_deps"); inline = true)
    @test metrics.succeeded == 1
    # However, it won't on a new module.
    metrics = compile_traces(Module(), trace_file("with_deps"); inline = true)
    @test metrics.failed == 1
    # Unless we setup the staging module with `inline = false`.
    metrics = compile_traces(Module(), trace_file("with_deps"); inline = false)
    @test metrics.succeeded == 1
  end

  @testset "Behavior of `inline` parameter" begin
    # Test that we can compile traces inline when everything is in scope, which correspond to SnoopCompile's traces.
    metrics = compile_traces(@__MODULE__, trace_file("inline"), inline = true)
    @test metrics.succeeded == 1
    # However, such traces need to be run in the relevant scope, so test that it fails on a new module which therefore has the wrong scope.
    metrics = compile_traces(Module(), trace_file("inline"); inline = true)
    @test metrics.failed == 1
  end

  @testset "Output & logging" begin
    @test_logs compile_traces(@__MODULE__, trace_file("with_deps"); warn = true)
    captured = capture_stdout(() -> compile_traces(Module(), tmp))
    @test isempty(captured)
    captured = capture_stdout(() -> compile_traces(Module(), tmp; verbose = true, progress=false))
    @test contains(captured, "Executing precompile statements...") && contains(captured, "Successfully executed")
    varname = VERSION ≥ v"1.9" ? "`doesnotexist`" : "doesnotexist"
    metrics = @test_logs (:warn, "failed to execute precompile(Tuple{typeof(Base.doesnotexist), Int64})\nUndefVarError: $varname not defined") match_mode=:any compile_traces(@__MODULE__, trace_file("error"); warn = true)
    @test metrics.succeeded == 1
    @test metrics.failed == 2
    @test_logs compile_traces(Module(), trace_file("error"))
    withenv("JULIA_COMPILE_TRACES_WARN" => "SomeModule,Main") do
      @test_logs (:warn, "failed to execute precompile(Tuple{typeof(Base.doesnotexist), Int64})\nUndefVarError: $varname not defined") match_mode=:any compile_traces(@__MODULE__, trace_file("error"), warn = false)
    end
    withenv("JULIA_COMPILE_TRACES_WARN" => "SomeModule") do
      @test_logs compile_traces(@__MODULE__, trace_file("error"), warn = false)
    end
  end

  @testset "Macro interface" begin
    res1 = compile_traces(@__MODULE__, tmp)
    res2 = @compile_traces tmp
    @test res1 == res2

    res1 = compile_traces(@__MODULE__, trace_file("inline"); inline = true)
    res2 = @compile_traces trace_file("inline") inline = true
    res3 = @compile_traces inline = true trace_file("inline")

    captured = capture_stdout() do
      res1 = compile_traces(@__MODULE__, trace_file("inline"))
      res2 = @compile_traces trace_file("inline")
      @test res1 == res2
    end
    @test isempty(captured)
  end

  @testset "Generating precompilation traces" begin
    if !haskey(ENV, "skip_test_generate_precompilation_traces")
      output = tempname()
      withenv("skip_test_generate_precompilation_traces" => "") do
        redirect_stderr(devnull) do
          generate_precompilation_traces(pkgdir(CompileTraces); output = output)
        end
      end
      display(read(output, String))
      @test length(collect(eachline(output))) > 10
      @test !isfile(joinpath(pkgdir(CompileTraces), "LocalPreferences.toml"))
    end
  end
end;

isfile(tmp) && rm(tmp)
