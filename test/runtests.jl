using CompileTraces
using Test

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
    end; display(fact(10))'
`)

function capture_stdout(f)
  mktemp() do _, io
    redirect_stdout(f, io)
    seekstart(io)
    return read(io, String)
  end
end

@testset "CompileTraces.jl" begin
  compile_traces(tmp)
  t = @elapsed display(fact(10))
  @test t < 1e-3
  captured = capture_stdout(() -> compile_traces(tmp; verbose=false))
  @test contains(captured, "Executing precompile statements...") && !contains(captured, "Successfully precompiled")
  captured = capture_stdout(() -> compile_traces(tmp; progress=false))
  @test contains(captured, "Executing precompile statements...") && contains(captured, "Successfully precompiled")
  captured = capture_stdout(() -> compile_traces(tmp; progress=false, verbose=false))
  @test isempty(captured)
end;
