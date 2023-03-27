using CompileTraces
using Test

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
  metrics = compile_traces(tmp)
  @test metrics.succeeded ≥ 1
  @test metrics.failed == 0
  @test metrics.skipped == 0
  @test metrics.succeeded == metrics.total
  captured = capture_stdout(() -> compile_traces(tmp; verbose=false))
  @test contains(captured, "Executing precompile statements...") && !contains(captured, "Successfully precompiled")
  captured = capture_stdout(() -> compile_traces(tmp; progress=false))
  @test contains(captured, "Executing precompile statements...") && contains(captured, "Successfully precompiled")
  captured = capture_stdout(() -> compile_traces(tmp; progress=false, verbose=false))
  varname = VERSION ≥ v"1.9" ? "`doesnotexist`" : "doesnotexist"
  metrics = @test_logs (:warn, "failed to execute precompile(Tuple{typeof(Base.doesnotexist), Int64})\nUndefVarError: $varname not defined") match_mode=:any compile_traces(trace_file("error"))
  @test metrics.succeeded == 1
  @test metrics.failed == 2
  @test_logs compile_traces(trace_file("error"); warn=false)
  @test isempty(capture_stdout(() -> compile_traces(trace_file("error"); verbose=false, progress=false, warn=false)))
end;
