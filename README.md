# CompileTraces

[![Build Status](https://github.com/serenity4/CompileTraces.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/serenity4/CompileTraces.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![pkgeval](https://juliahub.com/docs/CompileTraces/pkgeval.svg)](https://juliahub.com/ui/Packages/CompileTraces/FKKWd)
[![Coverage](https://codecov.io/gh/serenity4/CompileTraces.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/serenity4/CompileTraces.jl)
[![deps](https://juliahub.com/docs/CompileTraces/deps.svg)](https://juliahub.com/ui/Packages/CompileTraces/FKKWd?t=2)

Compile traces recorded in a trace file with a uniquely provided function, `compile_traces`.

The core functionality was in part extracted from [PackageCompiler.jl](https://github.com/JuliaLang/PackageCompiler.jl) internals. The package was designed to be as lightweight as possible:

```julia
julia> @time_imports using CompileTraces # exports compile_traces, CompilationMetrics
      0.2 ms  CompileTraces
```

## Basic usage

Generate compilation traces by executing code in a Julia process started with the `--trace-compile` option. For example, you can run a script which triggers compilation paths that you would like to generate traces for.

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

Then, in a new session, use this file along with any potential package dependencies that are required in order to compile the code:

```julia
using CompileTraces
using Test, LinearAlgebra # required for precompile statements to succeed

compile_traces(@__MODULE__, "/tmp/compiled.jl")
```

For convenience, `compile_traces` also accepts a list of trace files as first argument, if you want to aggregate multiple traces. Trace files must however have been written with the same format; see the documentation for `compile_traces` with `julia> ?compile_traces` for more information.

If used during precompilation, the first argument to `compile_traces` *must be the package itself*, as it is then forbidden to dynamically evaluate code in other modules.

### Usage with SnoopCompile

If trace files were obtained using `SnoopCompile.parcel` and `SnoopCompile.write`, they must be evaluated in scope of the intended package. For a trace file written at `MyPackage/src/precompile_statements.jl` for a given package `MyPackage`, use the option `inline = true` to execute the precompile directives in the intended scope:

```julia
module MyPackage


# Package code.
# ...

# Compile traces for precompilation.
using CompileTraces: compile_traces
# In addition of `inline = true`, disable all output as this will be
# executed during package precompilation, unless you want some debug
# information for use during local development only.
compile_traces(@__MODULE__, joinpath(@__DIR__, "precompile_statements.jl"); inline = true, verbose = false, progress = false, warn = false)
```

## Use cases

It can be useful to emit traces in a Julia session, compile them in a new session and execute a workload to quickly check that a set of traces completely cover that particular workload.

The end goal for such traces may be to use them in conjunction with [PackageCompiler.jl](https://github.com/JuliaLang/PackageCompiler.jl), to reduce latency using system images. In this case, being able to check traces manually without having to build the system image will lead to faster iterations.

Another intended use case is to generate traces from a script or a test suite, and then compile these traces as part of a package precompilation block. This is very similar to [SnoopPrecompile.jl](https://timholy.github.io/SnoopCompile.jl/dev/snoop_pc/), but without actually having to execute code. This can be useful in environments that require access to devices such as GPUs which may need advanced driver functionalities to be able to trigger certain code paths, or workloads that require access to external running services such as a database which might be only occasionally available or filled with appropriate data to cover all the code paths in a codebase.

For example, executing a workload involving GPU hardware ray-tracing will require a modern GPU with recent drivers, and any strategy (even clever) to conditionally include code based on available GPU features will be a likely point of failure. Using trace files, it is a win-win for both the user, who will have a more stable experience, and the developer who will be free to execute a highly specialized workload in a controlled environment to extend compilation coverage to a maximum.
