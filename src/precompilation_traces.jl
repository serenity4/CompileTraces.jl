precompile(Tuple{Type{CompileTraces.CompilationMetrics}, Vararg{Int64, 4}})
precompile(Tuple{typeof(Base.repr), CompileTraces.CompilationMetrics})
precompile(Tuple{typeof(Base.show), Base.GenericIOBuffer{Array{UInt8, 1}}, CompileTraces.CompilationMetrics})
precompile(Tuple{typeof(CompileTraces.show_current_status), Base.IOContext{Base.IOStream}, CompileTraces.CompilationMetrics})
precompile(Tuple{typeof(CompileTraces.setup_staging_area), Module})
precompile(Tuple{typeof(CompileTraces.execute_precompile_directives!), CompileTraces.CompilationMetrics, Module, Array{Expr, 1}, Bool, Bool, Bool, Int64})
precompile(Tuple{typeof(CompileTraces.execute_precompile_directive), Tuple{DataType}})
precompile(Tuple{typeof(Base.getproperty), CompileTraces.CompilationMetrics, Symbol})
precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:inline,), Tuple{Bool}}, typeof(CompileTraces.compile_traces), Module, String})
precompile(Tuple{typeof(Base.indexed_iterate), Tuple{Bool, Array{Test.LogRecord, 1}, CompileTraces.CompilationMetrics}, Int64})
precompile(Tuple{typeof(Base.indexed_iterate), Tuple{Bool, Array{Test.LogRecord, 1}, CompileTraces.CompilationMetrics}, Int64, Int64})
precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:verbose, :progress), Tuple{Bool, Bool}}, typeof(CompileTraces.compile_traces), Module, String})
precompile(Tuple{typeof(CompileTraces.show_current_status), Base.IOStream, CompileTraces.CompilationMetrics})
precompile(Tuple{typeof(Base.:(==)), CompileTraces.CompilationMetrics, CompileTraces.CompilationMetrics})
