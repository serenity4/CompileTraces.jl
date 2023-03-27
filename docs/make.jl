using CompileTraces
using Documenter

DocMeta.setdocmeta!(CompileTraces, :DocTestSetup, :(using CompileTraces); recursive=true)

makedocs(;
    modules=[CompileTraces],
    authors="Cédric BELMANT",
    repo="https://github.com/serenity4/CompileTraces.jl/blob/{commit}{path}#{line}",
    sitename="CompileTraces.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://serenity4.github.io/CompileTraces.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/serenity4/CompileTraces.jl",
    devbranch="main",
)
