# CompileTraces

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://serenity4.github.io/CompileTraces.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://serenity4.github.io/CompileTraces.jl/dev/)
[![Build Status](https://github.com/serenity4/CompileTraces.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/serenity4/CompileTraces.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/serenity4/CompileTraces.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/serenity4/CompileTraces.jl)

Compile traces recorded in a trace file with a uniquely provided function, `compile_traces`.

This function has been extracted from internals of PackageCompiler.jl for the most part.

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
using Test, LinearAlgebra # required for precompile statements to work

compile_traces("/tmp/compiled.jl")
```

For convenience, `compile_traces` also accepts a list of trace files as first argument, if you want to aggregate multiple traces.
