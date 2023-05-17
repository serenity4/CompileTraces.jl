# Changelog for CompileTraces.jl

## Version `v1.2.0`

- ![Feature][badge-feature] A `compile_traces` preference is now looked up to decide whether or not to proceed with compilation in `@compile_traces`, so that trace compilation may be disabled e.g. for the purpose of obtaining fresh traces for a given package.
- ![Feature][badge-feature] An experimental `generate_precompilation_traces` function is now available, which helps automate the generation of precompilation traces for packages by producing traces resulting from running a given package's test suite.
- ![Enhancement][badge-enhancement] The `verbose` option is now set to `false` by default.

[badge-breaking]: https://img.shields.io/badge/BREAKING-red.svg
[badge-deprecation]: https://img.shields.io/badge/deprecation-orange.svg
[badge-feature]: https://img.shields.io/badge/feature-green.svg
[badge-enhancement]: https://img.shields.io/badge/enhancement-blue.svg
[badge-bugfix]: https://img.shields.io/badge/bugfix-purple.svg
[badge-security]: https://img.shields.io/badge/security-black.svg
[badge-experimental]: https://img.shields.io/badge/experimental-lightgrey.svg
[badge-maintenance]: https://img.shields.io/badge/maintenance-gray.svg

<!--
# Badges (reused from the CHANGELOG.md of Documenter.jl)

![BREAKING][badge-breaking]
![Deprecation][badge-deprecation]
![Feature][badge-feature]
![Enhancement][badge-enhancement]
![Bugfix][badge-bugfix]
![Security][badge-security]
![Experimental][badge-experimental]
![Maintenance][badge-maintenance]
-->
