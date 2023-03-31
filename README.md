# CompileTraces

[![Build Status](https://github.com/serenity4/CompileTraces.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/serenity4/CompileTraces.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![pkgeval](https://juliahub.com/docs/CompileTraces/pkgeval.svg)](https://juliahub.com/ui/Packages/CompileTraces/FKKWd)
[![Coverage](https://codecov.io/gh/serenity4/CompileTraces.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/serenity4/CompileTraces.jl)
[![deps](https://juliahub.com/docs/CompileTraces/deps.svg)](https://juliahub.com/ui/Packages/CompileTraces/FKKWd?t=2)

Compile traces recorded in a trace file with a uniquely provided function, `compile_traces`.

This function has been extracted from internals of [PackageCompiler.jl](https://github.com/JuliaLang/PackageCompiler.jl) for the most part. The package is intended to be as lightweight as possible:

```julia
julia> @time_imports using CompileTraces
      0.2 ms  CompileTraces
```

## Basic usage

Generate compilation traces by executing code in a Julia process started with the `--trace-compile` option. For example, you can run a script which triggers the compilation paths that you would like to generate traces for.

```bash
julia --trace-compile=/tmp/compiled.jl script.jl
```

For example, `script.jl` could be:

```julia
using Test
using LinearAlgebra

set = @testset "Test set" begin end
display(set)

det(ones(4, 4)) isa Float64
```

Then, in a new session, use this file along with any potential module dependencies that are required in order to compile the code:

```julia
using CompileTraces
using Test, LinearAlgebra # required for precompile statements to succeed

compile_traces("/tmp/compiled.jl")
```

For convenience, `compile_traces` also accepts a list of trace files as first argument, if you want to aggregate multiple traces.

## Use cases

It can be useful to emit traces in a Julia session, compile them in a new session and execute a workload to quickly check that a set of traces completely cover that particular workload.

The end goal for such traces may be to use them in conjunction with [PackageCompiler.jl](https://github.com/JuliaLang/PackageCompiler.jl), to reduce latency using system images. In this case, being able to check traces manually without having to build the system image will lead to faster iterations.

Another intended use case is to generate traces from a script or a test suite, and then compile these traces as part of a package precompilation block. This is very similar to [SnoopPrecompile.jl](https://timholy.github.io/SnoopCompile.jl/dev/snoop_pc/), but without actually having to execute code. This can be useful in environments that require access to devices such as GPUs which may need advanced driver functionalities to be able to trigger certain code paths, or workloads that require access to external running services such as a database which might be only occasionally available or filled with appropriate data to cover all the code paths in a codebase.

For example, executing a workload involving GPU hardware ray-tracing will require a modern GPU with recent drivers, and any strategy (even clever) to conditionally include code based on available GPU features will be a likely point of failure. Using trace files, it is a win-win for both the user, who will have a more stable experience, and the developer who will be free to execute a highly specialized workload in a controlled environment to extend compilation coverage to a maximum.
